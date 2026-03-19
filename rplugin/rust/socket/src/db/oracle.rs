#![cfg(feature = "oracle-native")]

use anyhow::{Context, Result};
use oracle::Connection;

use super::{
    factory::{column_info_via_sql, primary_key_via_sql, table_info_via_sql},
    DbConn, DbType, EagerCursor, StmtCursor,
};

pub struct OracleConn {
    conn: Connection,
}

pub fn connect(dsn_body: &str, user: &str, pass: &str, _encoding: &str) -> Result<Box<dyn DbConn>> {
    let conn = Connection::connect(user, pass, dsn_body).context("Oracle connect")?;
    Ok(Box::new(OracleConn { conn }))
}

fn run_query(conn: &Connection, sql: &str, max_rows: i64) -> Result<Box<dyn StmtCursor>> {
    let mut stmt = conn.statement(sql).build().context("Oracle prepare")?;
    let rows_obj = stmt.query(&[])?;
    let columns: Vec<String> = rows_obj
        .column_info()
        .iter()
        .map(|c| c.name().to_string())
        .collect();
    let limit = if max_rows <= 0 { i64::MAX } else { max_rows + 1 };
    let mut rows: Vec<Vec<Option<String>>> = Vec::new();
    let mut count = 0i64;
    for row_result in rows_obj {
        if count >= limit {
            break;
        }
        let row = row_result.context("Oracle fetch")?;
        let ncols = columns.len();
        let vals: Vec<Option<String>> = (0..ncols)
            .map(|i| row.get::<_, Option<String>>(i).unwrap_or(None))
            .collect();
        rows.push(vals);
        count += 1;
    }
    Ok(Box::new(EagerCursor { columns, rows, pos: 0, affected_rows: 0 }))
}

impl DbConn for OracleConn {
    fn db_type(&self) -> DbType {
        DbType::Oracle
    }

    fn execute(&mut self, sql: &str) -> Result<i64> {
        let mut stmt = self.conn.statement(sql).build()
            .with_context(|| format!("Oracle prepare: {}", &sql[..sql.len().min(80)]))?;
        stmt.execute(&[])?;
        let n = stmt.row_count().unwrap_or(0);
        Ok(n as i64)
    }

    fn query(&mut self, sql: &str, max_rows: i64) -> Result<Box<dyn StmtCursor>> {
        run_query(&self.conn, sql, max_rows)
    }

    fn table_info_cursor(
        &mut self,
        schema: Option<&str>,
        table: Option<&str>,
        table_type: Option<&str>,
    ) -> Result<Box<dyn StmtCursor>> {
        table_info_via_sql(self, schema, table, table_type, DbType::Oracle)
    }

    fn primary_key_list(&mut self, schema: Option<&str>, table: &str) -> Result<Vec<String>> {
        primary_key_via_sql(self, schema, table, DbType::Oracle)
    }

    fn column_info_cursor(&mut self, schema: Option<&str>, table: &str) -> Result<Box<dyn StmtCursor>> {
        column_info_via_sql(self, schema, table, DbType::Oracle)
    }

    fn commit(&mut self) -> Result<()> {
        self.conn.commit().context("Oracle commit")
    }

    fn rollback(&mut self) -> Result<()> {
        self.conn.rollback().context("Oracle rollback")
    }

    fn disconnect(&mut self) -> Result<()> {
        let _ = self.conn.rollback();
        Ok(())
    }

    fn dbms_output_enable(&mut self, size: u32) {
        let sql = format!("BEGIN DBMS_OUTPUT.ENABLE({}); END;", size);
        let _ = self.conn.execute(&sql, &[]);
    }

    fn dbms_output_get(&mut self) -> Vec<String> {
        let mut result = Vec::new();
        loop {
            let mut stmt = match self.conn.statement(
                "DECLARE v_line VARCHAR2(32767); v_status INTEGER; \
                 BEGIN DBMS_OUTPUT.GET_LINE(v_line, v_status); \
                 :1 := v_line; :2 := v_status; END;"
            ).build() {
                Ok(s) => s,
                Err(_) => break,
            };
            // bind OUT params: positional index 1, 2
            if stmt.bind(1usize, &oracle::sql_type::OracleType::Varchar2(32767)).is_err() { break; }
            if stmt.bind(2usize, &oracle::sql_type::OracleType::Number(10, 0)).is_err() { break; }
            if stmt.execute(&[]).is_err() { break; }
            let status: i32 = stmt.bind_value(2usize).unwrap_or(1);
            if status != 0 {
                break;
            }
            let line: Option<String> = stmt.bind_value(1usize).unwrap_or(None);
            if let Some(l) = line {
                result.push(l);
            }
        }
        result
    }
}
