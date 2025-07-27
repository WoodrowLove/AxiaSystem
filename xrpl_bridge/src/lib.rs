pub mod logic;

pub mod ffi;
pub mod ffi_utils;
pub mod generate_ffi;

pub mod xrpl;
pub mod ic_trigger;
pub mod config;
pub mod log;
pub mod state;
pub mod monitor;

// Note: IC modules are disabled for now due to compilation issues
// They will be enabled once the real IC integration is needed
// pub mod ic;