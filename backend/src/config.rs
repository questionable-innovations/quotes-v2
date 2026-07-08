use std::env;

/// Runtime configuration, loaded from environment variables at startup.
#[derive(Clone)]
pub struct Config {
    pub database_path: String,
    /// 64-char hex (32-byte) key for Turso native page encryption. Empty = no encryption.
    pub db_encryption_hexkey: String,
    pub jwt_secret: String,
    pub access_ttl_secs: i64,
    pub refresh_ttl_secs: i64,
    pub storage_dir: String,
    /// 64-char hex (32-byte) key for attachment-at-rest encryption (XChaCha20-Poly1305).
    pub attachment_enc_hexkey: String,
    pub max_upload_bytes: usize,
    pub cors_origins: Vec<String>,
    pub bind_addr: String,
    pub resend_api_key: String,
    pub email_from: String,
    pub frontend_base_url: String,
    /// Invite / email-token lifetimes.
    pub invite_ttl_secs: i64,
    pub email_token_ttl_secs: i64,
}

fn var(key: &str) -> Option<String> {
    env::var(key).ok().filter(|v| !v.is_empty())
}

fn var_or(key: &str, default: &str) -> String {
    var(key).unwrap_or_else(|| default.to_string())
}

fn parse_or<T: std::str::FromStr>(key: &str, default: T) -> T {
    var(key).and_then(|v| v.parse().ok()).unwrap_or(default)
}

impl Config {
    pub fn from_env() -> Self {
        let cors_origins = var("CORS_ORIGINS")
            .map(|v| v.split(',').map(|s| s.trim().to_string()).collect())
            .unwrap_or_else(|| vec!["*".to_string()]);

        Config {
            database_path: var_or("DATABASE_PATH", "data/quotes.db"),
            db_encryption_hexkey: var_or("DB_ENCRYPTION_KEY", ""),
            jwt_secret: var_or("JWT_SECRET", "dev-insecure-change-me"),
            access_ttl_secs: parse_or("ACCESS_TTL_SECS", 3600),
            refresh_ttl_secs: parse_or("REFRESH_TTL_SECS", 60 * 60 * 24 * 30),
            storage_dir: var_or("STORAGE_DIR", "data/uploads"),
            attachment_enc_hexkey: var_or("ATTACHMENT_ENC_KEY", ""),
            max_upload_bytes: parse_or("MAX_UPLOAD_BYTES", 25 * 1024 * 1024),
            cors_origins,
            bind_addr: var_or("BIND_ADDR", "0.0.0.0:8080"),
            resend_api_key: var_or("RESEND_API_KEY", ""),
            email_from: var_or("EMAIL_FROM", "Quote Book <noreply@example.com>"),
            frontend_base_url: var_or("FRONTEND_BASE_URL", "http://localhost:5173"),
            invite_ttl_secs: parse_or("INVITE_TTL_SECS", 60 * 60 * 24 * 14),
            email_token_ttl_secs: parse_or("EMAIL_TOKEN_TTL_SECS", 60 * 60 * 24),
        }
    }
}
