#![cfg(feature = "pg")]

use anyhow::{Context, Result};
use postgres::{Client, NoTls};

use super::{
    factory::{column_info_via_sql, primary_key_via_sql, table_info_via_sql},
    DbConn, DbType, EagerCursor, StmtCursor,
};

pub struct PgConn {
    client: Client,
}

/// "Pg:dbname=foo;host=bar;port=5432" → "dbname=foo host=bar port=5432"
fn build_pg_connstring(dsn_body: &str, user: &str, pass: &str) -> String {
    let mut parts: Vec<String> = dsn_body
        .split(';')
        .filter(|s| !s.is_empty())
        .map(|kv| kv.replace(';', " "))
        .collect();
    if !user.is_empty() {
        parts.push(format!("user={}", user));
    }
    if !pass.is_empty() {
        parts.push(format!("password={}", pass));
    }
    parts.join(" ")
}

pub fn connect(dsn_body: &str, user: &str, pass: &str, _encoding: &str) -> Result<Box<dyn DbConn>> {
    let cs = build_pg_connstring(dsn_body, user, pass);
    let mut client = Client::connect(&cs, NoTls).with_context(|| format!("postgres connect: {}", cs))?;
    // Perl の AutoCommit=0 に相当: 明示的トランザクション開始
    client.simple_query("BEGIN").context("pg BEGIN")?;
    Ok(Box::new(PgConn { client }))
}

/// simple_query を使ってすべての型を文字列として受け取る
/// TIMESTAMP / DATE / NUMERIC など特殊型のバイナリデコードが不要になる
fn simple_query_to_cursor(
    client: &mut Client,
    sql: &str,
    max_rows: i64,
) -> Result<Box<dyn StmtCursor>> {
    use postgres::SimpleQueryMessage;
    let msgs = client
        .simple_query(sql)
        .with_context(|| format!("pg query: {}", &sql[..sql.len().min(80)]))?;

    let limit = if max_rows <= 0 { usize::MAX } else { (max_rows + 1) as usize };
    let mut columns: Vec<String> = vec![];
    let mut rows: Vec<Vec<Option<String>>> = vec![];

    for msg in msgs {
        match msg {
            SimpleQueryMessage::Row(row) => {
                if columns.is_empty() {
                    columns = row.columns().iter().map(|c| c.name().to_string()).collect();
                }
                if rows.len() < limit {
                    let vals: Vec<Option<String>> =
                        (0..row.len()).map(|i| row.get(i).map(|s| s.to_string())).collect();
                    rows.push(vals);
                }
            }
            _ => {}
        }
    }

    Ok(Box::new(EagerCursor { columns, rows, pos: 0, affected_rows: 0 }))
}

impl DbConn for PgConn {
    fn db_type(&self) -> DbType {
        DbType::Postgres
    }

    fn execute(&mut self, sql: &str) -> Result<i64> {
        let msgs = self.client.simple_query(sql)
            .with_context(|| format!("pg execute: {}", &sql[..sql.len().min(80)]))?;
        // CommandComplete メッセージから影響行数を取得
        let n = msgs.iter().find_map(|m| {
            if let postgres::SimpleQueryMessage::CommandComplete(n) = m { Some(*n as i64) } else { None }
        }).unwrap_or(0);
        Ok(n)
    }

    fn query(&mut self, sql: &str, max_rows: i64) -> Result<Box<dyn StmtCursor>> {
        simple_query_to_cursor(&mut self.client, sql, max_rows)
    }

    fn table_info_cursor(
        &mut self,
        schema: Option<&str>,
        table: Option<&str>,
        table_type: Option<&str>,
    ) -> Result<Box<dyn StmtCursor>> {
        table_info_via_sql(self, schema, table, table_type, DbType::Postgres)
    }

    fn primary_key_list(&mut self, schema: Option<&str>, table: &str) -> Result<Vec<String>> {
        primary_key_via_sql(self, schema, table, DbType::Postgres)
    }

    fn column_info_cursor(&mut self, schema: Option<&str>, table: &str) -> Result<Box<dyn StmtCursor>> {
        column_info_via_sql(self, schema, table, DbType::Postgres)
    }

    fn commit(&mut self) -> Result<()> {
        self.client.simple_query("COMMIT").context("pg commit")?;
        self.client.simple_query("BEGIN").context("pg BEGIN after commit")?;
        Ok(())
    }

    fn rollback(&mut self) -> Result<()> {
        self.client.simple_query("ROLLBACK").context("pg rollback")?;
        self.client.simple_query("BEGIN").context("pg BEGIN after rollback")?;
        Ok(())
    }

    fn disconnect(&mut self) -> Result<()> {
        let _ = self.client.simple_query("ROLLBACK");
        Ok(())
    }
}
