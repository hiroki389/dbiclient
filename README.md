# dbiclient.vim

An asynchronous SQL database client plugin for Vim / Neovim.  
The backend is a Rust TCP socket server supporting PostgreSQL, MySQL, SQLite, Oracle, and ODBC.

![demo](assets/demo.gif)

## 🚀 Features

* **Async execution** – Uses Vim 8.2+ / Neovim socket communication so heavy queries never block the editor.
* **Rust backend** – Fast Rust socket server (`rplugin/rust/socket`). Automatically builds on first connect if the binary is missing or the required driver is not compiled in.
* **Float window UI** *(Neovim only)* – Table list, query results, and SQL generation buffers all displayed in floating windows. Falls back to split windows in Vim.
* **Environment-variable connection management** – Connection settings live in environment variables for easy per-project switching.

---

## 📋 Requirements

| | Minimum version | Notes |
|---|---|---|
| **Neovim** | 0.9+ | Required for float window UI |
| **Vim** | 8.2+ | Float windows unavailable; SQL execution and results use splits |
| **Rust / Cargo** | 1.70+ | Required to build the backend |

### Building the backend

```shell
cd rplugin/rust/socket
cargo build --release --features pg,mysql-db,sqlite

# With Oracle support
cargo build --release --features pg,mysql-db,sqlite,oracle-native
```

> **Note:** If the binary at `g:dbiclient_rustPath` is missing or the required driver is not compiled in, the plugin triggers an automatic build from Vim.

---

## ⚡ Quick Start

### Step 1 — Install the plugin

