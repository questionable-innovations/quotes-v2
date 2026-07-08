use std::sync::Arc;

use crate::config::Config;
use crate::db::Db;
use crate::email::Mailer;
use crate::storage::Storage;

/// Shared application state handed to every handler.
#[derive(Clone)]
pub struct AppState {
    pub db: Db,
    pub config: Arc<Config>,
    pub storage: Arc<dyn Storage>,
    pub mailer: Arc<dyn Mailer>,
}
