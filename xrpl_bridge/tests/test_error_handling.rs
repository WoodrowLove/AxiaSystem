use candid::{Principal, Nat};
use ic_agent::Agent;
use xrpl_bridge::xrpl::memo::{parse_memo_string, validate_parsed_memo, extract_principal_from_memo, extract_nat_from_memo};
use xrpl_bridge::state::queue::{enqueue_action, get_pending_actions, clear_queue, dequeue_pending_action};
use xrpl_bridge::state::queue::PendingAction;
use xrpl_bridge::ic_trigger::route_action_to_canister;
use xrpl_bridge::config::BridgeConfig;
use xrpl_bridge::xrpl::types::XRPLActionType;

// Helper function to create a mock agent
async fn create_mock_agent() -> Result<Agent, Box<dyn std::error::Error>> {
    let identity = ic_agent::identity::AnonymousIdentity;
    let agent = Agent::builder()
        .with_url("http://localhost:8000")
        .with_identity(identity)
        .build()?;
    Ok(agent)
}

// Helper function to create a mock config
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
async fn test_memo_parsing_edge_cases() {
    // Test various edge cases in memo parsing
    
    // Valid memos
    let valid_memos = vec![
        "TIP|ARTIST:2vxsx-fae|UUID:tip123",
        "NFTSALE|NFT:42|BUYER:2vxsx-fae|UUID:nft456",
        "TOKENSWAP|TOKEN:XRP|AMOUNT:1000000|UUID:swap789",
    ];
    
    for memo in valid_memos {
        let parsed = parse_memo_string(memo).expect("Should parse valid memo");
        validate_parsed_memo(&parsed).expect("Should validate valid memo");
    }
    
    // Invalid action types
    let invalid_action_memos = vec![
        "INVALID|ARTIST:2vxsx-fae|UUID:test",
        "PURCHASE|ARTIST:2vxsx-fae|UUID:test",
        "TRANSFER|ARTIST:2vxsx-fae|UUID:test",
    ];
    
    for memo in invalid_action_memos {
        let result = parse_memo_string(memo);
        assert!(result.is_err(), "Should fail to parse invalid action: {}", memo);
    }
    
    // Malformed memos
    let malformed_memos = vec![
        "TIP", // No fields
        "TIP|", // Empty field
        "TIP|INVALID_FIELD", // No colon
        "TIP|ARTIST", // No value
        "TIP|ARTIST:|UUID:test", // Empty value
        "", // Empty memo
        "|||", // Only separators
    ];
    
    for memo in malformed_memos {
        let result = parse_memo_string(memo);
        // Some may parse but fail validation
        if let Ok(parsed) = result {
            assert!(validate_parsed_memo(&parsed).is_err(), "Should fail validation: {}", memo);
        }
    }
    
    println!("✅ Memo parsing edge cases test completed");
}

#[tokio::test]
async fn test_required_fields_validation() {
    // Test that each action type validates required fields correctly
    
    // TIP requires ARTIST and UUID
    let tip_memo_missing_artist = "TIP|UUID:test123";
    let tip_parsed = parse_memo_string(tip_memo_missing_artist).expect("Should parse");
    assert!(validate_parsed_memo(&tip_parsed).is_err(), "Should fail without ARTIST");
    
    let tip_memo_missing_uuid = "TIP|ARTIST:2vxsx-fae";
    let tip_parsed = parse_memo_string(tip_memo_missing_uuid).expect("Should parse");
    assert!(validate_parsed_memo(&tip_parsed).is_err(), "Should fail without UUID");
    
    // NFTSALE requires NFT, BUYER, and UUID
    let nft_memo_missing_nft = "NFTSALE|BUYER:2vxsx-fae|UUID:test123";
    let nft_parsed = parse_memo_string(nft_memo_missing_nft).expect("Should parse");
    assert!(validate_parsed_memo(&nft_parsed).is_err(), "Should fail without NFT");
    
    let nft_memo_missing_buyer = "NFTSALE|NFT:42|UUID:test123";
    let nft_parsed = parse_memo_string(nft_memo_missing_buyer).expect("Should parse");
    assert!(validate_parsed_memo(&nft_parsed).is_err(), "Should fail without BUYER");
    
    // TOKENSWAP requires TOKEN, AMOUNT, and UUID
    let swap_memo_missing_token = "TOKENSWAP|AMOUNT:1000000|UUID:test123";
    let swap_parsed = parse_memo_string(swap_memo_missing_token).expect("Should parse");
    assert!(validate_parsed_memo(&swap_parsed).is_err(), "Should fail without TOKEN");
    
    let swap_memo_missing_amount = "TOKENSWAP|TOKEN:XRP|UUID:test123";
    let swap_parsed = parse_memo_string(swap_memo_missing_amount).expect("Should parse");
    assert!(validate_parsed_memo(&swap_parsed).is_err(), "Should fail without AMOUNT");
    
    println!("✅ Required fields validation test completed");
}

