use std::collections::HashSet;
use std::sync::RwLock;
use std::time::{Instant, SystemTime};
use once_cell::sync::Lazy;

static TX_CACHE: Lazy<RwLock<HashSet<String>>> = Lazy::new(|| RwLock::new(HashSet::new()));
static FINALIZED_COUNT: Lazy<RwLock<usize>> = Lazy::new(|| RwLock::new(0));
static LAST_ERROR: Lazy<RwLock<Option<String>>> = Lazy::new(|| RwLock::new(None));
static LAST_SEEN_TX: Lazy<RwLock<Option<String>>> = Lazy::new(|| RwLock::new(None));
static START_TIME: Lazy<Instant> = Lazy::new(Instant::now);

/// Initializes memory state. Call once from `main.rs` if needed.
pub fn init_memory_state() {
    {
        let mut cache = TX_CACHE.write().unwrap();
        cache.clear();
    }
    {
        let mut count = FINALIZED_COUNT.write().unwrap();
        *count = 0;
    }
    {
        let mut err = LAST_ERROR.write().unwrap();
        *err = None;
    }
    {
        let mut tx = LAST_SEEN_TX.write().unwrap();
        *tx = None;
    }
    // Access START_TIME to ensure it's initialized; cannot reset Instant in static Lazy.
    let _ = Lazy::force(&START_TIME);
}

/// Stores the given tx hash in the in-memory cache.
pub fn cache_tx_hash(tx_hash: &str) {
    let mut cache = TX_CACHE.write().unwrap();
    cache.insert(tx_hash.to_string());
}

/// Returns true if the tx hash has already been cached (seen).
pub fn was_tx_seen(tx_hash: &str) -> bool {
    let cache = TX_CACHE.read().unwrap();
    cache.contains(tx_hash)
}

/// Increments the finalized action counter by 1.
pub fn increment_finalized_counter() {
    let mut count = FINALIZED_COUNT.write().unwrap();
    *count += 1;
}

/// Returns the total number of finalized actions.
pub fn get_finalized_count() -> usize {
    let count = FINALIZED_COUNT.read().unwrap();
    *count
}

/// Sets the most recent error message.
pub fn set_last_error(err: &str) {
    let mut error_slot = LAST_ERROR.write().unwrap();
    *error_slot = Some(err.to_string());
}

/// Gets the most recent error message, if any.
pub fn get_last_error() -> Option<String> {
    let error_slot = LAST_ERROR.read().unwrap();
    error_slot.clone()
}

/// Sets the last seen XRPL tx hash.
pub fn set_last_seen_tx(tx_hash: &str) {
    let mut tx_slot = LAST_SEEN_TX.write().unwrap();
    *tx_slot = Some(tx_hash.to_string());
}

/// Gets the last seen XRPL tx hash, if any.
pub fn get_last_seen_tx() -> Option<String> {
    let tx_slot = LAST_SEEN_TX.read().unwrap();
    tx_slot.clone()
}

/// Returns the number of seconds the bridge has been running.
pub fn get_uptime_seconds() -> u64 {
    START_TIME.elapsed().as_secs()
}

/// Resets all in-memory state to default (for testing or soft reboot).
pub fn reset_memory_state() {
    {
        let mut cache = TX_CACHE.write().unwrap();
        cache.clear();
    }

    {
        let mut count = FINALIZED_COUNT.write().unwrap();
        *count = 0;
    }

    {
        let mut error_slot = LAST_ERROR.write().unwrap();
        *error_slot = None;
    }

    {
        let mut tx_slot = LAST_SEEN_TX.write().unwrap();
        *tx_slot = None;
    }

    // Note: START_TIME is not reset, since it's a fixed Instant. We’d need a refactor if restart uptime is needed.
}

/// Clears the transaction queue cache.
pub fn clear_queue() {
    let mut cache = TX_CACHE.write().unwrap();
    cache.clear();
}

/// Clears verified transactions (currently implemented as clearing the cache).
pub fn clear_verified() {
    let mut cache = TX_CACHE.write().unwrap();
    cache.clear();
}

/// Resets metrics counters.
pub fn reset_metrics() {
    let mut count = FINALIZED_COUNT.write().unwrap();
    *count = 0;
    
    let mut error_slot = LAST_ERROR.write().unwrap();
    *error_slot = None;
}