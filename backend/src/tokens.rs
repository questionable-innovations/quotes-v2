use rand::Rng;
use sha2::{Digest, Sha256};

/// Generate a URL-safe random opaque token (raw secret, shown once).
pub fn generate() -> String {
    let mut bytes = [0u8; 32];
    rand::rng().fill_bytes(&mut bytes);
    hex::encode(bytes)
}

/// Deterministic SHA-256 hash used to store tokens at rest.
pub fn hash(token: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(token.as_bytes());
    hex::encode(hasher.finalize())
}
