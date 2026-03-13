use anyhow::{Context, Result};
use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use crate::cache::sha256_prefix;
use crate::db::factory::connect;
use crate::handler::{handle_request, DbState};
use crate::logging::outputlog;

pub fn run_server(
    port: u16,
    basedir: &Path,
    vim_encoding: &str,
    cancel_flag: Arc<AtomicBool>,
    exit_flag: Arc<AtomicBool>,
) -> Result<()> {
    let listener =
        TcpListener::bind(format!("127.0.0.1:{}", port)).with_context(|| format!("bind port {}", port))?;

    // Vim に対してポート番号を通知 (ポート 0 で起動した場合の実際のポート)
    // パイプ接続時は stdout がフルバッファリングされるため明示的にフラッシュが必要
    let actual_port = listener.local_addr()?.port();
    {
        use std::io::Write;
        println!("{}", actual_port);
        std::io::stdout().flush().ok();
    }

    outputlog("SERVER START", Some(actual_port));

    let mut db = DbState::new();
    let mut one_flag = true;

    loop {
        if exit_flag.load(Ordering::Relaxed) {
            break;
        }

        outputlog("------------------------", Some(actual_port));

        // 接続待機
        let (stream, peer_addr) = match listener.accept() {
            Ok(pair) => pair,
            Err(e) => {
                outputlog(&format!("accept error: {}", e), Some(actual_port));
                break;
            }
        };

        // 127.0.0.1 以外は拒否
        let peer_ip = peer_addr.ip().to_string();
        if peer_ip != "127.0.0.1" {
            outputlog(&format!("127.0.0.1<>{}", peer_ip), Some(actual_port));
            continue;
        }

        if let Err(e) = handle_connection(
            stream,
            &mut db,
            basedir,
            actual_port,
            vim_encoding,
            &cancel_flag,
            &exit_flag,
        ) {
            outputlog(&format!("connection error: {}", e), Some(actual_port));
        }

        if exit_flag.load(Ordering::Relaxed) {
            break;
        }

        cancel_flag.store(false, Ordering::Relaxed);
    }

    outputlog("SERVER STOP", Some(actual_port));
    db.disconnect();
    Ok(())
}

fn handle_connection(
    mut stream: TcpStream,
    db: &mut DbState,
    basedir: &Path,
    port: u16,
    vim_encoding: &str,
    cancel_flag: &Arc<AtomicBool>,
    exit_flag: &Arc<AtomicBool>,
) -> Result<()> {
    let mut reader = BufReader::new(stream.try_clone().context("stream clone")?);
    let mut line = String::new();
    reader.read_line(&mut line).context("read line")?;

    if line.is_empty() {
        outputlog("NO_DATA", Some(port));
        return Ok(());
    }

    let parsed: Value = serde_json::from_str(line.trim()).context("JSON parse")?;
    let arr = parsed.as_array().ok_or_else(|| anyhow::anyhow!("expected JSON array"))?;
    if arr.len() < 2 {
        return Err(anyhow::anyhow!("expected [sig, data] array"));
    }
    let sig = &arr[0];
    let data = &arr[1];

    // EXIT リクエスト
    if data.get("kill").is_some() {
        outputlog("EXIT", Some(port));
        exit_flag.store(true, Ordering::Relaxed);
        let result = json!({ "status": 1 });
        let response = serde_json::to_string(&json!([sig, result]))? + "\n";
        stream.write_all(response.as_bytes())?;
        return Ok(());
    }

    // DB 接続リクエスト
    if let Some(datasource) = data["datasource"].as_str() {
        db.disconnect();

        let result = handle_connect(data, db, datasource, port);
        let response = serde_json::to_string(&json!([sig, result]))? + "\n";
        stream.write_all(response.as_bytes())?;
        return Ok(());
    }

    // DB 未接続
    if db.conn.is_none() {
        let result = json!({ "status": 9 });
        let response = serde_json::to_string(&json!([sig, result]))? + "\n";
        stream.write_all(response.as_bytes())?;
        return Ok(());
    }

    // 通常リクエスト
    let tempfile = data["tempfile"].as_str().map(PathBuf::from).unwrap_or_else(|| {
        basedir.join(format!("tmp_{}", port))
    });

    // CLOSE だけは handler 外で処理
    if data.get("close").is_some() {
        db.disconnect();
        let result = json!({});
        let response = serde_json::to_string(&json!([sig, result]))? + "\n";
        stream.write_all(response.as_bytes())?;
        return Ok(());
    }

    let result = handle_request(data, db, &tempfile, basedir, port, vim_encoding, cancel_flag);
    let response = serde_json::to_string(&json!([sig, result]))? + "\n";
    stream.write_all(response.as_bytes())?;

    Ok(())
}

fn handle_connect(data: &Value, db: &mut DbState, datasource: &str, port: u16) -> Value {
    let user = data["user"].as_str().unwrap_or("").to_string();
    let pass = data["pass"].as_str().unwrap_or("").to_string();
    let limitrows = data["limitrows"].as_i64().unwrap_or(-1);
    let encoding = data["encoding"].as_str().unwrap_or("utf-8").to_string();
    let primary_key_flg = data["primarykeyflg"].as_i64().unwrap_or(0) != 0;
    let column_info_flg = data["columninfoflg"].as_i64().unwrap_or(0) != 0;
    let schema_list: Vec<String> = data["schema_list"]
        .as_array()
        .map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect())
        .unwrap_or_default();

    let envdict = data["envdict"]
        .as_object()
        .map(|m| m.iter().filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string()))).collect())
        .unwrap_or_default();

    // 環境変数を設定
    for (k, v) in &envdict {
        // SAFETY: 接続処理はシングルスレッドで行われる
        unsafe { std::env::set_var(k, v) };
    }

    let full_ds = format!("DBI:{}", datasource);
    let sha256sum = sha256_prefix(&full_ds);

    match connect(&full_ds, &user, &pass, &envdict, &encoding) {
        Ok(conn) => {
            outputlog(
                &format!("CONNECT:{} {} {}", datasource, user, encoding),
                Some(port),
            );
            db.conn = Some(conn);
            db.datasource = full_ds;
            db.user = user;
            db.pass = pass;
            db.limitrows = limitrows;
            db.db_encoding = encoding;
            db.primary_key_flg = primary_key_flg;
            db.column_info_flg = column_info_flg;
            db.schema_list = schema_list;
            db.sha256sum = sha256sum;
            json!({ "status": 1 })
        }
        Err(e) => {
            let msg = e.to_string();
            outputlog(
                &format!("CONNECT ERROR:DBI:{} {}:{}", datasource, user, msg),
                Some(port),
            );
            json!({ "status": 9, "message": msg })
        }
    }
}
