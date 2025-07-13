use std::collections::HashSet;
use once_cell::sync::Lazy;
use std::sync::Mutex;
use candid::{Principal, Nat};
use std::env;
use crate::xrpl::types::{VerifiedXRPLTx, XRPLActionType, CandidateXRPLTx, ParsedMemo, VerifierError};
use std::time::{SystemTime, UNIX_EPOCH};

// In-memory replay cache (replace with persistent state later)
static REPLAY_CACHE: Lazy<Mutex<HashSet<String>>> = Lazy::new(|| Mutex::new(HashSet::new()));

pub fn verify_candidate_tx(tx: CandidateXRPLTx) -> Result<VerifiedXRPLTx, VerifierError> {
    // Step 1: Replay protection
    if is_replay(&tx.tx_hash) {
        return Err(VerifierError::ReplayDetected(tx.tx_hash.clone()));
    }

    // Step 2: Tag parsing
    let action = parse_tag(&tx).ok_or_else(|| VerifierError::InvalidTag(tx.destination_tag.unwrap_or(0)))?;

    // Step 3: Memo parsing
    let memo = parse_memo(&tx.memo)?;

    // Step 4: Amount threshold enforcement
    let expected_min = Nat::from(1000u64); // Can be made dynamic per `action`
    if !validate_amount(&tx, expected_min.clone()) {
        return Err(VerifierError::InsufficientAmount(tx.amount.clone(), expected_min));
    }

    // Step 5: Destination check
    if !is_bridge_destination(&tx.destination) {
        return Err(VerifierError::InvalidDestination(tx.destination.clone()));
    }

    // Step 6: Create verified tx
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let verified = VerifiedXRPLTx {
        tx_hash: tx.tx_hash,
        action,
        sender: tx.sender,
        amount: tx.amount,
        memo,
        timestamp,
    };

    // Step 7: Log verification result
    log_verification(&verified);

    Ok(verified)
}

pub fn is_replay(tx_hash: &str) -> bool {
    let mut cache = REPLAY_CACHE.lock().unwrap();
    if cache.contains(tx_hash) {
        println!("⚠️ Replay detected for tx_hash: {}", tx_hash);
        true
    } else {
        cache.insert(tx_hash.to_string());
        false
    }
}

pub fn parse_tag(tx: &CandidateXRPLTx) -> Option<XRPLActionType> {
    match tx.destination_tag {
        Some(1001) => Some(XRPLActionType::Tip),
        Some(2001) => Some(XRPLActionType::NFTSale),
        Some(3001) => Some(XRPLActionType::TokenSwap),
        _ => None,
    }
}

pub fn parse_memo(memo: &str) -> Result<ParsedMemo, VerifierError> {
    let parts: Vec<&str> = memo.split('|').collect();

    if parts.len() < 1 {
        return Err(VerifierError::InvalidMemoFormat);
    }

    let action = match parts[0] {
        "TIP" => XRPLActionType::Tip,
        "NFT" => XRPLActionType::NFTSale,
        "SWAP" => XRPLActionType::TokenSwap,
        _ => return Err(VerifierError::UnknownAction),
    };

    let mut artist = None;
    let mut nft_id = None;
    let mut uuid = None;

    for part in parts.iter().skip(1) {
        if let Some(stripped) = part.strip_prefix("ARTIST:") {
            artist = Principal::from_text(stripped).ok();
        } else if let Some(stripped) = part.strip_prefix("NFT:") {
            if let Ok(parsed) = stripped.parse::<u128>() {
                nft_id = Some(Nat::from(parsed));
            }
        } else if let Some(stripped) = part.strip_prefix("UUID:") {
            uuid = Some(stripped.to_string());
        }
    }

    Ok(ParsedMemo {
        action,
        artist,
        nft_id,
        uuid,
    })
}

pub fn validate_amount(tx: &CandidateXRPLTx, expected_min: Nat) -> bool {
    tx.amount.clone() >= expected_min
}

/// NOTE: This assumes the bridge address is stored in env (or config file in the future).
pub fn is_bridge_destination(addr: &str) -> bool {
    if let Ok(bridge_addr) = env::var("XRPL_BRIDGE_ADDRESS") {
        addr.eq_ignore_ascii_case(&bridge_addr)
    } else {
        println!("⚠️ Bridge address not set in XRPL_BRIDGE_ADDRESS");
        false
    }
}

pub fn log_verification(tx: &VerifiedXRPLTx) {
    let log_line = serde_json::json!({
        "timestamp": tx.timestamp,
        "tx_hash": tx.tx_hash,
        "action": format!("{:?}", tx.action),
        "sender": tx.sender,
        "amount": tx.amount.to_string(),
        "uuid": tx.memo.uuid,
    });

    println!("📒 VerifiedTxLog: {}", log_line.to_string());
}