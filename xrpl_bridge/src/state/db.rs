use std::fs::{File, OpenOptions, create_dir_all, self};
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::path::Path;
use serde_json::{to_writer, from_reader};
use crate::state::queue::PendingAction;

use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
struct FailedActionRecord {
    action: PendingAction,
    reason: String,
    tx_hash: String,
}

#[derive(Debug)]
pub enum DBError {
    ReadFailure(String),
    WriteFailure(String),
    DeserializeError(String),
    FileNotFound,
}

const PERSIST_DIR: &str = ".persistent/";
const TX_LOG_FILE: &str = ".persistent/tx_log.jsonl";

fn get_pending_actions_file() -> String {
    format!("{}queue.json", PERSIST_DIR)
}

fn get_tx_log_file() -> String {
    format!("{}tx_log.jsonl", PERSIST_DIR)
}

fn get_failed_actions_file() -> String {
    format!("{}failed.jsonl", PERSIST_DIR)
}

/// 📁 Ensures the persistent directory exists.
fn ensure_persist_dir() -> Result<(), DBError> {
    create_dir_all(PERSIST_DIR)
        .map_err(|e| DBError::WriteFailure(format!("Failed to create persist directory: {}", e)))
}

/// 💾 Saves the pending actions queue to disk.
pub fn persist_pending_actions(actions: &[PendingAction]) -> Result<(), DBError> {
    ensure_persist_dir()?;

    let file = File::create(&get_pending_actions_file())
        .map_err(|e| DBError::WriteFailure(e.to_string()))?;

    to_writer(BufWriter::new(file), &actions)
        .map_err(|e| DBError::WriteFailure(e.to_string()))
}

/// 🔁 Loads pending actions from disk.
pub fn load_pending_actions() -> Result<Vec<PendingAction>, DBError> {
    let pending_actions_file = get_pending_actions_file();
    if !Path::new(&pending_actions_file).exists() {
        return Ok(vec![]); // No actions yet — not an error
    }

    let file = File::open(&pending_actions_file)
        .map_err(|e| DBError::ReadFailure(e.to_string()))?;

    from_reader(BufReader::new(file))
        .map_err(|e| DBError::DeserializeError(e.to_string()))
}

/// 📜 Appends a transaction to the tx log file.
pub fn append_to_tx_log(tx_hash: &str, action_type: &str, timestamp: u64) {
    let log_entry = format!(
        "{{ \"tx_hash\": \"{}\", \"action\": \"{}\", \"timestamp\": {} }}\n",
        tx_hash, action_type, timestamp
    );

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&get_tx_log_file())
        .expect("Failed to open tx log file");

    file.write_all(log_entry.as_bytes())
        .expect("Failed to write to tx log");
}

/// ❌ Appends a failed action with reason to `failed.jsonl`.
pub fn persist_failed_action(
    action: &PendingAction,
    reason: &str,
    tx_hash: &str,
) -> Result<(), DBError> {
    let record = FailedActionRecord {
        action: action.clone(),
        reason: reason.to_string(),
        tx_hash: tx_hash.to_string(),
    };

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&get_failed_actions_file())
        .map_err(|e| DBError::WriteFailure(e.to_string()))?;

    let json = serde_json::to_string(&record)
        .map_err(|e| DBError::WriteFailure(e.to_string()))?;

    writeln!(file, "{}", json).map_err(|e| DBError::WriteFailure(e.to_string()))
}

/// 📥 Reads all failed actions and their reasons.
pub fn load_failed_actions() -> Result<Vec<(PendingAction, String, String)>, DBError> {
    let failed_actions_file = get_failed_actions_file();
    if !Path::new(&failed_actions_file).exists() {
        return Ok(vec![]);
    }

    let file = File::open(&failed_actions_file)
        .map_err(|e| DBError::ReadFailure(e.to_string()))?;

    let reader = BufReader::new(file);
    let mut results = Vec::new();

    for line in reader.lines() {
        let line = line.map_err(|e| DBError::ReadFailure(e.to_string()))?;
        let parsed: FailedActionRecord =
            serde_json::from_str(&line).map_err(|e| DBError::DeserializeError(e.to_string()))?;
        results.push((parsed.action, parsed.reason, parsed.tx_hash));
    }

    Ok(results)
}

/// 🧹 Clears all `.persistent` db files: queue, failed, tx_log.
pub fn clear_db_files() -> Result<(), DBError> {
    let files = vec![
        get_pending_actions_file(),
        get_failed_actions_file(),
        get_tx_log_file(),
    ];

    for path in &files {
        if Path::new(path).exists() {
            fs::remove_file(path)
                .map_err(|e| DBError::WriteFailure(format!("Failed to delete {}: {}", path, e)))?;
        }
    }

    Ok(())
}

/// 📁 Returns the path to the tx log file.
pub fn get_tx_log_path() -> String {
    TX_LOG_FILE.to_string()
}

#[derive(Serialize, Deserialize)]
pub struct FailedAction {
    // Define the fields for a failed action
    pub id: u64,
    pub reason: String,
    // Add other relevant fields
}

pub fn read_failed_actions() -> Result<Vec<FailedAction>, Box<dyn std::error::Error>> {
    // TODO: Replace this mock implementation with actual DB logic
    Ok(vec![]) // Return an empty vector for now
}