use tokio::time::{sleep, Duration};
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::Message;
use url::Url;
use futures_util::{SinkExt, StreamExt};

use crate::xrpl::types::{CandidateXRPLTx, XRPLCommand, XRPLError, XRPLRawTx, XRPLSubmitResult};
use reqwest::Client;
use dashmap::DashSet;
use once_cell::sync::Lazy;
use candid::Nat;

//Global in-memory cache of subscribed accounts/tags
pub static SUBSCRIBED_ACCOUNTS: Lazy<DashSet<String>> = Lazy::new(|| DashSet::new());


/// Bootstraps the XRPL WebSocket client and starts the main event loop.
/// Will automatically reconnect with exponential backoff if disconnected.
pub async fn connect_to_xrpl() -> Result<(), XRPLError> {
    let endpoint = "wss://s.altnet.rippletest.net:51233"; // Testnet endpoint
    let mut retry_count = 0;
    let max_retries = 5;

    loop {
        match Url::parse(endpoint) {
            Ok(url) => {
                match connect_async(url).await {
                    Ok((ws_stream, _)) => {
                        println!("✅ Connected to XRPL WebSocket.");
                        retry_count = 0; // reset on success
                        let (mut write, mut read) = ws_stream.split();

                        // Send initial ping or config message if needed
                        let ping = serde_json::to_string(&XRPLCommand::Ping)?;
                        write.send(Message::Text(ping)).await?;

                        // Event loop
                        while let Some(msg) = read.next().await {
                            match msg {
                                Ok(Message::Text(txt)) => {
                                    println!("📥 XRPL Msg: {}", txt);
                                    // Here you would call `handle_xrpl_event(&txt)` eventually
                                },
                                Ok(_) => continue,
                                Err(e) => {
                                    eprintln!("⚠️ WebSocket error: {}", e);
                                    break;
                                }
                            }
                        }

                        eprintln!("🔌 XRPL connection lost. Reconnecting...");
                    }
                    Err(e) => {
                        eprintln!("❌ Failed to connect: {}", e);
                    }
                }
            }
            Err(_) => return Err(XRPLError::InvalidEndpoint("Invalid endpoint URL".to_string())),
        }

        if retry_count >= max_retries {
            return Err(XRPLError::ConnectionFailed(
                "Max retries reached. Could not connect to XRPL WebSocket.".to_string()
            ));
        }

        let backoff = 2u64.pow(retry_count.min(5)); // Cap backoff at 32s
        eprintln!("🔁 Reconnecting in {}s...", backoff);
        sleep(Duration::from_secs(backoff)).await;
        retry_count += 1;
    }
}


/// Subscribes to a given XRP address (and optional destination tag) over WebSocket.
/// Subscribes to a given XRP address (and optional destination tag) over WebSocket.
pub async fn subscribe_to_address(address: &str, tag: Option<u32>) -> Result<(), XRPLError> {
    let endpoint = "wss://s.altnet.rippletest.net:51233";
    let url = Url::parse(endpoint).map_err(|e| XRPLError::InvalidEndpoint(e.to_string()))?;

    let cache_key = format!("{}:{:?}", address, tag);
    if SUBSCRIBED_ACCOUNTS.contains(&cache_key) {
        println!("⚠️ Already subscribed to address: {} with tag: {:?}", address, tag);
        return Ok(());
    }

    let (ws_stream, _) = connect_async(url)
        .await
        .map_err(|e| XRPLError::ConnectionFailed(format!("WebSocket error: {}", e)))?;

    let (mut write, mut read) = ws_stream.split();

    // Build subscription payload
    let mut params = vec![serde_json::json!(address)];
    if let Some(destination_tag) = tag {
        params.push(serde_json::json!({ "destination_tag": destination_tag }));
    }

    let subscribe_msg = serde_json::json!({
        "id": "subscribe_cmd",
        "command": "subscribe",
        "accounts": params
    });

    let msg_str = subscribe_msg.to_string();
    write
        .send(Message::Text(msg_str))
        .await
        .map_err(|e| XRPLError::WebSocketSendFailed(format!("Send failed: {}", e)))?;

    println!("📡 Subscribed to address: {} with tag: {:?}", address, tag);

    SUBSCRIBED_ACCOUNTS.insert(cache_key); // 💾 Cache the subscription

    // Consume a response message for confirmation (optional)
    if let Some(Ok(Message::Text(response))) = read.next().await {
        println!("📥 Subscription Response: {}", response);
    }

    Ok(())
}

/// Fetch recent transactions for a given XRPL address using the REST API.
pub async fn fetch_recent_transactions(address: &str, limit: u32) -> Result<Vec<XRPLRawTx>, XRPLError> {
    let client = Client::new();
    let base_url = "https://testnet.xrpl-labs.com/api/v1/account";
    let full_url = format!("{}/{}/transactions?limit={}", base_url, address, limit);

    let resp = client
        .get(&full_url)
        .send()
        .await
        .map_err(|e| XRPLError::Other(format!("Failed to call XRPL API: {}", e)))?;

    if !resp.status().is_success() {
        return Err(XRPLError::Other(format!(
            "Non-success status: {}",
            resp.status()
        )));
    }

    let json = resp.json::<serde_json::Value>().await.map_err(|e| {
        XRPLError::Other(format!("Failed to parse JSON: {}", e))
    })?;

    let raw_txs = json["transactions"]
        .as_array()
        .ok_or_else(|| XRPLError::Other("Missing 'transactions' array".into()))?
        .iter()
        .filter_map(|tx| serde_json::from_value::<XRPLRawTx>(tx.clone()).ok())
        .collect::<Vec<XRPLRawTx>>();

    Ok(raw_txs)
}

