use axum::body::Body;
use axum::extract::{Multipart, Path, State};
use axum::http::{header, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::Json;

use crate::auth::extractor::AuthUser;
use crate::db;
use crate::error::{AppError, AppResult};
use crate::models::AttachmentDto;
use crate::repo;
use crate::state::AppState;

pub async fn upload(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(quote_id): Path<String>,
    mut multipart: Multipart,
) -> AppResult<Json<AttachmentDto>> {
    let conn = db::connect(&state.db)?;
    let quote = repo::quote_row(&conn, &quote_id)
        .await?
        .ok_or_else(|| AppError::NotFound("quote not found".into()))?;
    repo::require_view_book(&conn, &auth.id, &quote.book).await?;

    let mut file_name = "attachment.bin".to_string();
    let mut content_type = "application/octet-stream".to_string();
    let mut bytes = None;
    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::BadRequest(format!("multipart: {e}")))?
    {
        if field.name() == Some("file") {
            if let Some(name) = field.file_name() {
                file_name = name.to_string();
            }
            if let Some(ct) = field.content_type() {
                content_type = ct.to_string();
            }
            let data = field
                .bytes()
                .await
                .map_err(|e| AppError::BadRequest(format!("multipart: {e}")))?;
            if data.len() > state.config.max_upload_bytes {
                return Err(AppError::BadRequest("attachment too large".into()));
            }
            bytes = Some(data.to_vec());
            break;
        }
    }
    let data = bytes.ok_or_else(|| AppError::BadRequest("missing multipart file field".into()))?;
    let storage_key = state.storage.put(&data)?;
    repo::create_attachment(
        &conn,
        &quote_id,
        &file_name,
        &content_type,
        data.len() as i64,
        &storage_key,
        &auth.id,
    )
    .await
    .map(Json)
}

pub async fn get(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(attachment_id): Path<String>,
) -> AppResult<Response> {
    let conn = db::connect(&state.db)?;
    let attachment = repo::attachment_row(&conn, &attachment_id)
        .await?
        .ok_or_else(|| AppError::NotFound("attachment not found".into()))?;
    let quote = repo::quote_row(&conn, &attachment.quote)
        .await?
        .ok_or_else(|| AppError::NotFound("quote not found".into()))?;
    repo::require_view_book(&conn, &auth.id, &quote.book).await?;
    let bytes = state.storage.get(&attachment.storage_key)?;
    let mut res = (StatusCode::OK, Body::from(bytes)).into_response();
    res.headers_mut().insert(
        header::CONTENT_TYPE,
        HeaderValue::from_str(&attachment.content_type)
            .unwrap_or_else(|_| HeaderValue::from_static("application/octet-stream")),
    );
    let disposition = format!(
        "attachment; filename=\"{}\"",
        attachment.filename.replace('"', "")
    );
    if let Ok(value) = HeaderValue::from_str(&disposition) {
        res.headers_mut().insert(header::CONTENT_DISPOSITION, value);
    }
    Ok(res)
}

pub async fn delete(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(attachment_id): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    let attachment = repo::attachment_row(&conn, &attachment_id)
        .await?
        .ok_or_else(|| AppError::NotFound("attachment not found".into()))?;
    let quote = repo::quote_row(&conn, &attachment.quote)
        .await?
        .ok_or_else(|| AppError::NotFound("quote not found".into()))?;
    let book = repo::require_view_book(&conn, &auth.id, &quote.book).await?;
    if attachment.created_by.as_deref() != Some(auth.id.as_str()) && book.owner != auth.id {
        return Err(AppError::Forbidden);
    }
    repo::delete_attachment_record(&conn, &attachment_id).await?;
    state.storage.delete(&attachment.storage_key)?;
    Ok(Json(serde_json::json!({ "ok": true })))
}
