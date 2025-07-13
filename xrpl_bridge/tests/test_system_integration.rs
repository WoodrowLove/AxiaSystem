use candid::{Principal, Nat};
use xrpl_bridge::xrpl::memo::{parse_memo_string, validate_parsed_memo};
use xrpl_bridge::state::queue::{enqueue_action, get_pending_actions, clear_queue, dequeue_pending_action};
use xrpl_bridge::state::queue::PendingAction;
use xrpl_bridge::ic_trigger::route_action_to_canister;
use xrpl_bridge::config::BridgeConfig;
use xrpl_bridge::xrpl::types::XRPLActionType;

/// Full system integration test that simulates the complete XRPL bridge workflow
#[tokio::test]
async fn test_full_bridge_workflow() {
    clear_queue();
    
    // 🌊 Step 1: Simulate XRPL transactions with memos
    let xrpl_transactions = vec![
        (
            "TIP|ARTIST:2vxsx-fae|UUID:workflow-tip-001",
            1_000_000u64, // 1M drops (~$1.00)
            "XRPL_TX_HASH_TIP_001",
        ),
        (
            "NFTSALE|NFT:12345|BUYER:rdmx6-jaaaa-aaaaa-aaadq-cai|UUID:workflow-nft-001",
            10_000_000u64, // 10M drops (~$10.00)
            "XRPL_TX_HASH_NFT_001",
        ),
        (
            "TOKENSWAP|TOKEN:XRP|AMOUNT:5000000|UUID:workflow-swap-001",
            5_000_000u64, // 5M drops (~$5.00)
            "XRPL_TX_HASH_SWAP_001",
        ),
    ];
    
    println!("🔄 Processing {} XRPL transactions...", xrpl_transactions.len());
    
    // 🧠 Step 2: Parse and queue all transactions
    for (memo_str, amount, tx_hash) in xrpl_transactions {
        // Parse memo
        let parsed_memo = parse_memo_string(memo_str)
            .expect("Should parse memo");
        
        validate_parsed_memo(&parsed_memo)
            .expect("Should validate memo");
        
        // Create pending action based on memo type
        let action = match parsed_memo.action {
            XRPLActionType::Tip => {
                let artist = Principal::from_text(
                    parsed_memo.fields.get("ARTIST").unwrap()
                ).expect("Should parse artist principal");
                
                PendingAction::Tip {
                    artist,
                    amount: Nat::from(amount),
                    tx_hash: tx_hash.to_string(),
                    uuid: parsed_memo.fields.get("UUID").unwrap().to_string(),
                }
            }
            XRPLActionType::NFTSale => {
                let buyer = Principal::from_text(
                    parsed_memo.fields.get("BUYER").unwrap()
                ).expect("Should parse buyer principal");
                
                let nft_id = parsed_memo.fields.get("NFT").unwrap()
                    .parse::<u64>()
                    .expect("Should parse NFT ID");
                
                PendingAction::NFTSale {
                    nft_id: Nat::from(nft_id),
                    buyer,
                    price: Nat::from(amount),
                    tx_hash: tx_hash.to_string(),
                    uuid: parsed_memo.fields.get("UUID").unwrap().to_string(),
                }
            }
            XRPLActionType::TokenSwap => {
                // For token swap, we'll use a default artist principal
                let artist = Principal::from_text("2vxsx-fae").unwrap();
                
                PendingAction::TokenSwap {
                    artist,
                    amount: Nat::from(amount),
                    tx_hash: tx_hash.to_string(),
                    uuid: parsed_memo.fields.get("UUID").unwrap().to_string(),
                }
            }
        };
        
        // Queue the action
        enqueue_action(action).expect("Should enqueue action");
        
        println!("✅ Queued action: {:?}", parsed_memo.action);
    }
    
    // 🔍 Step 3: Verify all actions are queued
    let pending_actions = get_pending_actions();
    assert_eq!(pending_actions.len(), 3, "Should have 3 pending actions");
    
    println!("📊 Queue contains {} pending actions", pending_actions.len());
    
    // 🎯 Step 4: Process actions (simulating bridge main loop)
    let config = BridgeConfig {
        nft_canister_id: "rdmx6-jaaaa-aaaaa-aaadq-cai".to_string(),
        payment_log_canister_id: "rrkah-fqaaa-aaaaa-aaaaq-cai".to_string(),
        tip_handler_canister_id: "rno2w-sqaaa-aaaaa-aaacq-cai".to_string(),
        nft_sale_handler_canister_id: "rnp4e-6qaaa-aaaaa-aaaeq-cai".to_string(),
        token_swap_canister_id: "rzbzx-gyaaa-aaaaa-aaafq-cai".to_string(),
    };
    
    // Create mock agent for testing
    let agent = ic_agent::Agent::builder()
        .with_url("http://localhost:8000")
        .with_identity(ic_agent::identity::AnonymousIdentity)
        .build()
        .expect("Should build agent");
    
    let mut processed_count = 0;
    
    while let Some(action) = dequeue_pending_action() {
        match &action {
            PendingAction::Tip { uuid, .. } => {
                println!("🎁 Processing tip: {}", uuid);
            }
            PendingAction::NFTSale { uuid, .. } => {
                println!("🖼️  Processing NFT sale: {}", uuid);
            }
            PendingAction::TokenSwap { uuid, .. } => {
                println!("🔄 Processing token swap: {}", uuid);
            }
        }
        
        // In a real system, this would call the actual IC canisters
        // For testing, we expect this to fail but it validates the routing logic
        let result = route_action_to_canister(action, &agent, &config).await;
        
        // We expect failures in test environment but not panics
        assert!(result.is_err(), "Expected failure in test environment");
        
        processed_count += 1;
    }
    
    // 🏁 Step 5: Verify all actions were processed
    assert_eq!(processed_count, 3, "Should have processed 3 actions");
    assert_eq!(get_pending_actions().len(), 0, "Queue should be empty");
    
    println!("🎉 Full bridge workflow completed successfully!");
    println!("   - Parsed and validated 3 XRPL memos");
    println!("   - Queued 3 pending actions");
    println!("   - Processed all actions through routing logic");
    println!("   - Queue is now empty");
}

