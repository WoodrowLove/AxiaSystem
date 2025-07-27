/// 🔐 Identity Management
/// Handles .pem identity loading and management

use ic_agent::identity::{BasicIdentity, Secp256k1Identity};
use ic_agent::Identity;
use anyhow::{Result, Context};
use std::sync::Arc;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IdentityInfo {
    pub principal: String,
    pub identity_type: String,
    pub loaded_from: Option<String>,
}

pub struct IdentityManager;

impl IdentityManager {
    /// Load identity from PEM file
    pub async fn load_from_pem(path: &str) -> Result<Arc<dyn Identity>> {
        let pem_content = tokio::fs::read_to_string(path).await
            .context("Failed to read PEM identity file")?;

        // Try to parse as EC key first (most common for IC)
        if let Ok(identity) = Secp256k1Identity::from_pem(&pem_content) {
            return Ok(Arc::new(identity));
        }

        // Fall back to basic identity
        let identity = BasicIdentity::from_pem(&pem_content)
            .context("Failed to parse PEM identity")?;
        Ok(Arc::new(identity))
    }

    /// Load identity from DER bytes
    pub fn load_from_der(der_bytes: &[u8]) -> Result<Arc<dyn Identity>> {
        let identity = Secp256k1Identity::from_der(der_bytes)
            .context("Failed to parse DER identity")?;
        Ok(Arc::new(identity))
    }

    /// Create anonymous identity
    pub fn create_anonymous() -> Arc<dyn Identity> {
        Arc::new(BasicIdentity::new())
    }

    /// Get identity information
    pub fn get_info(identity: &Arc<dyn Identity>) -> Result<IdentityInfo> {
        let principal = identity.sender()?.to_text();
        
        // Try to determine identity type
        let identity_type = if principal == "2vxsx-fae" {
            "anonymous".to_string()
        } else {
            "secp256k1".to_string()
        };

        Ok(IdentityInfo {
            principal,
            identity_type,
            loaded_from: None,
        })
    }
}

/// Helper function for FFI interface
pub async fn load_identity_from_path(path: &str) -> Result<IdentityInfo> {
    let identity = IdentityManager::load_from_pem(path).await?;
    let mut info = IdentityManager::get_info(&identity)?;
    info.loaded_from = Some(path.to_string());
    Ok(info)
}
