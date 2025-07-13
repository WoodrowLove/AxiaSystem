// state/queue.rs

use std::collections::{HashMap, HashSet};
use std::sync::RwLock;
use lazy_static::lazy_static;
use candid::{Nat, Principal};
use chrono::{Utc, DateTime, Duration};
use serde::{Deserialize, Serialize};

use crate::xrpl::types::VerifiedXRPLTx;

/// Represents a queueable XRPL → ICP action
#[derive(Clone, Serialize, Deserialize, Debug)]
pub enum PendingAction {
    Tip {
        artist: Principal,
        amount: Nat,
        tx_hash: String,
        uuid: String,
    },
    NFTSale {
        nft_id: Nat,
        buyer: Principal,
        price: Nat,
        tx_hash: String,
        uuid: String,
    },
    TokenSwap {
        artist: Principal,
        amount: Nat,
        tx_hash: String,
        uuid: String,
    },
    // Future: NFTMint, etc.
}

#[derive(Debug)]
pub enum QueueError {
    AlreadyExists,
    NotFound,
    WriteFailure,
    ParseError,
    Unknown,
}

/// Internal record to wrap action with status metadata
#[derive(Clone, Debug)]
struct ActionWrapper {
    action: PendingAction,
    retries: u8,
    last_attempt: DateTime<Utc>,
    failed: bool,
}

lazy_static! {
    static ref PENDING_QUEUE: RwLock<HashMap<String, ActionWrapper>> = RwLock::new(HashMap::new());
    static ref PROCESSED_TXS: RwLock<HashSet<String>> = RwLock::new(HashSet::new());
}

/// Enqueues a verified transaction into the queue.
pub fn enqueue_verified_tx(tx: VerifiedXRPLTx) -> Result<(), QueueError> {
    let tx_hash = tx.tx_hash.clone();

    {
        // Prevent duplicates
        let pending = PENDING_QUEUE.read().unwrap();
        if pending.contains_key(&tx_hash) {
            return Err(QueueError::AlreadyExists);
        }
        let processed = PROCESSED_TXS.read().unwrap();
        if processed.contains(&tx_hash) {
            return Err(QueueError::AlreadyExists);
        }
    }

    let action = match tx.action {
        crate::xrpl::types::XRPLActionType::Tip => {
            let artist = tx.memo.artist.clone().ok_or(QueueError::ParseError)?;
            PendingAction::Tip {
                artist,
                amount: tx.amount,
                tx_hash: tx_hash.clone(),
                uuid: tx.memo.uuid.unwrap_or_default(),
            }
        }
        crate::xrpl::types::XRPLActionType::NFTSale => {
            let artist = tx.memo.artist.clone().ok_or(QueueError::ParseError)?;
            let nft_id = tx.memo.nft_id.clone().ok_or(QueueError::ParseError)?;
            PendingAction::NFTSale {
                buyer: artist,
                nft_id,
                price: tx.amount,
                tx_hash: tx_hash.clone(),
                uuid: tx.memo.uuid.unwrap_or_default(),
            }
        }
        _ => return Err(QueueError::ParseError), // Extendable
    };

    let wrapper = ActionWrapper {
        action,
        retries: 0,
        last_attempt: Utc::now(),
        failed: false,
    };

    let mut write_guard = PENDING_QUEUE.write().map_err(|_| QueueError::WriteFailure)?;
    write_guard.insert(tx_hash.clone(), wrapper);

    println!("📥 Enqueued verified tx: {}", tx_hash);
    Ok(())
}

/// Enqueues a pending action directly into the queue.
pub fn enqueue_action(action: PendingAction) -> Result<(), QueueError> {
    let tx_hash = match &action {
        PendingAction::Tip { tx_hash, .. } => tx_hash.clone(),
        PendingAction::NFTSale { tx_hash, .. } => tx_hash.clone(),
        PendingAction::TokenSwap { tx_hash, .. } => tx_hash.clone(),
    };

    {
        // Prevent duplicates
        let pending = PENDING_QUEUE.read().unwrap();
        if pending.contains_key(&tx_hash) {
            return Err(QueueError::AlreadyExists);
        }
        let processed = PROCESSED_TXS.read().unwrap();
        if processed.contains(&tx_hash) {
            return Err(QueueError::AlreadyExists);
        }
    }

    let wrapper = ActionWrapper {
        action,
        retries: 0,
        last_attempt: Utc::now(),
        failed: false,
    };

    {
        let mut pending = PENDING_QUEUE.write().unwrap();
        pending.insert(tx_hash, wrapper);
    }

    Ok(())
}

