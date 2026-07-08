use axum::extract::State;
use axum::Json;

use crate::auth::extractor::AuthUser;
use crate::auth::{jwt, password};
use crate::db;
use crate::email;
use crate::error::{AppError, AppResult};
use crate::models::*;
use crate::repo;
use crate::state::AppState;
use crate::tokens;
use crate::util::iso_in;

fn user_dto(user: &repo::UserRow) -> UserDto {
    UserDto {
        id: user.id.clone(),
        email: user.email.clone(),
        email_verified: user.email_verified,
    }
}

async fn issue_pair(state: &AppState, user: &repo::UserRow) -> AppResult<AuthResponse> {
    let access_token = jwt::create(&user.id, &user.email, &state.config)?;
    let refresh_token = tokens::generate();
    let conn = db::connect(&state.db)?;
    repo::create_refresh_token(
        &conn,
        &user.id,
        &refresh_token,
        &iso_in(state.config.refresh_ttl_secs),
    )
    .await?;
    Ok(AuthResponse {
        access_token,
        refresh_token,
        user: user_dto(user),
    })
}

pub async fn signup(
    State(state): State<AppState>,
    Json(req): Json<SignupReq>,
) -> AppResult<Json<AuthResponse>> {
    let email = req.email.trim().to_lowercase();
    if email.is_empty() || req.password.len() < 8 {
        return Err(AppError::BadRequest(
            "email and password>=8 are required".into(),
        ));
    }
    let conn = db::connect(&state.db)?;
    let hash = password::hash(&req.password)?;
    let user = repo::create_user(&conn, &email, &hash).await?;

    let verify_token = tokens::generate();
    repo::create_email_token(
        &conn,
        &user.id,
        "verify",
        &verify_token,
        &iso_in(state.config.email_token_ttl_secs),
    )
    .await?;
    let (subject, html) = email::verify_email(&state.config.frontend_base_url, &verify_token)?;
    state.mailer.send(&user.email, &subject, &html).await?;

    if let Some(invite_token) = req.invite_token {
        repo::accept_invite(&conn, &invite_token, &user.id).await?;
    }

    issue_pair(&state, &user).await.map(Json)
}

pub async fn login(
    State(state): State<AppState>,
    Json(req): Json<LoginReq>,
) -> AppResult<Json<AuthResponse>> {
    let conn = db::connect(&state.db)?;
    let user = repo::user_by_email(&conn, req.email.trim())
        .await?
        .ok_or(AppError::Unauthorized)?;
    let stored = user.password_hash.as_deref().unwrap_or("");
    if !password::verify(&req.password, stored) {
        return Err(AppError::Unauthorized);
    }
    issue_pair(&state, &user).await.map(Json)
}

pub async fn refresh(
    State(state): State<AppState>,
    Json(req): Json<RefreshReq>,
) -> AppResult<Json<AuthResponse>> {
    let conn = db::connect(&state.db)?;
    let user = repo::consume_refresh_token(&conn, &req.refresh_token).await?;
    issue_pair(&state, &user).await.map(Json)
}

pub async fn logout(
    State(state): State<AppState>,
    Json(req): Json<LogoutReq>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    repo::revoke_refresh_token(&conn, &req.refresh_token).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}

pub async fn me(State(state): State<AppState>, auth: AuthUser) -> AppResult<Json<UserDto>> {
    let conn = db::connect(&state.db)?;
    let user = repo::user_by_id(&conn, &auth.id)
        .await?
        .ok_or(AppError::Unauthorized)?;
    Ok(Json(user_dto(&user)))
}

pub async fn verify_email(
    State(state): State<AppState>,
    Json(req): Json<TokenReq>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    let user_id = repo::consume_email_token(&conn, &req.token, "verify").await?;
    repo::mark_email_verified(&conn, &user_id).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}

pub async fn resend_verification(
    State(state): State<AppState>,
    auth: AuthUser,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    let token = tokens::generate();
    repo::create_email_token(
        &conn,
        &auth.id,
        "verify",
        &token,
        &iso_in(state.config.email_token_ttl_secs),
    )
    .await?;
    let (subject, html) = email::verify_email(&state.config.frontend_base_url, &token)?;
    state.mailer.send(&auth.email, &subject, &html).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}

pub async fn request_password_reset(
    State(state): State<AppState>,
    Json(req): Json<EmailReq>,
) -> AppResult<Json<serde_json::Value>> {
    let conn = db::connect(&state.db)?;
    if let Some(user) = repo::user_by_email(&conn, req.email.trim()).await? {
        let token = tokens::generate();
        repo::create_email_token(
            &conn,
            &user.id,
            "reset",
            &token,
            &iso_in(state.config.email_token_ttl_secs),
        )
        .await?;
        let (subject, html) = email::reset_password(&state.config.frontend_base_url, &token)?;
        state.mailer.send(&user.email, &subject, &html).await?;
    }
    Ok(Json(serde_json::json!({ "ok": true })))
}

pub async fn reset_password(
    State(state): State<AppState>,
    Json(req): Json<ResetPasswordReq>,
) -> AppResult<Json<serde_json::Value>> {
    if req.password.len() < 8 {
        return Err(AppError::BadRequest(
            "password must be at least 8 characters".into(),
        ));
    }
    let conn = db::connect(&state.db)?;
    let user_id = repo::consume_email_token(&conn, &req.token, "reset").await?;
    let hash = password::hash(&req.password)?;
    repo::update_password(&conn, &user_id, &hash).await?;
    Ok(Json(serde_json::json!({ "ok": true })))
}
