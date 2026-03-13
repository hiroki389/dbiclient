pub mod factory;
pub mod odbc;
pub mod oracle;
pub mod postgres;
pub mod mysql;
pub mod sqlite;

use anyhow::Result;

/// DB の種別
#[derive(Debug, Clone, PartialEq)]
pub enum DbType {
    Oracle,
    Odbc,
    Postgres,
    Mysql,
    Sqlite,
}

/// SELECT 結果のカーソル（DBI の $sth 相当）
pub trait StmtCursor: Send {
    fn column_names(&self) -> &[String];
    /// 1行返す。None で終端
    fn fetch_row(&mut self) -> Option<Vec<Option<String>>>;
    /// フェッチ済み行数（不明な場合は -1）
    fn row_count(&self) -> i64;
    fn finish(&mut self);
}

/// 行を Vec<Vec<Option<String>>> で保持する汎用カーソル
pub struct EagerCursor {
    pub columns: Vec<String>,
    pub rows: Vec<Vec<Option<String>>>,
    pub pos: usize,
    pub affected_rows: i64,
}

impl StmtCursor for EagerCursor {
    fn column_names(&self) -> &[String] {
        &self.columns
    }
    fn fetch_row(&mut self) -> Option<Vec<Option<String>>> {
        if self.pos < self.rows.len() {
            let row = self.rows[self.pos].clone();
            self.pos += 1;
            Some(row)
        } else {
            None
        }
    }
    fn row_count(&self) -> i64 {
        self.affected_rows
    }
    fn finish(&mut self) {
        // 行を全て解放してメモリを解放
        self.rows.clear();
    }
}

/// DB 接続の統一インターフェイス（Perl の DBI/$dbh 相当）
pub trait DbConn: Send {
    fn db_type(&self) -> DbType;

    /// DML (INSERT/UPDATE/DELETE) 実行。影響行数を返す
    fn execute(&mut self, sql: &str) -> Result<i64>;

    /// SELECT 実行。カーソルを返す
    fn query(&mut self, sql: &str, max_rows: i64) -> Result<Box<dyn StmtCursor>>;

    /// テーブル一覧カーソル（DBI の table_info 相当）
    fn table_info_cursor(
        &mut self,
        schema: Option<&str>,
        table: Option<&str>,
        table_type: Option<&str>,
    ) -> Result<Box<dyn StmtCursor>>;

    /// プライマリキー列名リスト（DBI の primary_key 相当）
    fn primary_key_list(&mut self, schema: Option<&str>, table: &str) -> Result<Vec<String>>;

    /// カラム情報カーソル（DBI の column_info 相当）
    fn column_info_cursor(&mut self, schema: Option<&str>, table: &str)
        -> Result<Box<dyn StmtCursor>>;

    fn commit(&mut self) -> Result<()>;
    fn rollback(&mut self) -> Result<()>;
    fn disconnect(&mut self) -> Result<()>;

    /// Oracle の DBMS_OUTPUT_ENABLE (他DBでは no-op)
    fn dbms_output_enable(&mut self, _size: u32) {}

    /// Oracle の DBMS_OUTPUT_GET (他DBでは空リスト)
    fn dbms_output_get(&mut self) -> Vec<String> {
        vec![]
    }

    /// LongReadLen / LongTruncOk 等の属性設定（対応ドライバのみ有効）
    fn set_long_read_len(&mut self, _len: usize) {}
}
