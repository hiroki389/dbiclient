# DBIClient Copilot Instructions

## What This Plugin Is

DBIClient is an async SQL database client for Vim/Neovim. It supports PostgreSQL, MySQL, SQLite, Oracle, and ODBC via a **Rust TCP socket backend** that runs as a separate process. The VimScript layer manages UI and state; Rust handles all database I/O.

## Architecture

```
Vim/Neovim (VimScript)          Rust Backend (TCP localhost)
──────────────────────          ────────────────────────────
plugin/dbiclient.vim            main.rs        ← startup, signals
  └─ init + command defs        server.rs      ← TCP listener
autoload/dbiclient.vim          handler.rs     ← request routing
  └─ all business logic         exec_sql.rs    ← query execution
autoload/dbiclient/funclib.vim  cache.rs       ← SHA256 metadata cache
  └─ FP utilities               db/            ← per-DBMS drivers
```

- Vim connects to the Rust server on a random port (`127.0.0.1` only).
- The Rust process is spawned automatically if the binary is missing (auto-compiles via `cargo build`).
- Signal-based cancellation: Vim sends SIGINT to abort a running query.
- Cache stored in `$XDG_CACHE_HOME/dbiclient/` (required; plugin won't load without it).

## Building the Rust Backend

```bash
cd rplugin/rust/socket
cargo build --release --features pg,mysql-db,sqlite
# With Oracle:
cargo build --release --features pg,mysql-db,sqlite,oracle-native
# With ODBC:
cargo build --release --features pg,mysql-db,sqlite,odbc
```

Available feature flags: `pg`, `mysql-db`, `sqlite`, `oracle-native`, `odbc`.  
There is no test suite. Manual testing uses `assets/demo.db` (SQLite).

## VimScript Conventions

**Variable scopes** (strictly followed throughout):
- `s:` — script-local (private, within the autoload file)
- `g:` — global (user-configurable, set in `plugin/dbiclient.vim`)
- `b:` — buffer-local (state stored on result buffers)
- `w:` — window-local (state stored on float windows)

**Function naming**:
- `dbiclient#funcName()` — public autoload functions
- `s:funcName()` — private script-local functions
- All public commands are thin wrappers in `plugin/dbiclient.vim` that call into `autoload/dbiclient.vim`

**Functional library**: `autoload/dbiclient/funclib.vim` provides chainable FP utilities used for result formatting:
```vim
let result = dbiclient#funclib#List(rows).filter(...).map(...).value()
```
Use this library for data transformation instead of raw loops where possible.

## Unified Float Window

The plugin uses a **single integrated float window** with pseudo-tabs (`tables`, `result`, `history`, `jobs`, `log`) rather than separate floats per feature. Tab switching swaps the buffer in the existing window. Key state:

```vim
s:mainFloatWinid      " the single float window ID
s:mainFloatCurTab     " active tab name
s:mainFloatTabBufs    " {tab_name → bufnr}
s:tab_order           " ['tables', 'result', 'history', 'jobs', 'log']
```

When adding new UI panels, follow this pattern: assign a tab name, register a buffer in `s:mainFloatTabBufs`, and switch via the existing tab mechanism.

## Rust Conventions

- All DB drivers implement the `DbConn` and `StmtCursor` traits in `db/mod.rs`. Add new DBMS support by implementing these traits and registering in `db/factory.rs`.
- Error handling uses `anyhow`: `result.context("description")?`
- Cancellation is via `Arc<AtomicBool>` (`cancel_flag`) checked during query execution.
- `DbState` in `handler.rs` is the persistent connection state across multiple requests on one port.

## Key Global Config Variables

Defined with defaults in `plugin/dbiclient.vim`; users override in their vimrc:

| Variable | Default | Purpose |
|---|---|---|
| `g:dbiclient_rustPath` | `…/target/release/socket` | Path to compiled binary |
| `g:dbiclient_rust_features` | `'pg,mysql-db,sqlite'` | Features for auto-compilation |
| `g:dbiclient_rootPath` | `$XDG_CACHE_HOME/dbiclient` | Cache directory (required) |
| `g:dbiclient_timeout` | `120000` | Socket response timeout (ms) |
| `g:dbiclient_float_window` | `1` | Enable float UI (Neovim only) |
| `g:dbiclient_connect_opt_limitrows` | `1000` | Default row limit |



## 重要ルール
- 複雑なタスクに取り組む際は、まず日本語で「ステップ・バイ・ステップ」で論理を組み立ててください。
- 英語で思考するのではなく、日本語の語彙や文脈を活かして思考することで、より日本文化や言語習慣に即した回答を生成してください。
- 回答を生成する前に、必ず日本語による思考プロセス（Chain of Thought）を書き出してください。
 1. <thought>タグを使用して、ユーザーの意図の解釈、必要な情報の整理、回答の構成案を日本語で記述すること。
 2. その後に、最終的な回答を出力してください。
