#![cfg(feature = "pg")]

use anyhow::{Context, Result};
use native_tls::TlsConnector;
use postgres::Client;
use postgres_native_tls::MakeTlsConnector;

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

fn parse_pg_sslmode(dsn_body: &str) -> Option<String> {
    dsn_body
        .split(';')
        .filter_map(|kv| kv.split_once('='))
        .find(|(key, _)| key.trim().eq_ignore_ascii_case("sslmode"))
        .map(|(_, value)| value.trim().to_ascii_lowercase())
        .filter(|v| !v.is_empty())
}

fn redact_pg_connstring(connstring: &str) -> String {
    connstring
        .split_whitespace()
        .map(|part| {
            let Some((key, _value)) = part.split_once('=') else {
                return part.to_string();
            };
            if key.eq_ignore_ascii_case("password") {
                format!("{}=<redacted>", key)
            } else {
                part.to_string()
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn preview_sql(sql: &str, max_bytes: usize) -> &str {
    let mut end = max_bytes.min(sql.len());
    while end > 0 && !sql.is_char_boundary(end) {
        end -= 1;
    }
    &sql[..end]
}

fn build_pg_tls_connector(insecure: bool) -> Result<MakeTlsConnector> {
    let mut builder = TlsConnector::builder();
    if insecure {
        builder.danger_accept_invalid_certs(true);
        builder.danger_accept_invalid_hostnames(true);
    }
    let connector = builder.build().context("postgres TLS connector")?;
    Ok(MakeTlsConnector::new(connector))
}

pub fn connect(dsn_body: &str, user: &str, pass: &str, _encoding: &str) -> Result<Box<dyn DbConn>> {
    let cs = build_pg_connstring(dsn_body, user, pass);
    let sslmode = parse_pg_sslmode(dsn_body);
    let redacted_cs = redact_pg_connstring(&cs);

    let mut client = match sslmode.as_deref() {
        None | Some("disable") => {
            Client::connect(&cs, postgres::NoTls).with_context(|| format!("postgres connect: {}", redacted_cs))?
        }
        Some(_) => {
            let tls = build_pg_tls_connector(true)?;
            Client::connect(&cs, tls).with_context(|| format!("postgres connect: {}", redacted_cs))?
        }
    };
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
        .with_context(|| format!("pg query: {}", preview_sql(sql, 80)))?;

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

    if columns.is_empty() {
        let stmt = client
            .prepare(sql)
            .with_context(|| format!("pg prepare for columns: {}", preview_sql(sql, 80)))?;
        columns = stmt.columns().iter().map(|c| c.name().to_string()).collect();
    }

    Ok(Box::new(EagerCursor { columns, rows, pos: 0, affected_rows: 0 }))
}

impl DbConn for PgConn {
    fn db_type(&self) -> DbType {
        DbType::Postgres
    }

    fn execute(&mut self, sql: &str) -> Result<i64> {
        let msgs = self.client.simple_query(sql)
            .with_context(|| format!("pg execute: {}", preview_sql(sql, 80)))?;
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

#[cfg(test)]
mod tests {
    use super::{parse_pg_sslmode, preview_sql, redact_pg_connstring};

    #[test]
    fn preview_sql_keeps_utf8_boundaries() {
        let sql = "SELECT コード, 名称 FROM items";
        assert_eq!(preview_sql(sql, 8), "SELECT ");
        assert_eq!(preview_sql(sql, 10), "SELECT コ");
        assert_eq!(preview_sql(sql, sql.len()), sql);
    }

    #[test]
    fn redact_pg_connstring_hides_password() {
        let cs = "host=192.168.8.133 port=5433 dbname=mydatabase sslmode=require user=prd password=pass";
        let redacted = redact_pg_connstring(cs);
        assert_eq!(
            redacted,
            "host=192.168.8.133 port=5433 dbname=mydatabase sslmode=require user=prd password=<redacted>"
        );
        assert!(!redacted.contains("password=pass"));
    }

    #[test]
    fn parse_pg_sslmode_reads_mode() {
        assert_eq!(parse_pg_sslmode("host=a;sslmode=require;user=b"), Some("require".into()));
        assert_eq!(parse_pg_sslmode("host=a;sslmode=disable"), Some("disable".into()));
        assert_eq!(parse_pg_sslmode("host=a"), None);
    }
}
