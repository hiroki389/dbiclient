use anyhow::{bail, Result};
use std::collections::HashMap;

use super::{DbConn, DbType, EagerCursor, StmtCursor};

/// datasource 文字列 ("DBI:Pg:host=...;dbname=..." 形式) を解析して接続を作成
pub fn connect(
    datasource: &str,
    user: &str,
    pass: &str,
    envdict: &HashMap<String, String>,
    encoding: &str,
) -> Result<Box<dyn DbConn>> {
    // 環境変数を設定
    for (k, v) in envdict {
        // SAFETY: シングルスレッド初期化時のみ呼ばれる
        unsafe { std::env::set_var(k, v) };
    }

    // "DBI:" プレフィックスを除去
    let rest = datasource
        .strip_prefix("DBI:")
        .or_else(|| datasource.strip_prefix("dbi:"))
        .unwrap_or(datasource);

    // ドライバ名を取り出す
    let colon = rest.find(':').unwrap_or(rest.len());
    let driver = &rest[..colon];
    let dsn_body = if colon < rest.len() { &rest[colon + 1..] } else { "" };

    match driver.to_lowercase().as_str() {
        "sqlite" => {
            #[cfg(feature = "sqlite")]
            {
                return super::sqlite::connect(dsn_body, user, pass, encoding);
            }
            #[cfg(not(feature = "sqlite"))]
            bail!("SQLite driver not compiled in (enable feature 'sqlite')");
        }
        "pg" | "postgres" | "postgresql" => {
            #[cfg(feature = "pg")]
            {
                return super::postgres::connect(dsn_body, user, pass, encoding);
            }
            #[cfg(not(feature = "pg"))]
            bail!("PostgreSQL driver not compiled in (enable feature 'pg')");
        }
        "mysql" | "mariadb" => {
            #[cfg(feature = "mysql-db")]
            {
                return super::mysql::connect(dsn_body, user, pass, encoding);
            }
            #[cfg(not(feature = "mysql-db"))]
            bail!("MySQL driver not compiled in (enable feature 'mysql-db')");
        }
        "oracle" => {
            #[cfg(feature = "oracle-native")]
            {
                return super::oracle::connect(dsn_body, user, pass, encoding);
            }
            #[cfg(not(feature = "oracle-native"))]
            {
                // Oracle ODBC としてフォールバック
                #[cfg(feature = "odbc")]
                {
                    let odbc_dsn = format!("DRIVER={{Oracle}};{}", dsn_body);
                    return super::odbc::connect(&odbc_dsn, user, pass, encoding, DbType::Oracle);
                }
                #[cfg(not(feature = "odbc"))]
                bail!("Oracle driver not compiled in");
            }
        }
        "odbc" => {
            #[cfg(feature = "odbc")]
            {
                return super::odbc::connect(dsn_body, user, pass, encoding, DbType::Odbc);
            }
            #[cfg(not(feature = "odbc"))]
            bail!("ODBC driver not compiled in (enable feature 'odbc')");
        }
        other => {
            bail!("Unknown DBI driver: '{}'", other);
        }
    }

    // リンターのために (実際は到達しない)
    #[allow(unreachable_code)]
    bail!("Unreachable")
}

