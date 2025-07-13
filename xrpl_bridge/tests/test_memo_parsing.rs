use xrpl_bridge::xrpl::memo::{parse_memo_string, validate_parsed_memo, extract_principal_from_memo};
use xrpl_bridge::xrpl::types::XRPLActionType;

#[tokio::test]
async fn test_tip_memo_parsing() {
    let memo = "TIP|ARTIST:rdqQhzqkUEDwjjEdpd3xvtGAEfV1jjjmyJ|UUID:tip-123";
    
    let parsed = parse_memo_string(memo).expect("Should parse tip memo");
    assert_eq!(parsed.action, XRPLActionType::Tip);
    assert_eq!(parsed.fields.get("ARTIST").unwrap(), "rdqQhzqkUEDwjjEdpd3xvtGAEfV1jjjmyJ");
    assert_eq!(parsed.fields.get("UUID").unwrap(), "tip-123");
    
    validate_parsed_memo(&parsed).expect("Should validate tip memo");
    
    // Note: This principal format won't be valid for IC, but that's OK for memo parsing
    let artist_result = extract_principal_from_memo(&parsed, "ARTIST");
    assert!(artist_result.is_err()); // This should fail since it's not a valid IC principal
}

#[tokio::test]
async fn test_nft_sale_memo_parsing() {
    let memo = "NFTSALE|NFT:42|BUYER:rdqQhzqkUEDwjjEdpd3xvtGAEfV1jjjmyJ|UUID:sale-456";
    
    let parsed = parse_memo_string(memo).expect("Should parse NFT sale memo");
    assert_eq!(parsed.action, XRPLActionType::NFTSale);
    assert_eq!(parsed.fields.get("NFT").unwrap(), "42");
    assert_eq!(parsed.fields.get("BUYER").unwrap(), "rdqQhzqkUEDwjjEdpd3xvtGAEfV1jjjmyJ");
    assert_eq!(parsed.fields.get("UUID").unwrap(), "sale-456");
    
    validate_parsed_memo(&parsed).expect("Should validate NFT sale memo");
}

#[tokio::test]
async fn test_token_swap_memo_parsing() {
    let memo = "TOKENSWAP|TOKEN:XRP|AMOUNT:1000|UUID:swap-789";
    
    let parsed = parse_memo_string(memo).expect("Should parse token swap memo");
    assert_eq!(parsed.action, XRPLActionType::TokenSwap);
    assert_eq!(parsed.fields.get("TOKEN").unwrap(), "XRP");
    assert_eq!(parsed.fields.get("AMOUNT").unwrap(), "1000");
    assert_eq!(parsed.fields.get("UUID").unwrap(), "swap-789");
    
    validate_parsed_memo(&parsed).expect("Should validate token swap memo");
}

#[tokio::test]
async fn test_invalid_memo_formats() {
    // Test malformed format
    let result = parse_memo_string("INVALID_FORMAT");
    assert!(result.is_err());
    
    // Test unknown action type
    let result = parse_memo_string("UNKNOWN|ARTIST:rdqQhzqkUEDwjjEdpd3xvtGAEfV1jjjmyJ");
    assert!(result.is_err());
    
    // Test missing required fields for TIP
    let result = parse_memo_string("TIP|UUID:test123"); // Missing ARTIST
    let parsed = result.expect("Should parse but validation should fail");
    assert!(validate_parsed_memo(&parsed).is_err());
}

#[tokio::test]
async fn test_memo_edge_cases() {
    // Test with empty fields
    let result = parse_memo_string("TIP|ARTIST:|UUID:test");
    assert!(result.is_ok()); // This should parse fine
    let parsed = result.unwrap();
    assert_eq!(parsed.fields.get("ARTIST").unwrap(), "");
    
    // Test with duplicate fields
    let memo = "TIP|ARTIST:first-principal|ARTIST:second-principal|UUID:test";
    let parsed = parse_memo_string(memo).expect("Should parse even with duplicates");
    // Should use the last occurrence
    assert_eq!(parsed.fields.get("ARTIST").unwrap(), "second-principal");
    
    // Test case sensitive action types
    let memo = "tip|ARTIST:rdqQhzqkUEDwjjEdpd3xvtGAEfV1jjjmyJ|UUID:test";
    let result = parse_memo_string(memo);
    // Should fail since we expect uppercase
    assert!(result.is_err());
}
