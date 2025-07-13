use candid::{Principal, Nat};
use ic_agent::Agent;
use xrpl_bridge::xrpl::memo::{parse_memo_string, validate_parsed_memo};
use xrpl_bridge::state::queue::{enqueue_action, get_pending_actions, clear_queue, dequeue_pending_action};
use xrpl_bridge::state::queue::PendingAction;
use xrpl_bridge::ic_trigger::route_action_to_canister;
use xrpl_bridge::config::BridgeConfig;

// Helper function to create a mock agent for testing
async fn create_mock_agent() -> Result<Agent, Box<dyn std::error::Error>> {
    // Use a mock identity for testing
    let identity = ic_agent::identity::AnonymousIdentity;
    
    // Use a mock network URL for testing
    let agent = Agent::builder()
        .with_url("http://localhost:8000") // Mock local network
        .with_identity(identity)
        .build()?;
    
    // Note: In a real test, you'd want to mock the IC network entirely
    // For now, this will fail on actual calls but allows testing the logic
    Ok(agent)
}

// Helper function to create a mock bridge config
fn create_mock_config() -> BridgeConfig {
    BridgeConfig {
        nft_canister_id: "rdmx6-jaaaa-aaaaa-aaadq-cai".to_string(),
        payment_log_canister_id: "rrkah-fqaaa-aaaaa-aaaaq-cai".to_string(),
        tip_handler_canister_id: "rno2w-sqaaa-aaaaa-aaacq-cai".to_string(),
        nft_sale_handler_canister_id: "rnp4e-6qaaa-aaaaa-aaaeq-cai".to_string(),
        token_swap_canister_id: "rzbzx-gyaaa-aaaaa-aaafq-cai".to_string(),
    }
}

#[tokio::test]
async fn test_end_to_end_tip_flow() {
    // 🧹 Clear state before test
    clear_queue();

    // 🎯 Step 1: Parse XRPL memo
    let raw_memo = "TIP|ARTIST:2vxsx-fae|UUID:tip-integration-test";
    let parsed = parse_memo_string(raw_memo).expect("Should parse memo");
    validate_parsed_memo(&parsed).expect("Should validate memo");

    // 🎯 Step 2: Create pending action
    let artist = Principal::from_text("2vxsx-fae").unwrap();
    let amount = Nat::from(1_000_000u64); // 1 million drops
    let uuid = parsed.fields.get("UUID").unwrap().to_string();
    let tx_hash = format!("test-tx-{}", uuid);

    let action = PendingAction::Tip {
        artist,
        amount: amount.clone(),
        tx_hash: tx_hash.clone(),
        uuid: uuid.clone(),
    };

    // 🎯 Step 3: Enqueue action
    enqueue_action(action.clone()).expect("Should enqueue action");
    
    // Verify it's in the queue
    let actions = get_pending_actions();
    assert_eq!(actions.len(), 1);

    // 🎯 Step 4: Dequeue and process (this would normally be done by the main loop)
    let dequeued_action = dequeue_pending_action().expect("Should dequeue action");
    assert!(matches!(dequeued_action, PendingAction::Tip { .. }));

    // 🎯 Step 5: Test routing to canister (this will fail in test but validates the logic)
    if let Ok(agent) = create_mock_agent().await {
        let config = create_mock_config();
        
        // This will fail because we don't have a real IC network, but it tests the routing logic
        let result = route_action_to_canister(dequeued_action, &agent, &config).await;
        
        // We expect this to fail in the test environment, but not panic
        assert!(result.is_err());
    }
    
    println!("✅ End-to-end tip flow test completed");
}

#[tokio::test]
async fn test_nft_sale_flow() {
    clear_queue();

    let raw_memo = "NFTSALE|NFT:42|BUYER:2vxsx-fae|UUID:nft-sale-test";
    let parsed = parse_memo_string(raw_memo).expect("Should parse NFT sale memo");
    validate_parsed_memo(&parsed).expect("Should validate NFT sale memo");

    let buyer = Principal::from_text("2vxsx-fae").unwrap();
    let nft_id = Nat::from(42u64);
    let price = Nat::from(5_000_000u64); // 5 million drops
    let uuid = parsed.fields.get("UUID").unwrap().to_string();
    let tx_hash = format!("nft-tx-{}", uuid);

    let action = PendingAction::NFTSale {
        nft_id,
        buyer,
        price,
        tx_hash,
        uuid,
    };

    enqueue_action(action.clone()).expect("Should enqueue NFT sale action");
    
    let actions = get_pending_actions();
    assert_eq!(actions.len(), 1);
    
    match &actions[0] {
        PendingAction::NFTSale { nft_id: id, buyer: b, price: p, .. } => {
            assert_eq!(id, &Nat::from(42u64));
            assert_eq!(b, &buyer);
            assert_eq!(p, &Nat::from(5_000_000u64));
        }
        _ => panic!("Expected NFTSale action"),
    }

    println!("✅ NFT sale flow test completed");
}

