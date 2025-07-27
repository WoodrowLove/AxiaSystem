/// 📊 Shared Types for IC Integration

use serde::{Deserialize, Serialize};
use candid::CandidType;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BridgeHealth {
    pub agent_connected: bool,
    pub identity_loaded: bool,
    pub last_ping: Option<i64>,
    pub recent_calls: Vec<BridgeCall>,
    pub error_count: u32,
    pub uptime_seconds: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BridgeCall {
    pub id: String,
    pub method: String,
    pub canister: String,
    pub timestamp: i64,
    pub duration_ms: u64,
    pub success: bool,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BridgeMetadata {
    pub version: String,
    pub build_timestamp: String,
    pub supported_canisters: Vec<String>,
    pub features: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, CandidType)]
pub struct UserProfile {
    pub id: String,
    pub username: String,
    pub email: String,
    pub created_at: u64,
    pub last_login: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, CandidType)]
pub struct PaymentRequest {
    pub amount: u64,
    pub currency: String,
    pub recipient: String,
    pub metadata: Vec<(String, String)>,
}

#[derive(Debug, Clone, Serialize, Deserialize, CandidType)]
pub struct PaymentResult {
    pub transaction_id: String,
    pub status: String,
    pub amount: u64,
    pub timestamp: u64,
}