/// テーブル一覧の汎用 SQL ベース実装ヘルパー
pub fn table_info_via_sql(
    conn: &mut dyn DbConn,
    schema: Option<&str>,
    table: Option<&str>,
    table_type: Option<&str>,
    db_type: DbType,
) -> Result<Box<dyn StmtCursor>> {
    let mut conditions = vec!["1=1".to_string()];
    match db_type {
        DbType::Postgres => {
            let schema_cond = schema
                .map(|s| format!("table_schema = '{}'", s.replace('\'', "''")))
                .unwrap_or_else(|| "table_schema NOT IN ('pg_catalog','information_schema')".into());
            conditions.push(schema_cond);
            if let Some(t) = table {
                conditions.push(format!("table_name LIKE '{}'", t.replace('\'', "''")));
            }
            if let Some(tt) = table_type {
                let kind = match tt.to_uppercase().as_str() {
                    "TABLE" => "BASE TABLE",
                    "VIEW" => "VIEW",
                    _ => tt,
                };
                conditions.push(format!("table_type = '{}'", kind));
            }
            let sql = format!(
                "SELECT table_catalog AS \"TABLE_CAT\", t.table_schema AS \"TABLE_SCHEM\", \
                 t.table_name AS \"TABLE_NAME\", t.table_type AS \"TABLE_TYPE\", \
                 obj_description(c.oid, 'pg_class') AS \"REMARKS\" \
                 FROM information_schema.tables t \
                 LEFT JOIN pg_catalog.pg_class c ON c.relname = t.table_name \
                 LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.table_schema \
                 WHERE {} ORDER BY table_name",
                conditions.join(" AND ")
            );
            conn.query(&sql, -1)
        }
        DbType::Mysql => {
            if let Some(s) = schema {
                conditions.push(format!("TABLE_SCHEMA = '{}'", s.replace('\'', "''")));
            }
            if let Some(t) = table {
                conditions.push(format!("TABLE_NAME LIKE '{}'", t.replace('\'', "''")));
            }
            if let Some(tt) = table_type {
                conditions.push(format!("TABLE_TYPE = '{}'", tt.replace('\'', "''")));
            }
            let sql = format!(
                "SELECT TABLE_CATALOG, TABLE_SCHEMA AS TABLE_SCHEM, TABLE_NAME, \
                 TABLE_TYPE, TABLE_COMMENT AS REMARKS \
                 FROM information_schema.tables WHERE {} ORDER BY TABLE_NAME",
                conditions.join(" AND ")
            );
            conn.query(&sql, -1)
        }
        DbType::Sqlite => {
            let mut name_cond = String::new();
            if let Some(t) = table {
                name_cond = format!(" AND name LIKE '{}'", t.replace('\'', "''"));
            }
            let type_cond = match table_type {
                Some(tt) if !tt.is_empty() => {
                    format!(" AND type = '{}'", tt.to_lowercase().replace('\'', "''"))
                }
                _ => " AND type IN ('table','view')".into(),
            };
            let sql = format!(
                "SELECT NULL AS TABLE_CAT, NULL AS TABLE_SCHEM, name AS TABLE_NAME, \
                 upper(type) AS TABLE_TYPE, NULL AS REMARKS \
                 FROM sqlite_master WHERE 1=1{}{} ORDER BY name",
                name_cond, type_cond
            );
            conn.query(&sql, -1)
        }
        DbType::Oracle => {
            let mut obj_conditions = vec!["1=1".to_string()];
            if let Some(s) = schema {
                obj_conditions.push(format!("ao.OWNER = '{}'", s.to_uppercase().replace('\'', "''")));
            }
            if let Some(t) = table {
                obj_conditions.push(format!("ao.OBJECT_NAME LIKE '{}'", t.to_uppercase().replace('\'', "''")));
            }
            // table_type フィルタ: TABLE/VIEW/SYNONYM/MATERIALIZED VIEW に対応
            let type_filter = match table_type {
                Some(tt) if !tt.is_empty() => {
                    let upper = tt.to_uppercase();
                    match upper.as_str() {
                        "TABLE" => " AND OBJECT_TYPE IN ('TABLE','MATERIALIZED VIEW')",
                        "VIEW" => " AND OBJECT_TYPE = 'VIEW'",
                        "SYNONYM" => " AND OBJECT_TYPE = 'SYNONYM'",
                        _ => "",
                    }
                }
                _ => "",
            };
            let sql = format!(
                "SELECT NULL AS TABLE_CAT, ao.OWNER AS TABLE_SCHEM, ao.OBJECT_NAME AS TABLE_NAME, \
                 ao.OBJECT_TYPE AS TABLE_TYPE, tc.COMMENTS AS REMARKS \
                 FROM ALL_OBJECTS ao \
                 LEFT JOIN ALL_TAB_COMMENTS tc ON tc.OWNER = ao.OWNER AND tc.TABLE_NAME = ao.OBJECT_NAME \
                 WHERE ao.OBJECT_TYPE IN ('TABLE','VIEW','SYNONYM','MATERIALIZED VIEW') \
                 AND {} {} ORDER BY ao.OBJECT_NAME",
                obj_conditions.join(" AND "),
                type_filter
            );
            conn.query(&sql, -1)
        }
        DbType::Odbc => {
            // ODBC では専用 API を使うためここには来ない想定だが念のため
            bail!("ODBC table_info should use driver-level implementation")
        }
    }
}

