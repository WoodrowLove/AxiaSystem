use std::collections::HashMap;
use candid::{Nat, Principal};
use std::fmt;

use chrono::format::Parsed;
use rand::{distributions::Alphanumeric, Rng};

use crate::xrpl::types::XRPLActionType;

#[derive(Debug, Clone)]
pub struct ParsedMemo {
    pub action: XRPLActionType,
    pub fields: HashMap<String, String>,
}

#[derive(Debug)]
pub enum MemoError {
    MalformedFormat,
    MissingField(String),
    InvalidPrincipal(String),
    InvalidNat(String),
    UnknownActionType,
}

impl fmt::Display for MemoError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MemoError::MalformedFormat => write!(f, "Malformed memo format"),
            MemoError::MissingField(field) => write!(f, "Missing required field: {}", field),
            MemoError::InvalidPrincipal(value) => write!(f, "Invalid principal: {}", value),
            MemoError::InvalidNat(value) => write!(f, "Invalid natural number: {}", value),
            MemoError::UnknownActionType => write!(f, "Unknown action type"),
        }
    }
}

pub fn parse_memo_string(raw: &str) -> Result<ParsedMemo, MemoError> {
    let parts: Vec<&str> = raw.split('|').collect();

    if parts.is_empty() {
        return Err(MemoError::MalformedFormat);
    }

    let action = match parts[0] {
        "TIP" => XRPLActionType::Tip,
        "NFTSALE" => XRPLActionType::NFTSale,
        "TOKENSWAP" => XRPLActionType::TokenSwap,
        _ => return Err(MemoError::UnknownActionType),
    };

    let mut fields = HashMap::new();
    for part in &parts[1..] {
        let kv: Vec<&str> = part.splitn(2, ':').collect();
        if kv.len() != 2 {
            return Err(MemoError::MalformedFormat);
        }
        fields.insert(kv[0].to_uppercase(), kv[1].to_string());
    }

    Ok(ParsedMemo { action, fields })
}

pub fn validate_parsed_memo(memo: &ParsedMemo) -> Result<(), MemoError> {
    let required_fields = match memo.action {
        XRPLActionType::Tip => vec!["ARTIST", "UUID"],
        XRPLActionType::NFTSale => vec!["NFT", "BUYER", "UUID"],
        XRPLActionType::TokenSwap => vec!["TOKEN", "AMOUNT", "UUID"],
    };

    for field in required_fields {
        match memo.fields.get(field) {
            Some(value) if !value.is_empty() => {
                // Field exists and is not empty, continue
            }
            Some(_) => {
                // Field exists but is empty
                return Err(MemoError::MissingField(field.to_string()));
            }
            None => {
                // Field doesn't exist
                return Err(MemoError::MissingField(field.to_string()));
            }
        }
    }

    Ok(())
}

pub fn extract_principal_from_memo(memo: &ParsedMemo, key: &str) -> Result<Principal, MemoError> {
    match memo.fields.get(&key.to_uppercase()) {
        Some(val) => Principal::from_text(val)
            .map_err(|_| MemoError::InvalidPrincipal(val.clone())),
        None => Err(MemoError::MissingField(key.to_string())),
    }
}

pub fn extract_nat_from_memo(memo: &ParsedMemo, key: &str) -> Result<Nat, MemoError> {
    match memo.fields.get(&key.to_uppercase()) {
        Some(val) => val
            .parse::<u128>()
            .map(Nat::from)
            .map_err(|_| MemoError::InvalidNat(val.clone())),
        None => Err(MemoError::MissingField(key.to_string())),
    }
}

/// 🆔 Generates a simple random UUID (8-character alphanumeric).
pub fn generate_uuid() -> String {
    rand::thread_rng()
        .sample_iter(&Alphanumeric)
        .take(8)
        .map(char::from)
        .collect()
}

/// 🔍 Checks whether a memo contains a specific key.
pub fn memo_contains_field(memo: &ParsedMemo, key: &str) -> bool {
    memo.fields.contains_key(&key.to_uppercase())
}

/// 🔁 Serializes a ParsedMemo struct back into canonical string format.
pub fn reconstruct_memo(memo: &ParsedMemo) -> String {
    let mut parts = vec![match memo.action {
        XRPLActionType::Tip => "TIP",
        XRPLActionType::NFTSale => "NFTSALE",
        XRPLActionType::TokenSwap => "TOKENSWAP",
    }.to_string()];

    for (k, v) in &memo.fields {
        parts.push(format!("{}:{}", k, v));
    }

    parts.join("|")
}

pub fn decode_memo(raw: &str) -> Result<ParsedMemo, String> {
    
    Ok(ParsedMemo {
        action: XRPLActionType::Tip, // Default or parsed action
        fields: raw.split('|')
            .filter_map(|part| {
                let kv: Vec<&str> = part.splitn(2, ':').collect();
                if kv.len() == 2 {
                    Some((kv[0].to_uppercase(), kv[1].to_string()))
                } else {
                    None
                }
            })
            .collect(),
    })
}