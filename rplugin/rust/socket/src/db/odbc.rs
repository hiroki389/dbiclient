#![cfg(feature = "odbc")]

use anyhow::{Context, Result};
use odbc_api::{
    buffers::TextRowSet,
    Connection, ConnectionOptions, Cursor, Environment,
};
use std::sync::OnceLock;

use super::{DbConn, DbType, EagerCursor, StmtCursor};

static ODBC_ENV: OnceLock<Environment> = OnceLock::new();

pub struct OdbcConn {
    // SAFETY: ODBC_ENV が 'static なので Connection<'static> が正当
    conn: Connection<'static>,
    db_type: DbType,
}

unsafe impl Send for OdbcConn {}

pub fn connect(dsn: &str, user: &str, pass: &str, _encoding: &str, db_type: DbType) -> Result<Box<dyn DbConn>> {
    let env = ODBC_ENV.get_or_init(|| Environment::new().expect("ODBC Environment"));
    let env_ref: &'static Environment = unsafe { &*(env as *const Environment) };
    let conn = env_ref
        .connect(dsn, user, pass, ConnectionOptions::default())
        .with_context(|| format!("ODBC connect: {}", dsn))?;
    Ok(Box::new(OdbcConn { conn, db_type }))
}

const ODBC_BATCH: usize = 8192;

fn eager_from_cursor(mut cursor: impl Cursor, max_rows: i64) -> Result<Box<dyn StmtCursor>> {
    let columns: Vec<String> = cursor
        .column_names()
        .context("ODBC column_names")?
        .collect::<std::result::Result<Vec<_>, _>>()
        .context("ODBC column_names collect")?;
    let ncols = columns.len();
    if ncols == 0 {
        return Ok(Box::new(EagerCursor { columns, rows: vec![], pos: 0, affected_rows: 0 }));
    }
    let mut buffers = TextRowSet::for_cursor(ODBC_BATCH, &mut cursor, Some(4096))
        .context("ODBC TextRowSet")?;
    let mut row_cursor = cursor.bind_buffer(&mut buffers).context("ODBC bind_buffer")?;

    let limit = if max_rows <= 0 { i64::MAX } else { max_rows + 1 };
    let mut rows: Vec<Vec<Option<String>>> = Vec::new();
    let mut total = 0i64;

    while let Some(batch) = row_cursor.fetch().context("ODBC fetch")? {
        for row_idx in 0..batch.num_rows() {
            if total >= limit {
                break;
            }
            let vals: Vec<Option<String>> = (0..ncols)
                .map(|ci| {
                    batch.at_as_str(ci, row_idx)
                        .ok()
                        .flatten()
                        .map(|s| s.to_owned())
                })
                .collect();
            rows.push(vals);
            total += 1;
        }
        if total >= limit {
            break;
        }
    }
    Ok(Box::new(EagerCursor { columns, rows, pos: 0, affected_rows: 0 }))
}

impl DbConn for OdbcConn {
    fn db_type(&self) -> DbType {
        self.db_type.clone()
    }

    fn execute(&mut self, sql: &str) -> Result<i64> {
        self.conn
            .execute(sql, ())
            .with_context(|| format!("ODBC execute: {}", &sql[..sql.len().min(80)]))?;
        Ok(-1)
    }

    fn query(&mut self, sql: &str, max_rows: i64) -> Result<Box<dyn StmtCursor>> {
        match self.conn.execute(sql, ()).with_context(|| format!("ODBC query: {}", &sql[..sql.len().min(80)]))? {
            Some(cursor) => eager_from_cursor(cursor, max_rows),
            None => Ok(Box::new(EagerCursor { columns: vec![], rows: vec![], pos: 0, affected_rows: 0 })),
        }
    }

    fn table_info_cursor(
        &mut self,
        schema: Option<&str>,
        table: Option<&str>,
        table_type: Option<&str>,
    ) -> Result<Box<dyn StmtCursor>> {
        let cursor = self.conn
            .tables(
                "",
                schema.unwrap_or(""),
                table.unwrap_or(""),
                table_type.unwrap_or(""),
            )
            .context("ODBC tables()")?;
        eager_from_cursor(cursor, -1)
    }

    fn primary_key_list(&mut self, schema: Option<&str>, table: &str) -> Result<Vec<String>> {
        // odbc-api 8 には primary_keys が無いので information_schema を使う
        let sql = format!(
            "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE \
             WHERE CONSTRAINT_NAME='PRIMARY' AND TABLE_NAME='{}' \
             ORDER BY ORDINAL_POSITION",
            table.replace('\'', "''")
        );
        let cursor = match self.conn.execute(&sql, ()).context("ODBC primary_key query")? {
            Some(c) => c,
            None => return Ok(vec![]),
        };
        let mut eager = eager_from_cursor(cursor, -1)?;
        let mut keys = Vec::new();
        while let Some(row) = eager.fetch_row() {
            if let Some(Some(col)) = row.into_iter().next() {
                keys.push(col);
            }
        }
        Ok(keys)
    }

    fn column_info_cursor(&mut self, schema: Option<&str>, table: &str) -> Result<Box<dyn StmtCursor>> {
        let cursor = self.conn
            .columns(
                "",
                schema.unwrap_or(""),
                table,
                "",
            )
            .context("ODBC columns()")?;
        eager_from_cursor(cursor, -1)
    }

    fn commit(&mut self) -> Result<()> {
        self.conn.commit().context("ODBC commit")?;
        Ok(())
    }

    fn rollback(&mut self) -> Result<()> {
        self.conn.rollback().context("ODBC rollback")?;
        Ok(())
    }

    fn disconnect(&mut self) -> Result<()> {
        let _ = self.conn.rollback();
        Ok(())
    }
}
