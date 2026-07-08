use std::sync::Arc;

use axum::routing::{delete, get, post};
use axum::{Json, Router};
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

mod auth;
mod config;
mod db;
mod email;
mod error;
mod models;
mod repo;
mod routes;
mod state;
mod storage;
mod tokens;
mod util;

use config::Config;
use error::AppResult;
use state::AppState;
use storage::LocalDisk;

#[tokio::main]
async fn main() -> AppResult<()> {
    dotenvy::from_filename("../.env").ok();
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let config = Arc::new(Config::from_env());
    let db = db::init(&config).await?;
    let storage = Arc::new(LocalDisk::new(
        &config.storage_dir,
        &config.attachment_enc_hexkey,
    )?);
    let mailer = Arc::from(email::build(&config.resend_api_key, &config.email_from));
    let state = AppState {
        db,
        config: config.clone(),
        storage,
        mailer,
    };

    let app = router(state);
    let listener = tokio::net::TcpListener::bind(&config.bind_addr).await?;
    tracing::info!("listening on {}", config.bind_addr);
    axum::serve(listener, app).await?;
    Ok(())
}

fn router(state: AppState) -> Router {
    let cors = if state.config.cors_origins.iter().any(|o| o == "*") {
        CorsLayer::new()
            .allow_origin(Any)
            .allow_methods(Any)
            .allow_headers(Any)
    } else {
        CorsLayer::new()
            .allow_methods(Any)
            .allow_headers(Any)
            .allow_origin(
                state
                    .config
                    .cors_origins
                    .iter()
                    .filter_map(|o| o.parse().ok())
                    .collect::<Vec<_>>(),
            )
    };

    Router::new()
        .route("/health", get(health))
        .nest(
            "/api",
            Router::new()
                .route("/auth/signup", post(auth::routes::signup))
                .route("/auth/login", post(auth::routes::login))
                .route("/auth/refresh", post(auth::routes::refresh))
                .route("/auth/logout", post(auth::routes::logout))
                .route("/auth/me", get(auth::routes::me))
                .route("/auth/verify-email", post(auth::routes::verify_email))
                .route(
                    "/auth/resend-verification",
                    post(auth::routes::resend_verification),
                )
                .route(
                    "/auth/request-password-reset",
                    post(auth::routes::request_password_reset),
                )
                .route("/auth/reset-password", post(auth::routes::reset_password))
                .route(
                    "/books",
                    get(routes::books::list).post(routes::books::create),
                )
                .route(
                    "/books/{id}",
                    get(routes::books::get)
                        .patch(routes::books::rename)
                        .delete(routes::books::delete),
                )
                .route(
                    "/books/{id}/members",
                    get(routes::members::list).post(routes::members::add),
                )
                .route(
                    "/books/{id}/members/{user_id}",
                    delete(routes::members::remove),
                )
                .route("/books/{id}/invites", get(routes::invites::list))
                .route(
                    "/books/{id}/invites/{invite_id}",
                    delete(routes::invites::delete),
                )
                .route("/invites/{token}/accept", post(routes::invites::accept))
                .route(
                    "/books/{id}/share-links",
                    get(routes::share_links::list).post(routes::share_links::create),
                )
                .route(
                    "/books/{id}/share-links/{link_id}",
                    delete(routes::share_links::delete),
                )
                .route("/share-links/{token}", get(routes::share_links::preview))
                .route(
                    "/share-links/{token}/accept",
                    post(routes::share_links::accept),
                )
                .route(
                    "/books/{id}/quotes",
                    get(routes::quotes::list).post(routes::quotes::create),
                )
                .route(
                    "/books/{id}/quotes/{quote_id}",
                    delete(routes::quotes::delete),
                )
                .route(
                    "/quotes/{quote_id}/attachments",
                    post(routes::attachments::upload),
                )
                .route(
                    "/attachments/{id}",
                    get(routes::attachments::get).delete(routes::attachments::delete),
                ),
        )
        .with_state(state)
        .layer(cors)
        .layer(TraceLayer::new_for_http())
}

async fn health() -> Json<serde_json::Value> {
    Json(serde_json::json!({ "ok": true }))
}
