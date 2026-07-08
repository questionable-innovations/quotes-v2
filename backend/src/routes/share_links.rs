use axum::extract::{Path, State};
use axum::Json;

use crate::auth::extractor::AuthUser;
use crate::db;
use crate::error::AppResult;
use crate::models::*;
use crate::repo;
use crate::state::AppState;
use crate::tokens;

pub async fn create(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
    Json(req): Json<CreateShareLinkReq>,
) -> AppResult<Json<ShareLinkDto>> {
    let conn = db::connect(&state.db)?;
    repo::require_owner(&conn, &auth.id, &book_id).await?;
    let raw = tokens::generate();
    repo::create_share_link(
        &conn,
        &book_id,
        &auth.id,
        &raw,
        &req,
        &state.config.frontend_base_url,
    )
    .await
    .map(Json)
}

pub async fn list(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
) -> AppResult<Json<Vec<ShareLinkDto>>> {
    let conn = db::connect(&state.db)?;
    repo::require_owner(&conn, &auth.id, &book_id).await?;
    repo::list_share_links(&conn, &book_id, &state.config.frontend_base_url)
        .await
        .map(Json)
}

pub async fn delete(
    State(state): State<AppState>,
    auth: AuthUser,
    Path((book_id, link_id)): Path<(String, String)>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    repo::require_owner(&conn, &auth.id, &book_id).await?;
    repo::revoke_share_link(&conn, &book_id, &link_id).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}

pub async fn preview(
    State(state): State<AppState>,
    Path(token): Path<String>,
) -> AppResult<Json<ShareLinkPreviewDto>> {
    let conn = db::connect(&state.db)?;
    repo::share_preview(&conn, &token).await.map(Json)
}

pub async fn accept(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(token): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    repo::accept_share_link(&conn, &token, &auth.id).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}
