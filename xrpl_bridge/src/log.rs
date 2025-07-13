pub fn log_verified_payment(tag: &str, message: String) {
    println!("📝 [{}] {}", tag.to_uppercase(), message);
}

/// Emits a structured bridge log with tag and message
pub fn bridge_log_event(tag: &str, message: String) {
    println!("🪵 [{}] {}", tag.to_uppercase(), message);
}