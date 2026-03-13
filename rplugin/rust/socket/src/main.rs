mod cache;
mod db;
mod encoding;
mod exec_sql;
mod handler;
mod logging;
mod server;

use anyhow::{Context, Result};
use signal_hook::{
    consts::{SIGINT, SIGHUP, SIGTERM},
    iterator::Signals,
};
use std::fs::{self, File, OpenOptions};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 4 {
        eprintln!("Usage: socket <port> <basedir> <vim_encoding> [debuglog=1]");
        std::process::exit(1);
    }

    let port: u16 = args[1].parse().context("port parse")?;
    let basedir = PathBuf::from(&args[2]);
    let vim_encoding = args[3].clone();
    let debug_log = args.get(4).map(|s| s != "0").unwrap_or(true);

    // basedir と dictionary ディレクトリを作成
    fs::create_dir_all(&basedir).with_context(|| format!("mkdir: {}", basedir.display()))?;
    fs::create_dir_all(basedir.join("dictionary"))
        .with_context(|| format!("mkdir dictionary: {}", basedir.display()))?;

    // ロックファイルを作成
    let lock_path = basedir.join(format!("{}.lock", port));
    let _lock_file = OpenOptions::new()
        .append(true)
        .create(true)
        .open(&lock_path)
        .with_context(|| format!("lock file: {}", lock_path.display()))?;

    // ログを開く
    if debug_log {
        logging::open_log(&basedir, &vim_encoding).context("open log")?;
    }

    logging::outputlog("START", Some(port));

    let cancel_flag = Arc::new(AtomicBool::new(false));
    let exit_flag = Arc::new(AtomicBool::new(false));

    // シグナルハンドラ設定
    let cancel_flag2 = cancel_flag.clone();
    let exit_flag2 = exit_flag.clone();
    let lock_path2 = lock_path.clone();

    let mut signals = Signals::new([SIGTERM, SIGHUP, SIGINT]).context("signals")?;
    std::thread::spawn(move || {
        for sig in &mut signals {
            match sig {
                SIGINT => {
                    cancel_flag2.store(true, Ordering::Relaxed);
                    logging::outputlog("CANCEL", None);
                }
                SIGTERM | SIGHUP => {
                    exit_flag2.store(true, Ordering::Relaxed);
                    logging::outputlog("FIN", None);
                    let _ = std::fs::remove_file(&lock_path2);
                    std::process::exit(0);
                }
                _ => {}
            }
        }
    });

    // TCP サーバー起動
    let result = server::run_server(port, &basedir, &vim_encoding, cancel_flag, exit_flag);

    // 終了処理
    logging::outputlog("FIN", Some(port));
    let _ = fs::remove_file(&lock_path);

    result
}