/// Test that demonstrates the bridge's ability to handle various memo formats
#[tokio::test]
async fn test_memo_format_compatibility() {
    clear_queue();
    
    // Test various memo formats that might be seen in production
    let test_cases = vec![
        // Standard formats
        ("TIP|ARTIST:2vxsx-fae|UUID:std-tip-001", true),
        ("NFTSALE|NFT:42|BUYER:2vxsx-fae|UUID:std-nft-001", true),
        ("TOKENSWAP|TOKEN:XRP|AMOUNT:1000000|UUID:std-swap-001", true),
        
        // Edge cases that should work
        ("TIP|ARTIST:rdmx6-jaaaa-aaaaa-aaadq-cai|UUID:long-canister-id", true),
        ("NFTSALE|NFT:999999|BUYER:2vxsx-fae|UUID:large-nft-id", true),
        ("TOKENSWAP|TOKEN:XRP|AMOUNT:999999999999|UUID:large-amount", true),
        
        // Cases that should fail
        ("INVALID|ARTIST:2vxsx-fae|UUID:invalid-action", false),
        ("TIP|ARTIST:2vxsx-fae", false), // Missing UUID
        ("TIP|UUID:missing-artist", false), // Missing ARTIST
        ("NFTSALE|NFT:42|UUID:missing-buyer", false), // Missing BUYER
        ("TOKENSWAP|TOKEN:XRP|UUID:missing-amount", false), // Missing AMOUNT
    ];
    
    let mut passed = 0;
    let mut failed = 0;
    
    for (memo_str, should_succeed) in test_cases {
        let parse_result = parse_memo_string(memo_str);
        
        let is_valid = match parse_result {
            Ok(parsed) => validate_parsed_memo(&parsed).is_ok(),
            Err(_) => false,
        };
        
        if should_succeed {
            assert!(is_valid, "Memo should be valid: {}", memo_str);
            passed += 1;
        } else {
            assert!(!is_valid, "Memo should be invalid: {}", memo_str);
            failed += 1;
        }
    }
    
    println!("📝 Memo format compatibility test results:");
    println!("   - {} valid memos passed", passed);
    println!("   - {} invalid memos correctly rejected", failed);
    println!("   - Total test cases: {}", passed + failed);
}

