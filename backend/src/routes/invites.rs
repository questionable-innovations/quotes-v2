use axum::extract::{Path, State};
use axum::Json;

use crate::auth::extractor::AuthUser;
use crate::db;
use crate::error::AppResult;
use crate::models::InviteDto;
use crate::repo;
use crate::state::AppState;

pub async fn list(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
) -> AppResult<Json<Vec<InviteDto>>> {
    let conn = db::connect(&state.db)?;
    repo::require_owner(&conn, &auth.id, &book_id).await?;
    repo::list_invites(&conn, &book_id).await.map(Json)
}

pub async fn delete(
    State(state): State<AppState>,
    auth: AuthUser,
    Path((book_id, invite_id)): Path<(String, String)>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    repo::require_owner(&conn, &auth.id, &book_id).await?;
    repo::delete_invite(&conn, &book_id, &invite_id).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}

pub async fn accept(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(token): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    repo::accept_invite(&conn, &token, &auth.id).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}
