use async_trait::async_trait;
use mrml::prelude::render::RenderOptions;
use resend_rs::types::CreateEmailBaseOptions;
use resend_rs::Resend;

use crate::error::{AppError, AppResult};

/// Transactional email sender. Resend in production; a logging no-op otherwise.
#[async_trait]
pub trait Mailer: Send + Sync {
    async fn send(&self, to: &str, subject: &str, html: &str) -> AppResult<()>;
}

pub struct ResendMailer {
    client: Resend,
    from: String,
}

impl ResendMailer {
    pub fn new(api_key: &str, from: &str) -> Self {
        ResendMailer {
            client: Resend::new(api_key),
            from: from.to_string(),
        }
    }
}

#[async_trait]
impl Mailer for ResendMailer {
    async fn send(&self, to: &str, subject: &str, html: &str) -> AppResult<()> {
        let email =
            CreateEmailBaseOptions::new(&self.from, [to.to_string()], subject).with_html(html);
        self.client
            .emails
            .send(email)
            .await
            .map_err(|e| AppError::Internal(format!("resend: {e}")))?;
        Ok(())
    }
}

/// Fallback used when no Resend key is configured: logs the email instead of sending.
pub struct LogMailer;

#[async_trait]
impl Mailer for LogMailer {
    async fn send(&self, to: &str, subject: &str, html: &str) -> AppResult<()> {
        tracing::info!(%to, %subject, "email (log-only, no RESEND_API_KEY)\n{html}");
        Ok(())
    }
}

pub fn build(api_key: &str, from: &str) -> Box<dyn Mailer> {
    if api_key.trim().is_empty() {
        Box::new(LogMailer)
    } else {
        Box::new(ResendMailer::new(api_key, from))
    }
}

// ---- Templates --------------------------------------------------------------

const VERIFY_EMAIL_TEMPLATE: &str = include_str!("email/templates/verify_email.mjml");
const INVITE_TEMPLATE: &str = include_str!("email/templates/invite.mjml");
const RESET_PASSWORD_TEMPLATE: &str = include_str!("email/templates/reset_password.mjml");

pub fn verify_email(base_url: &str, token: &str) -> AppResult<(String, String)> {
    let link = format!("{base_url}/verify-email?token={token}");
    let html = render_template(VERIFY_EMAIL_TEMPLATE, &[("verify_url", &link)])?;
    Ok(("Verify your Quote Book email".to_string(), html))
}

pub fn invite(
    base_url: &str,
    token: &str,
    book_name: &str,
    inviter_email: &str,
) -> AppResult<(String, String)> {
    let link = format!("{base_url}/invite?token={token}");
    let html = render_template(
        INVITE_TEMPLATE,
        &[
            ("invite_url", &link),
            ("book_name", book_name),
            ("inviter_email", inviter_email),
        ],
    )?;
    Ok((
        format!("{inviter_email} shared a quote book with you"),
        html,
    ))
}

pub fn reset_password(base_url: &str, token: &str) -> AppResult<(String, String)> {
    let link = format!("{base_url}/reset-password?token={token}");
    let html = render_template(RESET_PASSWORD_TEMPLATE, &[("reset_url", &link)])?;
    Ok(("Reset your Quote Book password".to_string(), html))
}

fn render_template(template: &str, vars: &[(&str, &str)]) -> AppResult<String> {
    let mut mjml = template.to_string();
    for (key, value) in vars {
        mjml = mjml.replace(&format!("{{{{{key}}}}}"), &escape_xml(value));
    }

    let root = mrml::parse(&mjml)
        .map_err(|e| AppError::Internal(format!("parse email mjml template: {e:?}")))?;
    root.element
        .render(&RenderOptions::default())
        .map_err(|e| AppError::Internal(format!("render email mjml template: {e:?}")))
}

fn escape_xml(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for c in input.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&#39;"),
            _ => out.push(c),
        }
    }
    out
}
