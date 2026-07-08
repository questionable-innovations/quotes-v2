use axum::extract::{Path, State};
use axum::Json;

use crate::auth::extractor::AuthUser;
use crate::db;
use crate::email;
use crate::error::{AppError, AppResult};
use crate::models::*;
use crate::repo;
use crate::state::AppState;
use crate::tokens;
use crate::util::iso_in;

pub async fn list(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
) -> AppResult<Json<Vec<MemberDto>>> {
    let conn = db::connect(&state.db)?;
    repo::require_owner(&conn, &auth.id, &book_id).await?;
    repo::list_members(&conn, &book_id).await.map(Json)
}

pub async fn add(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
    Json(req): Json<AddMemberReq>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    let book = repo::require_owner(&conn, &auth.id, &book_id).await?;
    let email_addr = req.email.trim().to_lowercase();
    if email_addr == auth.email.to_lowercase() {
        return Err(AppError::BadRequest(
            "cannot share a book with yourself".into(),
        ));
    }
    if let Some(user) = repo::user_by_email(&conn, &email_addr).await? {
        if repo::is_member(&conn, &user.id, &book_id).await? {
            return Err(AppError::Conflict("user is already a member".into()));
        }
        repo::add_member(&conn, &user.id, &book_id).await?;
        Ok(Json(serde_json::json!({ "added": true, "invited": false })))
    } else {
        let raw = tokens::generate();
        let invite = repo::create_invite(
            &conn,
            &book_id,
            &email_addr,
            &auth.id,
            &raw,
            &iso_in(state.config.invite_ttl_secs),
        )
        .await?;
        let (subject, html) = email::invite(
            &state.config.frontend_base_url,
            &raw,
            book.name.as_deref().unwrap_or("Untitled"),
            &auth.email,
        )?;
        state.mailer.send(&email_addr, &subject, &html).await?;
        Ok(Json(
            serde_json::json!({ "added": false, "invited": true, "invite": invite }),
        ))
    }
}

pub async fn remove(
    State(state): State<AppState>,
    auth: AuthUser,
    Path((book_id, user_id)): Path<(String, String)>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    repo::require_owner(&conn, &auth.id, &book_id).await?;
    repo::remove_member(&conn, &book_id, &user_id).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}
