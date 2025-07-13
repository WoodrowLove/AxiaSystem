use std::collections::HashSet;
use std::sync::Mutex;
use lazy_static::lazy_static;

lazy_static! {
    static ref REPLAY_CACHE: Mutex<HashSet<String>> = Mutex::new(HashSet::new());
}

pub fn is_replay(tx_hash: &str) -> bool {
    let cache = REPLAY_CACHE.lock().unwrap();
    cache.contains(tx_hash)
}

pub fn mark_tx_as_seen(tx_hash: &str) {
    let mut cache = REPLAY_CACHE.lock().unwrap();
    cache.insert(tx_hash.to_string());
}