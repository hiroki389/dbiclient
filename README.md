# dbiclient.vim

Vim / Neovim から非同期で SQL を実行するデータベースクライアントプラグインです。
バックエンドは Rust 製の TCP ソケットサーバーで、PostgreSQL・MySQL・SQLite・Oracle・ODBC に対応しています。

## 🚀 特徴

* **非同期実行**: Vim 8.2+ / Neovim のソケット通信を利用し、重いクエリ実行中も Vim の操作を妨げません。
* **Rust バックエンド**: 高速な Rust 製ソケットサーバー (`rplugin/rust/socket`) を使用。接続時に未ビルドまたはドライバ未対応の場合は自動でビルドします。
* **フロートウィンドウ UI** *(Neovim 専用)*: テーブル一覧・クエリ結果・SQL 生成バッファをすべてフロートウィンドウで表示。分割せずに操作できます。Vim では従来のスプリットウィンドウにフォールバックします。
* **環境変数による接続管理**: 接続設定を環境変数で管理するため、プロジェクトごとの切り替えが容易です。

## 📋 必須要件

| | 最低バージョン | 備考 |
|---|---|---|
| **Neovim** | 0.9+ | フロートウィンドウ UI を使用する場合 |
| **Vim** | 8.2+ | フロートウィンドウは使用不可。SQL実行・結果表示はスプリットで動作 |
| **Rust / Cargo** | 1.70+ | バックエンドのビルドに必要 |

### バックエンドのビルド

```shell
# プラグインルートの Rust ソースをビルド
cd rplugin/rust/socket
cargo build --release --features pg,mysql-db,sqlite

# Oracle を使う場合
cargo build --release --features pg,mysql-db,sqlite,oracle-native
```

> **Note**: 接続時に `g:dbiclient_rustPath` のバイナリが存在しない、またはドライバが未コンパイルの場合は Vim から自動ビルドを実行します。

---

## ⚡ クイックスタート

### ステップ 1: プラグインをインストール

