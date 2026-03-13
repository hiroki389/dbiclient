use anyhow::{Context, Result};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

/// datasource 文字列から SHA256 の先頭 10 文字を返す
pub fn sha256_prefix(datasource: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(datasource.as_bytes());
    let result = hasher.finalize();
    hex::encode(result)[..10].to_string()
}

fn cache_path(basedir: &Path, schema: &str, user: &str, table: &str, sha256sum: &str, kind: &str) -> PathBuf {
    basedir
        .join("dictionary")
        .join(format!("{}_{}_{}_{}_{}.dat", schema, user, table, sha256sum, kind))
}

fn load_json_cache(path: &Path) -> Option<Vec<HashMap<String, Value>>> {
    let text = fs::read_to_string(path).ok()?;
    serde_json::from_str(&text).ok()
}

fn save_json_cache(path: &Path, data: &Vec<HashMap<String, Value>>) -> Result<()> {
    let text = serde_json::to_string(data).context("cache serialize")?;
    fs::write(path, text).with_context(|| format!("cache write: {}", path.display()))?;
    Ok(())
}

pub struct MetaCache<'a> {
    basedir: &'a Path,
    schema: String,
    user: String,
    table: String,
    sha256sum: String,
}

impl<'a> MetaCache<'a> {
    pub fn new(
        basedir: &'a Path,
        schema: Option<&str>,
        user: &str,
        table: &str,
        sha256sum: &str,
    ) -> Self {
        MetaCache {
            basedir,
            schema: schema.unwrap_or("NOUSER").to_string(),
            user: user.to_string(),
            table: table.to_string(),
            sha256sum: sha256sum.to_string(),
        }
    }

    pub fn load_tkey(&self) -> Option<Vec<HashMap<String, Value>>> {
        load_json_cache(&cache_path(self.basedir, &self.schema, &self.user, &self.table, &self.sha256sum, "TKEY"))
    }

    pub fn save_tkey(&self, data: &Vec<HashMap<String, Value>>) -> Result<()> {
        save_json_cache(&cache_path(self.basedir, &self.schema, &self.user, &self.table, &self.sha256sum, "TKEY"), data)
    }

    pub fn load_pkey(&self) -> Option<Vec<String>> {
        let path = cache_path(self.basedir, &self.schema, &self.user, &self.table, &self.sha256sum, "PKEY");
        let text = fs::read_to_string(&path).ok()?;
        serde_json::from_str(&text).ok()
    }

    pub fn save_pkey(&self, data: &Vec<String>) -> Result<()> {
        let path = cache_path(self.basedir, &self.schema, &self.user, &self.table, &self.sha256sum, "PKEY");
        let text = serde_json::to_string(data).context("pkey serialize")?;
        fs::write(&path, text).with_context(|| format!("pkey write: {}", path.display()))?;
        Ok(())
    }

    pub fn load_ckey(&self) -> Option<Vec<HashMap<String, Value>>> {
        load_json_cache(&cache_path(self.basedir, &self.schema, &self.user, &self.table, &self.sha256sum, "CKEY"))
    }

    pub fn save_ckey(&self, data: &Vec<HashMap<String, Value>>) -> Result<()> {
        save_json_cache(&cache_path(self.basedir, &self.schema, &self.user, &self.table, &self.sha256sum, "CKEY"), data)
    }
}

/// カーソルの全行を Vec<HashMap<String, Value>> に変換
pub fn cursor_to_rows(cursor: &mut Box<dyn crate::db::StmtCursor>) -> Vec<HashMap<String, Value>> {
    let cols = cursor.column_names().to_vec();
    let mut result = Vec::new();
    while let Some(row) = cursor.fetch_row() {
        let mut map = HashMap::new();
        for (i, val) in row.into_iter().enumerate() {
            let key = cols.get(i).cloned().unwrap_or_else(|| format!("col{}", i));
            let jv = match val {
                Some(s) => Value::String(s),
                None => Value::Null,
            };
            map.insert(key, jv);
        }
        result.push(map);
    }
    result
}
