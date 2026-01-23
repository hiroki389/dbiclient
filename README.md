# dbiclient.vim

Vimから非同期でSQLを実行するための、Perl DBIベースのデータベースクライアントツールです。

## 🚀 特徴

* **非同期実行**: Vim 8.2+ のソケット通信を利用し、重いクエリを実行中もVimの操作を妨げません。
* **Perl DBI連携**: 強力なPerlのDBIライブラリを使用して、多種多様なDBMSに接続可能です。
* **環境変数による管理**: 接続設定を環境変数で管理するため、プロジェクトごとの切り替えが容易です。

## 📋 必須要件

* **Vim 8.2 以上**
* **Perl** (実行環境にインストールされていること)

### 依存ライブラリのインストール

接続するDBに合わせて、以下のPerlモジュールをインストールしてください。

```shell
# CPANを使用したインストール例
cpan install JSON DBI

# 接続するDBに合わせてインストール
cpan install DBD::ODBC
cpan install DBD::Oracle
cpan install DBD::Pg
cpan install DBD::SQLite

```

## 🔌 DB接続方法

本プラグインは環境変数を参照して接続を行います。`dbiclient#connect({prefix} [, {options}])` を呼び出す際、`{prefix}` に指定した文字列に対応する環境変数が参照されます。

### 接続の例

#### ODBC接続

```vim
call setenv('MYODBC_DNS', 'ODBC:RIVUS')
call setenv('MYODBC_USER', 'RIVUS')
call setenv('MYODBC_PASS', 'password')
call dbiclient#connect('MYODBC')

```

#### Oracle接続 (環境変数の動的設定を含む)

```vim
call setenv('MYORA_DNS', 'Oracle:sid=XE')
call setenv('MYORA_USER', 'RIVUS')
call setenv('MYORA_PASS', 'password')

let l:opt = {}  
let l:opt.connect_opt_envdict = {'NLS_LANG': 'Japanese_Japan.AL32UTF8'}
call dbiclient#connect('MYORA', l:opt)

```

#### PostgreSQL接続

```vim
call setenv('MYPG_DNS', 'Pg:dbname=postgres')
call setenv('MYPG_USER', 'postgres')
call setenv('MYPG_PASS', 'password')
call dbiclient#connect('MYPG')

```

### 接続オプション（`connect` 関数の第2引数）
| キー | デフォルト値 | 説明 |
| :---------------------------- | :----------                                  | :----------------------------------------------------------- |
| connect_opt_limitrows         | g:dbiclient_connect_opt_limitrows = 1000     | 最大フェッチ件数                                             |
| connect_opt_encoding          | g:dbiclient_connect_opt_encoding = 'utf8'    | 文字エンコーディング                                         |
| connect_opt_table_name        | g:dbiclient_connect_opt_table_name = ''      | テーブル一覧のテーブルフィルター                             |
| connect_opt_table_type        | g:dbiclient_connect_opt_table_type = ''      | テーブル一覧のタイプフィルター                               |
| connect_opt_envdict           | g:dbiclient_connect_opt_envdict = {}         | DBMSの環境変数を設定                                         |
| connect_opt_schema_flg        | g:dbiclient_connect_opt_schema_flg = 0       | スキーマ名付与フラグ                                         |
| connect_opt_schema_list       | g:dbiclient_connect_opt_schema_list = []     | 同一インスタンス内の別スキーマからカラム名を取得する         |
| connect_opt_history_data_flg  | g:dbiclient_connect_opt_history_data_flg = 0 | SQL結果の履歴保持フラグ、一時領域の逼迫及びセキュリティの観点からデフォルトではOFFになっている                                      |
| connect_opt_columninfoflg     | g:dbiclient_connect_opt_columninfoflg = 0    | カラム名の表示設定                                      |

## 🛠 コマンドリファレンス
| コマンド | 内容 |
| :----------------------        | :-----------------------------------------------------------------------           |
| :DBIJobList                    | 接続中のDB情報一覧を表示する                                                       |
| :DBIClose [port]               | DBを切断する ※vim終了時は自動的にすべてのコネクションを切断する                                                                       |
| :DBITables                     | テーブル一覧を表示する                                                             |
| :DBISelect[!] [count]          | ビジュアルモードで選択したSQLを複数実行し結果を表示する(SQL区切り文字は / または ;)                            |
| :DBISelectFrom[!] [tableNm]    | テーブル名を指定し、SQLを実行する                                                  |
| :DBIColumnsTable [tableNm]     | テーブル名を指定し、カラム情報を取得する                                           |
| :DBIExecute[!]                 | ビジュアルモードで選択したSQLを複数実行する(SQL区切り文字は / または ;)                                        |
| :DBIExecuteNoSplit[!]          | ビジュアルモードで選択したSQLを一つ実行する             |
| :DBICommit                     | コミットする                                                                       |
| :DBIRollback                   | ロールバックする                                                                   |
| :DBICancel                     | 実行中のSQLをキャンセルする                                                                   |
| :DBIHistory                    | SQL履歴を表示する                                                                  |


### グローバル設定（`.vimrc` 用）
| 変数名 | デフォルト | 説明 |
|  :----------------------------    |  :----------                     |  :----------------------------------------------------------- |
|  g:dbiclient_col_delimiter        |  "\t"                            |  未整列状態のカラム区切り文字                                 |
|  g:dbiclient_col_delimiter_align  |  "&#124;"                        |  整列状態のカラム区切り文字                                   |
|  g:dbiclient_null                 |  ''                              |  NULLの表示文字                                               |
|  g:dbiclient_linesep              |  "\n"                            |  改行コードの表示文字                                         |
|  g:dbiclient_surround             |  ''                              |  カラムの囲い文字                                             |
|  g:dbiclient_new_window_hight     |  '12'                            |  ウィンドウの高さ                                             |
|  g:dbiclient_perl_binmode         |  'utf8'                          |  perlの文字エンコーディング                                   |
|  g:dbiclient_buffer_encoding      |  'utf8'                          |  vimの文字エンコーディング                                    |
|  g:dbiclient_hist_cnt             |  1000                            |  SQL履歴の最大保持件数                                        |
|  g:dbiclient_disp_headerline      |  1                               |  カラム名の下に罫線表示                                           |
|  g:dbiclient_disp_remarks         |  1                               |  カラム名の表示可否(connect_opt_columninfoflgがonの場合)                                           |
|  g:dbiclient_previewwindow        |  1                               |  プレビューウィンドウに結果を出力する                         |
|  g:dbiclient_prelinesep           |  '&lt;&lt;CRR&gt;&gt;'           |  改行コードの一時変換文字                                     |
|  g:Dbiclient_call_after_connected |  {-> dbiclient#userTablesMain()} |  DB接続後に実行する関数                                       |

---

## 📄 ライセンス

Copyright (c) 2019 Hiroki Kitamura

Released under the [MIT license](https://opensource.org/licenses/mit-license.php).

## 👤 著者

[hiroki389](https://github.com/hiroki389)

---

