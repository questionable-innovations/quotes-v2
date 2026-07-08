use argon2::password_hash::{
    rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString,
};
use argon2::Argon2;

use crate::error::{AppError, AppResult};

pub fn hash(password: &str) -> AppResult<String> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map(|h| h.to_string())
        .map_err(|e| AppError::Internal(format!("hash password: {e}")))
}

pub fn verify(password: &str, stored: &str) -> bool {
    if stored.trim().is_empty() {
        return false;
    }
    if stored.starts_with("$2a$") || stored.starts_with("$2b$") || stored.starts_with("$2y$") {
        return bcrypt::verify(password, stored).unwrap_or(false);
    }
    PasswordHash::new(stored)
        .ok()
        .and_then(|parsed| {
            Argon2::default()
                .verify_password(password.as_bytes(), &parsed)
                .ok()
        })
        .is_some()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verifies_argon2_hashes() {
        let hashed = hash("secret").unwrap();
        assert!(verify("secret", &hashed));
        assert!(!verify("wrong", &hashed));
    }

    #[test]
    fn verifies_bcrypt_hashes() {
        let hashed = bcrypt::hash("secret", 4).unwrap();
        assert!(verify("secret", &hashed));
        assert!(!verify("wrong", &hashed));
    }
}
