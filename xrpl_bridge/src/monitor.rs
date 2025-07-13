use std::sync::RwLock;
use std::time::{Duration, SystemTime};
use once_cell::sync::Lazy;
use std::net::TcpListener;
use std::io::Write;
use serde::Serialize;
use std::thread;

use crate::state::queue;
use crate::config::BUILD_VERSION;

// Global Status State
static LAST_SEEN_TX: Lazy<RwLock<Option<String>>> = Lazy::new(|| RwLock::new(None));
static FINALIZED_COUNT: Lazy<RwLock<usize>> = Lazy::new(|| RwLock::new(0));
static LAST_ERROR: Lazy<RwLock<Option<String>>> = Lazy::new(|| RwLock::new(None));
static START_TIME: Lazy<SystemTime> = Lazy::new(SystemTime::now);

// Status struct
#[derive(Serialize)]
pub struct BridgeStatus {
    pub is_connected_to_xrpl: bool,
    pub last_seen_tx_hash: Option<String>,
    pub pending_actions: usize,
    pub finalized_actions: usize,
    pub last_error: Option<String>,
    pub uptime_seconds: u64,
    pub build_version: &'static str,
}

/// Starts a simple HTTP status server
pub fn start_monitor_server(port: u16) {
    thread::spawn(move || {
        let listener = TcpListener::bind(("0.0.0.0", port)).expect("Failed to bind monitor port");

        for stream in listener.incoming() {
            if let Ok(mut stream) = stream {
                let status = get_bridge_status();
                let response = serde_json::to_string(&status).unwrap_or_else(|_| "{}".to_string());

                let http_response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\r\n{}",
                    response.len(),
                    response
                );

                let _ = stream.write_all(http_response.as_bytes());
            }
        }
    });
}

/// Collects live system status
pub fn get_bridge_status() -> BridgeStatus {
    let uptime = START_TIME.elapsed().unwrap_or(Duration::ZERO).as_secs();

    BridgeStatus {
        is_connected_to_xrpl: true, // Could hook into actual XRPL health
        last_seen_tx_hash: LAST_SEEN_TX.read().unwrap().clone(),
        pending_actions: queue::queue_size(),
        finalized_actions: *FINALIZED_COUNT.read().unwrap(),
        last_error: LAST_ERROR.read().unwrap().clone(),
        uptime_seconds: uptime,
        build_version: BUILD_VERSION,
    }
}

/// Records latest XRPL tx hash
pub fn update_last_seen_tx(tx_hash: &str) {
    let mut guard = LAST_SEEN_TX.write().unwrap();
    *guard = Some(tx_hash.to_string());
}

/// Records the most recent error string
pub fn record_error(err: &str) {
    let mut guard = LAST_ERROR.write().unwrap();
    *guard = Some(err.to_string());
}

/// Increments the finalized ICP action counter
pub fn increment_finalized_count() {
    let mut guard = FINALIZED_COUNT.write().unwrap();
    *guard += 1;
}

/// Resets all status fields (useful for test mode or reboot)
pub fn reset_status() {
    *LAST_SEEN_TX.write().unwrap() = None;
    *LAST_ERROR.write().unwrap() = None;
    *FINALIZED_COUNT.write().unwrap() = 0;
    // START_TIME remains unchanged for uptime tracking
}

/// Logs a custom metric to external system (placeholder)
pub fn log_metric(name: &str, value: u64) {
    println!("📊 [Metric] {} = {}", name, value);
    // Optional: send to Prometheus, Loki, or write to file
}