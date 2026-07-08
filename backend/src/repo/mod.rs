use turso::{params, Connection};

use crate::db;
use crate::error::{AppError, AppResult};
use crate::models::*;
use crate::tokens;
use crate::util::{is_past, new_id, now_iso};

#[derive(Clone)]
pub struct UserRow {
    pub id: String,
    pub email: String,
    pub password_hash: Option<String>,
    pub email_verified: bool,
}

#[derive(Clone)]
pub struct BookRow {
    pub _id: String,
    pub name: Option<String>,
    pub owner: String,
    pub _owner_email: String,
}

#[derive(Clone)]
pub struct QuoteRow {
    pub _id: String,
    pub book: String,
    pub created_by: Option<String>,
}

#[derive(Clone)]
pub struct AttachmentRow {
    pub _id: String,
    pub quote: String,
    pub filename: String,
    pub content_type: String,
    pub storage_key: String,
    pub created_by: Option<String>,
}

pub async fn user_by_email(conn: &Connection, email: &str) -> AppResult<Option<UserRow>> {
    let mut rows = conn
        .query(
            "SELECT id,email,password_hash,email_verified FROM users WHERE lower(email)=lower(?)",
            params![email],
        )
        .await?;
    rows.next()
        .await?
        .map(|r| {
            Ok(UserRow {
                id: db::text(&r, 0)?,
                email: db::text(&r, 1)?,
                password_hash: db::opt_text(&r, 2)?,
                email_verified: db::int(&r, 3)? != 0,
            })
        })
        .transpose()
}

pub async fn user_by_id(conn: &Connection, id: &str) -> AppResult<Option<UserRow>> {
    let mut rows = conn
        .query(
            "SELECT id,email,password_hash,email_verified FROM users WHERE id=?",
            params![id],
        )
        .await?;
    rows.next()
        .await?
        .map(|r| {
            Ok(UserRow {
                id: db::text(&r, 0)?,
                email: db::text(&r, 1)?,
                password_hash: db::opt_text(&r, 2)?,
                email_verified: db::int(&r, 3)? != 0,
            })
        })
        .transpose()
}

pub async fn create_user(
    conn: &Connection,
    email: &str,
    password_hash: &str,
) -> AppResult<UserRow> {
    let id = new_id();
    conn.execute(
        "INSERT INTO users(id,email,password_hash,email_verified,created_at) VALUES(?,?,?,?,?)",
        params![id.as_str(), email, password_hash, 0_i64, now_iso().as_str()],
    )
    .await
    .map_err(|e| {
        if e.to_string().to_lowercase().contains("unique") {
            AppError::Conflict("email already exists".into())
        } else {
            AppError::from(e)
        }
    })?;
    Ok(UserRow {
        id,
        email: email.to_string(),
        password_hash: Some(password_hash.to_string()),
        email_verified: false,
    })
}

pub async fn mark_email_verified(conn: &Connection, user_id: &str) -> AppResult<()> {
    conn.execute(
        "UPDATE users SET email_verified=1 WHERE id=?",
        params![user_id],
    )
    .await?;
    Ok(())
}

pub async fn update_password(conn: &Connection, user_id: &str, hash: &str) -> AppResult<()> {
    conn.execute(
        "UPDATE users SET password_hash=? WHERE id=?",
        params![hash, user_id],
    )
    .await?;
    Ok(())
}

pub async fn create_email_token(
    conn: &Connection,
    user_id: &str,
    kind: &str,
    raw: &str,
    expires_at: &str,
) -> AppResult<()> {
    conn.execute(
        "INSERT INTO email_tokens(id,user,kind,token_hash,expires_at,used,created_at) VALUES(?,?,?,?,?,0,?)",
        params![new_id().as_str(), user_id, kind, tokens::hash(raw).as_str(), expires_at, now_iso().as_str()],
    )
    .await?;
    Ok(())
}

pub async fn consume_email_token(conn: &Connection, raw: &str, kind: &str) -> AppResult<String> {
    let hash = tokens::hash(raw);
    let mut rows = conn
        .query(
            "SELECT id,user,expires_at,used FROM email_tokens WHERE token_hash=? AND kind=?",
            params![hash.as_str(), kind],
        )
        .await?;
    let row = rows
        .next()
        .await?
        .ok_or_else(|| AppError::BadRequest("invalid token".into()))?;
    let id = db::text(&row, 0)?;
    let user = db::text(&row, 1)?;
    let expires_at = db::text(&row, 2)?;
    let used = db::int(&row, 3)? != 0;
    if used || is_past(&expires_at) {
        return Err(AppError::BadRequest("expired token".into()));
    }
    conn.execute(
        "UPDATE email_tokens SET used=1 WHERE id=?",
        params![id.as_str()],
    )
    .await?;
    Ok(user)
}