**[lazy.nvim](https://github.com/folke/lazy.nvim)**

```lua
{
  "hiroki389/dbiclient",
  cmd = { "DBITables", "DBISelect", "DBIExecute" },
}
```

**[vim-plug](https://github.com/junegunn/vim-plug)**

```vim
Plug 'hiroki389/dbiclient'
```

### Step 2 — Add connection settings to your `vimrc` / `init.lua`

Connection details are stored in environment variables following the pattern  
`{PREFIX}_DB_DSN`, `{PREFIX}_DB_USER`, `{PREFIX}_DB_PASS`.  
Calling `dbiclient#connect('{PREFIX}')` reads those variables automatically.  
If a variable is not set, Vim prompts for input interactively.

```vim
" ── PostgreSQL example ─────────────────────────────────────
" DSN format: Pg:dbname=<DB>;host=<host>;port=<port>
call setenv('MYPG_DB_DSN',  'Pg:dbname=mydb;host=localhost')
call setenv('MYPG_DB_USER', 'myuser')
call setenv('MYPG_DB_PASS', 'mypassword')

" Register a short command in your vimrc for convenience
command! DBIConnMyPg call dbiclient#connect('MYPG')
```

> 💡 The prefix is completely free — register multiple connections like `WORK_PG`, `DEV_MYSQL`, etc.

### Step 3 — Connect

```
:DBIConnMyPg
```

On success the table list opens automatically (float window in Neovim, split in Vim).

### Step 4 — Explore

| Action | How |
|---|---|
| SELECT a table | Press `<CR>` in the table list |
| Execute SQL | Visual-select SQL → `:DBIExecute` |
| Change WHERE | Press `mw` in result → edit → `<CR>` |
| Commit | `:DBICommit` |

---

## 🔌 Connection Configuration

### Environment variable naming

```
{PREFIX}_DB_DSN   — data source name (driver:connection-params)
{PREFIX}_DB_USER  — user name
{PREFIX}_DB_PASS  — password
```

### DSN format by DBMS

| DBMS | DSN example |
|---|---|
| PostgreSQL | `Pg:dbname=mydb;host=localhost;port=5432` |
| MySQL / MariaDB | `mysql:dbname=mydb;host=localhost` |
| SQLite | `sqlite:/path/to/database.db` |
| Oracle | `Oracle:sid=XE` or `Oracle:service_name=XEPDB1` or `Oracle:host:port/service` |
| ODBC | `ODBC:MY_DSN_NAME` |

### Connection examples

#### PostgreSQL

```vim
call setenv('MYPG_DB_DSN',  'Pg:dbname=mydb;host=localhost')
call setenv('MYPG_DB_USER', 'postgres')
call setenv('MYPG_DB_PASS', 'password')
command! DBIConnMyPg call dbiclient#connect('MYPG')
```

#### MySQL / MariaDB

```vim
call setenv('MYSQL_DB_DSN',  'mysql:dbname=mydb;host=localhost')
call setenv('MYSQL_DB_USER', 'root')
call setenv('MYSQL_DB_PASS', 'password')
command! DBIConnMySQL call dbiclient#connect('MYSQL')
```

#### SQLite

```vim
" Password not required (leave empty)
call setenv('SQLITE_DB_DSN',  'sqlite:/path/to/my.db')
call setenv('SQLITE_DB_USER', '')
call setenv('SQLITE_DB_PASS', '')
command! DBIConnSQLite call dbiclient#connect('SQLITE')
```

#### Oracle

```vim
call setenv('ORA_DB_DSN',  'Oracle:host:1521/service_name')
call setenv('ORA_DB_USER', 'system')
call setenv('ORA_DB_PASS', 'password')

" Pass Oracle-specific environment variables when needed
let l:opt = {'connect_opt_envdict': {'NLS_LANG': 'Japanese_Japan.AL32UTF8'}}
command! DBIConnOra call dbiclient#connect('ORA', l:opt)
```

#### ODBC

```vim
call setenv('ODBC_DB_DSN',  'ODBC:MY_DSN_NAME')
call setenv('ODBC_DB_USER', 'myuser')
call setenv('ODBC_DB_PASS', 'password')
command! DBIConnODBC call dbiclient#connect('ODBC')
```

### `connect` options (second argument)

| Key | Default | Description |
| :--- | :--- | :--- |
| connect_opt_limitrows        | `g:dbiclient_connect_opt_limitrows = 1000`  | Maximum rows to fetch |
| connect_opt_encoding         | `g:dbiclient_connect_opt_encoding = 'utf8'` | Character encoding |
| connect_opt_table_name       | `g:dbiclient_connect_opt_table_name = ''`   | Table name filter for table list |
| connect_opt_table_type       | `g:dbiclient_connect_opt_table_type = ''`   | Table type filter for table list |
| connect_opt_envdict          | `g:dbiclient_connect_opt_envdict = {}`      | DBMS-specific environment variables |
| connect_opt_schema_flg       | `g:dbiclient_connect_opt_schema_flg = 0`    | Prefix schema name to table name |
| connect_opt_schema_list      | `g:dbiclient_connect_opt_schema_list = []`  | Additional schemas to search for column info |
| connect_opt_history_data_flg | `g:dbiclient_connect_opt_history_data_flg = 0` | Persist SQL result history (default OFF) |
| connect_opt_columninfoflg    | `g:dbiclient_connect_opt_columninfoflg = 0` | Show column comments |

---

## 🖥 Float Window UI *(Neovim only)*

In Neovim, results, condition editing, and SQL generation all use floating windows.

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Table List float                              │
│              (:DBITables / <CR> from :DBIJobList)                    │
└──────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────┐ ┌──────────────────────────────┐
│   Condition panel (left 50%)          │ │   Query result float (right)  │
│  WHERE / ORDER / SELECT / GROUP       │ │  SELECT * FROM ...            │
│  — press <CR> to run, panel closes    │ │                               │
└───────────────────────────────────────┘ └──────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                       ScratchSQL float (bottom)                       │
│        INSERT / UPDATE / DELETE statements appended here              │
└──────────────────────────────────────────────────────────────────────┘
```

### Float window navigation

| Key | Action |
|---|---|
| `<Tab>` | Cycle forward through float windows (passes through as normal `<Tab>` when no floats are open) |
| `<S-Tab>` | Cycle backward through float windows (passes through as normal `<S-Tab>` when no floats are open) |
| `q` | Close the current float (focus moves to another open float if one exists) |
| Move to a non-float window | All float windows are closed automatically |

---

## 🛠 Command Reference

| Command | Description |
| :--- | :--- |
| `:DBIJobList`                 | Show list of active DB connections |
| `:DBIClose [port]`            | Disconnect (all connections are closed automatically on Vim exit) |
| `:DBITables`                  | Open the table list |
| `:DBISelect[!] [count]`       | Execute multiple SQL statements from visual selection (delimiter: `/` or `;`) |
| `:DBISelectFrom[!] [tableNm]` | Run `SELECT * FROM <table>` |
| `:DBIColumnsTable [tableNm]`  | Fetch column info for a table |
| `:DBIExecute[!]`              | Execute multiple SQL statements from visual selection |
| `:DBIExecuteNoSplit[!]`       | Execute a single SQL statement from visual selection |
| `:DBICommit`                  | Commit |
| `:DBIRollback`                | Rollback |
| `:DBICancel`                  | Cancel the running SQL |
| `:DBIHistory`                 | Show SQL history |
| `:DBIOpenBuf`                 | Re-open the last result buffer in a float window |
| `:DBILog`                     | Open the socket log file (`socket_YYYYMMDD.log`) |

---

## ⌨ Key Mappings

### Table list

| Key (default) | Action |
|---|---|
| `<CR>` | SELECT the table under cursor |
| `mc`   | Count rows in the table |
| `mt`   | Change TABLE_TYPE filter |
| `mw`   | Change TABLE_NAME filter |

### Query result

| Key (default) | Action |
|---|---|
| `mw`  | Edit WHERE clause (opens condition panel) |
| `mo`  | Edit ORDER BY |
| `ms`  | Edit SELECT columns |
| `mg`  | Edit GROUP BY |
| `mji` | Add INNER JOIN table |
| `mjl` | Add LEFT JOIN table |
| `me`  | Edit SQL directly |
| `ma`  | Align column widths (EasyAlign) |
| `mr`  | Re-execute the current SQL |
| `mll` | Change LIMIT and re-execute |
| `+`   | Next result buffer |
| `-`   | Previous result buffer |
| `mid` | Generate DELETE → INSERT and append to ScratchSQL |

### SQL generation (ScratchSQL float)

In a result buffer, visually select one or more rows, then use the following keys to generate DML and **append** it to the ScratchSQL float.

| Key (default) | Action |
|---|---|
| `<C-I>` | Generate INSERT |
| `<C-U>` | Generate UPDATE |
| `<C-D>` | Generate DELETE |

---

## ⚙ Global Settings (`vimrc`)

| Variable | Default | Description |
| :--- | :--- | :--- |
| `g:dbiclient_rustPath`             | (auto-detected)                    | Path to the Rust backend binary |
| `g:dbiclient_rust_features`        | `'pg,mysql-db,sqlite'`             | Cargo features enabled at build time |
| `g:dbiclient_col_delimiter`        | `"\t"`                             | Column delimiter (non-aligned) |
| `g:dbiclient_col_delimiter_align`  | `"\|"`                             | Column delimiter (aligned) |
| `g:dbiclient_null`                 | `''`                               | String displayed for NULL |
| `g:dbiclient_linesep`              | `"\n"`                             | Newline placeholder character |
| `g:dbiclient_surround`             | `''`                               | Surrounding character for column values |
| `g:dbiclient_new_window_hight`     | `'12'`                             | Split height used when float is unavailable |
| `g:dbiclient_buffer_encoding`      | `'utf8'`                           | Vim buffer character encoding |
| `g:dbiclient_hist_cnt`             | `1000`                             | Maximum number of SQL history entries |
| `g:dbiclient_disp_headerline`      | `1`                                | Show a separator line below column headers |
| `g:dbiclient_disp_remarks`         | `1`                                | Show column comments (requires `columninfoflg`) |
| `g:dbiclient_float_window`         | `1`                                | Enable float window UI (Neovim only) |
| `g:dbiclient_float_window_width`   | `0.9`                              | Result float width ratio (fraction of screen width) |
| `g:dbiclient_float_window_height`  | `0.8`                              | Result float height ratio |
| `g:dbiclient_float_tables_width`   | `0.98`                             | Table list float width ratio |
| `g:dbiclient_float_tables_height`  | `0.92`                             | Table list float height ratio |
| `g:dbiclient_rootPath`             | `$XDG_CACHE_HOME/dbiclient`        | Directory for logs, cache, and history |
| `g:dbiclient_debuglog`             | `1`                                | Write socket log to file (`0` to disable) — view with `:DBILog` |
| `g:dbiclient_debugflg`             | `0`                                | Print Vim-side debug log to `echom` (`1` to enable) |
| `g:dbiclient_timeout`              | `120000`                           | Synchronous socket response timeout in ms (increase if first metadata fetch times out) |
| `g:dbiclient_prelinesep`           | `'<<CRR>>'`                        | Temporary newline escape sequence used internally |
| `g:Dbiclient_call_after_connected` | `{-> dbiclient#userTablesMain()}`  | Function called after a successful connection |

---

## 📄 License

Copyright (c) 2019 Hiroki Kitamura  
Released under the [MIT license](https://opensource.org/licenses/mit-license.php).

## 👤 Author

[hiroki389](https://github.com/hiroki389)