/// プライマリキー取得の汎用 SQL ベース実装ヘルパー
pub fn primary_key_via_sql(
    conn: &mut dyn DbConn,
    schema: Option<&str>,
    table: &str,
    db_type: DbType,
) -> Result<Vec<String>> {
    let sql = match db_type {
        DbType::Postgres => {
            let s = schema.unwrap_or("public");
            format!(
                "SELECT kcu.column_name \
                 FROM information_schema.table_constraints tc \
                 JOIN information_schema.key_column_usage kcu \
                   ON tc.constraint_name=kcu.constraint_name \
                  AND tc.table_schema=kcu.table_schema \
                  AND tc.table_name=kcu.table_name \
                 WHERE tc.constraint_type='PRIMARY KEY' \
                   AND tc.table_schema='{}' AND tc.table_name='{}' \
                 ORDER BY kcu.ordinal_position",
                s.replace('\'', "''"),
                table.replace('\'', "''")
            )
        }
        DbType::Mysql => {
            format!(
                "SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE \
                 WHERE CONSTRAINT_NAME='PRIMARY' AND TABLE_NAME='{}' \
                 ORDER BY ORDINAL_POSITION",
                table.replace('\'', "''")
            )
        }
        DbType::Sqlite => {
            format!(
                "SELECT name FROM pragma_table_info('{}') WHERE pk > 0 ORDER BY pk",
                table.replace('\'', "''")
            )
        }
        DbType::Oracle => {
            let s = schema.unwrap_or("");
            format!(
                "SELECT cols.column_name FROM all_constraints cons, all_cons_columns cols \
                 WHERE cons.constraint_type='P' AND cons.owner='{}' \
                   AND cons.table_name='{}' \
                   AND cons.owner=cols.owner AND cons.constraint_name=cols.constraint_name \
                 ORDER BY cols.position",
                s.to_uppercase().replace('\'', "''"),
                table.to_uppercase().replace('\'', "''")
            )
        }
        DbType::Odbc => {
            bail!("ODBC primary_key should use driver-level implementation")
        }
    };

    let mut cursor = conn.query(&sql, -1)?;
    let mut keys = Vec::new();
    while let Some(row) = cursor.fetch_row() {
        if let Some(Some(col)) = row.into_iter().next() {
            keys.push(col);
        }
    }
    Ok(keys)
}

