use anyhow::Result;
use serde_json::{json, Map, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Instant;

use crate::cache::{cursor_to_rows, sha256_prefix, MetaCache};
use crate::db::{DbConn, DbType};
use crate::exec_sql::{exec_sql, now_ms, ExecSqlResult};
use crate::logging::{getdatetime, outputlog};

pub struct DbState {
    pub conn: Option<Box<dyn DbConn>>,
    pub datasource: String,
    pub user: String,
    pub pass: String,
    pub limitrows: i64,
    pub db_encoding: String,
    pub primary_key_flg: bool,
    pub column_info_flg: bool,
    pub schema_list: Vec<String>,
    pub sha256sum: String,
}

impl DbState {
    pub fn new() -> Self {
        DbState {
            conn: None,
            datasource: String::new(),
            user: String::new(),
            pass: String::new(),
            limitrows: -1,
            db_encoding: "utf-8".into(),
            primary_key_flg: false,
            column_info_flg: false,
            schema_list: vec![],
            sha256sum: String::new(),
        }
    }

    pub fn disconnect(&mut self) {
        if let Some(ref mut c) = self.conn {
            let _ = c.rollback();
            let _ = c.disconnect();
        }
        self.conn = None;
    }

    pub fn is_oracle(&self) -> bool {
        self.conn.as_ref().map(|c| c.db_type() == DbType::Oracle).unwrap_or(false)
    }

    pub fn is_odbc(&self) -> bool {
        self.conn.as_ref().map(|c| c.db_type() == DbType::Odbc).unwrap_or(false)
    }
}

/// メインのリクエスト処理 (Perl の rutine 相当)
/// 返り値: (result JSON object, exit_flag)
pub fn handle_request(
    data: &Value,
    db: &mut DbState,
    tempfile: &Path,
    basedir: &Path,
    port: u16,
    vim_encoding: &str,
    cancel_flag: &Arc<AtomicBool>,
) -> Value {
    let start_dt = getdatetime();
    let mut result = json!({ "startdate": start_dt, "status": 1 });

    let exec_start = Instant::now();

    let mut outputlines: Vec<String> = Vec::new();

    // tempfile のエラーファイルへ stderr をリダイレクト (Rust では単純にキャプチャ)
    let err_path = PathBuf::from(format!("{}.err", tempfile.display()));

    let run_result = run_main(
        data,
        db,
        tempfile,
        basedir,
        port,
        vim_encoding,
        cancel_flag,
        &exec_start,
        &mut outputlines,
        &mut result,
    );

    if let Err(e) = run_result {
        let msg = clean_error_message(&e.to_string());
        outputlog(&msg, Some(port));
        outputlines.push(msg.clone());
        // Oracle DBMS_OUTPUT
        if let Some(ref mut conn) = db.conn {
            for line in conn.dbms_output_get() {
                outputlines.push(format!("DBMS_OUTPUT_GET:{}", line));
            }
        }
        result["status"] = json!(9);
    }

    // outputlines を tempfile に書く
    let lines_text = outputlines.join("\n");
    if !lines_text.is_empty() {
        use std::fs::OpenOptions;
        use std::io::Write;
        if let Ok(mut f) = OpenOptions::new().append(true).create(true).open(tempfile) {
            let _ = f.write_all(lines_text.as_bytes());
        }
    }

    // 空のエラーファイルを削除
    if err_path.exists() {
        if let Ok(meta) = std::fs::metadata(&err_path) {
            if meta.len() == 0 {
                let _ = std::fs::remove_file(&err_path);
            }
        }
    }

    result["enddate"] = json!(getdatetime());
    result
}

fn clean_error_message(msg: &str) -> String {
    // Perl の `$message =~ s/ at ((?! at ).)*\Z//m;` に相当
    // "... at file.pl line N" を末尾から除去
    if let Some(pos) = msg.rfind(" at ") {
        msg[..pos].to_string()
    } else {
        msg.to_string()
    }
}

fn run_main(
    data: &Value,
    db: &mut DbState,
    tempfile: &Path,
    basedir: &Path,
    port: u16,
    vim_encoding: &str,
    cancel_flag: &Arc<AtomicBool>,
    exec_start: &Instant,
    outputlines: &mut Vec<String>,
    result: &mut Value,
) -> Result<()> {
    if db.conn.is_none() {
        return Err(anyhow::anyhow!("Not connected"));
    }

    // Perl の rutine() と同様に、リクエストデータをそのままレスポンスに含める
    // Vim は result.data.callbackstr でコールバックを発火させるため必須
    result["data"] = data.clone();

    // limitrows の更新
    if let Some(lr) = data["limitrows"].as_i64() {
        db.limitrows = lr;
    }

    // ROLLBACK
    if data.get("rollback").is_some() {
        db.conn.as_mut().unwrap().rollback()?;
        result["rollback"] = json!(1);
        return Ok(());
    }

    // setkey / setvalue
    if data.get("setkey").is_some() && data.get("setvalue").is_some() {
        outputlog(
            &format!("SETKEY: {} = {}", data["setkey"], data["setvalue"]),
            Some(port),
        );
        return Ok(());
    }

    // COMMIT
    if data.get("commit").is_some() {
        db.conn.as_mut().unwrap().commit()?;
        result["commit"] = json!(1);
        return Ok(());
    }

    // CLOSE (disconnect)
    if data.get("close").is_some() {
        db.conn.as_mut().unwrap().rollback().ok();
        result["rollback"] = json!(1);
        return Ok(());
    }

    // DO: DML バッチ実行
    if let Some(sqls) = data["do"].as_array().cloned() {
        let continue_on_err = data["continue"].as_i64().unwrap_or(0) != 0;
        db.conn.as_mut().unwrap().set_long_read_len(102400);
        let start_time = Instant::now();

        for sql_val in &sqls {
            let sql_raw = match sql_val.as_str() {
                Some(s) => s,
                None => continue,
            };
            let sql = normalize_newlines(sql_raw);
            let lsql = compact_sql(&sql);
            if lsql.is_empty() {
                continue;
            }

            let loop_start_dt = getdatetime();
            let loop_start = Instant::now();

            outputlog(&format!("UPDATE START({})", db.user), Some(port));
            outputlog(&format!("SQL: {}", &lsql[..lsql.len().min(100)]), Some(port));

            let conn = db.conn.as_mut().unwrap();
            conn.dbms_output_enable(1_000_000);

            let exec_result = conn.execute(&sql);
            let rv = match exec_result {
                Ok(n) => {
                    outputlog(&format!("UPDATE END COUNT({})", n), Some(port));
                    n.to_string()
                }
                Err(e) => {
                    if !cancel_flag.load(Ordering::Relaxed) && !continue_on_err {
                        return Err(e);
                    }
                    outputlog(&format!("UPDATE ERROR: {}", e), Some(port));
                    "error".to_string()
                }
            };

            let elapsed_ms = loop_start.elapsed().as_millis() as i64;
            outputlines.push(format!(
                "{}({}ms) {} updated. \"{}\"",
                loop_start_dt, elapsed_ms, rv, lsql
            ));

            // DBMS_OUTPUT
            let conn = db.conn.as_mut().unwrap();
            for line in conn.dbms_output_get() {
                outputlines.push(format!("DBMS_OUTPUT_GET:{}", line));
                outputlog(&format!("DBMS_OUTPUT_LINE:{}", line), Some(port));
            }

            result["sqltime"] = json!(start_time.elapsed().as_millis() as i64);
        }
        return Ok(());
    }

    // SELECT / table_info / column_info / column_info_data
    // Perl の $user 相当: Oracle は大文字のユーザー名をスキーマとして使う
    // 非Oracle は undef ($user=undef for !$g_oracleflg) → スキーマ検索なし（全スキーマ）
    let user_str: String = if db.is_oracle() {
        db.user.to_uppercase()
    } else {
        String::new()
    };
    db.conn.as_mut().unwrap().set_long_read_len(102400);

    // ---- SELECT ----
    if let Some(sql_val) = data.get("sql") {
        let sql_raw = sql_val.as_str().unwrap_or("");
        if sql_raw.is_empty() {
            // table_info == 1 や column_info == 1 への継続を防ぐため早期リターン
        } else {
            let sql = normalize_newlines(sql_raw);
            let lsql = compact_sql(&sql);
            if lsql.is_empty() {
                return Ok(());
            }

            let loop_start_dt = getdatetime();
            let loop_start = Instant::now();

            let table_join_nm: Vec<String> = data["tableJoinNm"]
                .as_str()
                .unwrap_or("")
                .split_whitespace()
                .map(|s| s.to_string())
                .collect();

            let conn = db.conn.as_mut().unwrap();
            conn.dbms_output_enable(1_000_000);

            outputlog(&format!("SQL: {}", &lsql[..lsql.len().min(100)]), Some(port));

            let sql_start = Instant::now();
            let limitrows = db.limitrows;
            let mut cursor = conn.query(&sql, limitrows)?;
            result["sqltime"] = json!(sql_start.elapsed().as_millis() as i64);
            drop(conn);  // 以降で db を可変借用するため解放

            let exec_result = exec_sql(
                &mut cursor,
                tempfile,
                data,
                port,
                limitrows,
                cancel_flag,
                sql_start.elapsed().as_millis() as i64,
                false,
            )?;

            apply_exec_result(&exec_result, result);

            if exec_result.status == 2 {
                outputlines.push(format!(
                    "{}({}ms) {} updated. \"{}\"",
                    loop_start_dt,
                    loop_start.elapsed().as_millis() as i64,
                    exec_result.cnt,
                    lsql
                ));
            }

            // DBMS_OUTPUT
            let conn = db.conn.as_mut().unwrap();
            for line in conn.dbms_output_get() {
                outputlines.push(format!("DBMS_OUTPUT_GET:{}", line));
                outputlog(&format!("DBMS_OUTPUT_LINE:{}", line), Some(port));
            }

            // メタデータ取得 (テーブル一覧・PK・カラム情報)
            let col_start = Instant::now();
            let schem_raw = data["schem"].as_str().unwrap_or("").to_string();
            let schem_str: Option<String> = if schem_raw.is_empty() {
                if user_str.is_empty() { None } else { Some(user_str.clone()) }
            } else {
                Some(schem_raw.clone())
            };
            let schema_list = build_schema_list(schem_str.as_deref(), &db.schema_list.clone());

            result["primary_key"] = json!([]);
            result["table_info"] = json!([]);
            result["column_info"] = json!([]);

            if table_join_nm.len() <= 20 {
                for table_entry in &table_join_nm.clone() {
                    fetch_table_metadata(
                        db,
                        basedir,
                        table_entry,
                        &schema_list,
                        exec_result.status == 1,
                        result,
                        port,
                    );
                    if !result["table_info"].as_array().map(|a| a.is_empty()).unwrap_or(true) {
                        break;
                    }
                }
            }

            result["columntime"] = json!(col_start.elapsed().as_millis() as i64);
            return Ok(());
        }
    }

    // ---- table_info ----
    if data["table_info"].as_i64().unwrap_or(0) == 1 {
        let table_nm = data["table_name"].as_str().filter(|s| !s.trim().is_empty());
        let table_type = data["tabletype"].as_str().filter(|s| !s.trim().is_empty());
        let table_schem_str: Option<String> = if db.is_odbc()
            || db.conn.as_ref().map(|c| c.db_type() == DbType::Postgres).unwrap_or(false)
        {
            Some("public".to_string())
        } else {
            user_str.clone().into()
        };
        let table_schem_str = table_schem_str.filter(|s| !s.is_empty());
        let table_schem = table_schem_str.as_deref();

        outputlog("SQL: TABLE_INFO", Some(port));
        let conn = db.conn.as_mut().unwrap();
        let sql_start = Instant::now();
        let mut cursor = conn.table_info_cursor(table_schem, table_nm, table_type)?;
        result["sqltime"] = json!(sql_start.elapsed().as_millis() as i64);

        let limitrows = db.limitrows;
        let exec_result = exec_sql(
            &mut cursor,
            tempfile,
            data,
            port,
            limitrows,
            cancel_flag,
            sql_start.elapsed().as_millis() as i64,
            false,
        )?;
        apply_exec_result(&exec_result, result);
        return Ok(());
    }

    // ---- column_info_data ----
    if data["column_info_data"].as_i64().unwrap_or(0) == 1 {
        let table = data["tableNm"].as_str().unwrap_or("").to_string();
        outputlog(&format!("SQL: COLUMN_INFO_DATA({})", table), Some(port));
        let schem_raw = data["schem"].as_str().unwrap_or("");
        let schem_str: Option<String> = if schem_raw.is_empty() {
            if user_str.is_empty() { None } else { Some(user_str.clone()) }
        } else {
            Some(schem_raw.to_string())
        };
        let schema_list = build_schema_list(schem_str.as_deref(), &db.schema_list.clone());

        result["primary_key"] = json!([]);
        result["table_info"] = json!([]);
        result["column_info"] = json!([]);

        for schem2 in &schema_list.clone() {
            let schem2_opt = opt_schema(schem2.as_str());
            fetch_full_metadata(db, basedir, &table, schem_str.as_deref(), schem2_opt, true, true, result, port);
            if !result["table_info"].as_array().map(|a| a.is_empty()).unwrap_or(true) {
                break;
            }
        }
        outputlog(&format!("SQL: COLUMN_INFO_DATA({}) END", table), Some(port));
        return Ok(());
    }

    // ---- column_info ----
    if data["column_info"].as_i64().unwrap_or(0) == 1 {
        let table = data["tableNm"].as_str().unwrap_or("").to_string();
        let schem_raw = data["schem"].as_str().unwrap_or("");
        let schem_str: Option<String> = if schem_raw.is_empty() {
            if user_str.is_empty() { None } else { Some(user_str.clone()) }
        } else {
            Some(schem_raw.to_string())
        };
        let schema_list = build_schema_list(schem_str.as_deref(), &db.schema_list.clone());

        result["primary_key"] = json!([]);

        for schem2 in &schema_list.clone() {
            let schem2_opt = opt_schema(schem2.as_str());

            // テーブル存在確認
            let tinfo = fetch_table_info_cached(db, basedir, &table, schem_str.as_deref(), schem2_opt, port);
            if tinfo.is_empty() {
                continue;
            }

            // PK 取得
            let pk = fetch_pk_cached(db, basedir, &table, schem_str.as_deref(), schem2_opt, port);
            if !pk.is_empty() {
                result["primary_key"] = json!(pk);
            }

            // column_info カーソル → exec_sql
            outputlog(&format!("SQL: COLUMN_INFO({})", table), Some(port));
            let conn = db.conn.as_mut().unwrap();
            let sql_start = Instant::now();
            let mut cursor = match conn.column_info_cursor(schem2_opt, &table) {
                Ok(c) => c,
                Err(e) => {
                    outputlog(&format!("column_info error: {}", e), Some(port));
                    continue;
                }
            };
            result["sqltime"] = json!(sql_start.elapsed().as_millis() as i64);

            let limitrows = db.limitrows;
            let exec_result = exec_sql(
                &mut cursor,
                tempfile,
                data,
                port,
                limitrows,
                cancel_flag,
                sql_start.elapsed().as_millis() as i64,
                false,
            )?;
            apply_exec_result(&exec_result, result);

            if exec_result.cnt > 0 {
                break;
            }
        }
        return Ok(());
    }

    Ok(())
}

fn apply_exec_result(r: &ExecSqlResult, result: &mut Value) {
    result["status"] = json!(r.status);
    result["cnt"] = json!(r.cnt);
    result["hasnext"] = json!(if r.has_next { 1 } else { 0 });
    result["sqltime"] = json!(r.sql_time_ms);
    result["fetchtime"] = json!(r.fetch_time_ms);
    result["startfetch"] = json!(r.start_fetch.clone());
    result["cols"] = json!(r.cols);
    result["maxcols"] = json!(r.maxcols);
    result["colsindex"] = json!(r.colsindex);
}

fn normalize_newlines(s: &str) -> String {
    s.replace("\r\n", "\n").replace('\r', "\n")
}

fn compact_sql(s: &str) -> String {
    let mut result = s.replace('\t', " ").replace('\n', " ");
    while result.contains("  ") {
        result = result.replace("  ", " ");
    }
    result.trim_start().to_string()
}

fn build_schema_list(schem: Option<&str>, extra: &[String]) -> Vec<String> {
    let mut list: Vec<String> = Vec::new();
    // 大文字小文字を無視して重複排除
    let already = |list: &Vec<String>, s: &str| {
        let lower = s.to_lowercase();
        list.iter().any(|x| x.to_lowercase() == lower)
    };

    if let Some(s) = schem {
        if !s.is_empty() && !already(&list, s) {
            list.push(s.to_string());
        }
    }
    for s in extra {
        if !s.is_empty() && !already(&list, s) {
            list.push(s.clone());
        }
    }
    // リストが空でも最低1回はループを回す（schema=None で全スキーマ検索）
    if list.is_empty() {
        list.push(String::new());
    }
    list
}

fn opt_schema(s: &str) -> Option<&str> {
    if s.is_empty() { None } else { Some(s) }
}

fn fetch_table_metadata(
    db: &mut DbState,
    basedir: &Path,
    table_entry: &str,
    schema_list: &[String],
    fetch_column_info: bool,
    result: &mut Value,
    port: u16,
) {
    // schema.table 形式を分解
    let (forced_schema, table_name) = if let Some(dot) = table_entry.find('.') {
        (Some(&table_entry[..dot]), &table_entry[dot + 1..])
    } else {
        (None, table_entry)
    };

    let schemas: Vec<String> = if let Some(fs) = forced_schema {
        vec![fs.to_string(), fs.to_uppercase()]
    } else {
        schema_list.to_vec()
    };

    for schem2 in &schemas {
        let user_schem_str = db.user.clone();
        let user_schem = opt_schema(&user_schem_str);
        let schem2_opt = opt_schema(schem2.as_str());
        let tinfo = fetch_table_info_cached(db, basedir, table_name, user_schem, schem2_opt, port);
        if tinfo.is_empty() {
            continue;
        }
        // table_info に追加
        if let Value::Array(arr) = &mut result["table_info"] {
            for row in &tinfo {
                arr.push(json!(row));
            }
        }

        // PK 取得
        if db.primary_key_flg {
            let pk = fetch_pk_cached(db, basedir, table_name, user_schem, schem2_opt, port);
            if let Value::Array(arr) = &mut result["primary_key"] {
                for k in &pk {
                    arr.push(json!(k));
                }
            }
        }

        // カラム情報取得
        if fetch_column_info && db.column_info_flg {
            let cinfo = fetch_column_info_cached(db, basedir, table_name, user_schem, schem2_opt, port);
            if let Value::Array(arr) = &mut result["column_info"] {
                for row in &cinfo {
                    arr.push(json!(row));
                }
            }
        }

        break;
    }
}

fn fetch_full_metadata(
    db: &mut DbState,
    basedir: &Path,
    table: &str,
    schem: Option<&str>,
    schem2: Option<&str>,
    fetch_pk: bool,
    fetch_col: bool,
    result: &mut Value,
    port: u16,
) {
    let user_schem = schem;

    let tinfo = fetch_table_info_cached(db, basedir, table, user_schem, schem2, port);
    if tinfo.is_empty() {
        return;
    }

    if let Value::Array(arr) = &mut result["table_info"] {
        for row in &tinfo {
            arr.push(json!(row));
        }
    }

    if fetch_pk {
        let pk = fetch_pk_cached(db, basedir, table, user_schem, schem2, port);
        if let Value::Array(arr) = &mut result["primary_key"] {
            for k in &pk {
                arr.push(json!(k));
            }
        }
    }

    if fetch_col {
        let cinfo = fetch_column_info_cached(db, basedir, table, user_schem, schem2, port);
        if let Value::Array(arr) = &mut result["column_info"] {
            for row in &cinfo {
                arr.push(json!(row));
            }
        }
    }
}

fn fetch_table_info_cached(
    db: &mut DbState,
    basedir: &Path,
    table: &str,
    schem: Option<&str>,
    schem2: Option<&str>,
    port: u16,
) -> Vec<serde_json::Map<String, Value>> {
    // キャッシュキーは実際に照会するスキーマ(schem2)を使用
    let cache_schem = schem2.or(schem);
    let cache = MetaCache::new(basedir, cache_schem, &db.user, table, &db.sha256sum);
    if let Some(rows) = cache.load_tkey() {
        return rows.into_iter().map(|m| m.into_iter().collect()).collect();
    }

    let conn = match db.conn.as_mut() {
        Some(c) => c,
        None => return vec![],
    };

    // Oracle は SQL 内で UPPER() 変換するので uppercase retry は不要
    let result_rows = try_table_info(conn, schem2, table, port);

    if !result_rows.is_empty() {
        let _ = cache.save_tkey(&result_rows.iter().cloned().map(|m| m.into_iter().collect()).collect());
    }
    result_rows
}

fn try_table_info(
    conn: &mut Box<dyn DbConn>,
    schema: Option<&str>,
    table: &str,
    port: u16,
) -> Vec<serde_json::Map<String, Value>> {
    match conn.table_info_cursor(schema, Some(table), Some("TABLE")) {
        Ok(mut cursor) => cursor_to_map_rows(&mut cursor),
        Err(e) => {
            outputlog(&format!("table_info error: {}", e), Some(port));
            vec![]
        }
    }
}

fn fetch_pk_cached(
    db: &mut DbState,
    basedir: &Path,
    table: &str,
    schem: Option<&str>,
    schem2: Option<&str>,
    port: u16,
) -> Vec<String> {
    let cache_schem = schem2.or(schem);
    let cache = MetaCache::new(basedir, cache_schem, &db.user, table, &db.sha256sum);
    if let Some(pk) = cache.load_pkey() {
        return pk;
    }

    let conn = match db.conn.as_mut() {
        Some(c) => c,
        None => return vec![],
    };
    let pk = try_primary_key(conn, schem2, table, port);
    if !pk.is_empty() {
        let _ = cache.save_pkey(&pk);
    }
    pk
}

fn try_primary_key(
    conn: &mut Box<dyn DbConn>,
    schema: Option<&str>,
    table: &str,
    port: u16,
) -> Vec<String> {
    match conn.primary_key_list(schema, table) {
        Ok(pk) => pk,
        Err(e) => {
            outputlog(&format!("primary_key error: {}", e), Some(port));
            vec![]
        }
    }
}

fn fetch_column_info_cached(
    db: &mut DbState,
    basedir: &Path,
    table: &str,
    schem: Option<&str>,
    schem2: Option<&str>,
    port: u16,
) -> Vec<serde_json::Map<String, Value>> {
    let cache_schem = schem2.or(schem);
    let cache = MetaCache::new(basedir, cache_schem, &db.user, table, &db.sha256sum);
    if let Some(rows) = cache.load_ckey() {
        return rows.into_iter().map(|m| m.into_iter().collect()).collect();
    }

    let conn = match db.conn.as_mut() {
        Some(c) => c,
        None => return vec![],
    };
    let rows = try_column_info(conn, schem2, table, port);
    if !rows.is_empty() {
        let _ = cache.save_ckey(&rows.iter().cloned().map(|m| m.into_iter().collect()).collect());
    }
    rows
}

fn try_column_info(
    conn: &mut Box<dyn DbConn>,
    schema: Option<&str>,
    table: &str,
    port: u16,
) -> Vec<serde_json::Map<String, Value>> {
    match conn.column_info_cursor(schema, table) {
        Ok(mut cursor) => cursor_to_map_rows(&mut cursor),
        Err(e) => {
            outputlog(&format!("column_info error: {}", e), Some(port));
            vec![]
        }
    }
}

fn cursor_to_map_rows(cursor: &mut Box<dyn crate::db::StmtCursor>) -> Vec<serde_json::Map<String, Value>> {
    let cols = cursor.column_names().to_vec();
    let mut result = Vec::new();
    while let Some(row) = cursor.fetch_row() {
        let mut map = serde_json::Map::new();
        for (i, val) in row.into_iter().enumerate() {
            let key = cols.get(i).cloned().unwrap_or_else(|| format!("col{}", i));
            let jv = match val {
                Some(s) => Value::String(s),
                None => Value::Null,
            };
            map.insert(key, jv);
        }
        result.push(map);
    }
    result
}
