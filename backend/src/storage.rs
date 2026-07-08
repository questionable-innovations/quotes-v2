use std::path::{Path, PathBuf};

use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};
use rand::Rng;

use crate::error::{AppError, AppResult};

/// Attachment blob storage. Currently local disk with encryption at rest;
/// the trait keeps a future S3/MinIO backend a one-file swap.
pub trait Storage: Send + Sync {
    /// Persist bytes, returning an opaque storage key.
    fn put(&self, data: &[u8]) -> AppResult<String>;
    /// Read bytes back for a storage key.
    fn get(&self, key: &str) -> AppResult<Vec<u8>>;
    /// Remove a stored blob (missing key is not an error).
    fn delete(&self, key: &str) -> AppResult<()>;
}

pub struct LocalDisk {
    dir: PathBuf,
    /// 32-byte key; None disables at-rest encryption (dev only).
    cipher_key: Option<[u8; 32]>,
}

impl LocalDisk {
    pub fn new(dir: &str, hexkey: &str) -> AppResult<Self> {
        std::fs::create_dir_all(dir)?;
        let cipher_key = if hexkey.trim().is_empty() {
            None
        } else {
            let bytes = hex::decode(hexkey.trim())
                .map_err(|_| AppError::Internal("ATTACHMENT_ENC_KEY not valid hex".into()))?;
            let arr: [u8; 32] = bytes.try_into().map_err(|_| {
                AppError::Internal("ATTACHMENT_ENC_KEY must be 32 bytes (64 hex chars)".into())
            })?;
            Some(arr)
        };
        Ok(LocalDisk {
            dir: PathBuf::from(dir),
            cipher_key,
        })
    }

    fn path(&self, key: &str) -> PathBuf {
        self.dir.join(key)
    }

    fn encrypt(&self, key: &[u8; 32], plaintext: &[u8]) -> AppResult<Vec<u8>> {
        let cipher = XChaCha20Poly1305::new(key.into());
        let mut nonce = [0u8; 24];
        rand::rng().fill_bytes(&mut nonce);
        let nonce_ref = <&XNonce>::try_from(nonce.as_slice())
            .map_err(|_| AppError::Internal("attachment nonce invalid".into()))?;
        let ciphertext = cipher
            .encrypt(nonce_ref, plaintext)
            .map_err(|_| AppError::Internal("attachment encrypt failed".into()))?;
        // Layout: [24-byte nonce][ciphertext+tag]
        let mut out = Vec::with_capacity(24 + ciphertext.len());
        out.extend_from_slice(&nonce);
        out.extend_from_slice(&ciphertext);
        Ok(out)
    }

    fn decrypt(&self, key: &[u8; 32], stored: &[u8]) -> AppResult<Vec<u8>> {
        if stored.len() < 24 {
            return Err(AppError::Internal("attachment file too short".into()));
        }
        let (nonce, ciphertext) = stored.split_at(24);
        let cipher = XChaCha20Poly1305::new(key.into());
        let nonce_ref = <&XNonce>::try_from(nonce)
            .map_err(|_| AppError::Internal("attachment nonce invalid".into()))?;
        cipher
            .decrypt(nonce_ref, ciphertext)
            .map_err(|_| AppError::Internal("attachment decrypt failed".into()))
    }
}

impl Storage for LocalDisk {
    fn put(&self, data: &[u8]) -> AppResult<String> {
        let key = format!("{}.bin", crate::tokens::generate());
        let bytes = match &self.cipher_key {
            Some(k) => self.encrypt(k, data)?,
            None => data.to_vec(),
        };
        std::fs::write(self.path(&key), bytes)?;
        Ok(key)
    }

    fn get(&self, key: &str) -> AppResult<Vec<u8>> {
        let path = self.path(key);
        if !Path::new(&path).exists() {
            return Err(AppError::NotFound("attachment file missing".into()));
        }
        let bytes = std::fs::read(&path)?;
        match &self.cipher_key {
            Some(k) => self.decrypt(k, &bytes),
            None => Ok(bytes),
        }
    }

    fn delete(&self, key: &str) -> AppResult<()> {
        let path = self.path(key);
        if Path::new(&path).exists() {
            std::fs::remove_file(&path)?;
        }
        Ok(())
    }
}