pub async fn create_refresh_token(
    conn: &Connection,
    user_id: &str,
    raw: &str,
    expires_at: &str,
) -> AppResult<()> {
    conn.execute(
        "INSERT INTO refresh_tokens(id,user,token_hash,expires_at,revoked,created_at) VALUES(?,?,?,?,0,?)",
        params![new_id().as_str(), user_id, tokens::hash(raw).as_str(), expires_at, now_iso().as_str()],
    )
    .await?;
    Ok(())
}

pub async fn consume_refresh_token(conn: &Connection, raw: &str) -> AppResult<UserRow> {
    let hash = tokens::hash(raw);
    let mut rows = conn
        .query(
            "SELECT id,user,expires_at,revoked FROM refresh_tokens WHERE token_hash=?",
            params![hash.as_str()],
        )
        .await?;
    let row = rows.next().await?.ok_or(AppError::Unauthorized)?;
    let id = db::text(&row, 0)?;
    let user_id = db::text(&row, 1)?;
    let expires_at = db::text(&row, 2)?;
    let revoked = db::int(&row, 3)? != 0;
    if revoked || is_past(&expires_at) {
        return Err(AppError::Unauthorized);
    }
    conn.execute(
        "UPDATE refresh_tokens SET revoked=1 WHERE id=?",
        params![id.as_str()],
    )
    .await?;
    user_by_id(conn, &user_id)
        .await?
        .ok_or(AppError::Unauthorized)
}

pub async fn revoke_refresh_token(conn: &Connection, raw: &str) -> AppResult<()> {
    conn.execute(
        "UPDATE refresh_tokens SET revoked=1 WHERE token_hash=?",
        params![tokens::hash(raw).as_str()],
    )
    .await?;
    Ok(())
}

pub async fn list_books(conn: &Connection, user_id: &str) -> AppResult<Vec<BookDto>> {
    let mut rows = conn
        .query(
            "SELECT b.id,b.name,u.id,u.email,CASE WHEN b.owner=? THEN 1 ELSE 0 END,\
             (SELECT count(*) FROM quotes q WHERE q.book=b.id) \
             FROM books b JOIN users u ON u.id=b.owner \
             WHERE b.owner=? OR EXISTS (SELECT 1 FROM book_members m WHERE m.book=b.id AND m.user=?) \
             ORDER BY b.created_at DESC",
            params![user_id, user_id, user_id],
        )
        .await?;
    let mut out = Vec::new();
    while let Some(r) = rows.next().await? {
        out.push(BookDto {
            id: db::text(&r, 0)?,
            name: db::opt_text(&r, 1)?,
            owner: OwnerDto {
                id: db::text(&r, 2)?,
                email: db::text(&r, 3)?,
            },
            is_owner: db::int(&r, 4)? != 0,
            quote_count: db::int(&r, 5)?,
        });
    }
    Ok(out)
}

pub async fn create_book(conn: &Connection, user_id: &str, name: &str) -> AppResult<BookDto> {
    let id = new_id();
    conn.execute(
        "INSERT INTO books(id,name,owner,created_at) VALUES(?,?,?,?)",
        params![id.as_str(), name, user_id, now_iso().as_str()],
    )
    .await?;
    book_dto(conn, user_id, &id)
        .await?
        .ok_or_else(|| AppError::Internal("created book missing".into()))
}

pub async fn book_row(conn: &Connection, book_id: &str) -> AppResult<Option<BookRow>> {
    let mut rows = conn
        .query(
            "SELECT b.id,b.name,b.owner,u.email FROM books b JOIN users u ON u.id=b.owner WHERE b.id=?",
            params![book_id],
        )
        .await?;
    rows.next()
        .await?
        .map(|r| {
            Ok(BookRow {
                _id: db::text(&r, 0)?,
                name: db::opt_text(&r, 1)?,
                owner: db::text(&r, 2)?,
                _owner_email: db::text(&r, 3)?,
            })
        })
        .transpose()
}