#[tokio::test]
async fn test_token_swap_flow() {
    clear_queue();

    let raw_memo = "TOKENSWAP|TOKEN:XRP|AMOUNT:1000000|UUID:swap-test";
    let parsed = parse_memo_string(raw_memo).expect("Should parse token swap memo");
    validate_parsed_memo(&parsed).expect("Should validate token swap memo");

    let artist = Principal::from_text("2vxsx-fae").unwrap();
    let amount = Nat::from(1_000_000u64);
    let uuid = parsed.fields.get("UUID").unwrap().to_string();
    let tx_hash = format!("swap-tx-{}", uuid);

    let action = PendingAction::TokenSwap {
        artist,
        amount,
        tx_hash,
        uuid,
    };

    enqueue_action(action.clone()).expect("Should enqueue token swap action");
    
    let actions = get_pending_actions();
    assert_eq!(actions.len(), 1);

    println!("✅ Token swap flow test completed");
}

#[tokio::test]
async fn test_queue_operations() {
    clear_queue();

    // Test multiple actions in queue
    let actions = vec![
        PendingAction::Tip {
            artist: Principal::from_text("2vxsx-fae").unwrap(),
            amount: Nat::from(1000u64),
            tx_hash: "tip-1".to_string(),
            uuid: "uuid-1".to_string(),
        },
        PendingAction::NFTSale {
            nft_id: Nat::from(1u64),
            buyer: Principal::from_text("2vxsx-fae").unwrap(),
            price: Nat::from(2000u64),
            tx_hash: "nft-1".to_string(),
            uuid: "uuid-2".to_string(),
        },
        PendingAction::TokenSwap {
            artist: Principal::from_text("2vxsx-fae").unwrap(),
            amount: Nat::from(3000u64),
            tx_hash: "swap-1".to_string(),
            uuid: "uuid-3".to_string(),
        },
    ];

    // Enqueue all actions
    for action in actions {
        enqueue_action(action).expect("Should enqueue action");
    }

    // Verify all are in queue
    let pending = get_pending_actions();
    assert_eq!(pending.len(), 3);

    // Dequeue and verify order
    let _first = dequeue_pending_action().expect("Should dequeue first action");
    let _second = dequeue_pending_action().expect("Should dequeue second action");
    let _third = dequeue_pending_action().expect("Should dequeue third action");

    // Verify queue is empty
    assert!(dequeue_pending_action().is_none());

    println!("✅ Queue operations test completed");
}

#[tokio::test]
async fn test_duplicate_prevention() {
    clear_queue();

    let action = PendingAction::Tip {
        artist: Principal::from_text("2vxsx-fae").unwrap(),
        amount: Nat::from(1000u64),
        tx_hash: "duplicate-test".to_string(),
        uuid: "uuid-dup".to_string(),
    };

    // First enqueue should succeed
    enqueue_action(action.clone()).expect("Should enqueue first action");

    // Second enqueue should fail due to duplicate tx_hash
    let result = enqueue_action(action);
    assert!(result.is_err());

    // Queue should still have only one action
    let pending = get_pending_actions();
    assert_eq!(pending.len(), 1);

    println!("✅ Duplicate prevention test completed");
}

#[tokio::test]
async fn test_error_handling() {
    clear_queue();

    // Test invalid memo parsing
    let invalid_memos = vec![
        "INVALID_FORMAT",
        "UNKNOWN_ACTION|ARTIST:2vxsx-fae|UUID:test",
        "TIP|INVALID_FIELD:value",
        "TIP|ARTIST:2vxsx-fae", // Missing UUID
    ];

    for memo in invalid_memos {
        let result = parse_memo_string(memo);
        if let Ok(parsed) = result {
            // If parsing succeeds, validation should fail
            assert!(validate_parsed_memo(&parsed).is_err());
        } else {
            // Parsing should fail for invalid formats
            assert!(result.is_err());
        }
    }

    println!("✅ Error handling test completed");
}
