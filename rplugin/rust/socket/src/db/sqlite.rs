#![cfg(feature = "sqlite")]

use anyhow::{Context, Result};
use rusqlite::{types::ValueRef, Connection};

use super::{
    factory::{column_info_via_sql, primary_key_via_sql, table_info_via_sql},
    DbConn, DbType, EagerCursor, StmtCursor,
};

pub struct SqliteConn {
    conn: Connection,
    encoding: String,
}

pub fn connect(dsn_body: &str, _user: &str, _pass: &str, encoding: &str) -> Result<Box<dyn DbConn>> {
    // DSN body: "dbname=/path/to/file" or ":memory:" or just the path
    let path = if let Some(rest) = dsn_body.strip_prefix("dbname=") {
        rest.trim().to_string()
    } else if dsn_body.is_empty() {
        ":memory:".to_string()
    } else {
        dsn_body.to_string()
    };

    let conn = Connection::open(&path).with_context(|| format!("SQLite open: {}", path))?;
    Ok(Box::new(SqliteConn {
        conn,
        encoding: encoding.to_string(),
    }))
}

fn cell_to_string(v: ValueRef) -> Option<String> {
    match v {
        ValueRef::Null => None,
        ValueRef::Integer(n) => Some(n.to_string()),
        ValueRef::Real(f) => Some(f.to_string()),
        ValueRef::Text(s) => Some(String::from_utf8_lossy(s).into_owned()),
        ValueRef::Blob(b) => Some(format!("<blob:{}>", b.len())),
    }
}

fn run_query(conn: &Connection, sql: &str, max_rows: i64) -> Result<Box<dyn StmtCursor>> {
    let mut stmt = conn.prepare(sql).with_context(|| format!("prepare: {}", &sql[..sql.len().min(80)]))?;
    let col_count = stmt.column_count();
    let columns: Vec<String> = (0..col_count)
        .map(|i| stmt.column_name(i).unwrap_or("?").to_string())
        .collect();

    let mut rows: Vec<Vec<Option<String>>> = Vec::new();
    let mut raw = stmt.query([]).context("query")?;
    let limit = if max_rows <= 0 { i64::MAX } else { max_rows + 1 };
    let mut count = 0i64;
    while let Some(row) = raw.next().context("fetch row")? {
        if count >= limit {
            break;
        }
        let vals: Vec<Option<String>> = (0..col_count).map(|i| cell_to_string(row.get_ref_unwrap(i))).collect();
        rows.push(vals);
        count += 1;
    }

    Ok(Box::new(EagerCursor {
        columns,
        rows,
        pos: 0,
        affected_rows: 0,
    }))
}

impl DbConn for SqliteConn {
    fn db_type(&self) -> DbType {
        DbType::Sqlite
    }

    fn execute(&mut self, sql: &str) -> Result<i64> {
        let n = self.conn.execute(sql, []).with_context(|| format!("execute: {}", &sql[..sql.len().min(80)]))?;
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
        table_info_via_sql(self, schema, table, table_type, DbType::Sqlite)
    }

    fn primary_key_list(&mut self, schema: Option<&str>, table: &str) -> Result<Vec<String>> {
        primary_key_via_sql(self, schema, table, DbType::Sqlite)
    }

    fn column_info_cursor(&mut self, schema: Option<&str>, table: &str) -> Result<Box<dyn StmtCursor>> {
        column_info_via_sql(self, schema, table, DbType::Sqlite)
    }

    fn commit(&mut self) -> Result<()> {
        self.conn.execute_batch("COMMIT; BEGIN").context("commit")?;
        Ok(())
    }

    fn rollback(&mut self) -> Result<()> {
        self.conn.execute_batch("ROLLBACK; BEGIN").context("rollback")?;
        Ok(())
    }

    fn disconnect(&mut self) -> Result<()> {
        let _ = self.conn.execute_batch("ROLLBACK");
        Ok(())
    }
}