pub async fn book_dto(
    conn: &Connection,
    user_id: &str,
    book_id: &str,
) -> AppResult<Option<BookDto>> {
    let mut rows = conn
        .query(
            "SELECT b.id,b.name,u.id,u.email,CASE WHEN b.owner=? THEN 1 ELSE 0 END,\
             (SELECT count(*) FROM quotes q WHERE q.book=b.id) \
             FROM books b JOIN users u ON u.id=b.owner WHERE b.id=?",
            params![user_id, book_id],
        )
        .await?;
    rows.next()
        .await?
        .map(|r| {
            Ok(BookDto {
                id: db::text(&r, 0)?,
                name: db::opt_text(&r, 1)?,
                owner: OwnerDto {
                    id: db::text(&r, 2)?,
                    email: db::text(&r, 3)?,
                },
                is_owner: db::int(&r, 4)? != 0,
                quote_count: db::int(&r, 5)?,
            })
        })
        .transpose()
}

pub async fn can_view_book(conn: &Connection, user_id: &str, book_id: &str) -> AppResult<bool> {
    let mut rows = conn
        .query(
            "SELECT 1 FROM books b WHERE b.id=? AND (b.owner=? OR EXISTS (SELECT 1 FROM book_members m WHERE m.book=b.id AND m.user=?))",
            params![book_id, user_id, user_id],
        )
        .await?;
    Ok(rows.next().await?.is_some())
}

pub async fn require_view_book(
    conn: &Connection,
    user_id: &str,
    book_id: &str,
) -> AppResult<BookRow> {
    let book = book_row(conn, book_id)
        .await?
        .ok_or_else(|| AppError::NotFound("book not found".into()))?;
    if book.owner == user_id || can_view_book(conn, user_id, book_id).await? {
        Ok(book)
    } else {
        Err(AppError::Forbidden)
    }
}

pub async fn require_owner(conn: &Connection, user_id: &str, book_id: &str) -> AppResult<BookRow> {
    let book = book_row(conn, book_id)
        .await?
        .ok_or_else(|| AppError::NotFound("book not found".into()))?;
    if book.owner == user_id {
        Ok(book)
    } else {
        Err(AppError::Forbidden)
    }
}

pub async fn rename_book(conn: &Connection, book_id: &str, name: &str) -> AppResult<()> {
    conn.execute("UPDATE books SET name=? WHERE id=?", params![name, book_id])
        .await?;
    Ok(())
}

pub async fn delete_book_records(conn: &Connection, book_id: &str) -> AppResult<Vec<String>> {
    let mut rows = conn
        .query(
            "SELECT a.storage_key FROM attachments a JOIN quotes q ON q.id=a.quote WHERE q.book=?",
            params![book_id],
        )
        .await?;
    let mut keys = Vec::new();
    while let Some(r) = rows.next().await? {
        keys.push(db::text(&r, 0)?);
    }
    conn.execute(
        "DELETE FROM attachments WHERE quote IN (SELECT id FROM quotes WHERE book=?)",
        params![book_id],
    )
    .await?;
    conn.execute("DELETE FROM quotes WHERE book=?", params![book_id])
        .await?;
    conn.execute("DELETE FROM book_members WHERE book=?", params![book_id])
        .await?;
    conn.execute("DELETE FROM book_invites WHERE book=?", params![book_id])
        .await?;
    conn.execute("DELETE FROM share_links WHERE book=?", params![book_id])
        .await?;
    conn.execute("DELETE FROM books WHERE id=?", params![book_id])
        .await?;
    Ok(keys)
}

pub async fn list_members(conn: &Connection, book_id: &str) -> AppResult<Vec<MemberDto>> {
    let mut rows = conn
        .query(
            "SELECT u.id,u.email FROM users u JOIN book_members m ON m.user=u.id WHERE m.book=? ORDER BY u.email",
            params![book_id],
        )
        .await?;
    let mut out = Vec::new();
    while let Some(r) = rows.next().await? {
        out.push(MemberDto {
            id: db::text(&r, 0)?,
            email: db::text(&r, 1)?,
        });
    }
    Ok(out)
}

pub async fn is_member(conn: &Connection, user_id: &str, book_id: &str) -> AppResult<bool> {
    let mut rows = conn
        .query(
            "SELECT 1 FROM book_members WHERE user=? AND book=?",
            params![user_id, book_id],
        )
        .await?;
    Ok(rows.next().await?.is_some())
}