/// Attempts to convert a raw XRPL transaction into a CandidateXRPLTx for processing.
pub fn process_incoming_tx(tx: &XRPLRawTx) -> Option<CandidateXRPLTx> {
    // Filter based on transaction type
    if tx.tx_type.as_deref()? != "Payment" {
        return None;
    }

    // Example filter: destination tag must be present
    tx.destination_tag?;
    let memo = tx.memo.as_ref()?;

    // Basic memo validation (e.g., TIP|ARTIST:... format)
    if !memo.starts_with("TIP|") && !memo.starts_with("SALE|") {
        return None;
    }

    // Build and return candidate transaction
    let amount_drops = match &tx.amount {
        Some(amount_str) => match amount_str.parse::<u64>() {
            Ok(val) => val,
            Err(_) => return None,
        },
        None => return None,
    };

let candidate = Some(CandidateXRPLTx {
    tx_hash: tx.hash.clone(),
    sender: tx.account.clone(),
    destination: tx.destination.clone().unwrap_or_default(),
    destination_tag: tx.destination_tag, // assuming it's already Option<u32>
    amount: Nat::from(amount_drops), // use u64 directly
    memo: memo.clone(),
});
candidate
}

/// Returns true if the transaction is a relevant Payment type.
/// Used for pre-filtering XRPL txs before processing.
pub fn is_relevant_payment_tx(tx: &XRPLRawTx) -> bool {
// Only interested in Payment transactions
if let Some(ref tx_type) = tx.tx_type {
    if tx_type.to_lowercase() != "payment" {
        return false;
    }
} else {
    return false;
}

// Ensure the destination tag is set
if tx.destination_tag.is_none() {
    return false;
}

// Check amount is non-zero (simple sanity filter)
if let Some(ref amount_str) = tx.amount {
    if let Ok(amt) = amount_str.parse::<u64>() {
        if amt == 0 {
            return false;
        }
    } else {
        return false;
    }
} else {
    return false;
}
true
}

/// Handles a raw XRPL event JSON string, processing relevant transactions.
pub fn handle_xrpl_event(raw: &str) -> Result<(), XRPLError> {
    // Try to parse the raw JSON message into a map
    let json: serde_json::Value = serde_json::from_str(raw)
        .map_err(|e| XRPLError::Other(format!("Invalid JSON: {}", e)))?;

    // Check if it's a transaction message
    if json["type"] == "transaction" {
        if let Some(tx_obj) = json.get("transaction") {
            let parsed: XRPLRawTx = serde_json::from_value(tx_obj.clone())
                .map_err(|e| XRPLError::Other(format!("Failed to decode XRPLRawTx: {}", e)))?;

            if is_relevant_payment_tx(&parsed) {
                if let Some(candidate) = process_incoming_tx(&parsed) {
                    // ⬇️ This is where you'd push into the queue layer
                    // e.g., state::queue::enqueue_candidate_tx(candidate);
                    println!("📤 Candidate XRPL tx queued: {:?}", candidate);
                } else {
                    println!("⚠️ Ignored tx: did not meet processing rules");
                }
            } else {
                println!("⚠️ Ignored tx: not relevant");
            }
        }
    }

    Ok(())
}

/// Represents a reconnection strategy with exponential backoff and cap.
pub struct ReconnectStrategy {
    pub max_retries: u32,
    pub initial_delay_secs: u64,
    pub max_delay_secs: u64,
}

impl ReconnectStrategy {
    /// Computes backoff delay for the given retry attempt.
    pub fn backoff_delay(&self, retry_count: u32) -> Duration {
        let exp_backoff = self.initial_delay_secs.saturating_mul(2u64.pow(retry_count.min(6)));
        Duration::from_secs(exp_backoff.min(self.max_delay_secs))
    }

    /// Returns true if retries should continue.
    pub fn should_retry(&self, retry_count: u32) -> bool {
        retry_count < self.max_retries
    }
}

/// Pings the XRPL endpoint and returns true if reachable.
pub async fn xrpl_health_check(endpoint: &str) -> Result<bool, XRPLError> {
    let url = Url::parse(endpoint).map_err(|e| XRPLError::InvalidEndpoint(e.to_string()))?;
    match connect_async(url).await {
        Ok((stream, _)) => {
            let ping = serde_json::to_string(&XRPLCommand::Ping)?;
            let (mut write, mut read) = stream.split();
            write.send(Message::Text(ping)).await?;
            if let Some(Ok(Message::Text(response))) = read.next().await {
                println!("✅ XRPL Pong: {}", response);
                return Ok(true);
            }
            Ok(false)
        }
        Err(_) => Ok(false),
    }
}

// Dummy until connected to full logic
pub fn submit_raw_xrpl_tx(_raw_json: &str) -> Result<XRPLSubmitResult, String> {
    Ok(XRPLSubmitResult {
        tx_hash: "mock_tx_hash".to_string(), // Mock response
        ledger_index: 0, // Provide a mock or default value
        status: "mock_status".to_string(), // Provide a mock or default value
    })
}
