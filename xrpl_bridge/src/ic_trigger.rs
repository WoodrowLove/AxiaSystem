use ic_agent::{Agent, Identity};
use candid::{Nat, Encode, Decode, Principal};
use anyhow::Result;
use std::sync::Arc;
use crate::state::queue::{PendingAction};

use crate::xrpl::types::ParsedMemo;
use crate::config::BridgeConfig;

#[derive(Debug)]
pub enum TriggerError {
    AgentBuildFailed,
    InvalidPrincipal,
    CanisterUnreachable,
    CallFailed(String),
    SerializationError(String),
    UnknownActionType,
    NotYetImplemented,
}

/// Create a new IC agent using a given identity and the configured network URL.
pub async fn create_agent(identity: Arc<dyn Identity>) -> Result<Agent> {
    let url = std::env::var("AXIA_NETWORK_URL")
        .unwrap_or_else(|_| "https://icp-api.io".to_string());

    let agent = Agent::builder()
        .with_url(url)
        .with_identity(identity)
        .build()?;

    agent.fetch_root_key().await?;
    Ok(agent)
}

/// Marks a given NFT as mirrored to XRPL using the configured NFT canister.
pub async fn mirror_nft_to_xrpl(
    agent: &Agent,
    config: &BridgeConfig,
    nft_id: Nat,
) -> Result<()> {
    let canister_id = Principal::from_text(&config.nft_canister_id)?;
    let args = Encode!(&nft_id)?;

    let response = agent
        .update(&canister_id, "markAsMirrored")
        .with_arg(args)
        .call_and_wait()
        .await?;

    let result: Result<(), String> = Decode!(&response, Result::<(), String>)?;

    match result {
        Ok(_) => {
            println!("✅ NFT mirrored successfully: {}", nft_id);
            Ok(())
        }
        Err(e) => Err(anyhow::anyhow!("❌ Failed to mirror NFT: {}", e)),
    }
}

/// Logs a verified XRPL payment on-chain using the configured payment log canister.
pub async fn log_verified_payment(
    agent: &Agent,
    config: &BridgeConfig,
    memo: &ParsedMemo,
    sender: String,
    amount: Nat,
) -> Result<()> {
    let canister_id = Principal::from_text(&config.payment_log_canister_id)?;

    let uuid = memo.uuid.clone().unwrap_or_else(|| "unknown".to_string());
    let action = format!("{:?}", memo.action);
    let args = Encode!(&uuid, &sender, &action, &amount)?;

    let response = agent
        .update(&canister_id, "logPayment")
        .with_arg(args)
        .call_and_wait()
        .await?;

    let result: Result<(), String> = Decode!(&response, Result::<(), String>)?;

    match result {
        Ok(_) => {
            println!("📦 Payment logged: {}, {}, {}", uuid, sender, amount);
            Ok(())
        }
        Err(e) => Err(anyhow::anyhow!("❌ Log failed: {}", e)),
    }
}

/// Handle a tip action from XRPL → AxiaSystem
pub async fn handle_tip(
    agent: &Agent,
    config: &BridgeConfig,
    artist: Principal,
    amount: Nat,
    uuid: String,
) -> Result<()> {
    let canister_id = Principal::from_text(&config.tip_handler_canister_id)?;
    let args = Encode!(&artist, &amount, &uuid)?;

    let response = agent
        .update(&canister_id, "handleTipFromXRPL")
        .with_arg(args)
        .call_and_wait()
        .await?;

    let result: Result<(), String> = Decode!(&response, Result::<(), String>)?;
    result.map_err(|e| anyhow::anyhow!("Tip handling failed: {}", e))
}