/// Returns all currently queued, unprocessed actions.
pub fn get_pending_actions() -> Vec<PendingAction> {
    let guard = PENDING_QUEUE.read().unwrap();
    guard
        .values()
        .filter(|w| !w.failed) // exclude known failed if needed
        .map(|w| w.action.clone())
        .collect()
}

/// Marks an action as processed and removes from queue.
pub fn mark_action_finalized(tx_hash: &str) -> Result<(), QueueError> {
    let mut queue = PENDING_QUEUE.write().map_err(|_| QueueError::WriteFailure)?;
    let mut processed = PROCESSED_TXS.write().map_err(|_| QueueError::WriteFailure)?;

    if !queue.contains_key(tx_hash) {
        return Err(QueueError::NotFound);
    }

    queue.remove(tx_hash);
    processed.insert(tx_hash.to_string());

    println!("✅ Finalized tx: {}", tx_hash);
    Ok(())
}

/// Flags a transaction as failed and updates its metadata for retry tracking.
pub fn mark_action_failed(tx_hash: &str, reason: &str) -> Result<(), QueueError> {
    let mut queue = PENDING_QUEUE.write().map_err(|_| QueueError::WriteFailure)?;

    if let Some(wrapper) = queue.get_mut(tx_hash) {
        wrapper.failed = true;
        wrapper.retries += 1;
        wrapper.last_attempt = Utc::now();
        println!("❌ Marked tx {} as failed ({} retries). Reason: {}", tx_hash, wrapper.retries, reason);
        Ok(())
    } else {
        Err(QueueError::NotFound)
    }
}

/// Returns actions that failed but are eligible for retry based on timing.
pub fn retry_failed_actions() -> Vec<PendingAction> {
    let now = Utc::now();
    let retry_threshold = Duration::seconds(30); // Simple static backoff

    let queue = PENDING_QUEUE.read().unwrap();

    queue
        .values()
        .filter(|wrapper| {
            wrapper.failed && now.signed_duration_since(wrapper.last_attempt) > retry_threshold
        })
        .map(|wrapper| wrapper.action.clone())
        .collect()
}

/// Checks if an action already exists in either queue or processed set.
pub fn action_exists(tx_hash: &str) -> bool {
    let queue = PENDING_QUEUE.read().unwrap();
    let processed = PROCESSED_TXS.read().unwrap();

    queue.contains_key(tx_hash) || processed.contains(tx_hash)
}

/// Clears all pending transactions from the queue.
/// Intended for test/reset/admin flows.
pub fn clear_queue() {
    let mut queue = PENDING_QUEUE.write().unwrap();
    println!("🧹 Clearing {} pending actions...", queue.len());

    for (tx_hash, wrapper) in queue.iter() {
        println!("⚠️ Deleting pending tx: {} (Action: {:?})", tx_hash, wrapper.action);
    }

    queue.clear();
}

/// Returns the number of pending actions currently in the queue.
pub fn queue_size() -> usize {
    let queue = PENDING_QUEUE.read().unwrap();
    queue.len()
}

/// Dequeues the next pending action from the queue.
pub fn dequeue_pending_action() -> Option<PendingAction> {
    let mut pending = PENDING_QUEUE.write().unwrap();
    
    // Get the first item from the queue
    if let Some((tx_hash, wrapper)) = pending.iter().next() {
        let tx_hash = tx_hash.clone();
        let action = wrapper.action.clone();
        
        // Remove from pending queue
        pending.remove(&tx_hash);
        
        Some(action)
    } else {
        None
    }
}