use std::fmt;
use std::io;
use candid::Principal;
use tokio_tungstenite::tungstenite::Error as WsError;
use std::time::Duration;
use candid::{Nat};


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
    HttpRequestFailed(String),
    InvalidTransaction(String),
    TransactionNotFound(String),
    TransactionRejected(String),
    TransactionMalformed(String),
    TransactionAlreadyExists(String),
    TransactionTimeout(String),
    TransactionInsufficientFunds(String),
    TransactionInvalidSignature(String),
    TransactionInvalidSequence(String),
    Other(String),
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

impl From<anyhow::Error> for XRPLError {
    fn from(e: anyhow::Error) -> Self {
        XRPLError::Other(e.to_string())
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
pub struct MemoField {
    #[serde(rename = "MemoType")]
    pub memo_type: Option<String>,
    #[serde(rename = "MemoData")]
    pub memo_data: Option<String>,
    #[serde(rename = "MemoFormat")]
    pub memo_format: Option<String>,
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
    pub ledger_index: u64,
    pub sequence: u32,
    pub memos: Option<Vec<MemoField>>,
    // Add more fields as needed from XRPL spec
}

// A filtered, bridge-relevant XRPL transaction ready for processing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CandidateXRPLTx {
    pub tx_hash: String,
    pub sender: String,
    pub destination: String,
    pub destination_tag: Option<u32>,
    pub amount: Nat, // Using candid's Nat for large numbers
    pub memo: String,
}

#[derive(Debug, Clone, PartialEq)]
pub enum XRPLActionType {
    Tip,
    NFTSale,
    TokenSwap,
}

#[derive(Debug, Clone)]
pub struct ParsedMemo {
    pub action: XRPLActionType,
    pub artist: Option<Principal>,
    pub nft_id: Option<Nat>,
    pub uuid: Option<String>,
}

#[derive(Debug, Clone)]
pub struct VerifiedXRPLTx {
    pub tx_hash: String,
    pub action: XRPLActionType,
    pub sender: String,
    pub amount: Nat,
    pub memo: ParsedMemo,
    pub timestamp: u64,
}

#[derive(Debug)]
pub enum VerifierError {
    ReplayDetected(String),
    InvalidTag(u32),
    MemoParseFailed(String),
    InsufficientAmount(Nat, Nat),
    InvalidDestination(String),
    Internal(String),
    InvalidMemoFormat,
    UnknownAction,
}

#[derive(Clone, Debug)]
pub struct XRPLClientConfig {
    pub endpoint: String,
    pub max_retries: u8,
    pub ping_interval: Duration,
    pub accounts: Vec<String>,
}

/// Tracks XRPL mirror info for a specific asset.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct XRPLMirrorStatus {
    pub mirrored: bool,
    pub pending: bool,
    pub tx_hash: Option<String>,
    pub mirror_type: Option<String>, // e.g., "NFT", "IOU", etc.
}

#[derive(Debug, Clone)]
pub enum MirrorError {
    AlreadyExists(String),
    NotFound(String),
    InvalidStatus(String),
    Internal(String),
    InternalError(String),
    NetworkError(String),
    InvalidAssetId(String),
    InvalidArtist(String),
    InvalidMetadata(String),
    InvalidMirrorType(String),
    InsufficientFunds(String),
    InvalidParameters(String),
    Other(String), 

}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TipRequest {
    pub artist_principal: String,
    pub amount: u64,
    pub memo: Option<String>,
    pub destination_tag: Option<u32>,
}

pub struct XRPLSubmitResult {
    pub tx_hash: String,
    pub status: String, // e.g., "submitted", "confirmed", etc.
    pub ledger_index: u64,
}