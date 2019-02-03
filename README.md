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
cpan> install DBI
cpan> install DBD::ODBC
cpan> install DBD::Oracle
cpan> install DBD::Pg
cpan> install DBD::SQLite
```

# Database connection method
dbiclient#connect({port}, {dns}, {user}, {password}, [limit], [encoding] [, {opt}])
```vim
"example
:call dbiclient#connect(9001,'ODBC:RIVUS','RIVUS','password',10000,'utf8')

let opt={}  
" Filter the object type.
let opt.connect_opt_table_type='TABLE,SYNONYM'
" Filter the table displayed in the table list.
let opt.connect_opt_table_name='TEST%'
" Set environment variables within perl.
let opt.connect_opt_envdict={'NLS_LANG':'Japanese_Japan.AL32UTF8'}
:call dbiclient#connect(9001,'Oracle:sid=XE','RIVUS','password',1000,'utf8',opt)

:call dbiclient#connect(9001,'Pg:dbname=postgres','postgres','password',1000,'utf8')
```

# Explanation of the ex command
|excommand              | Description                                                            |
|:----------------------|:-----------------------------------------------------------------------|
|:DBITables             | Display table list                                                     |
|:DBISelect             | Execute select statement of selected range                             |
|:DBISelectFrmTbl       | Execute the select statement of the table name at the cursor position  |
|:DBIReload             | Reload the SQL                                                         |
|:DBIColumnsFrmTbl      | Display table information from the table name at the cursor position   |
|:DBIExecute            | Execute the selection SQL (insert, update, delete etc.)                |
|:DBICommit             | Commit                                                                 |
|:DBIRollback           | Rollback                                                               |
|:DBICancel             | Request cancellation before SQL timeout                                |
|:DBIHistory            | Display execution history of select statement                          |
|:DBIHistoryDo          | Display execution history of SQL (insert, update, delete etc.)         |
|:DBIJobStop            | Stop the socket application                                            |
|:DBIJobStopAll         | Stop the socket application on all ports. It is also called when vim exits.  |
|:DBIJobNext            | Switch to the next job when running on multiple ports                  |
|:DBIJobList            | Display job list when running on multiple ports                        |
|:DBIClose              | Close the DB connection                                                |

# Description of global variables
|global variable              | Default   | Description                                                |
|:----------------------------|:----------|:-----------------------------------------------------------|
|g:dbiclient_col_delimiter    | "\t"      | Set column delimiter                                       |
|g:dbiclient_null             | ''        | Set display setting of NULL value                          |
|g:dbiclient_linesep          | v:null    | Set display settings for line breaks in columns            |
|g:dbiclient_surround         | v:null    | Set display setting of column enclosure                    |
|g:dbiclient_new_window_hight | ''        | Set the height of the buffer                               |
|g:dbiclient_perl_binmode     | 'utf8'    | Set perl input / output encoding                           |
|g:dbiclient_buffer_encoding  | 'utf8'    | Set buffer encoding                                        |

# Licence
Copyright (c) 2019 Hiroki Kitamura  
Released under the MIT license  
[MIT](https://opensource.org/licenses/mit-license.php)

# Author
[hiroki389](https://github.com/hiroki389)
