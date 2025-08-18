# Asset Canister Triad Integration FFI Specification

## Overview
This document specifies the Foreign Function Interface (FFI) requirements for integrating the Asset canister with the Triad architecture (User ↔ Identity ↔ Wallet). This enables the XRPL bridge and other external systems to interact with Triad-compliant asset operations.

## Core Triad Concepts

### Identity Layer (Canonical Authority)
- **Identity Principal**: The cryptographic root of trust for asset ownership
- **Link Proof**: Cryptographic proof of device/session authorization
- **Device Verification**: Multi-device support through device key validation

### User Layer (Optional Context)
- **User Principal**: Human-readable account layer for UX
- **User-Identity Link**: Verified connection between User profile and Identity

### Wallet Layer (Optional Value Context)
- **Wallet Principal**: Value layer for asset-related financial operations
- **Wallet-Identity Ownership**: Verified ownership of wallet by Identity

## FFI Function Specifications

### Core Triad Asset Operations

#### 1. Register Asset (Triad-Compliant)
```rust
rust_register_asset_triad(
    identity_id_c: *const c_char,           // Required: Identity Principal (canonical owner)
    metadata_c: *const c_char,              // Required: Asset metadata/description
    proof_json_c: *const c_char,            // Required: LinkProof JSON authentication
    user_id_c_or_null: *const c_char,       // Optional: User Principal for UX context
    wallet_id_c_or_null: *const c_char      // Optional: Wallet Principal for value context
) -> *const c_char
```

**LinkProof JSON Format:**
```json
{
    "signature": "base64_signature_bytes",
    "challenge": "base64_challenge_bytes", 
    "device": "base64_device_key_optional"
}
```

**Return Format:**
```json
{
    "ok": {
        "asset_id": 12345
    }
}
// OR
{
    "err": "unauthorized" | "invalid_metadata" | "user_identity_mismatch" | "wallet_ownership_mismatch"
}
```

#### 2. Transfer Asset Ownership (Triad-Compliant)
```rust
rust_transfer_asset_triad(
    identity_id_c: *const c_char,           // Required: Current owner Identity
    asset_id_u64: u64,                     // Required: Asset ID to transfer
    new_owner_identity_c: *const c_char,    // Required: New owner Identity Principal
    proof_json_c: *const c_char,            // Required: LinkProof authentication
    user_id_c_or_null: *const c_char        // Optional: User context for event tracking
) -> *const c_char
```

**Return Format:**
```json
{
    "ok": null
}
// OR  
{
    "err": "unauthorized" | "asset_not_found" | "asset_inactive" | "not_asset_owner"
}
```

#### 3. Deactivate Asset (Triad-Compliant)
```rust
rust_deactivate_asset_triad(
    identity_id_c: *const c_char,    // Required: Owner Identity
    asset_id_u64: u64,               // Required: Asset ID
    proof_json_c: *const c_char      // Required: LinkProof authentication
) -> *const c_char
```

#### 4. Reactivate Asset (Triad-Compliant)  
```rust
rust_reactivate_asset_triad(
    identity_id_c: *const c_char,    // Required: Owner Identity
    asset_id_u64: u64,               // Required: Asset ID
    proof_json_c: *const c_char      // Required: LinkProof authentication
) -> *const c_char
```

### Query Operations (Backward Compatible)

#### 5. Get Single Asset
```rust
rust_get_asset(asset_id_u64: u64) -> *const c_char
```

**Return Format:**
```json
{
    "ok": {
        "id": 12345,
        "ownerIdentity": "principal_string",
        "userId": "optional_user_principal",
        "walletId": "optional_wallet_principal", 
        "metadata": "asset_description",
        "registeredAt": 1692284400000000000,
        "updatedAt": 1692284400000000000,
        "isActive": true,
        "triadVerified": true
    }
}
// OR
{
    "err": "asset_not_found"
}
```

#### 6. Get All Assets
```rust
rust_get_all_assets() -> *const c_char
```

**Return Format:**
```json
{
    "ok": [
        {
            "id": 12345,
            "ownerIdentity": "principal_string",
            // ... full asset object
        }
        // ... more assets
    ]
}
```

#### 7. Get Assets by Owner (Identity-Based)
```rust
rust_get_assets_by_owner(identity_id_c: *const c_char) -> *const c_char
```

#### 8. Search Assets by Metadata
```rust
rust_search_assets_by_metadata(keyword_c: *const c_char) -> *const c_char
```

#### 9. Get Active Assets Only
```rust
rust_get_active_assets() -> *const c_char
```

### Legacy Support (Backward Compatibility)

