dbiclient.vim
====

dbiclient is a client tool for accessing databases from vim.

# Description
You can execute SQL asynchronously with vim's socket function.  
It supports various databases to use the perl DBI library.

# Requirement
vim8.1  
perl5.24

# DBI library installation
cpan
```shell
cpan> install JSON
cpan> install DBI
cpan> install DBD::ODBC
cpan> install DBD::Oracle
cpan> install DBD::Pg
cpan> install DBD::SQLite
```

# Usage database connection method
dbiclient#connect({port}, {dns}, {user}, {password} [, {opt}])   
dbiclient#connect_secure({port}, {dns}, {user}, {passfileName} [, {opt}])
```vim
:call dbiclient#connect(v:null,'ODBC:RIVUS','RIVUS','password')
```

```vim
:DBISetSecurePassword PASSFILE
:call dbiclient#connect_secure(v:null,'ODBC:RIVUS','RIVUS','PASSFILE')
```

```vim
let opt={}  
let opt.connect_opt_table_type  = 'TABLE,SYNONYM'
let opt.connect_opt_table_name  = 'TEST%'
let opt.connect_opt_envdict     = {'NLS_LANG':'Japanese_Japan.AL32UTF8'}
let opt.connect_opt_schema_flg  = 1
let opt.connect_opt_schema_list = ['SCHEMA1','SCHEMA2']
let opt.connect_opt_limitrows   = 10000
let opt.connect_opt_encoding    = 'cp932'
:call dbiclient#connect(9001,'Oracle:sid=XE','RIVUS','password',opt)
```

```vim
:call dbiclient#connect(9001,'Pg:dbname=postgres','postgres','password')
```
# Description connecting options
| key                           | Default     | Description                                                  |
| :---------------------------- | :---------- | :----------------------------------------------------------- |
| connect_opt_limitrows         | 1000        | Set to limit number of rows                                  |
| connect_opt_encoding          | 'utf8'      | Set encoding                                                 |
| connect_opt_table_name        | ''          | Filter the table displayed in the table list                 |
| connect_opt_table_type        | ''          | Filter the object type                                       |
| connect_opt_envdict           | undef       | Set environment variables                                    |
| connect_opt_schema_flg        | 0(disabled) | Add schema with table                                        |
| connect_opt_schema_list       | []          | Search columns info using schema name                        |

# Explanation of the ex command
| excommand               | Description                                                                 |
| :---------------------- | :-----------------------------------------------------------------------    |
| :DBIJobList             | Display job list when running on multiple ports                             |
| :DBISelect              | Execute select statement of selected range                                  |
| :DBISelectSlash         | Execute select statement of selected range                                  |
| :DBISelectTable         | Execute the select statement of the table name at the cursor position       |
| :DBIReload              | Reload the SQL                                                              |
| :DBIColumnsTable        | Display table information from the table name at the cursor position        |
| :DBIExecute             | Execute the selection SQL (insert, update, delete etc.)                     |
| :DBIExecuteSlash        | Execute the selection SQL (procedure etc.)                                  |
| :DBICommit              | Commit                                                                      |
| :DBIRollback            | Rollback                                                                    |
| :DBICancel              | Request cancellation before SQL timeout                                     |
| :DBIHistoryAll          | Display execution history of select statement                               |
| :DBISetSecurePassword   | Write db password in encrypted file                                         |

# Description of global variables
| global variable                 | Default     | Description                                                  |
| :----------------------------   | :---------- | :----------------------------------------------------------- |
| g:dbiclient_col_delimiter       | "\t"        | Set column delimiter                                         |
| g:dbiclient_col_delimiter_align | "|"         | Set column delimiter                                         |
| g:dbiclient_null                | ''          | Set display setting of NULL value                            |
| g:dbiclient_linesep             | v:null      | Set display settings for line breaks in columns              |
| g:dbiclient_surround            | v:null      | Set display setting of column enclosure                      |
| g:dbiclient_new_window_hight    | ''          | Set the height of the buffer                                 |
| g:dbiclient_perl_binmode        | 'utf8'      | Set perl input / output encoding                             |
| g:dbiclient_buffer_encoding     | 'utf8'      | Set buffer encoding                                          |
| g:dbiclient_hist_cnt            | 1000        | Set number of sql history                                    |

# Licence
Copyright (c) 2019 Hiroki Kitamura  
Released under the MIT license  
[MIT](https://opensource.org/licenses/mit-license.php)

# Author
[hiroki389](https://github.com/hiroki389)
