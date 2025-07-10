use std::fmt;
use std::io;
use tokio_tungstenite::tungstenite::Error as WsError;

#[derive(Debug)]
pub enum XRPLError {
    WebSocketError(WsError),
    HttpError(reqwest::Error),
    IoError(io::Error),
    InvalidResponse(String),
    SubscriptionFailed(String),
    ReconnectFailed(String),
    SendError(String),
    JsonParseError(String),
    UnexpectedMessage(String),
    InvalidEndpoint(String),
    ConnectionFailed(String),
    WebSocketSendFailed(String),
    SubscriptionError(String),
}

impl fmt::Display for XRPLError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::error::Error for XRPLError {}

impl From<WsError> for XRPLError {
    fn from(e: WsError) -> Self {
        XRPLError::WebSocketError(e)
    }
}

impl From<reqwest::Error> for XRPLError {
    fn from(e: reqwest::Error) -> Self {
        XRPLError::HttpError(e)
    }
}

impl From<io::Error> for XRPLError {
    fn from(e: io::Error) -> Self {
        XRPLError::IoError(e)
    }
}

impl From<serde_json::Error> for XRPLError {
    fn from(e: serde_json::Error) -> Self {
        XRPLError::JsonParseError(e.to_string())
    }
}

use serde::Serialize;
use serde::Deserialize;

#[derive(Debug, Serialize)]
#[serde(tag = "command")]
pub enum XRPLCommand {
    #[serde(rename = "subscribe")]
    Subscribe {
        streams: Option<Vec<String>>,
        accounts: Option<Vec<String>>,
    },
    #[serde(rename = "unsubscribe")]
    Unsubscribe {
        streams: Option<Vec<String>>,
        accounts: Option<Vec<String>>,
    },
    #[serde(rename = "ping")]
    Ping,
}

#[derive(Debug, Clone)]
pub struct ReconnectStrategy {
    pub max_attempts: usize,
    pub base_delay_ms: u64,
    pub max_delay_ms: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct XRPLRawTx {
    pub account: String,
    pub destination: Option<String>,
    pub amount: Option<String>,
    pub destination_tag: Option<u32>,
    pub tx_type: Option<String>,
    pub hash: String,
    pub memo: Option<String>,
    // Add more fields as needed from XRPL spec
}