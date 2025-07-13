use std::env;

pub const BUILD_VERSION: &str = "v0.2.4"; // Set dynamically at build time if desired

/// Gets the XRPL bridge address (from env)
pub fn get_bridge_address() -> Option<String> {
    env::var("XRPL_BRIDGE_ADDRESS").ok()
}

/// Gets the default minimum tip amount in drops
pub fn get_minimum_tip_drops() -> u64 {
    env::var("MIN_TIP_DROPS")
        .ok()
        .and_then(|val| val.parse::<u64>().ok())
        .unwrap_or(1000) // fallback default
}

/// Holds bridge-related canister IDs loaded at runtime (e.g. from env).
#[derive(Debug, Clone)]
pub struct BridgeConfig {
    pub nft_canister_id: String,
    pub payment_log_canister_id: String,
    pub token_swap_canister_id: String,
    pub tip_handler_canister_id: String,
    pub nft_sale_handler_canister_id: String,
    // Add more as needed later
}

impl BridgeConfig {
    /// Load config from env vars or fallback defaults
    pub fn load() -> Self {
        let nft_canister_id = std::env::var("NFT_CANISTER_ID")
            .unwrap_or_else(|_| "aaaaa-aa".to_string());

        let payment_log_canister_id = std::env::var("PAYMENT_LOG_CANISTER_ID")
            .unwrap_or_else(|_| "bbbbb-bb".to_string());

        let token_swap_canister_id = std::env::var("TOKEN_SWAP_CANISTER_ID")
            .unwrap_or_else(|_| "ccccc-cc".to_string());

        let tip_handler_canister_id = std::env::var("TIP_HANDLER_CANISTER_ID")
            .unwrap_or_else(|_| "ddddd-dd".to_string());

        let nft_sale_handler_canister_id = std::env::var("NFT_SALE_HANDLER_CANISTER_ID")
            .unwrap_or_else(|_| "eeeee-ee".to_string());

        BridgeConfig {
            nft_canister_id,
            payment_log_canister_id,
            token_swap_canister_id,
            tip_handler_canister_id,
            nft_sale_handler_canister_id,
        }
    }
}

/// Convenience function to load bridge configuration
pub fn load_bridge_config() -> Result<BridgeConfig, Box<dyn std::error::Error>> {
    // Add any additional logic here if needed (e.g., validation)
    Ok(BridgeConfig::load())
}

/// Extended bridge configuration that includes additional settings
#[derive(Debug, Clone)]
pub struct ExtendedBridgeConfig {
    pub bridge_config: BridgeConfig,
    pub enable_monitor: bool,
    pub log_level: String,
    pub max_retries: u8,
}

impl ExtendedBridgeConfig {
    pub fn load() -> Self {
        let enable_monitor = std::env::var("ENABLE_MONITOR")
            .unwrap_or_else(|_| "true".to_string())
            .parse()
            .unwrap_or(true);

        let log_level = std::env::var("LOG_LEVEL")
            .unwrap_or_else(|_| "info".to_string());

        let max_retries = std::env::var("MAX_RETRIES")
            .unwrap_or_else(|_| "3".to_string())
            .parse()
            .unwrap_or(3);

        ExtendedBridgeConfig {
            bridge_config: BridgeConfig::load(),
            enable_monitor,
            log_level,
            max_retries,
        }
    }
}