/// カラム情報の汎用 SQL ベース実装ヘルパー
pub fn column_info_via_sql(
    conn: &mut dyn DbConn,
    schema: Option<&str>,
    table: &str,
    db_type: DbType,
) -> Result<Box<dyn StmtCursor>> {
    let sql = match db_type {
        DbType::Postgres => {
            let s = schema.unwrap_or("public");
            format!(
                "SELECT NULL AS \"TABLE_CAT\", c.table_schema AS \"TABLE_SCHEM\", c.table_name AS \"TABLE_NAME\", \
                 c.column_name AS \"COLUMN_NAME\", c.data_type AS \"TYPE_NAME\", \
                 c.character_maximum_length AS \"COLUMN_SIZE\", \
                 c.numeric_precision AS \"NUM_PREC_RADIX\", \
                 c.is_nullable AS \"IS_NULLABLE\", c.column_default AS \"COLUMN_DEF\", \
                 c.ordinal_position AS \"ORDINAL_POSITION\", \
                 pgd.description AS \"REMARKS\" \
                 FROM information_schema.columns c \
                 LEFT JOIN pg_catalog.pg_statio_all_tables st \
                   ON st.schemaname = c.table_schema AND st.relname = c.table_name \
                 LEFT JOIN pg_catalog.pg_description pgd \
                   ON pgd.objoid = st.relid AND pgd.objsubid = c.ordinal_position \
                 WHERE c.table_schema='{}' AND c.table_name='{}' \
                 ORDER BY c.ordinal_position",
                s.replace('\'', "''"),
                table.replace('\'', "''")
            )
        }
        DbType::Mysql => {
            format!(
                "SELECT NULL AS TABLE_CAT, TABLE_SCHEMA AS TABLE_SCHEM, TABLE_NAME, \
                 COLUMN_NAME, DATA_TYPE AS TYPE_NAME, CHARACTER_MAXIMUM_LENGTH AS COLUMN_SIZE, \
                 NUMERIC_PRECISION AS NUM_PREC_RADIX, IS_NULLABLE, COLUMN_DEFAULT AS COLUMN_DEF, \
                 ORDINAL_POSITION, COLUMN_COMMENT AS REMARKS \
                 FROM information_schema.COLUMNS \
                 WHERE TABLE_NAME='{}' \
                 ORDER BY ORDINAL_POSITION",
                table.replace('\'', "''")
            )
        }
        DbType::Sqlite => {
            let sql = format!(
                "SELECT NULL AS \"TABLE_CAT\", NULL AS \"TABLE_SCHEM\", '{}' AS \"TABLE_NAME\", \
                 name AS \"COLUMN_NAME\", type AS \"TYPE_NAME\", NULL AS \"COLUMN_SIZE\", \
                 NULL AS \"NUM_PREC_RADIX\", \
                 CASE WHEN \"notnull\"=0 THEN 'YES' ELSE 'NO' END AS \"IS_NULLABLE\", \
                 dflt_value AS \"COLUMN_DEF\", cid+1 AS \"ORDINAL_POSITION\", \
                 NULL AS \"REMARKS\" \
                 FROM pragma_table_info('{}') ORDER BY cid",
                table.replace('\'', "''"),
                table.replace('\'', "''")
            );
            return conn.query(&sql, -1);
        }
        DbType::Oracle => {
            let s = schema.unwrap_or("");
            let owner = s.to_uppercase().replace('\'', "''");
            let tbl   = table.to_uppercase().replace('\'', "''");
            format!(
                "SELECT NULL AS TABLE_CAT, c.OWNER AS TABLE_SCHEM, c.TABLE_NAME, \
                 c.COLUMN_NAME, c.DATA_TYPE AS TYPE_NAME, c.DATA_LENGTH AS COLUMN_SIZE, \
                 c.DATA_PRECISION AS NUM_PREC_RADIX, c.NULLABLE AS IS_NULLABLE, \
                 c.DATA_DEFAULT AS COLUMN_DEF, c.COLUMN_ID AS ORDINAL_POSITION, \
                 cc.COMMENTS AS REMARKS \
                 FROM ALL_TAB_COLUMNS c \
                 LEFT JOIN (SELECT COLUMN_NAME, COMMENTS FROM ALL_COL_COMMENTS \
                            WHERE OWNER='{}' AND TABLE_NAME='{}') cc \
                   ON cc.COLUMN_NAME = c.COLUMN_NAME \
                 WHERE c.OWNER='{}' AND c.TABLE_NAME='{}' \
                 ORDER BY c.COLUMN_ID",
                owner, tbl, owner, tbl
            )
        }
        DbType::Odbc => {
            bail!("ODBC column_info should use driver-level implementation")
        }
    };

    conn.query(&sql, -1)
}