#### 10. Register Asset (Legacy - Deprecated)
```rust
rust_register_asset_legacy(
    owner_principal_c: *const c_char,    // Legacy: Direct Principal (no Triad validation)
    metadata_c: *const c_char
) -> *const c_char
```

**Note**: Sets `triadVerified: false` for migration tracking

#### 11. Transfer Asset (Legacy - Deprecated)
```rust
rust_transfer_asset_legacy(
    asset_id_u64: u64,
    new_owner_c: *const c_char    // Legacy: Direct Principal transfer
) -> *const c_char
```

## Event Integration

### Triad Event Format
All Triad operations emit standardized events:

```json
{
    "topic": "asset.registered" | "asset.transferred" | "asset.deactivated" | "asset.reactivated",
    "identityId": "principal_string",           // Required: Identity layer
    "userId": "optional_user_principal",        // Optional: User layer
    "walletId": "optional_wallet_principal",    // Optional: Wallet layer  
    "ref": "asset:12345",                      // Asset reference
    "data": "base64_encoded_payload",          // Optional serialized data
    "ts": 1692284400000000000                  // Timestamp (nanoseconds)
}
```

## Error Handling Patterns

### Authentication Errors
- `"unauthorized"`: LinkProof verification failed
- `"identity_not_found"`: Identity Principal doesn't exist
- `"device_not_registered"`: Device key not associated with Identity

### Validation Errors  
- `"user_identity_mismatch"`: User Principal not linked to provided Identity
- `"wallet_ownership_mismatch"`: Wallet not owned by provided Identity
- `"invalid_metadata"`: Empty or malformed metadata

### Asset Operation Errors
- `"asset_not_found"`: Asset ID doesn't exist
- `"asset_inactive"`: Operation not allowed on deactivated asset
- `"not_asset_owner"`: Identity doesn't own the specified asset

### System Errors
- `"canister_error"`: Internal canister communication failure
- `"storage_error"`: Asset storage/retrieval failure

## Migration Strategy

### Phase 1: Dual API Support
- Deploy both Triad and Legacy endpoints
- New integrations use Triad FFI functions
- Existing integrations continue using Legacy functions
- Mark Legacy functions as deprecated

### Phase 2: Migration Assistance
- Provide migration utilities to convert Legacy calls to Triad calls
- Backfill existing assets with `triadVerified: false`
- Gradual migration of existing asset operations

### Phase 3: Legacy Deprecation
- Remove Legacy FFI functions
- All assets must be `triadVerified: true`
- Full Triad compliance required

## Performance Considerations

### Optimizations
- Owner index provides O(assets_owned) lookup instead of O(all_assets)
- Identity verification cached for session duration
- Batch operations for multiple asset transfers

### Scaling Limits
- Current: ~10K assets efficiently with array storage
- Future: Hash-based storage for production scale
- Metadata search: O(N) - add inverted index if needed

## Security Model

### Triad Security Layers
1. **Identity Layer**: Cryptographic device verification via LinkProof
2. **User Layer**: Optional profile consistency validation  
3. **Wallet Layer**: Optional financial context authorization

### Access Control
- All write operations require valid LinkProof
- Asset ownership verified through Identity Principal
- Cross-layer consistency enforced when User/Wallet context provided
- Event audit trail for all state changes

## Implementation Notes

### Canister Architecture
- **Main Actor**: Public API endpoints (Triad + Legacy)
- **Triad Service**: Validation wrapper around core module
- **Asset Module**: Core business logic with enhanced storage
- **Proxy Interface**: Inter-canister communication types

### Storage Schema
```motoko
public type Asset = {
    id: Nat;
    ownerIdentity: Principal;     // Canonical owner (Identity layer)
    userId: ?Principal;           // Optional User layer context
    walletId: ?Principal;         // Optional Wallet layer context
    metadata: Text;
    registeredAt: Int;           // Nanoseconds
    updatedAt: Int;
    isActive: Bool;
    triadVerified: Bool;         // Triad compliance flag
};
```

### Index Structure
- Primary: `assetId -> Asset`
- Owner Index: `identityPrincipal -> [assetId]`
- Future: Metadata Index: `token -> [assetId]`

## Bridge Integration

### XRPL Bridge Compatibility
- Asset operations map to XRPL transactions with Triad context
- Identity Principal provides consistent cross-chain identity
- Events enable XRPL bridge state synchronization
- Wallet context enables XRPL payment integration

### External System Integration
- RESTful wrapper around FFI functions for HTTP APIs
- GraphQL schema generation from Asset types
- WebSocket event streaming for real-time updates
- OAuth2 integration with Identity layer authentication

---

**Document Version**: 1.0  
**Last Updated**: August 17, 2025  
**Compatibility**: Asset Canister v2.0+ (Triad-Enhanced)  
**Status**: Implementation Ready
