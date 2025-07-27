/// 🤖 IC Agent Management
/// Handles the ic-agent connection to Internet Computer

use ic_agent::{Agent, Identity};
use ic_agent::identity::{BasicIdentity, Secp256k1Identity};
use anyhow::{Result, Context};
use once_cell::sync::Lazy;
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentConfig {
    pub network_url: String,
    pub identity_path: Option<String>,
    pub timeout_seconds: u64,
}

impl Default for AgentConfig {
    fn default() -> Self {
        Self {
            network_url: "https://ic0.app".to_string(),
            identity_path: None,
            timeout_seconds: 30,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentStatus {
    pub connected: bool,
    pub network_url: String,
    pub principal: String,
    pub last_ping: Option<i64>,
    pub error: Option<String>,
}

/// Global agent manager
static AGENT_MANAGER: Lazy<Arc<Mutex<AgentManager>>> = Lazy::new(|| {
    Arc::new(Mutex::new(AgentManager::new()))
});

pub struct AgentManager {
    agent: Option<Agent>,
    config: AgentConfig,
    status: AgentStatus,
}

impl AgentManager {
    pub fn new() -> Self {
        Self {
            agent: None,
            config: AgentConfig::default(),
            status: AgentStatus {
                connected: false,
                network_url: "https://ic0.app".to_string(),
                principal: "anonymous".to_string(),
                last_ping: None,
                error: None,
            },
        }
    }

    pub async fn initialize(&mut self, config: AgentConfig) -> Result<()> {
        self.config = config.clone();
        
        let identity: Arc<dyn Identity> = if let Some(identity_path) = &config.identity_path {
            // Load identity from file
            let identity_bytes = tokio::fs::read(identity_path).await
                .context("Failed to read identity file")?;
            Arc::new(Secp256k1Identity::from_der(&identity_bytes)?)
        } else {
            // Use anonymous identity
            Arc::new(BasicIdentity::new())
        };

        let agent = Agent::builder()
            .with_url(&config.network_url)
            .with_identity(identity.clone())
            .build()?;

        // Test connection with a ping
        let principal = identity.sender()?.to_text();
        match agent.status().await {
            Ok(_) => {
                self.status = AgentStatus {
                    connected: true,
                    network_url: config.network_url.clone(),
                    principal,
                    last_ping: Some(chrono::Utc::now().timestamp()),
                    error: None,
                };
                self.agent = Some(agent);
                log::info!("✅ IC Agent initialized successfully");
                Ok(())
            }
            Err(e) => {
                self.status.error = Some(e.to_string());
                self.status.connected = false;
                Err(e.into())
            }
        }
    }

    pub fn get_agent(&self) -> Option<&Agent> {
        self.agent.as_ref()
    }

    pub fn get_status(&self) -> AgentStatus {
        self.status.clone()
    }

    pub async fn ping(&mut self) -> Result<()> {
        if let Some(agent) = &self.agent {
            match agent.status().await {
                Ok(_) => {
                    self.status.last_ping = Some(chrono::Utc::now().timestamp());
                    self.status.connected = true;
                    self.status.error = None;
                    Ok(())
                }
                Err(e) => {
                    self.status.connected = false;
                    self.status.error = Some(e.to_string());
                    Err(e.into())
                }
            }
        } else {
            Err(anyhow::anyhow!("Agent not initialized"))
        }
    }
}

/// Global functions for external access
pub async fn initialize_agent(config: AgentConfig) -> Result<()> {
    let mut manager = AGENT_MANAGER.lock().unwrap();
    manager.initialize(config).await
}

pub fn get_agent_status() -> AgentStatus {
    let manager = AGENT_MANAGER.lock().unwrap();
    manager.get_status()
}

pub async fn ping_agent() -> Result<()> {
    let mut manager = AGENT_MANAGER.lock().unwrap();
    manager.ping().await
}

pub fn with_agent<F, R>(f: F) -> Result<R>
where
    F: FnOnce(&Agent) -> Result<R>,
{
    let manager = AGENT_MANAGER.lock().unwrap();
    if let Some(agent) = manager.get_agent() {
        f(agent)
    } else {
        Err(anyhow::anyhow!("Agent not initialized"))
    }
}
