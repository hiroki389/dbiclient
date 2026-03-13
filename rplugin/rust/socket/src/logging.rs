use chrono::Local;
use std::fs::{File, OpenOptions};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

static LOG_WRITER: OnceLock<Mutex<Option<BufWriter<File>>>> = OnceLock::new();

fn log_writer() -> &'static Mutex<Option<BufWriter<File>>> {
    LOG_WRITER.get_or_init(|| Mutex::new(None))
}

/// ログファイルを開く
pub fn open_log(basedir: &Path, vim_encoding: &str) -> std::io::Result<()> {
    let date_str = Local::now().format("%Y%m%d").to_string();
    let path = basedir.join(format!("socket_{}.log", date_str));
    let file = OpenOptions::new().append(true).create(true).open(&path)?;
    *log_writer().lock().unwrap() = Some(BufWriter::new(file));
    Ok(())
}

/// ログを出力する (outputlog 相当)
pub fn outputlog(msg: &str, port: Option<u16>) {
    let mut guard = log_writer().lock().unwrap();
    if let Some(ref mut w) = *guard {
        let dt = Local::now().format("%c").to_string();
        let port_str = port.map(|p| format!(" PORT:{}", p)).unwrap_or_default();
        let pid = std::process::id();
        let line = format!("{}{} PID:{} {}\n", dt, port_str, pid, msg);
        let _ = w.write_all(line.as_bytes());
        let _ = w.flush();
    }
}

pub fn getdate() -> String {
    Local::now().format("%Y%m%d").to_string()
}

pub fn getdatetime() -> String {
    Local::now().format("%c").to_string()
}
