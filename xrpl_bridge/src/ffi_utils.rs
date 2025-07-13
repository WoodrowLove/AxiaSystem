use std::ffi::CString;
use std::os::raw::c_char;
use std::ffi::CStr;
use std::ptr;


// Placeholder until full logic is defined
use crate::xrpl::types::TipRequest;

pub fn parse_tip_request(json: &str) -> Result<TipRequest, String> {
    serde_json::from_str(json).map_err(|e| e.to_string())
}

pub fn parse_c_string(ptr: *const c_char) -> Result<String, String> {
    if ptr.is_null() {
        return Err("Null pointer received".into());
    }
    let c_str = unsafe { CStr::from_ptr(ptr) };
    c_str
        .to_str()
        .map(|s| s.to_owned())
        .map_err(|e| format!("Failed to parse C string: {}", e))
}

pub fn to_c_char(s: &str) -> *mut c_char {
    CString::new(s).map(|cs| cs.into_raw()).unwrap_or_else(|_| ptr::null_mut())
}

pub fn execute_async<F>(fut: F) -> *mut c_char
where
    F: std::future::Future<Output = Result<String, String>> + Send + 'static,
{
    let result = std::thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        match rt.block_on(fut) {
            Ok(s) => s,
            Err(e) => format!(r#"{{"error":"{}"}}"#, e),
        }
    })
    .join()
    .unwrap_or_else(|_| r#"{"error":"Panic occurred"}"#.to_string());

    to_c_char(&result)
}

