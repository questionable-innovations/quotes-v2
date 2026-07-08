use serde::{Deserialize, Serialize};

// ---- Requests ---------------------------------------------------------------

#[derive(Deserialize)]
pub struct SignupReq {
    pub email: String,
    pub password: String,
    pub invite_token: Option<String>,
}

#[derive(Deserialize)]
pub struct LoginReq {
    pub email: String,
    pub password: String,
}

#[derive(Deserialize)]
pub struct RefreshReq {
    pub refresh_token: String,
}

#[derive(Deserialize)]
pub struct LogoutReq {
    pub refresh_token: String,
}

#[derive(Deserialize)]
pub struct TokenReq {
    pub token: String,
}

#[derive(Deserialize)]
pub struct EmailReq {
    pub email: String,
}

#[derive(Deserialize)]
pub struct ResetPasswordReq {
    pub token: String,
    pub password: String,
}

#[derive(Deserialize)]
pub struct CreateBookReq {
    pub name: String,
}

#[derive(Deserialize)]
pub struct RenameBookReq {
    pub name: String,
}

#[derive(Deserialize)]
pub struct AddMemberReq {
    pub email: String,
}

#[derive(Deserialize)]
pub struct CreateQuoteReq {
    pub person: String,
    pub quote: String,
    pub date: String,
}

#[derive(Deserialize)]
pub struct CreateShareLinkReq {
    pub expires_at: Option<String>,
    pub max_uses: Option<i64>,
}

// ---- Responses --------------------------------------------------------------

#[derive(Serialize, Clone)]
pub struct UserDto {
    pub id: String,
    pub email: String,
    pub email_verified: bool,
}

#[derive(Serialize)]
pub struct AuthResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub user: UserDto,
}

#[derive(Serialize)]
pub struct OwnerDto {
    pub id: String,
    pub email: String,
}

#[derive(Serialize)]
pub struct BookDto {
    pub id: String,
    pub name: Option<String>,
    pub owner: OwnerDto,
    pub is_owner: bool,
    pub quote_count: i64,
}

#[derive(Serialize)]
pub struct MemberDto {
    pub id: String,
    pub email: String,
}

#[derive(Serialize)]
pub struct AttachmentDto {
    pub id: String,
    pub filename: String,
    pub content_type: String,
    pub size_bytes: i64,
    pub created_at: String,
}

#[derive(Serialize)]
pub struct QuoteDto {
    pub id: String,
    pub person: String,
    pub quote: String,
    pub date: String,
    pub created_by: Option<String>,
    pub created_at: String,
    pub attachments: Vec<AttachmentDto>,
}

#[derive(Serialize)]
pub struct InviteDto {
    pub id: String,
    pub email: String,
    pub expires_at: String,
    pub created_at: String,
}

#[derive(Serialize)]
pub struct ShareLinkDto {
    pub id: String,
    pub url: String,
    pub expires_at: Option<String>,
    pub max_uses: Option<i64>,
    pub uses: i64,
    pub revoked: bool,
    pub created_at: String,
}

#[derive(Serialize)]
pub struct ShareLinkPreviewDto {
    pub book_name: Option<String>,
    pub owner_email: String,
}
