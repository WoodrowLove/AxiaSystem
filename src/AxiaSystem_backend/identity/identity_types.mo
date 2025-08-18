// IdentityTypes.mo - Canonical data types for Triad Identity System
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Float "mo:base/Float";

module IdentityTypes {
    public type IdentityID = Principal;

    // Cryptographic algorithms supported
    public type SigAlgo = { 
        #ed25519; 
        #secp256k1; 
    };

    // Device trust levels for attestation
    public type DeviceTrust = { 
        #trusted;    // Platform-attested device (iOS/Android keychain)
        #verified;   // Manually verified device
        #pending;    // Awaiting verification
        #revoked;    // Compromised or disabled
    };

    // Device key with cryptographic proof capability
    public type DeviceKey = {
        deviceId    : Principal;         // Logical device handle
        algo        : SigAlgo;           // Signature algorithm
        pubkey      : Blob;              // Raw public key bytes
        platform    : ?Text;             // "iOS", "Android", "macOS", "HWKey", etc.
        attestation : ?Blob;             // Platform attestation blob
        trust       : DeviceTrust;       // Trust level
        addedAt     : Nat64;            // When device was added
        lastUsedAt  : ?Nat64;           // Last authentication timestamp
    };

    // Role-based access control
    public type Role = Text;             // e.g. "gov.finalizer", "escrow.arbitrator"
    
    public type Permission = { 
        resource : Text;                 // Resource identifier
        actions : [Text];               // Allowed actions
        constraints : ?Text;            // Optional constraints (JSON)
    };

    // Authentication levels for adaptive security
    public type AuthLevel = { 
        #basic;      // Standard authentication
        #elevated;   // MFA or biometric
        #high;       // Multiple factors + device attestation
        #maximum;    // Hardware key required
    };

    // Security profile for risk-based authentication
    public type SecurityProfile = {
        authenticationLevel : AuthLevel;
        mfaEnabled          : Bool;
        failedAttempts      : Nat;
        lockoutUntil        : ?Nat64;
        riskScore           : Float;     // 0.0 (safe) to 1.0 (high risk)
    };

    // Core identity record (stable)
    public type Identity = {
        id            : IdentityID;
        devices       : [DeviceKey];
        roles         : [Role];
        permissions   : [Permission];
        metadata      : Trie.Trie<Text, Text>;  // Encrypted for sensitive data
        security      : SecurityProfile;
        createdAt     : Nat64;
        updatedAt     : Nat64;
        disabled      : Bool;                   // Replaces delete - identities persist
    };

    // Challenge for cryptographic proof
    public type Challenge = { 
        nonce : Blob;           // 32-byte random nonce
        aud : Principal;        // Target canister principal
        method : Text;          // Intended method name
        expiresAt : Nat64;      // Expiration timestamp
    };

    // LinkProof for cryptographic verification
    public type LinkProof = {
        algo     : SigAlgo;
        deviceId : Principal;
        pubkey   : Blob;         // Must match stored device
        sig      : Blob;         // Signature over hash(challenge || identityId)
        challenge: Challenge;    // Echoed challenge for verification
    };

    // Session tokens for fast-path verification
    public type Session = {
        sessionId : Text;        // Random opaque token
        identity  : IdentityID;
        deviceId  : Principal;
        scopes    : [Text];      // e.g. ["payment:write","escrow:release"]
        issuedAt  : Nat64;
        expiresAt : Nat64;
    };

    // Verification result with detailed context
    public type VerificationResult = {
        ok : Bool;
        level : AuthLevel;
        deviceTrust : DeviceTrust;
        risk : Float;
    };

    // Session validation result
    public type SessionValidation = {
        valid : Bool;
        identity : Principal;
        deviceId : Principal;
        expiresAt : Nat64;
    };

    // Wallet linking record
    public type WalletLink = {
        identity : IdentityID;
        wallet : Principal;
        linkedAt : Nat64;
        active : Bool;
    };

    // Standard error codes for deterministic responses
    public type IdentityError = {
        #unknown_identity;
        #device_unknown;
        #device_revoked;
        #unauthorized;
        #expired;
        #replayed;
        #rate_limited;
        #insufficient_auth_level;
        #session_invalid;
        #nonce_reused;
        #signature_invalid;
        #identity_disabled;
        #device_limit_exceeded;
        #role_not_found;
        #permission_denied;
    };

    // Event types for triad coordination
    public type IdentityEventType = {
        #identity_created;
        #identity_disabled;
        #device_added;
        #device_rotated;
        #device_revoked;
        #session_issued;
        #session_revoked;
        #role_granted;
        #role_revoked;
        #wallet_linked;
        #security_incident;
        #verification_failed;
        #verification_succeeded;
    };

