use std::ffi::{CStr,};
use std::os::raw::c_char;

use crate::ffi_utils::{ to_c_char, parse_tip_request, parse_c_string, execute_async }; 
use crate::xrpl::memo::{ parse_memo_string, validate_parsed_memo };
use crate::monitor::get_bridge_status;

use crate::xrpl::types::{ XRPLSubmitResult};
use crate::xrpl::client::submit_raw_xrpl_tx;


#[no_mangle]
pub extern "C" fn rust_tip_artist_via_xrpl(json_payload: *const c_char) -> *mut c_char {
    let json_str = unsafe {
        if json_payload.is_null() {
            return to_c_char("{\"error\": \"null input\"}");
        }
        CStr::from_ptr(json_payload).to_string_lossy().into_owned()
    };

    match parse_tip_request(&json_str) {
        Ok(_req) => {
            // Simulate tip logic: (in real case you'd handle the tx and queue)
            let mock_tx_hash = "ABC123TIP";
            let response = format!(r#"{{"status":"ok","tx_hash":"{}"}}"#, mock_tx_hash);
            to_c_char(&response)
        }
        Err(e) => to_c_char(&format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[no_mangle]
pub extern "C" fn rust_check_bridge_status() -> *mut c_char {
    match serde_json::to_string(&get_bridge_status()) {
        Ok(status_json) => to_c_char(&status_json),
        Err(_) => to_c_char("{\"error\": \"Failed to serialize status\"}"),
    }
}

#[no_mangle]
pub extern "C" fn rust_submit_raw_xrpl_tx(raw_json: *const c_char) -> *mut c_char {
    let input = unsafe {
        if raw_json.is_null() {
            return to_c_char("{\"error\": \"null input\"}");
        }
        CStr::from_ptr(raw_json).to_string_lossy().into_owned()
    };

    match submit_raw_xrpl_tx(&input) {
        Ok(XRPLSubmitResult { tx_hash, status: _, ledger_index: _ }) => {
            let response = format!(r#"{{"status":"submitted","tx_hash":"{}"}}"#, tx_hash);
            to_c_char(&response)
        }
        Err(e) => to_c_char(&format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[no_mangle]
pub extern "C" fn rust_decode_xrpl_memo(raw_memo: *const c_char) -> *mut c_char {
    let raw_string = match parse_c_string(raw_memo) {
        Ok(s) => s,
        Err(e) => return to_c_char(&format!(r#"{{"error":"{}"}}"#, e)),
    };

    execute_async(async move {
        let parsed = parse_memo_string(&raw_string).map_err(|e| e.to_string())?;
        validate_parsed_memo(&parsed).map_err(|e| e.to_string())?;

        let json = serde_json::to_string(&parsed.fields).map_err(|e| e.to_string())?;
        Ok(json)
    })
}

#[no_mangle]
pub extern "C" fn rust_log_bridge_event(message: *const c_char) {
    if let Ok(msg) = parse_c_string(message) {
        eprintln!("📜 [SWIFT LOG] {}", msg); // Or optionally write to DB
    }
}

#[no_mangle]
pub extern "C" fn rust_get_failed_actions() -> *mut c_char {
    execute_async(async move {
        use crate::state::db::load_failed_actions;
        let entries = load_failed_actions().unwrap_or_else(|_| vec![]);
        let json = serde_json::to_string(&entries).map_err(|e| e.to_string())?;
        Ok(json)
    })
}

#[no_mangle]
pub extern "C" fn rust_reset_bridge_state() {
    use crate::state::memory::{clear_queue, clear_verified, reset_metrics};
    clear_queue();
    clear_verified();
    reset_metrics();
    eprintln!("🧹 Bridge memory state reset.");
}