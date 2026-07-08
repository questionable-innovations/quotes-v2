use axum::extract::{Path, State};
use axum::Json;

use crate::auth::extractor::AuthUser;
use crate::db;
use crate::error::{AppError, AppResult};
use crate::models::*;
use crate::repo;
use crate::state::AppState;

pub async fn list(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
) -> AppResult<Json<Vec<QuoteDto>>> {
    let conn = db::connect(&state.db)?;
    repo::require_view_book(&conn, &auth.id, &book_id).await?;
    repo::list_quotes(&conn, &book_id).await.map(Json)
}

pub async fn create(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(book_id): Path<String>,
    Json(req): Json<CreateQuoteReq>,
) -> AppResult<Json<QuoteDto>> {
    let conn = db::connect(&state.db)?;
    repo::require_view_book(&conn, &auth.id, &book_id).await?;
    repo::create_quote(&conn, &book_id, &auth.id, &req)
        .await
        .map(Json)
}

pub async fn delete(
    State(state): State<AppState>,
    auth: AuthUser,
    Path((book_id, quote_id)): Path<(String, String)>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    let book = repo::require_view_book(&conn, &auth.id, &book_id).await?;
    let quote = repo::quote_row(&conn, &quote_id)
        .await?
        .ok_or_else(|| AppError::NotFound("quote not found".into()))?;
    if quote.book != book_id {
        return Err(AppError::NotFound("quote not found".into()));
    }
    if quote.created_by.as_deref() != Some(auth.id.as_str()) && book.owner != auth.id {
        return Err(AppError::Forbidden);
    }
    let keys = repo::delete_quote_records(&conn, &quote_id).await?;
    for key in keys {
        state.storage.delete(&key)?;
    }
    Ok(Json(serde_json::json!({ "ok": true })))
}
