use std::sync::Arc;

use turso::{Builder, Connection, Database, Row, Value};

use crate::config::Config;
use crate::error::{AppError, AppResult};

/// Shared handle to the embedded Turso database.
pub type Db = Arc<Database>;

const MIGRATION: &str = include_str!("../migrations/0001_init.sql");

/// Open (creating if needed) the Turso database, applying native page encryption
/// when a key is configured, then run migrations.
pub async fn init(config: &Config) -> AppResult<Db> {
    if let Some(parent) = std::path::Path::new(&config.database_path).parent() {
        std::fs::create_dir_all(parent)?;
    }

    let mut builder = Builder::new_local(&config.database_path);
    let key = config.db_encryption_hexkey.trim();
    if !key.is_empty() {
        // AES-256-GCM per-page encryption (experimental in this Turso pre-release).
        builder = builder
            .experimental_encryption(true)
            .with_encryption(turso::EncryptionOpts {
                cipher: "aes256gcm".to_string(),
                hexkey: key.to_string(),
            });
    }

    let db = builder
        .build()
        .await
        .map_err(|e| AppError::Internal(format!("open db: {e}")))?;

    let conn = db.connect()?;
    conn.execute_batch(MIGRATION)
        .await
        .map_err(|e| AppError::Internal(format!("migrate: {e}")))?;

    Ok(Arc::new(db))
}

/// A fresh connection for a single unit of work. Turso connections are cheap.
pub fn connect(db: &Db) -> AppResult<Connection> {
    db.connect().map_err(Into::into)
}

// ---- Row extraction helpers -------------------------------------------------

pub fn text(row: &Row, idx: usize) -> AppResult<String> {
    match row.get_value(idx)? {
        Value::Text(s) => Ok(s),
        Value::Null => Err(AppError::Internal(format!("null text at col {idx}"))),
        other => Err(AppError::Internal(format!(
            "expected text at col {idx}, got {other:?}"
        ))),
    }
}

pub fn opt_text(row: &Row, idx: usize) -> AppResult<Option<String>> {
    match row.get_value(idx)? {
        Value::Text(s) => Ok(Some(s)),
        Value::Null => Ok(None),
        other => Err(AppError::Internal(format!(
            "expected text/null at col {idx}, got {other:?}"
        ))),
    }
}

pub fn int(row: &Row, idx: usize) -> AppResult<i64> {
    match row.get_value(idx)? {
        Value::Integer(n) => Ok(n),
        Value::Null => Ok(0),
        other => Err(AppError::Internal(format!(
            "expected integer at col {idx}, got {other:?}"
        ))),
    }
}

pub fn opt_int(row: &Row, idx: usize) -> AppResult<Option<i64>> {
    match row.get_value(idx)? {
        Value::Integer(n) => Ok(Some(n)),
        Value::Null => Ok(None),
        other => Err(AppError::Internal(format!(
            "expected integer/null at col {idx}, got {other:?}"
        ))),
    }
}
