-- Quote Book schema. Standard SQLite subset (Turso-compatible).
-- UUID/text primary keys mirror the original Supabase ids so migrated FKs map directly.

CREATE TABLE IF NOT EXISTS users (
    id            TEXT PRIMARY KEY,
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    email_verified INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS books (
    id         TEXT PRIMARY KEY,
    name       TEXT,
    owner      TEXT NOT NULL REFERENCES users(id),
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS book_members (
    id    TEXT PRIMARY KEY,
    user  TEXT NOT NULL REFERENCES users(id),
    book  TEXT NOT NULL REFERENCES books(id),
    created_at TEXT NOT NULL,
    UNIQUE(user, book)
);

CREATE TABLE IF NOT EXISTS quotes (
    id         TEXT PRIMARY KEY,
    book       TEXT NOT NULL REFERENCES books(id),
    person     TEXT NOT NULL,
    quote      TEXT NOT NULL,
    date       TEXT NOT NULL,
    created_by TEXT REFERENCES users(id),
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS attachments (
    id           TEXT PRIMARY KEY,
    quote        TEXT NOT NULL REFERENCES quotes(id),
    filename     TEXT NOT NULL,
    content_type TEXT NOT NULL,
    size_bytes   INTEGER NOT NULL,
    storage_key  TEXT NOT NULL,
    created_by   TEXT REFERENCES users(id),
    created_at   TEXT NOT NULL
);

-- Pending share to an email address that may not have an account yet.
CREATE TABLE IF NOT EXISTS book_invites (
    id          TEXT PRIMARY KEY,
    book        TEXT NOT NULL REFERENCES books(id),
    email       TEXT NOT NULL,
    token_hash  TEXT NOT NULL,
    invited_by  TEXT NOT NULL REFERENCES users(id),
    expires_at  TEXT NOT NULL,
    accepted_at TEXT,
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS share_links (
    id         TEXT PRIMARY KEY,
    book       TEXT NOT NULL REFERENCES books(id),
    token_hash TEXT NOT NULL,
    created_by TEXT NOT NULL REFERENCES users(id),
    expires_at TEXT,
    max_uses   INTEGER,
    uses       INTEGER NOT NULL DEFAULT 0,
    revoked    INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);

-- Email verification + password reset tokens (kind = 'verify' | 'reset').
CREATE TABLE IF NOT EXISTS email_tokens (
    id         TEXT PRIMARY KEY,
    user       TEXT NOT NULL REFERENCES users(id),
    kind       TEXT NOT NULL,
    token_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    used       INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id         TEXT PRIMARY KEY,
    user       TEXT NOT NULL REFERENCES users(id),
    token_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked    INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_quotes_book ON quotes(book);
CREATE INDEX IF NOT EXISTS idx_members_book ON book_members(book);
CREATE INDEX IF NOT EXISTS idx_members_user ON book_members(user);
CREATE INDEX IF NOT EXISTS idx_attachments_quote ON attachments(quote);
CREATE INDEX IF NOT EXISTS idx_invites_email ON book_invites(email);
CREATE INDEX IF NOT EXISTS idx_invites_token ON book_invites(token_hash);
CREATE INDEX IF NOT EXISTS idx_share_links_book ON share_links(book);
CREATE INDEX IF NOT EXISTS idx_share_links_token ON share_links(token_hash);
CREATE INDEX IF NOT EXISTS idx_email_tokens_token ON email_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token ON refresh_tokens(token_hash);