pub async fn add_member(conn: &Connection, user_id: &str, book_id: &str) -> AppResult<()> {
    if is_member(conn, user_id, book_id).await? {
        return Ok(());
    }
    conn.execute(
        "INSERT OR IGNORE INTO book_members(id,user,book,created_at) VALUES(?,?,?,?)",
        params![new_id().as_str(), user_id, book_id, now_iso().as_str()],
    )
    .await?;
    Ok(())
}

pub async fn remove_member(conn: &Connection, book_id: &str, user_id: &str) -> AppResult<()> {
    conn.execute(
        "DELETE FROM book_members WHERE book=? AND user=?",
        params![book_id, user_id],
    )
    .await?;
    Ok(())
}

pub async fn create_invite(
    conn: &Connection,
    book_id: &str,
    email: &str,
    invited_by: &str,
    raw: &str,
    expires_at: &str,
) -> AppResult<InviteDto> {
    let id = new_id();
    let created_at = now_iso();
    conn.execute(
        "INSERT INTO book_invites(id,book,email,token_hash,invited_by,expires_at,created_at) VALUES(?,?,?,?,?,?,?)",
        params![id.as_str(), book_id, email, tokens::hash(raw).as_str(), invited_by, expires_at, created_at.as_str()],
    )
    .await?;
    Ok(InviteDto {
        id,
        email: email.to_string(),
        expires_at: expires_at.to_string(),
        created_at,
    })
}

pub async fn list_invites(conn: &Connection, book_id: &str) -> AppResult<Vec<InviteDto>> {
    let mut rows = conn
        .query("SELECT id,email,expires_at,created_at FROM book_invites WHERE book=? AND accepted_at IS NULL ORDER BY created_at DESC", params![book_id])
        .await?;
    let mut out = Vec::new();
    while let Some(r) = rows.next().await? {
        out.push(InviteDto {
            id: db::text(&r, 0)?,
            email: db::text(&r, 1)?,
            expires_at: db::text(&r, 2)?,
            created_at: db::text(&r, 3)?,
        });
    }
    Ok(out)
}

pub async fn delete_invite(conn: &Connection, book_id: &str, invite_id: &str) -> AppResult<()> {
    conn.execute(
        "DELETE FROM book_invites WHERE book=? AND id=?",
        params![book_id, invite_id],
    )
    .await?;
    Ok(())
}

pub async fn accept_invite(conn: &Connection, raw: &str, user_id: &str) -> AppResult<()> {
    let hash = tokens::hash(raw);
    let mut rows = conn
        .query(
            "SELECT id,book,email,expires_at,accepted_at FROM book_invites WHERE token_hash=?",
            params![hash.as_str()],
        )
        .await?;
    let row = rows
        .next()
        .await?
        .ok_or_else(|| AppError::BadRequest("invalid invite".into()))?;
    let id = db::text(&row, 0)?;
    let book = db::text(&row, 1)?;
    let expires_at = db::text(&row, 3)?;
    let accepted_at = db::opt_text(&row, 4)?;
    if accepted_at.is_some() || is_past(&expires_at) {
        return Err(AppError::BadRequest("expired invite".into()));
    }
    add_member(conn, user_id, &book).await?;
    conn.execute(
        "UPDATE book_invites SET accepted_at=? WHERE id=?",
        params![now_iso().as_str(), id.as_str()],
    )
    .await?;
    Ok(())
}

pub async fn create_quote(
    conn: &Connection,
    book_id: &str,
    user_id: &str,
    req: &CreateQuoteReq,
) -> AppResult<QuoteDto> {
    let id = new_id();
    let created_at = now_iso();
    conn.execute(
        "INSERT INTO quotes(id,book,person,quote,date,created_by,created_at) VALUES(?,?,?,?,?,?,?)",
        params![
            id.as_str(),
            book_id,
            req.person.as_str(),
            req.quote.as_str(),
            req.date.as_str(),
            user_id,
            created_at.as_str()
        ],
    )
    .await?;
    Ok(QuoteDto {
        id,
        person: req.person.clone(),
        quote: req.quote.clone(),
        date: req.date.clone(),
        created_by: Some(user_id.to_string()),
        created_at,
        attachments: Vec::new(),
    })
}

