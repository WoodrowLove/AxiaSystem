/// 🏗️ Canister Service Layer
/// Provides high-level access to NamoraAI and other Axia canisters

use ic_agent::{Agent, export::Principal};
use candid::{Encode, Decode, CandidType};
use anyhow::{Result, Context};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use super::agent::with_agent;

#[derive(Debug, Clone, Serialize, Deserialize, CandidType)]
pub struct SystemInsight {
    pub source: String,
    pub severity: String,
    pub message: String,
    pub timestamp: u64,
    pub tags: Vec<String>,
    pub metadata: Vec<(String, String)>,
}

#[derive(Debug, Clone, Serialize, Deserialize, CandidType)]
pub struct SmartAlert {
    pub id: u32,
    pub severity: String,
    pub message: String,
    pub source: String,
    pub timestamp: u64,
    pub resolved: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, CandidType)]
pub struct SystemHealthSummary {
    pub overall_score: f64,
    pub active_alerts: u32,
    pub recent_insights: u32,
    pub uptime_hours: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CanisterEndpoints {
    pub namora_ai: String,
    pub user: String,
    pub payment: String,
    pub escrow: String,
    pub asset: String,
    pub identity: String,
    pub governance: String,
}

impl Default for CanisterEndpoints {
    fn default() -> Self {
        Self {
            namora_ai: "rdmx6-jaaaa-aaaah-qdrqq-cai".to_string(),
            user: "rrkah-fqaaa-aaaah-qccpq-cai".to_string(),
            payment: "rno2w-sqaaa-aaaah-qdrra-cai".to_string(),
            escrow: "by6od-j4aaa-aaaaa-qaadq-cai".to_string(),
            asset: "bw4dl-smaaa-aaaaa-qaacq-cai".to_string(),
            identity: "asrmz-lmaaa-aaaaa-qaaeq-cai".to_string(),
            governance: "avqkn-guaaa-aaaaa-qaaea-cai".to_string(),
        }
    }
}

pub struct CanisterService {
    endpoints: CanisterEndpoints,
}

impl CanisterService {
    pub fn new(endpoints: CanisterEndpoints) -> Self {
        Self { endpoints }
    }

    /// Push insight to NamoraAI canister
    pub async fn push_insight(&self, insight: SystemInsight) -> Result<()> {
        with_agent(|agent| {
            let principal = Principal::from_text(&self.endpoints.namora_ai)?;
            let args = Encode!(&insight)?;
            
            // Use update call for state-changing operations
            let response = agent.update(&principal, "pushInsight")
                .with_arg(args)
                .call();

            // Convert to blocking call for FFI compatibility
            let rt = tokio::runtime::Runtime::new()?;
            rt.block_on(response)?;
            
            Ok(())
        })
    }

    /// Get recent insights from NamoraAI
    pub async fn get_recent_insights(&self) -> Result<Vec<SystemInsight>> {
        with_agent(|agent| {
            let principal = Principal::from_text(&self.endpoints.namora_ai)?;
            
            let response = agent.query(&principal, "getRecentInsights")
                .call();

            let rt = tokio::runtime::Runtime::new()?;
            let result = rt.block_on(response)?;
            
            let insights = Decode!(result.as_slice(), Vec<SystemInsight>)?;
            Ok(insights)
        })
    }

    /// Get system health summary
    pub async fn get_system_health(&self) -> Result<SystemHealthSummary> {
        with_agent(|agent| {
            let principal = Principal::from_text(&self.endpoints.namora_ai)?;
            
            let response = agent.query(&principal, "getSystemHealthSummary")
                .call();

            let rt = tokio::runtime::Runtime::new()?;
            let result = rt.block_on(response)?;
            
            let health = Decode!(result.as_slice(), SystemHealthSummary)?;
            Ok(health)
        })
    }

    /// Get smart alerts
    pub async fn get_smart_alerts(&self) -> Result<Vec<SmartAlert>> {
        with_agent(|agent| {
            let principal = Principal::from_text(&self.endpoints.namora_ai)?;
            
            let response = agent.query(&principal, "getSmartAlerts")
                .call();

            let rt = tokio::runtime::Runtime::new()?;
            let result = rt.block_on(response)?;
            
            let alerts = Decode!(result.as_slice(), Vec<SmartAlert>)?;
            Ok(alerts)
        })
    }

    /// Create user via identity canister
    pub async fn create_user(&self, username: String, email: String, password: String) -> Result<String> {
        with_agent(|agent| {
            let principal = Principal::from_text(&self.endpoints.user)?;
            let args = Encode!(&username, &email, &password)?;
            
            let response = agent.update(&principal, "createUser")
                .with_arg(args)
                .call();

            let rt = tokio::runtime::Runtime::new()?;
            let result = rt.block_on(response)?;
            
            let user_id = Decode!(result.as_slice(), String)?;
            Ok(user_id)
        })
    }

    /// Test canister connectivity
    pub async fn ping_canister(&self, canister_id: &str) -> Result<bool> {
        with_agent(|agent| {
            let principal = Principal::from_text(canister_id)?;
            
            let response = agent.query(&principal, "ping")
                .call();

            let rt = tokio::runtime::Runtime::new()?;
            let result = rt.block_on(response);
            
            Ok(result.is_ok())
        })
    }
}