    // Standard event envelope for triad consistency
    public type IdentityEvent = {
        topic : IdentityEventType;
        identityId : IdentityID;
        userId : ?Text;
        walletId : ?Principal;
        ref : ?Text;                    // "<type>:<id>" reference
        data : Blob;                    // CBOR/JSON payload
        timestamp : Nat64;
    };

    // Rate limiting configuration
    public type RateLimit = {
        maxRequests : Nat;              // Max requests per window
        windowSecs : Nat32;             // Time window in seconds
        burstLimit : Nat;               // Burst allowance
    };

    // Nonce tracking for anti-replay
    public type NonceTracker = {
        deviceId : Principal;
        identity : IdentityID;
        nonce : Blob;
        usedAt : Nat64;
    };

    // Index structures for performance
    public type RoleIndex = Trie.Trie<Text, [Principal]>;
    public type DeviceIndex = Trie.Trie<Principal, Principal>; // deviceId -> identity
    public type SessionIndex = Trie.Trie<Text, Session>;
    public type NonceIndex = Trie.Trie<(Principal, Principal), [Blob]>; // (identity, device) -> nonces

    // Migration support
    public type LegacyIdentity = {
        id: Principal;
        metadata: Trie.Trie<Text, Text>;
        createdAt: Int;
        updatedAt: Int;
    };

    // Crypto helper interface (for external Rust canister if needed)
    public type CryptoHelper = actor {
        ed25519_verify : (pubkey: Blob, message: Blob, signature: Blob) -> async Bool;
        secp256k1_verify : (pubkey: Blob, message: Blob, signature: Blob) -> async Bool;
        sha256 : (data: Blob) -> async Blob;
        random_bytes : (length: Nat) -> async Blob;
    };

    // Standard scopes for session-based auth
    public let PAYMENT_WRITE_SCOPE = "payment:write";
    public let ESCROW_CREATE_SCOPE = "escrow:create";
    public let ESCROW_RELEASE_SCOPE = "escrow:release";
    public let ASSET_TRANSFER_SCOPE = "asset:transfer";
    public let GOV_VOTE_SCOPE = "gov:vote";
    public let GOV_FINALIZE_SCOPE = "gov:finalize";
    public let WALLET_LINK_SCOPE = "wallet:link";
    public let ADMIN_SCOPE = "admin:*";

    // Standard roles
    public let GOV_FINALIZER_ROLE = "gov.finalizer";
    public let GOV_UPGRADE_CUSTODIAN_ROLE = "gov.upgrade.custodian";
    public let ESCROW_ARBITRATOR_ROLE = "escrow.arbitrator";
    public let ADMIN_SECURITY_ROLE = "admin.security";
    public let ADMIN_BILLING_ROLE = "admin.billing";

    // Utility functions
    public func errorToText(error: IdentityError) : Text {
        switch (error) {
            case (#unknown_identity) { "unknown_identity" };
            case (#device_unknown) { "device_unknown" };
            case (#device_revoked) { "device_revoked" };
            case (#unauthorized) { "unauthorized" };
            case (#expired) { "expired" };
            case (#replayed) { "replayed" };
            case (#rate_limited) { "rate_limited" };
            case (#insufficient_auth_level) { "insufficient_auth_level" };
            case (#session_invalid) { "session_invalid" };
            case (#nonce_reused) { "nonce_reused" };
            case (#signature_invalid) { "signature_invalid" };
            case (#identity_disabled) { "identity_disabled" };
            case (#device_limit_exceeded) { "device_limit_exceeded" };
            case (#role_not_found) { "role_not_found" };
            case (#permission_denied) { "permission_denied" };
        }
    };

    public func isHighPrivilegeScope(scope: Text) : Bool {
        scope == GOV_FINALIZE_SCOPE or 
        scope == ESCROW_RELEASE_SCOPE or 
        scope == ADMIN_SCOPE
    };

    public func getMinAuthLevel(scope: Text) : AuthLevel {
        if (scope == GOV_FINALIZE_SCOPE or scope == ADMIN_SCOPE) {
            #maximum
        } else if (scope == ESCROW_RELEASE_SCOPE or scope == GOV_VOTE_SCOPE) {
            #elevated
        } else {
            #basic
        }
    };

    public func deviceTrustScore(trust: DeviceTrust) : Float {
        switch (trust) {
            case (#trusted) { 1.0 };
            case (#verified) { 0.8 };
            case (#pending) { 0.4 };
            case (#revoked) { 0.0 };
        }
    };

    public func authLevelScore(level: AuthLevel) : Float {
        switch (level) {
            case (#maximum) { 1.0 };
            case (#high) { 0.75 };
            case (#elevated) { 0.5 };
            case (#basic) { 0.25 };
        }
    };
}
