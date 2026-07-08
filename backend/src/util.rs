use time::format_description::well_known::Rfc3339;
use time::{Duration, OffsetDateTime};

/// Current UTC time as an ISO-8601 / RFC-3339 string (our canonical timestamp format).
pub fn now_iso() -> String {
    OffsetDateTime::now_utc()
        .format(&Rfc3339)
        .unwrap_or_default()
}

/// `now + secs` as an ISO-8601 string (token/invite expiry).
pub fn iso_in(secs: i64) -> String {
    (OffsetDateTime::now_utc() + Duration::seconds(secs))
        .format(&Rfc3339)
        .unwrap_or_default()
}

/// True if the RFC-3339 timestamp is in the past. Unparseable → treated as expired.
pub fn is_past(iso: &str) -> bool {
    match OffsetDateTime::parse(iso, &Rfc3339) {
        Ok(t) => t <= OffsetDateTime::now_utc(),
        Err(_) => true,
    }
}

pub fn new_id() -> String {
    uuid::Uuid::new_v4().to_string()
}
