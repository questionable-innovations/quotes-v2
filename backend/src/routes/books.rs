use axum::extract::{Path, State};
use axum::Json;

use crate::auth::extractor::AuthUser;
use crate::db;
use crate::error::AppResult;
use crate::models::*;
use crate::repo;
use crate::state::AppState;

pub async fn list(State(state): State<AppState>, auth: AuthUser) -> AppResult<Json<Vec<BookDto>>> {
    let conn = db::connect(&state.db)?;
    repo::list_books(&conn, &auth.id).await.map(Json)
}

pub async fn create(
    State(state): State<AppState>,
    auth: AuthUser,
    Json(req): Json<CreateBookReq>,
) -> AppResult<Json<BookDto>> {
    let conn = db::connect(&state.db)?;
    repo::create_book(&conn, &auth.id, req.name.trim())
        .await
        .map(Json)
}

pub async fn get(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
) -> AppResult<Json<BookDto>> {
    let conn = db::connect(&state.db)?;
    repo::require_view_book(&conn, &auth.id, &book_id).await?;
    let book = repo::book_dto(&conn, &auth.id, &book_id).await?.unwrap();
    Ok(Json(book))
}

pub async fn rename(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
    Json(req): Json<RenameBookReq>,
) -> AppResult<Json<BookDto>> {
    let conn = db::connect(&state.db)?;
    repo::require_owner(&conn, &auth.id, &book_id).await?;
    repo::rename_book(&conn, &book_id, req.name.trim()).await?;
    let book = repo::book_dto(&conn, &auth.id, &book_id).await?.unwrap();
    Ok(Json(book))
}

pub async fn delete(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    repo::require_owner(&conn, &auth.id, &book_id).await?;
    let keys = repo::delete_book_records(&conn, &book_id).await?;
    for key in keys {
        state.storage.delete(&key)?;
    }
    Ok(Json(serde_json::json!({ "ok": true })))
}
