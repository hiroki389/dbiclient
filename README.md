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

## 🔌 DB接続方法

本プラグインは環境変数を参照して接続を行います。`dbiclient#connect({prefix} [, {options}])` を呼び出す際、`{prefix}` に指定した文字列に対応する環境変数が参照されます。

### 接続の例

#### PostgreSQL接続

```vim
call setenv('MYPG_DNS', 'Pg:dbname=postgres')
call setenv('MYPG_USER', 'postgres')
call setenv('MYPG_PASS', 'password')
call dbiclient#connect('MYPG')
```

#### MySQL / MariaDB 接続

```vim
call setenv('MYDB_DNS', 'mysql:dbname=mydb;host=localhost')
call setenv('MYDB_USER', 'root')
call setenv('MYDB_PASS', 'password')
call dbiclient#connect('MYDB')
```

#### SQLite 接続

```vim
call setenv('MYDB_DNS', 'sqlite:/path/to/my.db')
call setenv('MYDB_USER', '')
call setenv('MYDB_PASS', '')
call dbiclient#connect('MYDB')
```

#### Oracle 接続 (環境変数の動的設定を含む)

```vim
call setenv('MYORA_DNS', 'Oracle:sid=XE')
call setenv('MYORA_USER', 'RIVUS')
call setenv('MYORA_PASS', 'password')

let l:opt = {}
let l:opt.connect_opt_envdict = {'NLS_LANG': 'Japanese_Japan.AL32UTF8'}
call dbiclient#connect('MYORA', l:opt)
```

#### ODBC 接続

```vim
call setenv('MYODBC_DNS', 'ODBC:RIVUS')
call setenv('MYODBC_USER', 'RIVUS')
call setenv('MYODBC_PASS', 'password')
call dbiclient#connect('MYODBC')
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
| `q` / `<Esc>` | フロートを閉じる（結果フロートや ScratchSQL は別フロートへフォーカス移動） |
| 閉じた後 | 優先順位: vsFloat → 結果フロート → ScratchSQL |

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
|  g:dbiclient_float_window_height     |  `0.6`                           |  結果フロートの高さ比率                                       |
|  g:dbiclient_float_tables_width      |  `0.95`                          |  テーブル一覧フロートの幅比率                                 |
|  g:dbiclient_float_tables_height     |  `0.85`                          |  テーブル一覧フロートの高さ比率                               |
|  g:dbiclient_prelinesep              |  `'<<CRR>>'`                     |  改行コードの一時変換文字                                     |
|  g:Dbiclient_call_after_connected    |  `{-> dbiclient#userTablesMain()}`| DB 接続後に実行する関数                                      |

---

## 📄 ライセンス

Copyright (c) 2019 Hiroki Kitamura

Released under the [MIT license](https://opensource.org/licenses/mit-license.php).

## 👤 著者

[hiroki389](https://github.com/hiroki389)

---