pub async fn list_quotes(conn: &Connection, book_id: &str) -> AppResult<Vec<QuoteDto>> {
    let mut rows = conn
        .query("SELECT id,person,quote,date,created_by,created_at FROM quotes WHERE book=? ORDER BY date DESC, created_at DESC", params![book_id])
        .await?;
    let mut quotes = Vec::new();
    while let Some(r) = rows.next().await? {
        let id = db::text(&r, 0)?;
        let attachments = list_quote_attachments(conn, &id).await?;
        quotes.push(QuoteDto {
            id,
            person: db::text(&r, 1)?,
            quote: db::text(&r, 2)?,
            date: db::text(&r, 3)?,
            created_by: db::opt_text(&r, 4)?,
            created_at: db::text(&r, 5)?,
            attachments,
        });
    }
    Ok(quotes)
}

pub async fn quote_row(conn: &Connection, quote_id: &str) -> AppResult<Option<QuoteRow>> {
    let mut rows = conn
        .query(
            "SELECT id,book,created_by FROM quotes WHERE id=?",
            params![quote_id],
        )
        .await?;
    rows.next()
        .await?
        .map(|r| {
            Ok(QuoteRow {
                _id: db::text(&r, 0)?,
                book: db::text(&r, 1)?,
                created_by: db::opt_text(&r, 2)?,
            })
        })
        .transpose()
}

pub async fn delete_quote_records(conn: &Connection, quote_id: &str) -> AppResult<Vec<String>> {
    let mut rows = conn
        .query(
            "SELECT storage_key FROM attachments WHERE quote=?",
            params![quote_id],
        )
        .await?;
    let mut keys = Vec::new();
    while let Some(r) = rows.next().await? {
        keys.push(db::text(&r, 0)?);
    }
    conn.execute("DELETE FROM attachments WHERE quote=?", params![quote_id])
        .await?;
    conn.execute("DELETE FROM quotes WHERE id=?", params![quote_id])
        .await?;
    Ok(keys)
}

pub async fn create_attachment(
    conn: &Connection,
    quote_id: &str,
    filename: &str,
    content_type: &str,
    size: i64,
    storage_key: &str,
    user_id: &str,
) -> AppResult<AttachmentDto> {
    let id = new_id();
    let created_at = now_iso();
    conn.execute(
        "INSERT INTO attachments(id,quote,filename,content_type,size_bytes,storage_key,created_by,created_at) VALUES(?,?,?,?,?,?,?,?)",
        params![id.as_str(), quote_id, filename, content_type, size, storage_key, user_id, created_at.as_str()],
    )
    .await?;
    Ok(AttachmentDto {
        id,
        filename: filename.to_string(),
        content_type: content_type.to_string(),
        size_bytes: size,
        created_at,
    })
}

pub async fn list_quote_attachments(
    conn: &Connection,
    quote_id: &str,
) -> AppResult<Vec<AttachmentDto>> {
    let mut rows = conn
        .query("SELECT id,filename,content_type,size_bytes,created_at FROM attachments WHERE quote=? ORDER BY created_at", params![quote_id])
        .await?;
    let mut out = Vec::new();
    while let Some(r) = rows.next().await? {
        out.push(AttachmentDto {
            id: db::text(&r, 0)?,
            filename: db::text(&r, 1)?,
            content_type: db::text(&r, 2)?,
            size_bytes: db::int(&r, 3)?,
            created_at: db::text(&r, 4)?,
        });
    }
    Ok(out)
}

pub async fn attachment_row(
    conn: &Connection,
    attachment_id: &str,
) -> AppResult<Option<AttachmentRow>> {
    let mut rows = conn
        .query("SELECT id,quote,filename,content_type,storage_key,created_by FROM attachments WHERE id=?", params![attachment_id])
        .await?;
    rows.next()
        .await?
        .map(|r| {
            Ok(AttachmentRow {
                _id: db::text(&r, 0)?,
                quote: db::text(&r, 1)?,
                filename: db::text(&r, 2)?,
                content_type: db::text(&r, 3)?,
                storage_key: db::text(&r, 4)?,
                created_by: db::opt_text(&r, 5)?,
            })
        })
        .transpose()
}

pub async fn delete_attachment_record(conn: &Connection, attachment_id: &str) -> AppResult<()> {
    conn.execute("DELETE FROM attachments WHERE id=?", params![attachment_id])
        .await?;
    Ok(())
}

