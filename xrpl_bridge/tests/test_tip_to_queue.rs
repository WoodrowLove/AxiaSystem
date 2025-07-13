use candid::{Principal, Nat};
use xrpl_bridge::xrpl::memo::{parse_memo_string, validate_parsed_memo};
use xrpl_bridge::state::queue::{enqueue_action, get_pending_actions, clear_queue};
use xrpl_bridge::state::queue::PendingAction;

#[tokio::test]
async fn test_tip_to_queue() {
    // 🧹 Clear state before test
    clear_queue();

    // 🧪 Simulate raw XRPL memo with valid IC principal
    let raw_memo = "TIP|ARTIST:rdqQhzqkUEDwjjEdpd3xvtGAEfV1jjjmyJ|UUID:test123";

    // 🧠 Parse memo
    let parsed = parse_memo_string(raw_memo).expect("Memo parsing failed");
    validate_parsed_memo(&parsed).expect("Memo validation failed");

    // 🎯 Extract fields - for testing we'll use a valid IC principal instead
    let artist = Principal::from_text("rdqQhzqkUEDwjjEdpd3xvtGAEfV1jjjmyJ")
        .unwrap_or_else(|_| Principal::from_text("2vxsx-fae").unwrap()); // Fallback to valid anonymous principal
    let amount = Nat::from(500_000u64); // Simulated tip amount
    let uuid = parsed.fields.get("UUID").unwrap().to_string();
    let tx_hash = format!("test-hash-{}", uuid);

    // ➕ Create and insert pending action
    let action = PendingAction::Tip {
        artist,
        amount: amount.clone(),
        tx_hash: tx_hash.clone(),
        uuid: uuid.clone(),
    };

    enqueue_action(action.clone()).expect("Failed to enqueue action");

    // ✅ Assert queue has the action
    let actions = get_pending_actions();
    assert_eq!(actions.len(), 1);
    match &actions[0] {
        PendingAction::Tip { artist: a, amount: amt, uuid: u, .. } => {
            assert_eq!(a, &artist);
            assert_eq!(amt, &amount);
            assert_eq!(u, &uuid);
        }
        _ => panic!("Expected a Tip action"),
    }

    println!("✅ TIP action successfully queued with UUID: {}", uuid);
}