[lazy.nvim](https://github.com/folke/lazy.nvim) の例:

```lua
{
  "hiroki389/dbiclient",
  cmd = { "DBITables", "DBISelect", "DBIExecute" },
}
```

[vim-plug](https://github.com/junegunn/vim-plug) の例:

```vim
Plug 'hiroki389/dbiclient'
```

### ステップ 2: 接続設定を `init.vim` / `init.lua` に書く

接続情報は **任意の「名前」に `_DB_DSN` / `_DB_USER` / `_DB_PASS` を付けた環境変数** で指定します。
`dbiclient#connect('名前')` を呼ぶと対応する環境変数が自動で読み込まれます。

環境変数が未設定の場合は Vim が対話的に入力を求めます（試すだけなら設定不要）。

```vim
" ── PostgreSQL の例 ──────────────────────────────────────
" DSN 書式: Pg:dbname=<DB名>;host=<ホスト>;port=<ポート>
call setenv('MYPG_DB_DSN',  'Pg:dbname=mydb;host=localhost')
call setenv('MYPG_DB_USER', 'myuser')
call setenv('MYPG_DB_PASS', 'mypassword')

" vimrc/init.vim に接続コマンドを登録しておくと便利
command! DBIConnMyPg call dbiclient#connect('MYPG')
```

> 💡 **名前は自由に付けられます。** `WORK_PG`・`DEV_MYSQL` など用途別に複数登録できます。

### ステップ 3: 接続する

```
:DBIConnMyPg
```

接続に成功するとテーブル一覧が自動で表示されます（Neovim ではフロートウィンドウ、Vim ではスプリット）。

### ステップ 4: 操作する

| 操作 | 手順 |
|---|---|
| テーブルを SELECT | テーブル一覧で `<CR>` |
| SQL を実行 | ビジュアルモードで範囲選択 → `:DBIExecute` |
| WHERE 条件を変える | SELECT 結果で `mw` → 値を編集 → `<CR>` |
| コミット | `:DBICommit` |

---

## 🔌 DB 接続設定の詳細

### 環境変数の命名規則

```
{PREFIX}_DB_DSN   ← データソース名（ドライバ名:接続パラメータ）
{PREFIX}_DB_USER  ← ユーザー名
{PREFIX}_DB_PASS  ← パスワード
```

`dbiclient#connect('{PREFIX}')` が上記3変数を読み取ります。変数が未設定の場合は Vim が対話的に入力を促します。

### DSN 書式一覧

| DBMS | DSN の書式例 |
|---|---|
| PostgreSQL | `Pg:dbname=mydb;host=localhost;port=5432` |
| MySQL / MariaDB | `mysql:dbname=mydb;host=localhost` |
| SQLite | `sqlite:/path/to/database.db` |
| Oracle | `Oracle:sid=XE` または `Oracle:service_name=XEPDB1` |
| ODBC | `ODBC:MY_DSN_NAME` |

### 接続設定の例

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
" パスワード不要 (空文字でよい)
call setenv('SQLITE_DB_DSN',  'sqlite:/path/to/my.db')
call setenv('SQLITE_DB_USER', '')
call setenv('SQLITE_DB_PASS', '')
command! DBIConnSQLite call dbiclient#connect('SQLITE')
```

#### Oracle

```vim
call setenv('ORA_DB_DSN',  'Oracle:sid=XE')
call setenv('ORA_DB_USER', 'system')
call setenv('ORA_DB_PASS', 'password')

" NLS_LANG など Oracle 固有の環境変数が必要な場合
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

### 接続オプション（`connect` 関数の第2引数）
| キー | デフォルト値 | 説明 |
| :---------------------------- | :----------                                  | :----------------------------------------------------------- |
| connect_opt_limitrows         | g:dbiclient_connect_opt_limitrows = 1000     | 最大フェッチ件数                                             |
| connect_opt_encoding          | g:dbiclient_connect_opt_encoding = 'utf8'    | 文字エンコーディング                                         |
| connect_opt_table_name        | g:dbiclient_connect_opt_table_name = ''      | テーブル一覧のテーブルフィルター                             |
| connect_opt_table_type        | g:dbiclient_connect_opt_table_type = ''      | テーブル一覧のタイプフィルター                               |
| connect_opt_envdict           | g:dbiclient_connect_opt_envdict = {}         | DBMS の環境変数を設定                                        |
| connect_opt_schema_flg        | g:dbiclient_connect_opt_schema_flg = 0       | スキーマ名付与フラグ                                         |
| connect_opt_schema_list       | g:dbiclient_connect_opt_schema_list = []     | 同一インスタンス内の別スキーマからカラム名を取得する         |
| connect_opt_history_data_flg  | g:dbiclient_connect_opt_history_data_flg = 0 | SQL結果の履歴保持フラグ（デフォルト OFF）                    |
| connect_opt_columninfoflg     | g:dbiclient_connect_opt_columninfoflg = 0    | カラムコメントの表示設定                                     |

## 🖥 フロートウィンドウ UI *(Neovim 専用)*

Neovim では結果・条件編集・SQL 生成をフロートウィンドウで表示します。

```
┌──────────────────────────────────────────────────────────────────────┐
│                        テーブル一覧フロート                           │
│   (幅 95% × 高さ 85%  ─  :DBITables / DBIJobList の <CR>)           │
└──────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────┐ ┌──────────────────────────────┐
│   条件編集パネル (左 50%)              │ │   クエリ結果フロート (右 50%)  │
│  WHERE / ORDER / SELECT / GROUP       │ │  SELECT * FROM ...           │
│  ─ <CR> で実行・パネルが閉じて復元     │ │                              │
└───────────────────────────────────────┘ └──────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                        ScratchSQL フロート (下部)                     │
│  INSERT / UPDATE / DELETE 文の生成結果を追記形式で集約                │
└──────────────────────────────────────────────────────────────────────┘
```

### フロートウィンドウの操作

| キー | 動作 |
|---|---|
| `<Tab>` | フロートウィンドウを順方向に切り替える（フロートがない場合は通常の `<Tab>`） |
| `<S-Tab>` | フロートウィンドウを逆方向に切り替える（フロートがない場合は通常の `<S-Tab>`） |
| `q` / `<Esc>` | フロートを閉じる（別フロートが残っていればそちらへフォーカス移動） |
| 非フロートウィンドウへ移動 | 全フロートウィンドウを自動的に閉じる |

## 🛠 コマンドリファレンス
| コマンド | 内容 |
| :----------------------        | :-----------------------------------------------------------------------           |
| :DBIJobList                    | 接続中の DB 情報一覧を表示する                                                      |
| :DBIClose [port]               | DB を切断する（Vim 終了時は全コネクションを自動切断）                               |
| :DBITables                     | テーブル一覧を表示する                                                              |
| :DBISelect[!] [count]          | ビジュアルモードで選択した SQL を複数実行し結果を表示する（区切り文字: `/` or `;`）  |
| :DBISelectFrom[!] [tableNm]    | テーブル名を指定して SELECT を実行する                                              |
| :DBIColumnsTable [tableNm]     | テーブル名を指定してカラム情報を取得する                                            |
| :DBIExecute[!]                 | ビジュアルモードで選択した SQL を複数実行する（区切り文字: `/` or `;`）              |
| :DBIExecuteNoSplit[!]          | ビジュアルモードで選択した SQL を1件実行する                                        |
| :DBICommit                     | コミットする                                                                        |
| :DBIRollback                   | ロールバックする                                                                    |
| :DBICancel                     | 実行中の SQL をキャンセルする                                                       |
| :DBIHistory                    | SQL 履歴を表示する                                                                  |
| :DBIOpenBuf                    | 直前の結果バッファをフロートウィンドウで再表示する                                  |
| :DBILog                        | ソケットのログファイル（`socket_YYYYMMDD.log`）を開く                               |

### テーブル一覧のキーマップ
| キー (デフォルト) | 動作 |
|---|---|
| `<CR>` | カーソル行のテーブルを SELECT |
| `mc`   | テーブルの件数を取得 |
| `mt`   | TABLE_TYPE フィルタを変更 |
| `mw`   | TABLE_NAME フィルタを変更 |

### クエリ結果のキーマップ
| キー (デフォルト) | 動作 |
|---|---|
| `mw` | WHERE 条件を編集（左パネルで開く） |
| `mo` | ORDER BY を編集 |
| `ms` | SELECT カラムを編集 |
| `mg` | GROUP BY を編集 |
| `mji`| INNER JOIN テーブルを追加 |
| `mjl`| LEFT JOIN テーブルを追加 |
| `me` | SQL を直接編集 |
| `ma` | カラム幅を整列（EasyAlign） |
| `mr` | 現在の SQL を再実行 |
| `mll`| LIMIT 件数を変更して再実行 |
| `+`  | 次の結果バッファへ |
| `-`  | 前の結果バッファへ |
| `mid`| DELETE → INSERT 文を生成して ScratchSQL に追記 |

### SQL 生成 (ScratchSQL フロート)

SELECT 結果バッファ上で以下のキーを押すと INSERT/UPDATE/DELETE 文が生成され、**ScratchSQL** フロートに追記されます（上書きではありません）。

| キー (デフォルト) | 動作 |
|---|---|
| `mi` | INSERT 文を生成 |
| `mu` | UPDATE 文を生成 |
| `md` | DELETE 文を生成 |

## ⚙ グローバル設定（`.vimrc` 用）
| 変数名 | デフォルト | 説明 |
|  :----------------------------       |  :----------                     |  :----------------------------------------------------------- |
|  g:dbiclient_rustPath                |  (自動検出)                      |  Rust バイナリのパス                                          |
|  g:dbiclient_rust_features           |  `'pg,mysql-db,sqlite'`          |  ビルド時に有効にする Cargo features                          |
|  g:dbiclient_col_delimiter           |  `"\t"`                          |  未整列状態のカラム区切り文字                                 |
|  g:dbiclient_col_delimiter_align     |  `"\|"`                          |  整列状態のカラム区切り文字                                   |
|  g:dbiclient_null                    |  `''`                            |  NULL の表示文字                                              |
|  g:dbiclient_linesep                 |  `"\n"`                          |  改行コードの表示文字                                         |
|  g:dbiclient_surround                |  `''`                            |  カラムの囲い文字                                             |
|  g:dbiclient_new_window_hight        |  `'12'`                          |  フォールバック時のスプリット高さ                             |
|  g:dbiclient_buffer_encoding         |  `'utf8'`                        |  Vim バッファの文字エンコーディング                           |
|  g:dbiclient_hist_cnt                |  `1000`                          |  SQL 履歴の最大保持件数                                       |
|  g:dbiclient_disp_headerline         |  `1`                             |  カラム名の下に罫線を表示                                     |
|  g:dbiclient_disp_remarks            |  `1`                             |  カラムコメントを表示（columninfoflg が ON の場合）           |
|  g:dbiclient_float_window            |  `1`                             |  フロートウィンドウを使用する（Neovim のみ有効）               |
|  g:dbiclient_float_window_width      |  `0.9`                           |  結果フロートの幅比率（画面幅に対する割合）                   |
|  g:dbiclient_float_window_height     |  `0.8`                           |  結果フロートの高さ比率                                       |
|  g:dbiclient_float_tables_width      |  `0.98`                          |  テーブル一覧フロートの幅比率                                 |
|  g:dbiclient_float_tables_height     |  `0.92`                          |  テーブル一覧フロートの高さ比率                               |
|  g:dbiclient_rootPath                |  `$XDG_CACHE_HOME/dbiclient`     |  ログ・キャッシュ・履歴の保存先ディレクトリ                   |
|  g:dbiclient_debuglog                |  `1`                             |  ソケットログをファイルに出力する（`0` で無効）→ `:DBILog` で確認 |
|  g:dbiclient_debugflg                |  `0`                             |  Vim 側デバッグログを `echom` に出力する（`1` で有効）         |
|  g:dbiclient_timeout                 |  `120000`                        |  ソケット同期応答のタイムアウト（ミリ秒）。初回メタデータ取得が遅い場合に大きくする |
|  g:dbiclient_prelinesep              |  `'<<CRR>>'`                     |  改行コードの一時変換文字                                     |
|  g:Dbiclient_call_after_connected    |  `{-> dbiclient#userTablesMain()}`| DB 接続後に実行する関数                                      |

---

## 📄 ライセンス

Copyright (c) 2019 Hiroki Kitamura

Released under the [MIT license](https://opensource.org/licenses/mit-license.php).

## 👤 著者

[hiroki389](https://github.com/hiroki389)

---

