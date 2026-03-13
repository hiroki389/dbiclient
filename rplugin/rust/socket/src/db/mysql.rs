#![cfg(feature = "mysql-db")]

use anyhow::{Context, Result};
use mysql::prelude::Queryable;
use mysql::{OptsBuilder, Pool, PooledConn, Value};

use super::{
    factory::{column_info_via_sql, primary_key_via_sql, table_info_via_sql},
    DbConn, DbType, EagerCursor, StmtCursor,
};

pub struct MysqlConn {
    conn: PooledConn,
}

/// "mysql:database=foo;host=bar;port=3306" → OptsBuilder
fn parse_dsn(dsn_body: &str, user: &str, pass: &str) -> OptsBuilder {
    let mut builder = OptsBuilder::new();
    if !user.is_empty() {
        builder = builder.user(Some(user));
    }
    if !pass.is_empty() {
        builder = builder.pass(Some(pass));
    }
    for kv in dsn_body.split(';') {
        let parts: Vec<&str> = kv.splitn(2, '=').collect();
        if parts.len() != 2 {
            continue;
        }
        match parts[0].trim().to_lowercase().as_str() {
            "database" | "dbname" | "db" => {
                builder = builder.db_name(Some(parts[1].trim()));
            }
            "host" | "server" => {
                builder = builder.ip_or_hostname(Some(parts[1].trim()));
            }
            "port" => {
                if let Ok(p) = parts[1].trim().parse::<u16>() {
                    builder = builder.tcp_port(p);
                }
            }
            _ => {}
        }
    }
    builder
}

pub fn connect(dsn_body: &str, user: &str, pass: &str, _encoding: &str) -> Result<Box<dyn DbConn>> {
    let opts = parse_dsn(dsn_body, user, pass);
    let pool = Pool::new(opts).context("mysql pool")?;
    let conn = pool.get_conn().context("mysql get_conn")?;
    Ok(Box::new(MysqlConn { conn }))
}

fn mysql_value_to_string(v: &Value) -> Option<String> {
    match v {
        Value::NULL => None,
        Value::Bytes(b) => Some(String::from_utf8_lossy(b).into_owned()),
        Value::Int(n) => Some(n.to_string()),
        Value::UInt(n) => Some(n.to_string()),
        Value::Float(f) => Some(f.to_string()),
        Value::Double(f) => Some(f.to_string()),
        Value::Date(y, mo, d, h, mi, s, _us) => {
            Some(format!("{:04}-{:02}-{:02} {:02}:{:02}:{:02}", y, mo, d, h, mi, s))
        }
        Value::Time(neg, _d, h, mi, s, _us) => {
            let sign = if *neg { "-" } else { "" };
            Some(format!("{}{:02}:{:02}:{:02}", sign, h, mi, s))
        }
    }
}

impl DbConn for MysqlConn {
    fn db_type(&self) -> DbType {
        DbType::Mysql
    }

    fn execute(&mut self, sql: &str) -> Result<i64> {
        self.conn.query_drop(sql).with_context(|| format!("mysql execute: {}", &sql[..sql.len().min(80)]))?;
        Ok(self.conn.affected_rows() as i64)
    }

    fn query(&mut self, sql: &str, max_rows: i64) -> Result<Box<dyn StmtCursor>> {
        let result = self.conn.query_iter(sql).with_context(|| format!("mysql query: {}", &sql[..sql.len().min(80)]))?;
        let columns: Vec<String> = result.columns().as_ref().iter().map(|c| c.name_str().into_owned()).collect();
        let limit = if max_rows <= 0 { i64::MAX } else { max_rows + 1 };
        let mut rows: Vec<Vec<Option<String>>> = Vec::new();
        let mut count = 0i64;
        for row in result {
            if count >= limit {
                break;
            }
            let row = row.context("mysql fetch row")?;
            let vals: Vec<Option<String>> = row.unwrap().iter().map(mysql_value_to_string).collect();
            rows.push(vals);
            count += 1;
        }
        Ok(Box::new(EagerCursor { columns, rows, pos: 0, affected_rows: 0 }))
    }

    fn table_info_cursor(
        &mut self,
        schema: Option<&str>,
        table: Option<&str>,
        table_type: Option<&str>,
    ) -> Result<Box<dyn StmtCursor>> {
        table_info_via_sql(self, schema, table, table_type, DbType::Mysql)
    }

    fn primary_key_list(&mut self, schema: Option<&str>, table: &str) -> Result<Vec<String>> {
        primary_key_via_sql(self, schema, table, DbType::Mysql)
    }

    fn column_info_cursor(&mut self, schema: Option<&str>, table: &str) -> Result<Box<dyn StmtCursor>> {
        column_info_via_sql(self, schema, table, DbType::Mysql)
    }

    fn commit(&mut self) -> Result<()> {
        self.conn.query_drop("COMMIT").context("mysql commit")?;
        Ok(())
    }

    fn rollback(&mut self) -> Result<()> {
        self.conn.query_drop("ROLLBACK").context("mysql rollback")?;
        Ok(())
    }

    fn disconnect(&mut self) -> Result<()> {
        let _ = self.conn.query_drop("ROLLBACK");
        Ok(())
    }
}
