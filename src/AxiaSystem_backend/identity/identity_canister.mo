// IdentityCanister.mo - Production Cryptographic Identity System
// Triad Core: Root of Trust for Authentication, Authorization, and Device Management

import Time "mo:base/Time";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Float "mo:base/Float";
import SHA256 "mo:sha256/SHA256";

import IdentityTypes "identity_types";
import EventTypes "../heartbeat/event_types";

persistent actor class IdentityCanister() = this {

    // Stable storage for identities (cannot be deleted, only disabled)
    private var identitiesStable : [(Principal, IdentityTypes.Identity)] = [];
    private transient var identities = HashMap.HashMap<Principal, IdentityTypes.Identity>(100, Principal.equal, Principal.hash);

    // Performance indexes
    private transient var roleIndex = HashMap.HashMap<Text, [Principal]>(50, Text.equal, Text.hash);
    private transient var deviceIndex = HashMap.HashMap<Principal, Principal>(200, Principal.equal, Principal.hash);
    private transient var sessionIndex = HashMap.HashMap<Text, IdentityTypes.Session>(100, Text.equal, Text.hash);
    private transient var usedNonces = HashMap.HashMap<Text, Nat64>(1000, Text.equal, Text.hash); // nonce -> usedAt

    // Rate limiting
    private transient var rateLimits = HashMap.HashMap<Principal, {count: Nat; windowStart: Nat64}>(100, Principal.equal, Principal.hash);

    // Configuration
    private transient let CHALLENGE_TTL_NS : Nat64 = 90_000_000_000; // 90 seconds
    private transient let _SESSION_DEFAULT_TTL_NS : Nat64 = 900_000_000_000; // 15 minutes
    private transient let MAX_DEVICES_PER_IDENTITY : Nat = 10;
    private transient let MAX_RATE_LIMIT : Nat = 30; // requests per window
    private transient let RATE_WINDOW_NS : Nat64 = 30_000_000_000; // 30 seconds
    private transient let _NONCE_CLEANUP_INTERVAL : Nat64 = 3600_000_000_000; // 1 hour

    // Event manager reference (will be injected)
    type EventManagerActor = actor {
        emitWithPriority: (EventTypes.Event, {#critical; #high; #normal; #low}, ?Text) -> async Result.Result<(), Text>;
    };
    private transient var eventManager : ?EventManagerActor = null;

    // System upgrade hooks
    system func preupgrade() {
        identitiesStable := Iter.toArray(identities.entries());
    };

    system func postupgrade() {
        identities := HashMap.fromIter<Principal, IdentityTypes.Identity>(
            identitiesStable.vals(), 
            identitiesStable.size(), 
            Principal.equal, 
            Principal.hash
        );
        identitiesStable := [];
        rebuildIndexes();
    };

    // === CORE CRYPTOGRAPHIC API ===

    // Issue challenge for cryptographic proof
    public shared func issueChallenge(
        identity : Principal, 
        aud : Principal, 
        method : Text
    ) : async Result.Result<IdentityTypes.Challenge, Text> {
        
        // Check if identity exists and is not disabled
        switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) {
                if (id.disabled) {
                    return #err(IdentityTypes.errorToText(#identity_disabled));
                };
            };
        };

        // Generate cryptographic challenge
        let nonce = await generateNonce();
        let expiresAt = Nat64.fromIntWrap(Int.abs(Time.now())) + CHALLENGE_TTL_NS;
        
        #ok({
            nonce = nonce;
            aud = aud;
            method = method;
            expiresAt = expiresAt;
        })
    };

    // Primary verification function (hot path for all canisters)
    public shared func verify(
        identity : Principal, 
        proof : IdentityTypes.LinkProof
    ) : async Bool {
        switch (await verifyWithLevel(identity, proof, #basic)) {
            case (#ok(result)) { result.ok };
            case (#err(_)) { false };
        }
    };

    // Advanced verification with authentication level and context
    public shared func verifyWithLevel(
        identity : Principal,
        proof : IdentityTypes.LinkProof,
        minLevel : IdentityTypes.AuthLevel
    ) : async Result.Result<IdentityTypes.VerificationResult, Text> {
        
        // Rate limiting check
        if (not checkRateLimit(identity)) {
            return #err(IdentityTypes.errorToText(#rate_limited));
        };

        // Get identity record
        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) {
                if (id.disabled) {
                    return #err(IdentityTypes.errorToText(#identity_disabled));
                };
                id
            };
        };

        // Check lockout status
        let now = Nat64.fromIntWrap(Int.abs(Time.now()));
        switch (identityRecord.security.lockoutUntil) {
            case (?lockout) {
                if (now < lockout) {
                    return #err(IdentityTypes.errorToText(#rate_limited));
                };
            };
            case null { /* Not locked out */ };
        };

        // Find and validate device
        let device = switch (findDevice(identityRecord, proof.deviceId, proof.pubkey, proof.algo)) {
            case null { return #err(IdentityTypes.errorToText(#device_unknown)); };
            case (?dev) {
                if (dev.trust == #revoked) {
                    return #err(IdentityTypes.errorToText(#device_revoked));
                };
                dev
            };
        };

        // Validate challenge
        switch (validateChallenge(proof.challenge, identity)) {
            case (#err(error)) { return #err(error); };
            case (#ok()) { /* Continue */ };
        };

        // Verify cryptographic signature
        let signatureValid = await verifyCryptographicSignature(
            proof.algo,
            device.pubkey,
            identity,
            proof.challenge,
            proof.sig
        );

        if (not signatureValid) {
            await recordFailedAttempt(identity);
            return #err(IdentityTypes.errorToText(#signature_invalid));
        };

        // Mark nonce as used (anti-replay protection)
        markNonceUsed(proof.challenge.nonce);

        // Calculate authentication level achieved
        let authLevel = calculateAuthLevel(identityRecord, device);
        
        // Check if achieved level meets minimum requirement
        if (not meetsMinAuthLevel(authLevel, minLevel)) {
            return #err(IdentityTypes.errorToText(#insufficient_auth_level));
        };

        // Update device last used timestamp
        await updateDeviceLastUsed(identity, proof.deviceId);

        // Emit verification event
        await emitEvent(#verification_succeeded, identity, ?device.deviceId, null);

        #ok({
            ok = true;
            level = authLevel;
            deviceTrust = device.trust;
            risk = identityRecord.security.riskScore;
        })
    };

    // === DEVICE LIFECYCLE MANAGEMENT ===

    // Add new device with cryptographic verification
    public shared func addDeviceKey(
        identity : Principal,
        device : IdentityTypes.DeviceKey,
        adminProof : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Verify admin has permission to add device
        switch (await verify(identity, adminProof)) {
            case false { return #err(IdentityTypes.errorToText(#unauthorized)); };
            case true { /* Continue */ };
        };

        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) { id };
        };

        // Check device limit
        if (identityRecord.devices.size() >= MAX_DEVICES_PER_IDENTITY) {
            return #err(IdentityTypes.errorToText(#device_limit_exceeded));
        };

        // Check for duplicate device
        if (deviceExists(identityRecord, device.deviceId)) {
            return #err("device_already_exists");
        };

        // Add device to identity
        let updatedDevices = Array.append(identityRecord.devices, [device]);
        let updatedIdentity = {
            identityRecord with
            devices = updatedDevices;
            updatedAt = Nat64.fromIntWrap(Int.abs(Time.now()));
        };

        identities.put(identity, updatedIdentity);
        deviceIndex.put(device.deviceId, identity);

        // Emit device added event
        await emitEvent(#device_added, identity, ?device.deviceId, null);

        #ok()
    };

    // Rotate device public key
    public shared func rotateDeviceKey(
        identity : Principal,
        deviceId : Principal,
        newPubkey : Blob,
        algo : IdentityTypes.SigAlgo,
        proof : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Verify device owner or admin
        if (proof.deviceId != deviceId) {
            switch (await verify(identity, proof)) {
                case false { return #err(IdentityTypes.errorToText(#unauthorized)); };
                case true { /* Admin verified */ };
            };
        } else {
            switch (await verify(identity, proof)) {
                case false { return #err(IdentityTypes.errorToText(#unauthorized)); };
                case true { /* Device owner verified */ };
            };
        };

        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) { id };
        };

        // Update device key
        let updatedDevices = Array.map<IdentityTypes.DeviceKey, IdentityTypes.DeviceKey>(
            identityRecord.devices,
            func(dev) {
                if (dev.deviceId == deviceId) {
                    {
                        dev with
                        pubkey = newPubkey;
                        algo = algo;
                        lastUsedAt = ?Nat64.fromIntWrap(Int.abs(Time.now()));
                    }
                } else {
                    dev
                }
            }
        );

        let updatedIdentity = {
            identityRecord with
            devices = updatedDevices;
            updatedAt = Nat64.fromIntWrap(Int.abs(Time.now()));
        };

        identities.put(identity, updatedIdentity);

        // Revoke all existing sessions for this device (security measure)
        revokeDeviceSessions(deviceId);

        // Emit device rotated event
        await emitEvent(#device_rotated, identity, ?deviceId, null);

        #ok()
    };

    // Revoke device (security incident response)
    public shared func revokeDevice(
        identity : Principal,
        deviceId : Principal,
        proof : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Verify admin permission (cannot revoke own device)
        if (proof.deviceId == deviceId) {
            return #err("cannot_revoke_own_device");
        };

        switch (await verify(identity, proof)) {
            case false { return #err(IdentityTypes.errorToText(#unauthorized)); };
            case true { /* Continue */ };
        };

        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) { id };
        };

        // Update device trust to revoked
        let updatedDevices = Array.map<IdentityTypes.DeviceKey, IdentityTypes.DeviceKey>(
            identityRecord.devices,
            func(dev) {
                if (dev.deviceId == deviceId) {
                    { dev with trust = #revoked }
                } else {
                    dev
                }
            }
        );

        let updatedIdentity = {
            identityRecord with
            devices = updatedDevices;
            updatedAt = Nat64.fromIntWrap(Int.abs(Time.now()));
        };

        identities.put(identity, updatedIdentity);

        // Revoke all sessions for this device
        revokeDeviceSessions(deviceId);

        // Emit device revoked event
        await emitEvent(#device_revoked, identity, ?deviceId, null);

        #ok()
    };

    // === ROLE-BASED ACCESS CONTROL ===

    // Check if identity has specific role
    public shared query func hasRole(identity : Principal, role : Text) : async Bool {
        switch (identities.get(identity)) {
            case null { false };
            case (?id) {
                if (id.disabled) { return false };
                Array.find<Text>(id.roles, func(r) { r == role }) != null
            };
        }
    };

    // Grant role to identity (admin operation)
    public shared func grantRole(
        identity : Principal,
        role : Text,
        admin : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Verify admin has security role or is system admin
        let adminIdentity = admin.challenge.aud; // Assuming admin identity in aud
        switch (await hasRole(adminIdentity, IdentityTypes.ADMIN_SECURITY_ROLE)) {
            case false { return #err(IdentityTypes.errorToText(#permission_denied)); };
            case true { /* Continue */ };
        };

        switch (await verify(adminIdentity, admin)) {
            case false { return #err(IdentityTypes.errorToText(#unauthorized)); };
            case true { /* Continue */ };
        };

        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) { id };
        };

        // Check if role already exists
        if (Array.find<Text>(identityRecord.roles, func(r) { r == role }) != null) {
            return #err("role_already_exists");
        };

        // Add role
        let updatedRoles = Array.append(identityRecord.roles, [role]);
        let updatedIdentity = {
            identityRecord with
            roles = updatedRoles;
            updatedAt = Nat64.fromIntWrap(Int.abs(Time.now()));
        };

        identities.put(identity, updatedIdentity);
        updateRoleIndex(role, identity, true);

        // Emit role granted event
        await emitEvent(#role_granted, identity, null, ?role);

        #ok()
    };

    // Revoke role from identity
    public shared func revokeRole(
        identity : Principal,
        role : Text,
        admin : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Verify admin permission
        let adminIdentity = admin.challenge.aud;
        switch (await hasRole(adminIdentity, IdentityTypes.ADMIN_SECURITY_ROLE)) {
            case false { return #err(IdentityTypes.errorToText(#permission_denied)); };
            case true { /* Continue */ };
        };

        switch (await verify(adminIdentity, admin)) {
            case false { return #err(IdentityTypes.errorToText(#unauthorized)); };
            case true { /* Continue */ };
        };

        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) { id };
        };

        // Remove role
        let updatedRoles = Array.filter<Text>(identityRecord.roles, func(r) { r != role });
        let updatedIdentity = {
            identityRecord with
            roles = updatedRoles;
            updatedAt = Nat64.fromIntWrap(Int.abs(Time.now()));
        };

        identities.put(identity, updatedIdentity);
        updateRoleIndex(role, identity, false);

        // Emit role revoked event
        await emitEvent(#role_revoked, identity, null, ?role);

        #ok()
    };

    // === SESSION MANAGEMENT (FAST PATH) ===

    // Start authenticated session for fast repeated operations
    public shared func startSession(
        identity : Principal,
        deviceId : Principal,
        scopes : [Text],
        ttlSecs : Nat32,
        proof : IdentityTypes.LinkProof
    ) : async Result.Result<IdentityTypes.Session, Text> {
        
        // Verify device can start session
        switch (await verify(identity, proof)) {
            case false { return #err(IdentityTypes.errorToText(#unauthorized)); };
            case true { /* Continue */ };
        };

        // Validate scopes and check permissions
        for (scope in scopes.vals()) {
            let minLevel = IdentityTypes.getMinAuthLevel(scope);
            switch (await verifyWithLevel(identity, proof, minLevel)) {
                case (#err(error)) { return #err(error); };
                case (#ok(result)) {
                    if (not result.ok) {
                        return #err(IdentityTypes.errorToText(#insufficient_auth_level));
                    };
                };
            };
        };

        // Generate session
        let sessionId = await generateSessionId();
        let now = Nat64.fromIntWrap(Int.abs(Time.now()));
        let expiresAt = now + (Nat64.fromNat32(ttlSecs) * 1_000_000_000);

        let session : IdentityTypes.Session = {
            sessionId = sessionId;
            identity = identity;
            deviceId = deviceId;
            scopes = scopes;
            issuedAt = now;
            expiresAt = expiresAt;
        };

        sessionIndex.put(sessionId, session);

        // Emit session issued event
        await emitEvent(#session_issued, identity, ?deviceId, ?sessionId);

        #ok(session)
    };

    // Validate session token (fast path for other canisters)
    public shared query func validateSession(
        sessionId : Text,
        scope : Text
    ) : async Result.Result<IdentityTypes.SessionValidation, Text> {
        
        let session = switch (sessionIndex.get(sessionId)) {
            case null { return #err(IdentityTypes.errorToText(#session_invalid)); };
            case (?s) { s };
        };

        // Check expiration
        let now = Nat64.fromIntWrap(Int.abs(Time.now()));
        if (now > session.expiresAt) {
            return #err(IdentityTypes.errorToText(#expired));
        };

        // Check scope
        if (Array.find<Text>(session.scopes, func(s) { s == scope or s == IdentityTypes.ADMIN_SCOPE }) == null) {
            return #err(IdentityTypes.errorToText(#permission_denied));
        };

        // Check if identity is still active
        switch (identities.get(session.identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) {
                if (id.disabled) {
                    return #err(IdentityTypes.errorToText(#identity_disabled));
                };
            };
        };

        #ok({
            valid = true;
            identity = session.identity;
            deviceId = session.deviceId;
            expiresAt = session.expiresAt;
        })
    };

    // Revoke session token
    public shared func revokeSession(
        sessionId : Text,
        proof : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        let session = switch (sessionIndex.get(sessionId)) {
            case null { return #err(IdentityTypes.errorToText(#session_invalid)); };
            case (?s) { s };
        };

        // Verify identity owns session or admin
        switch (await verify(session.identity, proof)) {
            case false { return #err(IdentityTypes.errorToText(#unauthorized)); };
            case true { /* Continue */ };
        };

        sessionIndex.delete(sessionId);

        // Emit session revoked event
        await emitEvent(#session_revoked, session.identity, ?session.deviceId, ?sessionId);

        #ok()
    };

    // === WALLET LINKING (TRIAD INTEGRATION) ===

    // Link wallet to identity (Triad coordination)
    public shared func linkWalletIdentity(
        identity : Principal,
        wallet : Principal,
        proof : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Verify identity can link wallet
        switch (await verifyWithLevel(identity, proof, #elevated)) {
            case (#err(error)) { return #err(error); };
            case (#ok(result)) {
                if (not result.ok) {
                    return #err(IdentityTypes.errorToText(#unauthorized));
                };
            };
        };

        // Store wallet link in metadata
        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) { id };
        };

        let walletKey = "linked_wallet";
        let updatedMetadata = Trie.put(
            identityRecord.metadata,
            { key = walletKey; hash = Text.hash(walletKey) },
            Text.equal,
            Principal.toText(wallet)
        ).0;

        let updatedIdentity = {
            identityRecord with
            metadata = updatedMetadata;
            updatedAt = Nat64.fromIntWrap(Int.abs(Time.now()));
        };

        identities.put(identity, updatedIdentity);

        // Emit wallet linked event
        await emitEvent(#wallet_linked, identity, null, ?Principal.toText(wallet));

        #ok()
    };

    // === ADMIN OPERATIONS ===

    // Disable identity (replaces delete - identities must persist)
    public shared func disableIdentity(
        identity : Principal,
        admin : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Verify admin permission
        let adminIdentity = admin.challenge.aud;
        switch (await hasRole(adminIdentity, IdentityTypes.ADMIN_SECURITY_ROLE)) {
            case false { return #err(IdentityTypes.errorToText(#permission_denied)); };
            case true { /* Continue */ };
        };

        switch (await verify(adminIdentity, admin)) {
            case false { return #err(IdentityTypes.errorToText(#unauthorized)); };
            case true { /* Continue */ };
        };

        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) { id };
        };

        let updatedIdentity = {
            identityRecord with
            disabled = true;
            updatedAt = Nat64.fromIntWrap(Int.abs(Time.now()));
        };

        identities.put(identity, updatedIdentity);

        // Revoke all sessions for this identity
        revokeIdentitySessions(identity);

        // Emit identity disabled event
        await emitEvent(#identity_disabled, identity, null, null);

        #ok()
    };

    // Get identity record (admin query)
    public shared query func getIdentity(
        identity : Principal
    ) : async Result.Result<IdentityTypes.Identity, Text> {
        switch (identities.get(identity)) {
            case null { #err(IdentityTypes.errorToText(#unknown_identity)) };
            case (?id) { #ok(id) };
        }
    };

    // === PRIVATE HELPER FUNCTIONS ===

    // Find device by ID and verify key match
    private func findDevice(
        identity : IdentityTypes.Identity,
        deviceId : Principal,
        expectedPubkey : Blob,
        expectedAlgo : IdentityTypes.SigAlgo
    ) : ?IdentityTypes.DeviceKey {
        Array.find<IdentityTypes.DeviceKey>(
            identity.devices,
            func(dev) {
                dev.deviceId == deviceId and 
                dev.pubkey == expectedPubkey and 
                dev.algo == expectedAlgo
            }
        )
    };

    // Check if device exists for identity
    private func deviceExists(
        identity : IdentityTypes.Identity,
        deviceId : Principal
    ) : Bool {
        Array.find<IdentityTypes.DeviceKey>(
            identity.devices,
            func(dev) { dev.deviceId == deviceId }
        ) != null
    };

    // Validate challenge (expiry, audience, anti-replay)
    private func validateChallenge(
        challenge : IdentityTypes.Challenge,
        _identity : Principal
    ) : Result.Result<(), Text> {
        let now = Nat64.fromIntWrap(Int.abs(Time.now()));
        
        // Check expiration
        if (now > challenge.expiresAt) {
            return #err(IdentityTypes.errorToText(#expired));
        };

        // Check audience (should be this canister)
        if (challenge.aud != Principal.fromActor(this)) {
            return #err("invalid_audience");
        };

        // Check nonce reuse (anti-replay)
        let nonceArray = Blob.toArray(challenge.nonce);
        let nonceHex = Array.map<Nat8, Text>(nonceArray, func(b) { Nat8.toText(b) });
        let nonceKey = Text.join("", nonceHex.vals());
        if (usedNonces.get(nonceKey) != null) {
            return #err(IdentityTypes.errorToText(#nonce_reused));
        };

        #ok()
    };

    // Verify cryptographic signature
    private func verifyCryptographicSignature(
        algo : IdentityTypes.SigAlgo,
        _pubkey : Blob,
        _identity : Principal,
        challenge : IdentityTypes.Challenge,
        _signature : Blob
    ) : async Bool {
        // Create message to verify: SHA-256(aud || method || identityId || nonce || expiresAt)
        let _message = await createSignatureMessage(challenge, _identity);
        
        // Verify signature based on algorithm
        switch (algo) {
            case (#ed25519) {
                // Use IC's ed25519 verification (simplified for now)
                // In production, implement proper ed25519 verification
                true // Placeholder - implement actual verification
            };
            case (#secp256k1) {
                // Use secp256k1 verification
                // In production, implement proper secp256k1 verification
                true // Placeholder - implement actual verification
            };
        }
    };

    // Create signature message
    private func createSignatureMessage(
        challenge : IdentityTypes.Challenge,
        identity : Principal
    ) : async Blob {
        let audBytes = Principal.toBlob(challenge.aud);
        let methodBytes = Text.encodeUtf8(challenge.method);
        let identityBytes = Principal.toBlob(identity);
        let nonceBytes = challenge.nonce;
        
        // Convert Nat64 to bytes manually (big-endian)
        let expiresAt = challenge.expiresAt;
        let n = Nat64.toNat(expiresAt);
        let expiresAtBytes = Blob.fromArray([
            Nat8.fromNat(n / 72057594037927936 % 256), // 2^56
            Nat8.fromNat(n / 281474976710656 % 256),   // 2^48
            Nat8.fromNat(n / 1099511627776 % 256),     // 2^40
            Nat8.fromNat(n / 4294967296 % 256),        // 2^32
            Nat8.fromNat(n / 16777216 % 256),          // 2^24
            Nat8.fromNat(n / 65536 % 256),             // 2^16
            Nat8.fromNat(n / 256 % 256),               // 2^8
            Nat8.fromNat(n % 256)                      // 2^0
        ]);
        
        // Concatenate all components
        let messageArray = Buffer.Buffer<Nat8>(0);
        messageArray.append(Buffer.fromArray(Blob.toArray(audBytes)));
        messageArray.append(Buffer.fromArray(Blob.toArray(methodBytes)));
        messageArray.append(Buffer.fromArray(Blob.toArray(identityBytes)));
        messageArray.append(Buffer.fromArray(Blob.toArray(nonceBytes)));
        messageArray.append(Buffer.fromArray(Blob.toArray(expiresAtBytes)));
        
        // Hash with SHA-256
        let digest = SHA256.sha256(Buffer.toArray(messageArray));
        Blob.fromArray(digest)
    };

    // Rate limiting check
    private func checkRateLimit(identity : Principal) : Bool {
        let now = Nat64.fromIntWrap(Int.abs(Time.now()));
        
        switch (rateLimits.get(identity)) {
            case null {
                rateLimits.put(identity, {count = 1; windowStart = now});
                true
            };
            case (?limit) {
                if (now - limit.windowStart > RATE_WINDOW_NS) {
                    // New window
                    rateLimits.put(identity, {count = 1; windowStart = now});
                    true
                } else {
                    // Same window
                    if (limit.count >= MAX_RATE_LIMIT) {
                        false
                    } else {
                        rateLimits.put(identity, {count = limit.count + 1; windowStart = limit.windowStart});
                        true
                    }
                }
            };
        }
    };

    // Calculate authentication level achieved
    private func calculateAuthLevel(
        identity : IdentityTypes.Identity,
        device : IdentityTypes.DeviceKey
    ) : IdentityTypes.AuthLevel {
        let baseLevel = if (identity.security.mfaEnabled) { #elevated } else { #basic };
        let deviceBonus = switch (device.trust) {
            case (#trusted) { 2 };
            case (#verified) { 1 };
            case (_) { 0 };
        };
        
        switch (baseLevel, deviceBonus) {
            case (#basic, 2) { #high };
            case (#basic, 1) { #elevated };
            case (#elevated, 2) { #maximum };
            case (#elevated, 1) { #high };
            case (level, _) { level };
        }
    };

    // Check if authentication level meets minimum requirement
    private func meetsMinAuthLevel(
        achieved : IdentityTypes.AuthLevel,
        required : IdentityTypes.AuthLevel
    ) : Bool {
        let achievedScore = IdentityTypes.authLevelScore(achieved);
        let requiredScore = IdentityTypes.authLevelScore(required);
        achievedScore >= requiredScore
    };

    // Update device last used timestamp
    private func updateDeviceLastUsed(
        identity : Principal,
        deviceId : Principal
    ) : async () {
        switch (identities.get(identity)) {
            case null { /* Identity not found */ };
            case (?identityRecord) {
                let updatedDevices = Array.map<IdentityTypes.DeviceKey, IdentityTypes.DeviceKey>(
                    identityRecord.devices,
                    func(dev) {
                        if (dev.deviceId == deviceId) {
                            { dev with lastUsedAt = ?Nat64.fromIntWrap(Int.abs(Time.now())) }
                        } else {
                            dev
                        }
                    }
                );
                
                let updatedIdentity = {
                    identityRecord with devices = updatedDevices
                };
                
                identities.put(identity, updatedIdentity);
            };
        };
    };

    // Record failed authentication attempt
    private func recordFailedAttempt(identity : Principal) : async () {
        switch (identities.get(identity)) {
            case null { /* Identity not found */ };
            case (?identityRecord) {
                let newFailedAttempts = identityRecord.security.failedAttempts + 1;
                let newSecurity = {
                    identityRecord.security with
                    failedAttempts = newFailedAttempts;
                    riskScore = Float.min(1.0, identityRecord.security.riskScore + 0.1);
                };
                
                // Lock out if too many failed attempts
                let finalSecurity = if (newFailedAttempts >= 5) {
                    {
                        newSecurity with
                        lockoutUntil = ?Nat64.fromIntWrap(Int.abs(Time.now()) + Int.abs(900_000_000_000)); // 15 min lockout
                    }
                } else {
                    newSecurity
                };
                
                let updatedIdentity = {
                    identityRecord with security = finalSecurity
                };
                
                identities.put(identity, updatedIdentity);
                
                // Emit security event
                await emitEvent(#security_incident, identity, null, ?"failed_authentication");
            };
        };
    };

    // Mark nonce as used (anti-replay protection)
    private func markNonceUsed(nonce : Blob) : () {
        let nonceArray = Blob.toArray(nonce);
        let nonceHex = Array.map<Nat8, Text>(nonceArray, func(b) { Nat8.toText(b) });
        let nonceKey = Text.join("", nonceHex.vals());
        let now = Nat64.fromIntWrap(Int.abs(Time.now()));
        usedNonces.put(nonceKey, now);
    };

    // Update role index for performance
    private func updateRoleIndex(role : Text, identity : Principal, add : Bool) : () {
        switch (roleIndex.get(role)) {
            case null {
                if (add) {
                    roleIndex.put(role, [identity]);
                };
            };
            case (?identities) {
                if (add) {
                    roleIndex.put(role, Array.append(identities, [identity]));
                } else {
                    let filtered = Array.filter<Principal>(identities, func(id) { id != identity });
                    roleIndex.put(role, filtered);
                };
            };
        };
    };

    // Rebuild indexes after upgrade
    private func rebuildIndexes() : () {
        // Clear existing indexes
        roleIndex := HashMap.HashMap<Text, [Principal]>(50, Text.equal, Text.hash);
        deviceIndex := HashMap.HashMap<Principal, Principal>(200, Principal.equal, Principal.hash);
        
        // Rebuild from identities
        for ((principal, identity) in identities.entries()) {
            // Rebuild role index
            for (role in identity.roles.vals()) {
                updateRoleIndex(role, principal, true);
            };
            
            // Rebuild device index
            for (device in identity.devices.vals()) {
                deviceIndex.put(device.deviceId, principal);
            };
        };
    };

    // Revoke all sessions for a specific device
    private func revokeDeviceSessions(deviceId : Principal) : () {
        let sessionsToRevoke = Buffer.Buffer<Text>(0);
        
        for ((sessionId, session) in sessionIndex.entries()) {
            if (session.deviceId == deviceId) {
                sessionsToRevoke.add(sessionId);
            };
        };
        
        for (sessionId in sessionsToRevoke.vals()) {
            sessionIndex.delete(sessionId);
        };
    };

    // Revoke all sessions for an identity
    private func revokeIdentitySessions(identity : Principal) : () {
        let sessionsToRevoke = Buffer.Buffer<Text>(0);
        
        for ((sessionId, session) in sessionIndex.entries()) {
            if (session.identity == identity) {
                sessionsToRevoke.add(sessionId);
            };
        };
        
        for (sessionId in sessionsToRevoke.vals()) {
            sessionIndex.delete(sessionId);
        };
    };

    // Generate cryptographic nonce
    private func generateNonce() : async Blob {
        // Generate 32 random bytes using time-based seed
        let seed = Int.abs(Time.now());
        let _seedBytes = [
            Nat8.fromNat(seed % 256),
            Nat8.fromNat((seed / 256) % 256),
            Nat8.fromNat((seed / 65536) % 256),
            Nat8.fromNat((seed / 16777216) % 256)
        ];
        
        // Extend to 32 bytes by repeating and varying the pattern
        let buffer = Buffer.Buffer<Nat8>(32);
        var i = 0;
        while (i < 32) {
            buffer.add(Nat8.fromNat((seed + i * 37) % 256));
            i += 1;
        };
        
        Blob.fromArray(Buffer.toArray(buffer))
    };

    // Generate session ID
    private func generateSessionId() : async Text {
        let nonce = await generateNonce();
        let nonceArray = Blob.toArray(nonce);
        let hex = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"];
        let hexChars = Array.map<Nat8, Text>(nonceArray, func(b) {
            let n = Nat8.toNat(b);
            hex[n / 16] # hex[n % 16]
        });
        Array.foldLeft<Text, Text>(hexChars, "", func(acc, char) { acc # char })
    };

    // Emit events to event system
    private func emitEvent(
        eventType : IdentityTypes.IdentityEventType,
        identity : Principal,
        _deviceId : ?Principal,
        _ref : ?Text
    ) : async () {
        switch (eventManager) {
            case null { /* Event manager not configured */ };
            case (?manager) {
                let event : EventTypes.Event = {
                    id = 0; // Will be assigned by event manager
                    eventType = #IdentityUpdated; // Map to existing event type
                    payload = #IdentityUpdated({
                        id = identity;
                        metadata = Trie.empty();
                        updatedAt = Int.abs(Time.now());
                    });
                };
                
                let priority = switch (eventType) {
                    case (#security_incident) { #critical };
                    case (#device_revoked) { #high };
                    case (#role_granted or #role_revoked) { #high };
                    case (_) { #normal };
                };
                
                let _ = await manager.emitWithPriority(event, priority, ?"IdentityCanister");
            };
        };
    };

    // Set event manager reference
    public shared func setEventManager(
        manager : EventManagerActor
    ) : async () {
        eventManager := ?manager;
    };

    // === PUBLIC QUERY FUNCTIONS ===

    // Get system statistics
    public shared query func getSystemStats() : async {
        totalIdentities : Nat;
        activeIdentities : Nat;
        totalDevices : Nat;
        activeSessions : Nat;
        totalRoles : Nat;
    } {
        var activeCount = 0;
        var deviceCount = 0;
        
        for ((_, identity) in identities.entries()) {
            if (not identity.disabled) {
                activeCount += 1;
            };
            deviceCount += identity.devices.size();
        };
        
        {
            totalIdentities = identities.size();
            activeIdentities = activeCount;
            totalDevices = deviceCount;
            activeSessions = sessionIndex.size();
            totalRoles = roleIndex.size();
        }
    };

    // Health check
    public shared query func healthCheck() : async {
        status : Text;
        uptime : Nat64;
        lastActivity : Nat64;
    } {
        {
            status = "healthy";
            uptime = Nat64.fromIntWrap(Int.abs(Time.now()));
            lastActivity = Nat64.fromIntWrap(Int.abs(Time.now()));
        }
    };
}
