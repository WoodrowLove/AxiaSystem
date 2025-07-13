use std::error::Error;
use std::sync::Arc;
use std::time::Duration;

use tokio::time;
use xrpl_bridge::config::{BridgeConfig, ExtendedBridgeConfig};
use xrpl_bridge::log::bridge_log_event;
use xrpl_bridge::monitor::start_monitor_server;
use xrpl_bridge::state::memory::init_memory_state;
use xrpl_bridge::state::db::{load_pending_actions};
use xrpl_bridge::state::queue::{enqueue_action, dequeue_pending_action};
use xrpl_bridge::ic_trigger::{route_action_to_canister, create_agent_from_env};
use xrpl_bridge::xrpl::client::connect_to_xrpl;

/// Setup logging format and targets (stdout, file, etc.)
fn setup_logging() {
    use env_logger::Env;
    env_logger::Builder::from_env(Env::default().default_filter_or("info")).init();
}

/// 🧠 Main runtime function.
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    setup_logging();
    bridge_log_event("startup", "🚀 Starting XRPL Bridge...".to_string());

    // Load config
    let extended_config = ExtendedBridgeConfig::load();
    let config = extended_config.bridge_config.clone();

    // Init memory state
    init_memory_state();

    // Load pending queue from DB
    match load_pending_actions() {
        Ok(actions) => {
            for action in actions {
                if let Err(e) = enqueue_action(action) {
                    bridge_log_event("warn", format!("Failed to enqueue action: {:?}", e));
                }
            }
            bridge_log_event("queue", "✅ Loaded persisted pending actions.".to_string());
        }
        Err(e) => {
            bridge_log_event("warn", format!("Could not load persisted queue: {:?}", e));
        }
    }

    // Start monitor server (optional)
    if extended_config.enable_monitor {
        tokio::spawn(async move {
            start_monitor_server(8080);
            bridge_log_event("info", "✅ Monitor server started on port 8080".to_string());
        });
    }

    // Start XRPL client
    tokio::spawn(async move {
        if let Err(e) = connect_to_xrpl().await {
            bridge_log_event("error", format!("❌ XRPL client failed: {}", e));
        }
    });

    // Start core loop (trigger ICP from pending queue)
    run_bridge_core(config).await;

    Ok(())
}

/// 🔁 Queue processor: drain queue → trigger ICP → mark done.
async fn run_bridge_core(config: BridgeConfig) {
    // Create IC agent once for the entire core loop
    let agent = match create_agent_from_env().await {
        Ok(agent) => agent,
        Err(e) => {
            bridge_log_event("error", format!("❌ Failed to create IC agent: {}", e));
            return; // Exit if we can't create the agent
        }
    };

    // Set the interval in seconds for queue processing (default: 6)
    let interval_secs = 6;

    loop {
        match dequeue_pending_action() {
            Some(action) => {
                let cloned_config = config.clone();
                let cloned_agent = agent.clone();
                tokio::spawn(async move {
                    if let Err(e) = route_action_to_canister(action.clone(), &cloned_agent, &cloned_config).await {
                        bridge_log_event("error", format!("❌ Failed to route action: {:?}", e));
                        // Optional: persist_failed_action(...)
                    } else {
                        bridge_log_event("trigger", "✅ Routed action to ICP.".to_string());
                    }
                });
            }
            None => {
                // No pending action found
            }
        }

        time::sleep(Duration::from_secs(interval_secs)).await;
    }
}