#[tokio::test]
async fn test_principal_extraction_edge_cases() {
    // Test principal extraction with various formats
    
    let memo = "TIP|ARTIST:2vxsx-fae|BUYER:rdmx6-jaaaa-aaaaa-aaadq-cai|UUID:test";
    let parsed = parse_memo_string(memo).expect("Should parse");
    
    // Valid principal extraction
    let artist = extract_principal_from_memo(&parsed, "ARTIST").expect("Should extract artist");
    assert_eq!(artist.to_text(), "2vxsx-fae");
    
    let buyer = extract_principal_from_memo(&parsed, "BUYER").expect("Should extract buyer");
    assert_eq!(buyer.to_text(), "rdmx6-jaaaa-aaaaa-aaadq-cai");
    
    // Invalid principal formats
    let invalid_memo = "TIP|ARTIST:invalid-principal-format|UUID:test";
    let invalid_parsed = parse_memo_string(invalid_memo).expect("Should parse");
    
    let result = extract_principal_from_memo(&invalid_parsed, "ARTIST");
    assert!(result.is_err(), "Should fail to extract invalid principal");
    
    // Missing field
    let result = extract_principal_from_memo(&parsed, "NONEXISTENT");
    assert!(result.is_err(), "Should fail to extract non-existent field");
    
    println!("✅ Principal extraction edge cases test completed");
}

#[tokio::test]
async fn test_nat_extraction_edge_cases() {
    // Test Nat extraction with various formats
    
    let memo = "TOKENSWAP|TOKEN:XRP|AMOUNT:1000000|SMALL:1|LARGE:999999999999999999999|UUID:test";
    let parsed = parse_memo_string(memo).expect("Should parse");
    
    // Valid Nat extraction
    let amount = extract_nat_from_memo(&parsed, "AMOUNT").expect("Should extract amount");
    assert_eq!(amount, Nat::from(1_000_000u64));
    
    let small = extract_nat_from_memo(&parsed, "SMALL").expect("Should extract small number");
    assert_eq!(small, Nat::from(1u64));
    
    let large = extract_nat_from_memo(&parsed, "LARGE").expect("Should extract large number");
    assert_eq!(large, Nat::from(999_999_999_999_999_999_999u128));
    
    // Invalid Nat formats
    let invalid_memo = "TOKENSWAP|TOKEN:XRP|AMOUNT:not-a-number|UUID:test";
    let invalid_parsed = parse_memo_string(invalid_memo).expect("Should parse");
    
    let result = extract_nat_from_memo(&invalid_parsed, "AMOUNT");
    assert!(result.is_err(), "Should fail to extract invalid Nat");
    
    // Negative numbers
    let negative_memo = "TOKENSWAP|TOKEN:XRP|AMOUNT:-1000|UUID:test";
    let negative_parsed = parse_memo_string(negative_memo).expect("Should parse");
    
    let result = extract_nat_from_memo(&negative_parsed, "AMOUNT");
    assert!(result.is_err(), "Should fail to extract negative number");
    
    // Missing field
    let result = extract_nat_from_memo(&parsed, "NONEXISTENT");
    assert!(result.is_err(), "Should fail to extract non-existent field");
    
    println!("✅ Nat extraction edge cases test completed");
}

#[tokio::test]
async fn test_queue_error_handling() {
    clear_queue();
    
    // Test duplicate prevention
    let action = PendingAction::Tip {
        artist: Principal::from_text("2vxsx-fae").unwrap(),
        amount: Nat::from(1000u64),
        tx_hash: "duplicate_tx".to_string(),
        uuid: "dup_uuid".to_string(),
    };
    
    // First enqueue should succeed
    enqueue_action(action.clone()).expect("Should enqueue first action");
    
    // Second enqueue should fail
    let result = enqueue_action(action);
    assert!(result.is_err(), "Should fail to enqueue duplicate");
    
    // Queue should still have one action
    let actions = get_pending_actions();
    assert_eq!(actions.len(), 1);
    
    // Test empty queue dequeue
    dequeue_pending_action().expect("Should dequeue the action");
    let empty_result = dequeue_pending_action();
    assert!(empty_result.is_none(), "Should return None for empty queue");
    
    println!("✅ Queue error handling test completed");
}