pub async fn create_share_link(
    conn: &Connection,
    book_id: &str,
    user_id: &str,
    raw: &str,
    req: &CreateShareLinkReq,
    base_url: &str,
) -> AppResult<ShareLinkDto> {
    let id = new_id();
    let created_at = now_iso();
    conn.execute(
        "INSERT INTO share_links(id,book,token_hash,created_by,expires_at,max_uses,uses,revoked,created_at) VALUES(?,?,?,?,?,?,0,0,?)",
        params![id.as_str(), book_id, tokens::hash(raw).as_str(), user_id, req.expires_at.as_deref(), req.max_uses, created_at.as_str()],
    )
    .await?;
    Ok(ShareLinkDto {
        id,
        url: format!("{base_url}/share?token={raw}"),
        expires_at: req.expires_at.clone(),
        max_uses: req.max_uses,
        uses: 0,
        revoked: false,
        created_at,
    })
}

pub async fn list_share_links(
    conn: &Connection,
    book_id: &str,
    base_url: &str,
) -> AppResult<Vec<ShareLinkDto>> {
    let mut rows = conn
        .query("SELECT id,expires_at,max_uses,uses,revoked,created_at FROM share_links WHERE book=? ORDER BY created_at DESC", params![book_id])
        .await?;
    let mut out = Vec::new();
    while let Some(r) = rows.next().await? {
        let id = db::text(&r, 0)?;
        out.push(ShareLinkDto {
            url: format!("{base_url}/share-links/{id}"),
            id,
            expires_at: db::opt_text(&r, 1)?,
            max_uses: db::opt_int(&r, 2)?,
            uses: db::int(&r, 3)?,
            revoked: db::int(&r, 4)? != 0,
            created_at: db::text(&r, 5)?,
        });
    }
    Ok(out)
}

pub async fn revoke_share_link(conn: &Connection, book_id: &str, link_id: &str) -> AppResult<()> {
    conn.execute(
        "UPDATE share_links SET revoked=1 WHERE book=? AND id=?",
        params![book_id, link_id],
    )
    .await?;
    Ok(())
}

pub async fn share_preview(conn: &Connection, raw: &str) -> AppResult<ShareLinkPreviewDto> {
    let hash = tokens::hash(raw);
    let mut rows = conn
        .query(
            "SELECT b.name,u.email,sl.expires_at,sl.max_uses,sl.uses,sl.revoked \
             FROM share_links sl JOIN books b ON b.id=sl.book JOIN users u ON u.id=b.owner \
             WHERE sl.token_hash=?",
            params![hash.as_str()],
        )
        .await?;
    let r = rows
        .next()
        .await?
        .ok_or_else(|| AppError::NotFound("share link not found".into()))?;
    validate_share_link(&r)?;
    Ok(ShareLinkPreviewDto {
        book_name: db::opt_text(&r, 0)?,
        owner_email: db::text(&r, 1)?,
    })
}

pub async fn accept_share_link(conn: &Connection, raw: &str, user_id: &str) -> AppResult<()> {
    let hash = tokens::hash(raw);
    let mut rows = conn
        .query(
            "SELECT sl.id,sl.book,sl.expires_at,sl.max_uses,sl.uses,sl.revoked FROM share_links sl WHERE sl.token_hash=?",
            params![hash.as_str()],
        )
        .await?;
    let r = rows
        .next()
        .await?
        .ok_or_else(|| AppError::NotFound("share link not found".into()))?;
    validate_share_link_at(&r, 2)?;
    let id = db::text(&r, 0)?;
    let book = db::text(&r, 1)?;
    add_member(conn, user_id, &book).await?;
    conn.execute(
        "UPDATE share_links SET uses=uses+1 WHERE id=?",
        params![id.as_str()],
    )
    .await?;
    Ok(())
}

fn validate_share_link(row: &turso::Row) -> AppResult<()> {
    validate_share_link_at(row, 2)
}

fn validate_share_link_at(row: &turso::Row, offset: usize) -> AppResult<()> {
    let expires_at = db::opt_text(row, offset)?;
    let max_uses = db::opt_int(row, offset + 1)?;
    let uses = db::int(row, offset + 2)?;
    let revoked = db::int(row, offset + 3)? != 0;
    if revoked || expires_at.as_deref().is_some_and(is_past) || max_uses.is_some_and(|m| uses >= m)
    {
        return Err(AppError::Forbidden);
    }
    Ok(())
}