/// Handle an NFT sale settlement from XRPL
pub async fn handle_nft_sale(
    agent: &Agent,
    config: &BridgeConfig,
    artist: Principal,
    nft_id: String,
    amount: Nat,
    uuid: String,
) -> Result<()> {
    let canister_id = Principal::from_text(&config.nft_sale_handler_canister_id)?;
    let args = Encode!(&artist, &nft_id, &amount, &uuid)?;

    let response = agent
        .update(&canister_id, "handleNFTSaleFromXRPL")
        .with_arg(args)
        .call_and_wait()
        .await?;

    let result: Result<(), String> = Decode!(&response, Result::<(), String>)?;
    result.map_err(|e| anyhow::anyhow!("NFT sale handling failed: {}", e))
}

/// Handle token swap / liquidity action from XRPL
pub async fn handle_token_swap(
    agent: &Agent,
    config: &BridgeConfig,
    artist: Principal,
    amount: Nat,
    uuid: String,
) -> Result<()> {
    let canister_id = Principal::from_text(&config.token_swap_canister_id)?; // 🔁 Replace with AxiaSystem Swap/Liquidity canister
    let args = Encode!(&artist, &amount, &uuid)?;

    let response = agent
        .update(&canister_id, "handleTokenSwapFromXRPL")
        .with_arg(args)
        .call_and_wait()
        .await?;

    let result: Result<(), String> = Decode!(&response, Result::<(), String>)?;
    result.map_err(|e| anyhow::anyhow!("Token swap handling failed: {}", e))
}

/// Creates an agent from PEM and environment variable (standardized)
pub async fn create_agent_from_env() -> Result<Agent> {
    let identity = Arc::new(
        ic_agent::identity::BasicIdentity::from_pem_file("identity.pem")?
    ) as Arc<dyn Identity>;
    
    let url = std::env::var("AXIA_NETWORK_URL")
        .unwrap_or_else(|_| "https://icp-api.io".to_string());

    let agent = Agent::builder()
        .with_url(url)
        .with_identity(identity)
        .build()?;

    agent.fetch_root_key().await?;
    Ok(agent)
}

/// Utility to verify if a canister is reachable before making a call.
pub async fn verify_canister_reachable(canister_id: Principal, agent: &Agent) -> Result<bool, TriggerError> {
    let response = agent
        .query(&canister_id, "healthCheck") // Assumes the canister has this method
        .with_arg(Encode!().map_err(|e| TriggerError::SerializationError(format!("Encode failed: {:?}", e)))?)
        .call()
        .await;

    match response {
        Ok(_) => Ok(true),
        Err(_) => Ok(false), // Don't hard fail; just treat as unreachable
    }
}

/// Attempts to decode a standard Motoko response of type Result<(), Text>
pub fn decode_response(response: Vec<u8>) -> Result<(), TriggerError> {
    let decoded: Result<Result<(), String>, _> = Decode!(&response, Result<(), String>);
    match decoded {
        Ok(Ok(())) => Ok(()),
        Ok(Err(e)) => Err(TriggerError::CallFailed(e)),
        Err(e) => Err(TriggerError::SerializationError(format!("Decode failed: {:?}", e))),
    }
}

/// Central dispatcher that maps a PendingAction to its Motoko-triggering handler.
pub async fn route_action_to_canister(
    action: PendingAction,
    agent: &Agent,
    config: &BridgeConfig,
) -> Result<(), TriggerError> {
    match action {
        PendingAction::Tip {
            artist,
            amount,
            tx_hash: _,
            uuid,
        } => {
            handle_tip(agent, config, artist, amount, uuid)
                .await
                .map_err(|e| TriggerError::CallFailed(e.to_string()))
        }

        PendingAction::NFTSale {
            nft_id,
            buyer,
            price,
            tx_hash: _,
            uuid,
        } => {
            handle_nft_sale(agent, config, buyer, nft_id.to_string(), price, uuid)
                .await
                .map_err(|e| TriggerError::CallFailed(e.to_string()))
        }

        PendingAction::TokenSwap {
            artist,
            amount,
            tx_hash: _,
            uuid,
        } => {
            handle_token_swap(agent, config, artist, amount, uuid)
                .await
                .map_err(|e| TriggerError::CallFailed(e.to_string()))
        }
    }
}