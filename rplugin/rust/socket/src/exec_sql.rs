use anyhow::Result;
use serde_json::Value;
use std::fs::{File, OpenOptions};
use std::io::{BufWriter, Write};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use crate::db::StmtCursor;
use crate::encoding::ulength;
use crate::logging::{getdatetime, outputlog};

pub struct ExecSqlResult {
    pub status: i32,      // 1=ok(SELECT), 2=DML, 9=error
    pub cnt: i64,
    pub has_next: bool,
    pub sql_time_ms: i64,
    pub fetch_time_ms: i64,
    pub cols: Vec<String>,
    pub maxcols: Vec<usize>,
    pub colsindex: Vec<usize>,
    pub start_fetch: String,
}

/// SELECT 結果をファイルに書き出す (exec_sql 相当)
/// cursor: 既に prepare/execute 済みのカーソル
pub fn exec_sql(
    cursor: &mut Box<dyn StmtCursor>,
    tempfile: &Path,
    data: &Value,
    port: u16,
    limitrows: i64,
    cancel_flag: &Arc<AtomicBool>,
    exec_start_ms: i64,
    is_dml: bool,
) -> Result<ExecSqlResult> {
    let start_fetch = getdatetime();

    // DML の場合は行がない → status=2
    if is_dml {
        let cnt = cursor.row_count();
        return Ok(ExecSqlResult {
            status: 2,
            cnt,
            has_next: false,
            sql_time_ms: exec_start_ms,
            fetch_time_ms: 0,
            cols: vec![],
            maxcols: vec![],
            colsindex: vec![],
            start_fetch,
        });
    }

    let cols: Vec<String> = cursor.column_names().to_vec();
    if cols.is_empty() {
        // カラムなし → DML 扱い
        let cnt = cursor.row_count();
        return Ok(ExecSqlResult {
            status: 2,
            cnt,
            has_next: false,
            sql_time_ms: exec_start_ms,
            fetch_time_ms: 0,
            cols: vec![],
            maxcols: vec![],
            colsindex: vec![],
            start_fetch,
        });
    }

    let ncols = cols.len();
    let colsindex: Vec<usize> = (0..ncols).collect();
    let mut maxcols: Vec<usize> = cols.iter().map(|c| ulength(c)).collect();

    let null_str = data["null"].as_str().unwrap_or("").to_string();
    let linesep = data["linesep"].as_str().unwrap_or("\n").to_string();
    let surround = data["surround"].as_str().unwrap_or("").to_string();
    let prelinesep = data["prelinesep"].as_str().unwrap_or("").to_string();
    let is_column_info = data["column_info"].as_i64().unwrap_or(0) == 1;
    let is_table_info = data["table_info"].as_i64().unwrap_or(0) == 1;

    let file = OpenOptions::new()
        .append(true)
        .create(true)
        .open(tempfile)?;
    let mut writer = BufWriter::new(file);

    let fetch_start = std::time::Instant::now();
    outputlog("FETCH START", Some(port));

    let cbrcnt = 50000i64;
    let mut brcnt = cbrcnt;
    let mut total_cnt = 0i64;
    let mut has_next = false;

    while brcnt >= cbrcnt && limitrows != 0 {
        brcnt = 1;
        let mut batch: Vec<Vec<Option<String>>> = Vec::new();

        loop {
            if cancel_flag.load(Ordering::Relaxed) {
                break;
            }
            let row = match cursor.fetch_row() {
                Some(r) => r,
                None => break,
            };
            batch.push(row);
            // limitrows > 0: その件数でストップ
            if limitrows > 0 && (total_cnt + batch.len() as i64) >= limitrows {
                // もう1行フェッチして hasnext を確認
                if cursor.fetch_row().is_some() {
                    has_next = true;
                }
                break;
            }
            if brcnt >= cbrcnt {
                let t = fetch_start.elapsed().as_millis() as i64;
                outputlog(
                    &format!("EXEC WHILE: TIME({}ms) COUNT({}) LIMITROWS({}) {}", t, total_cnt + batch.len() as i64, limitrows, tempfile.display()),
                    Some(port),
                );
                break;
            }
            brcnt += 1;
        }

        // バッチを書き出す
        let mut rows_buf = String::new();
        for row in &batch {
            let mut record = String::new();
            for (i, val_opt) in row.iter().enumerate() {
                let mut val = match val_opt {
                    Some(v) => v.clone(),
                    None => null_str.clone(),
                };

                // 改行の正規化
                if linesep != "\n" {
                    val = val.replace("\r\n", &linesep).replace('\r', &linesep).replace('\n', &linesep);
                }

                // 制御文字 (タブ・改行以外) を '?' に置換
                if val.bytes().any(|b| b < 0x20 && b != b'\t' && b != b'\n' && b != b'\r') {
                    val = val
                        .chars()
                        .map(|c| if c.is_control() && c != '\t' && c != '\n' && c != '\r' { '?' } else { c })
                        .collect();
                }

                let maxsize: usize;

                if linesep == "\n" && val.contains('\n') {
                    // 複数行値 → surround で囲む
                    let surr = if surround.is_empty() { "\"".to_string() } else { surround.clone() };
                    let surrounded = format!("{}{}{}", surr, val, surr);
                    let lines: Vec<&str> = surrounded.split('\n').collect();
                    maxsize = lines.iter().map(|l| ulength(l)).max().unwrap_or(0);
                    val = format!("{}{}{}{}{}", prelinesep, surr, val, surr, prelinesep);
                } else if !surround.is_empty() && !is_column_info && !is_table_info {
                    let surrounded = format!("{}{}{}", surround, val, surround);
                    maxsize = ulength(&surrounded);
                    val = surrounded;
                } else {
                    maxsize = ulength(&val);
                }

                if maxcols[i] < maxsize {
                    maxcols[i] = maxsize;
                }

                // タブをエスケープ
                val = val.replace('\t', "<<#TAB#>>");

                if i == 0 {
                    record = val;
                } else {
                    record.push('\t');
                    record.push_str(&val);
                }
            }
            record.push('\n');
            rows_buf.push_str(&record);
        }
        writer.write_all(rows_buf.as_bytes())?;
        total_cnt += batch.len() as i64;

        if brcnt < cbrcnt {
            break;
        }
    }

    writer.flush()?;
    cursor.finish();

    let fetch_time_ms = fetch_start.elapsed().as_millis() as i64;
    outputlog(
        &format!("FETCH END: TIME({}ms) COUNT({}) LIMITROWS({}) {}", fetch_time_ms, total_cnt, limitrows, tempfile.display()),
        Some(port),
    );

    Ok(ExecSqlResult {
        status: 1,
        cnt: total_cnt,
        has_next,
        sql_time_ms: exec_start_ms,
        fetch_time_ms,
        cols,
        maxcols,
        colsindex,
        start_fetch,
    })
}

pub fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}