#[tokio::test]
async fn test_large_queue_operations() {
    clear_queue();
    
    // Test with a large number of actions
    let action_count = 1000;
    
    for i in 0..action_count {
        let action = PendingAction::Tip {
            artist: Principal::from_text("2vxsx-fae").unwrap(),
            amount: Nat::from(i as u64),
            tx_hash: format!("large_test_{}", i),
            uuid: format!("large_uuid_{}", i),
        };
        
        enqueue_action(action).expect("Should enqueue action");
    }
    
    // Verify all actions are queued
    let actions = get_pending_actions();
    assert_eq!(actions.len(), action_count);
    
    // Dequeue all actions
    let mut dequeued_count = 0;
    while dequeue_pending_action().is_some() {
        dequeued_count += 1;
    }
    
    assert_eq!(dequeued_count, action_count);
    assert_eq!(get_pending_actions().len(), 0);
    
    println!("✅ Large queue operations test completed");
}

#[tokio::test]
async fn test_concurrent_queue_access() {
    clear_queue();
    
    // Test concurrent access to queue (simulated)
    let mut handles = vec![];
    
    for i in 0..10 {
        let handle = tokio::spawn(async move {
            let action = PendingAction::Tip {
                artist: Principal::from_text("2vxsx-fae").unwrap(),
                amount: Nat::from(i as u64),
                tx_hash: format!("concurrent_test_{}", i),
                uuid: format!("concurrent_uuid_{}", i),
            };
            
            enqueue_action(action).expect("Should enqueue action");
        });
        
        handles.push(handle);
    }
    
    // Wait for all tasks to complete
    for handle in handles {
        handle.await.expect("Task should complete");
    }
    
    // Verify all actions were queued
    let actions = get_pending_actions();
    assert_eq!(actions.len(), 10);
    
    println!("✅ Concurrent queue access test completed");
}

#[tokio::test]
async fn test_action_type_validation() {
    // Test that action types are properly validated
    
    // Test all valid action types
    let valid_actions = vec![
        ("TIP", XRPLActionType::Tip),
        ("NFTSALE", XRPLActionType::NFTSale),
        ("TOKENSWAP", XRPLActionType::TokenSwap),
    ];
    
    for (action_str, expected_type) in valid_actions {
        let memo = format!("{}|ARTIST:2vxsx-fae|UUID:test", action_str);
        let parsed = parse_memo_string(&memo).expect("Should parse valid action");
        assert_eq!(parsed.action, expected_type);
    }
    
    // Test case sensitivity
    let case_sensitive_actions = vec![
        "tip",
        "Tip",
        "TIP",
        "nftsale",
        "NFTSale",
        "tokenswap",
        "TokenSwap",
    ];
    
    for action_str in case_sensitive_actions {
        let memo = format!("{}|ARTIST:2vxsx-fae|UUID:test", action_str);
        let result = parse_memo_string(&memo);
        
        if action_str != "TIP" && action_str != "NFTSALE" && action_str != "TOKENSWAP" {
            assert!(result.is_err(), "Should fail for case-sensitive action: {}", action_str);
        }
    }
    
    println!("✅ Action type validation test completed");
}

#[tokio::test]
async fn test_bridge_resilience() {
    clear_queue();
    
    // Test bridge resilience to various error conditions
    
    // 1. Test with network failures (simulated)
    let action = PendingAction::Tip {
        artist: Principal::from_text("2vxsx-fae").unwrap(),
        amount: Nat::from(1000u64),
        tx_hash: "resilience_test".to_string(),
        uuid: "resilience_uuid".to_string(),
    };
    
    enqueue_action(action.clone()).expect("Should enqueue action");
    
    // Create agent that will fail (invalid URL)
    let invalid_agent = Agent::builder()
        .with_url("http://invalid-url-that-does-not-exist.com")
        .with_identity(ic_agent::identity::AnonymousIdentity)
        .build()
        .expect("Should build agent");
    
    let config = create_mock_config();
    let dequeued = dequeue_pending_action().expect("Should dequeue action");
    
    // This should fail gracefully
    let result = route_action_to_canister(dequeued, &invalid_agent, &config).await;
    assert!(result.is_err(), "Should fail with invalid network");
    
    // 2. Test with invalid canister IDs
    let mut invalid_config = create_mock_config();
    invalid_config.tip_handler_canister_id = "invalid-canister-id".to_string();
    
    let action2 = PendingAction::Tip {
        artist: Principal::from_text("2vxsx-fae").unwrap(),
        amount: Nat::from(2000u64),
        tx_hash: "resilience_test_2".to_string(),
        uuid: "resilience_uuid_2".to_string(),
    };
    
    enqueue_action(action2.clone()).expect("Should enqueue action");
    
    if let Ok(agent) = create_mock_agent().await {
        let dequeued2 = dequeue_pending_action().expect("Should dequeue action");
        let result = route_action_to_canister(dequeued2, &agent, &invalid_config).await;
        assert!(result.is_err(), "Should fail with invalid canister ID");
    }
    
    println!("✅ Bridge resilience test completed");
}