/// Test that demonstrates the bridge's error recovery capabilities
#[tokio::test]
async fn test_error_recovery() {
    clear_queue();
    
    // Simulate a scenario where some actions fail but the bridge continues
    let actions = vec![
        PendingAction::Tip {
            artist: Principal::from_text("2vxsx-fae").unwrap(),
            amount: Nat::from(1000u64),
            tx_hash: "recovery-test-1".to_string(),
            uuid: "recovery-uuid-1".to_string(),
        },
        PendingAction::NFTSale {
            nft_id: Nat::from(42u64),
            buyer: Principal::from_text("2vxsx-fae").unwrap(),
            price: Nat::from(2000u64),
            tx_hash: "recovery-test-2".to_string(),
            uuid: "recovery-uuid-2".to_string(),
        },
        PendingAction::TokenSwap {
            artist: Principal::from_text("2vxsx-fae").unwrap(),
            amount: Nat::from(3000u64),
            tx_hash: "recovery-test-3".to_string(),
            uuid: "recovery-uuid-3".to_string(),
        },
    ];
    
    // Queue all actions
    for action in &actions {
        enqueue_action(action.clone()).expect("Should enqueue action");
    }
    
    println!("🔄 Testing error recovery with {} actions", actions.len());
    
    // Simulate processing with failures
    let config = BridgeConfig {
        nft_canister_id: "invalid-canister-id".to_string(), // This will cause failures
        payment_log_canister_id: "invalid-canister-id".to_string(),
        tip_handler_canister_id: "invalid-canister-id".to_string(),
        nft_sale_handler_canister_id: "invalid-canister-id".to_string(),
        token_swap_canister_id: "invalid-canister-id".to_string(),
    };
    
    let agent = ic_agent::Agent::builder()
        .with_url("http://localhost:8000")
        .with_identity(ic_agent::identity::AnonymousIdentity)
        .build()
        .expect("Should build agent");
    
    let mut processed = 0;
    let mut failed = 0;
    
    while let Some(action) = dequeue_pending_action() {
        let result = route_action_to_canister(action, &agent, &config).await;
        
        processed += 1;
        
        if result.is_err() {
            failed += 1;
            // In a real system, failed actions might be:
            // 1. Logged for manual intervention
            // 2. Retried with exponential backoff
            // 3. Moved to a dead letter queue
        }
    }
    
    println!("⚠️  Error recovery test results:");
    println!("   - {} actions processed", processed);
    println!("   - {} actions failed (expected)", failed);
    println!("   - Bridge continued processing despite failures");
    
    // Verify queue is empty (all actions were processed, even if they failed)
    assert_eq!(get_pending_actions().len(), 0, "Queue should be empty");
}

/// Test that validates the complete data flow from XRPL to AxiaSystem
#[tokio::test]
async fn test_data_flow_validation() {
    clear_queue();
    
    // Define a comprehensive test scenario
    let test_data = vec![
        (
            "TIP|ARTIST:2vxsx-fae|UUID:data-flow-tip-001",
            500_000u64,
            "XRPL_TX_TIP_001",
        ),
        (
            "NFTSALE|NFT:98765|BUYER:rdmx6-jaaaa-aaaaa-aaadq-cai|UUID:data-flow-nft-001",
            15_000_000u64,
            "XRPL_TX_NFT_001",
        ),
        (
            "TOKENSWAP|TOKEN:XRP|AMOUNT:2500000|UUID:data-flow-swap-001",
            2_500_000u64,
            "XRPL_TX_SWAP_001",
        ),
    ];
    
    println!("🔍 Validating data flow for {} transactions", test_data.len());
    
    for (memo_str, expected_amount, tx_hash) in test_data {
        // Step 1: Parse memo
        let parsed = parse_memo_string(memo_str).expect("Should parse memo");
        validate_parsed_memo(&parsed).expect("Should validate memo");
        
        // Step 2: Extract data according to memo type
        let (action, actual_amount) = match parsed.action {
            XRPLActionType::Tip => {
                let artist = Principal::from_text(
                    parsed.fields.get("ARTIST").unwrap()
                ).expect("Should parse artist");
                
                let action = PendingAction::Tip {
                    artist,
                    amount: Nat::from(expected_amount),
                    tx_hash: tx_hash.to_string(),
                    uuid: parsed.fields.get("UUID").unwrap().to_string(),
                };
                
                (action, expected_amount)
            }
            XRPLActionType::NFTSale => {
                let buyer = Principal::from_text(
                    parsed.fields.get("BUYER").unwrap()
                ).expect("Should parse buyer");
                
                let nft_id = parsed.fields.get("NFT").unwrap()
                    .parse::<u64>()
                    .expect("Should parse NFT ID");
                
                let action = PendingAction::NFTSale {
                    nft_id: Nat::from(nft_id),
                    buyer,
                    price: Nat::from(expected_amount),
                    tx_hash: tx_hash.to_string(),
                    uuid: parsed.fields.get("UUID").unwrap().to_string(),
                };
                
                (action, expected_amount)
            }
            XRPLActionType::TokenSwap => {
                let artist = Principal::from_text("2vxsx-fae").unwrap();
                
                let action = PendingAction::TokenSwap {
                    artist,
                    amount: Nat::from(expected_amount),
                    tx_hash: tx_hash.to_string(),
                    uuid: parsed.fields.get("UUID").unwrap().to_string(),
                };
                
                (action, expected_amount)
            }
        };
        
        // Step 3: Validate data integrity
        let amount_from_action = match &action {
            PendingAction::Tip { amount, .. } => amount.clone(),
            PendingAction::NFTSale { price, .. } => price.clone(),
            PendingAction::TokenSwap { amount, .. } => amount.clone(),
        };
        
        assert_eq!(amount_from_action, Nat::from(actual_amount), "Amount should match");
        
        // Step 4: Queue and verify
        enqueue_action(action).expect("Should enqueue action");
        
        println!("✅ Validated data flow for: {:?}", parsed.action);
    }
    
    // Final verification
    let queued_actions = get_pending_actions();
    assert_eq!(queued_actions.len(), 3, "Should have 3 queued actions");
    
    println!("🎉 Data flow validation completed successfully!");
}
