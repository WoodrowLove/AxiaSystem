use crate::xrpl::types::{VerifiedXRPLTx, XRPLActionType};
use crate::ic_trigger::{handle_tip, handle_nft_sale, handle_token_swap};
use crate::log::bridge_log_event;
use crate::xrpl::verifier::log_verification;
use anyhow::Result;
use candid::Nat;
use crate::xrpl::types::{XRPLMirrorStatus, MirrorError};
use std::collections::HashMap;
use std::sync::RwLock;
use once_cell::sync::Lazy;
use ic_agent::Agent;
use crate::config::BridgeConfig;

/// Dispatches a verified XRPL transaction to the appropriate handler.
pub async fn dispatch_verified_tx(
    agent: &Agent,
    config: &BridgeConfig,
    tx: VerifiedXRPLTx) {
    log_verification(&tx); // Always log first

    match tx.action {
        XRPLActionType::Tip => {
            println!("🎯 Dispatching TIP...");

            if let Some(artist) = &tx.memo.artist {
                let uuid = tx.memo.uuid.clone()
                    .expect("Missing UUID in XRPL memo (TIP)");

                if let Err(e) = handle_tip(
                    &agent,
                    &config,
                    artist.clone(),
                    tx.amount.clone(),
                    uuid,
                ).await {
                    bridge_log_event("error", format!("Failed to handle tip: {}", e));
                }
            } else {
                bridge_log_event("error", "Missing artist Principal for TIP".into());
            }
        }

        XRPLActionType::NFTSale => {
            println!("🎯 Dispatching NFT Sale...");

            if let (Some(artist), Some(nft_id)) = (&tx.memo.artist, &tx.memo.nft_id) {
                let uuid = tx.memo.uuid.clone()
                    .expect("Missing UUID in XRPL memo (NFTSale)");

                if let Err(e) = handle_nft_sale(
                    &agent,
                    &config,
                    artist.clone(),
                    nft_id.to_string(),
                    tx.amount.clone(),
                    uuid,
                ).await {
                    bridge_log_event("error", format!("Failed to handle NFT sale: {}", e));
                }
            } else {
                bridge_log_event("error", "Missing artist or NFT ID for NFT sale".into());
            }
        }

        XRPLActionType::TokenSwap => {
            println!("🎯 Dispatching Token Swap...");

            if let Some(artist) = &tx.memo.artist {
                let uuid = tx.memo.uuid.clone()
                    .expect("Missing UUID in XRPL memo (TokenSwap)");

                if let Err(e) = handle_token_swap(
                    &agent,
                    &config,
                    artist.clone(),
                    tx.amount.clone(),
                    uuid,
                ).await {
                    bridge_log_event("error", format!("Failed to handle token swap: {}", e));
                }
            } else {
                bridge_log_event("error", "Missing artist Principal for token swap".into());
            }
        }
    }
}

/// Registers an Axia asset (e.g., NFT or token) on XRPL by initiating a mirror.
/// This could mint a side-chain representation or IOU depending on config/purpose.
pub fn register_axia_asset_on_xrpl(
    _asset_id: Nat,
    artist_principal: String,
    metadata_uri: String,
    mirror_type: String, // e.g., "IOU", "NFT"
) -> Result<XRPLMirrorStatus, MirrorError> {
    // Validate input
    if artist_principal.is_empty() || metadata_uri.is_empty() {
        return Err(MirrorError::InvalidParameters("Missing metadata or artist".into()));
    }

    // [🔁 Placeholder for real XRPL IOU minting logic via external trigger]
    // e.g., Call `mirror_nft_to_xrpl` from ic_trigger with agent + config

    // Simulate a successful mirror for now
    Ok(XRPLMirrorStatus {
        mirrored: true,
        pending: false,
        tx_hash: Some("SIMULATED_XRPL_TX_HASH_1234".to_string()),
        mirror_type: Some(mirror_type),
    })
}


/// Burns or deactivates the XRPL-mirrored version of an Axia asset.
/// Does not delete original asset on ICP; just severs XRPL tie.
pub fn burn_xrpl_mirrored_token(tx_hash: &str) -> Result<(), MirrorError> {
    if tx_hash.is_empty() {
        return Err(MirrorError::InvalidParameters("Missing tx_hash".into()));
    }

    // [🚫 Placeholder: XRPL bridge logic to invalidate or burn mirrored token]

    println!("🔥 XRPL mirrored token invalidated: {}", tx_hash);
    Ok(())
}

/// Temporary in-memory mirror status store (to be replaced by persistent ICP call)
static MIRROR_STATUS_STORE: Lazy<RwLock<HashMap<Nat, XRPLMirrorStatus>>> = Lazy::new(|| {
    RwLock::new(HashMap::new())
});

/// Returns mirror status info for a given Axia asset NFT.
pub fn get_mirror_status_for_asset(nft_id: Nat) -> Result<XRPLMirrorStatus, MirrorError> {
    let store = MIRROR_STATUS_STORE.read().map_err(|_| MirrorError::InternalError("Lock error".into()))?;

    match store.get(&nft_id) {
        Some(status) => Ok(status.clone()),
        None => Err(MirrorError::NotFound("No mirror info found for asset".into())),
    }
}

/// Verifies that the XRPL transaction correctly represents a mirror of the intended asset.
/// For now, this only checks basic conditions. Full version would verify against chain data.
pub fn verify_xrpl_mirror_tx(tx: &VerifiedXRPLTx) -> Result<(), MirrorError> {
    // Check for valid UUID, artist, and mirror-related memo fields
    if tx.memo.uuid.is_none() || tx.memo.artist.is_none() {
        return Err(MirrorError::InvalidParameters("Missing memo fields for mirror validation".into()));
    }

    // Check minimum amount if applicable
    if tx.amount == Nat::from(0u8) {
        return Err(MirrorError::InvalidParameters("Amount must be non-zero".into()));
    }

    // Placeholder for XRPL-side tx validation logic
    println!("✅ Mirror tx verified: UUID = {:?}", tx.memo.uuid);

    Ok(())
}