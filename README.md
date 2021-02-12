dbiclient.vim
====

vimからSQLを実行するためのクライアントツール

# 説明
vimのソケット通信を利用し、perlのDBIライブラリを呼び出します。  
ソケット通信を利用することで、非同期にSQLを実行します。

# 必須アプリ
vim8.2以上  
perl

# perlライブラリのインストール方法
cpan または ppm
```shell
cpan> install JSON
cpan> install DBI
cpan> install DBD::ODBC
cpan> install DBD::Oracle
cpan> install DBD::Pg
cpan> install DBD::SQLite
```

# DB接続方法
DB接続するには、connect関数とconnect_secure関数を利用する方法があります。  
引数 ポート番号、データソース、ユーザー名、パスワード、オプション  
dbiclient#connect({port}, {dsn}, {user}, {password} [, {opt}])   

connect_secure関数を利用する場合は、予めパスワードファイルを作成しておきます。  
引数 ポート番号、データソース、ユーザー名、パスワードID、オプション  
dbiclient#connect_secure({port}, {dsn}, {user}, {passfileName} [, {opt}])  

ODBCの例
```vim
:call dbiclient#connect(9001,'ODBC:RIVUS','RIVUS','password')
```
ODBCの例(connect_secure)
```vim
:DBISetSecurePassword PASSFILE
:call dbiclient#connect_secure(9001,'ODBC:RIVUS','RIVUS','PASSFILE')
```
oracleでNLS_LANGをUTF8に設定して接続する例
```vim
let opt={}  
let opt.connect_opt_envdict          = {'NLS_LANG':'Japanese_Japan.AL32UTF8'}
:call dbiclient#connect(9001,'Oracle:sid=XE','RIVUS','password',opt)
```
postgreの例
```vim
:call dbiclient#connect(9001,'Pg:dbname=postgres','postgres','password')
```
# DB接続オプション
| key                           | Default                                      | Description                                                  |
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

# exコマンド
| excommand                      | Description                                                                        |
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
| :DBIHistory                    | SQL履歴を表示する                                                                  |
| :DBISetSecurePassword [name]   | パスワードファイルを作成する                                                       |

# 各種設定方法
|  global variable                  |  Default                         |  Description                                                  |
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

# ライセンス
Copyright (c) 2019 Hiroki Kitamura  
Released under the MIT license  
[MIT](https://opensource.org/licenses/mit-license.php)

# 著者
[hiroki389](https://github.com/hiroki389)
