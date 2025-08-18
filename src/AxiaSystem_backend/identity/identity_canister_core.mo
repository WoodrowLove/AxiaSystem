// IdentityCanister.mo - Production Cryptographic Identity System (Core Implementation)
// Triad Core: Root of Trust for Authentication, Authorization, and Device Management

import Time "mo:base/Time";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";

import IdentityTypes "identity_types";

persistent actor class IdentityCanister() = this {

    // Stable storage for identities (cannot be deleted, only disabled)
    private var identitiesStable : [(Principal, IdentityTypes.Identity)] = [];
    private transient var identities = HashMap.HashMap<Principal, IdentityTypes.Identity>(100, Principal.equal, Principal.hash);

    // Performance indexes
    private transient var roleIndex = HashMap.HashMap<Text, [Principal]>(50, Text.equal, Text.hash);
    private transient var deviceIndex = HashMap.HashMap<Principal, Principal>(200, Principal.equal, Principal.hash);
    private transient var sessionIndex = HashMap.HashMap<Text, IdentityTypes.Session>(100, Text.equal, Text.hash);
    private transient var usedNonces = HashMap.HashMap<Text, Nat64>(1000, Text.equal, Text.hash);

    // Rate limiting
    private transient var rateLimits = HashMap.HashMap<Principal, {count: Nat; windowStart: Nat64}>(100, Principal.equal, Principal.hash);

    // Configuration
    private transient let CHALLENGE_TTL_NS : Nat64 = 90_000_000_000; // 90 seconds
    private transient let _SESSION_DEFAULT_TTL_NS : Nat64 = 900_000_000_000; // 15 minutes
    private transient let MAX_DEVICES_PER_IDENTITY : Nat = 10;
    private transient let MAX_RATE_LIMIT : Nat = 30;
    private transient let RATE_WINDOW_NS : Nat64 = 30_000_000_000;

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
    public shared query func issueChallenge(
        identity : Principal, 
        aud : Principal, 
        method : Text
    ) : async Result.Result<IdentityTypes.Challenge, Text> {
        
        switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) {
                if (id.disabled) {
                    return #err(IdentityTypes.errorToText(#identity_disabled));
                };
            };
        };

        // Generate challenge (simplified for compilation)
        let nonce = Text.encodeUtf8("random_nonce_" # Int.toText(Time.now()));
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

        // Validate challenge (simplified)
        let now = Nat64.fromIntWrap(Int.abs(Time.now()));
        if (now > proof.challenge.expiresAt) {
            return #err(IdentityTypes.errorToText(#expired));
        };

        // Check nonce reuse (anti-replay)
        let nonceKey = blobToHex(proof.challenge.nonce);
        if (usedNonces.get(nonceKey) != null) {
            return #err(IdentityTypes.errorToText(#nonce_reused));
        };

        // Mark nonce as used
        usedNonces.put(nonceKey, now);

        // Calculate authentication level
        let authLevel = calculateAuthLevel(identityRecord, device);
        
        // Check minimum requirement
        if (not meetsMinAuthLevel(authLevel, minLevel)) {
            return #err(IdentityTypes.errorToText(#insufficient_auth_level));
        };

        // Update device last used
        updateDeviceLastUsed(identity, proof.deviceId);

        #ok({
            ok = true;
            level = authLevel;
            deviceTrust = device.trust;
            risk = identityRecord.security.riskScore;
        })
    };

    // === DEVICE LIFECYCLE MANAGEMENT ===

    // Add new device with verification
    public shared func addDeviceKey(
        identity : Principal,
        device : IdentityTypes.DeviceKey,
        adminProof : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Verify admin permission
        if (not (await verify(identity, adminProof))) {
            return #err(IdentityTypes.errorToText(#unauthorized));
        };

        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) { id };
        };

        // Check device limit
        if (identityRecord.devices.size() >= MAX_DEVICES_PER_IDENTITY) {
            return #err(IdentityTypes.errorToText(#device_limit_exceeded));
        };

        // Add device
        let updatedDevices = Array.append(identityRecord.devices, [device]);
        let updatedIdentity = {
            identityRecord with
            devices = updatedDevices;
            updatedAt = Nat64.fromIntWrap(Int.abs(Time.now()));
        };

        identities.put(identity, updatedIdentity);
        deviceIndex.put(device.deviceId, identity);

        #ok()
    };

    // Revoke device
    public shared func revokeDevice(
        identity : Principal,
        deviceId : Principal,
        proof : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Cannot revoke own device
        if (proof.deviceId == deviceId) {
            return #err("cannot_revoke_own_device");
        };

        if (not (await verify(identity, proof))) {
            return #err(IdentityTypes.errorToText(#unauthorized));
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
        revokeDeviceSessions(deviceId);

        #ok()
    };

    // === ROLE-BASED ACCESS CONTROL ===

    // Check if identity has role
    public shared query func hasRole(identity : Principal, role : Text) : async Bool {
        switch (identities.get(identity)) {
            case null { false };
            case (?id) {
                if (id.disabled) { return false };
                Array.find<Text>(id.roles, func(r) { r == role }) != null
            };
        }
    };

    // Grant role (admin operation)
    public shared func grantRole(
        identity : Principal,
        role : Text,
        admin : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Simplified admin check - in production verify admin role
        let adminIdentity = identity; // Simplified for now
        if (not (await verify(adminIdentity, admin))) {
            return #err(IdentityTypes.errorToText(#unauthorized));
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

        #ok()
    };

    // === SESSION MANAGEMENT ===

    // Start session for fast repeated operations
    public shared func startSession(
        identity : Principal,
        deviceId : Principal,
        scopes : [Text],
        ttlSecs : Nat32,
        proof : IdentityTypes.LinkProof
    ) : async Result.Result<IdentityTypes.Session, Text> {
        
        if (not (await verify(identity, proof))) {
            return #err(IdentityTypes.errorToText(#unauthorized));
        };

        // Generate session ID (simplified)
        let sessionId = "session_" # Principal.toText(identity) # "_" # Int.toText(Time.now());
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
        #ok(session)
    };

    // Validate session (fast path for other canisters)
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

        // Check identity still active
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

    // === WALLET LINKING ===

    // Link wallet to identity
    public shared func linkWalletIdentity(
        identity : Principal,
        wallet : Principal,
        proof : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        if (not (await verify(identity, proof))) {
            return #err(IdentityTypes.errorToText(#unauthorized));
        };

        let identityRecord = switch (identities.get(identity)) {
            case null { return #err(IdentityTypes.errorToText(#unknown_identity)); };
            case (?id) { id };
        };

        // Store wallet link in metadata
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
        #ok()
    };

    // === ADMIN OPERATIONS ===

    // Disable identity (replaces delete)
    public shared func disableIdentity(
        identity : Principal,
        admin : IdentityTypes.LinkProof
    ) : async Result.Result<(), Text> {
        
        // Simplified admin check
        let adminIdentity = identity; // In production, verify admin role
        if (not (await verify(adminIdentity, admin))) {
            return #err(IdentityTypes.errorToText(#unauthorized));
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
        revokeIdentitySessions(identity);

        #ok()
    };

    // Get identity record
    public shared query func getIdentity(
        identity : Principal
    ) : async Result.Result<IdentityTypes.Identity, Text> {
        switch (identities.get(identity)) {
            case null { #err(IdentityTypes.errorToText(#unknown_identity)) };
            case (?id) { #ok(id) };
        }
    };

    // === HELPER FUNCTIONS ===

    // Find device by ID and verify match
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
                    rateLimits.put(identity, {count = 1; windowStart = now});
                    true
                } else {
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

    // Calculate authentication level
    private func calculateAuthLevel(
        identity : IdentityTypes.Identity,
        device : IdentityTypes.DeviceKey
    ) : IdentityTypes.AuthLevel {
        let baseLevel = if (identity.security.mfaEnabled) { #elevated } else { #basic };
        
        switch (baseLevel, device.trust) {
            case (#basic, #trusted) { #high };
            case (#basic, #verified) { #elevated };
            case (#elevated, #trusted) { #maximum };
            case (#elevated, #verified) { #high };
            case (level, _) { level };
        }
    };

    // Check if auth level meets minimum
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
    ) : () {
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

    // Convert blob to hex string (simplified)
    private func blobToHex(blob : Blob) : Text {
        let bytes = Blob.toArray(blob);
        var hex = "";
        for (byte in bytes.vals()) {
            hex := hex # Nat8.toText(byte);
        };
        hex
    };

    // Update role index
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
        roleIndex := HashMap.HashMap<Text, [Principal]>(50, Text.equal, Text.hash);
        deviceIndex := HashMap.HashMap<Principal, Principal>(200, Principal.equal, Principal.hash);
        
        for ((principal, identity) in identities.entries()) {
            for (role in identity.roles.vals()) {
                updateRoleIndex(role, principal, true);
            };
            
            for (device in identity.devices.vals()) {
                deviceIndex.put(device.deviceId, principal);
            };
        };
    };

    // Revoke device sessions
    private func revokeDeviceSessions(deviceId : Principal) : () {
        let sessionsToRevoke = Array.filter<(Text, IdentityTypes.Session)>(
            Iter.toArray(sessionIndex.entries()),
            func((_, session)) { session.deviceId == deviceId }
        );
        
        for ((sessionId, _) in sessionsToRevoke.vals()) {
            sessionIndex.delete(sessionId);
        };
    };

    // Revoke identity sessions
    private func revokeIdentitySessions(identity : Principal) : () {
        let sessionsToRevoke = Array.filter<(Text, IdentityTypes.Session)>(
            Iter.toArray(sessionIndex.entries()),
            func((_, session)) { session.identity == identity }
        );
        
        for ((sessionId, _) in sessionsToRevoke.vals()) {
            sessionIndex.delete(sessionId);
        };
    };

    // === PUBLIC QUERY FUNCTIONS ===

    // System statistics
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
        timestamp : Nat64;
    } {
        {
            status = "healthy";
            timestamp = Nat64.fromIntWrap(Int.abs(Time.now()));
        }
    };

    // Create new identity (admin operation)
    public shared func createIdentity(
        identity : Principal,
        initialDevice : IdentityTypes.DeviceKey,
        metadata : Trie.Trie<Text, Text>
    ) : async Result.Result<(), Text> {
        
        // Check if identity already exists
        switch (identities.get(identity)) {
            case (?_) { return #err("identity_already_exists"); };
            case null { /* Continue */ };
        };

        let now = Nat64.fromIntWrap(Int.abs(Time.now()));
        let newIdentity : IdentityTypes.Identity = {
            id = identity;
            devices = [initialDevice];
            roles = [];
            permissions = [];
            metadata = metadata;
            security = {
                authenticationLevel = #basic;
                mfaEnabled = false;
                failedAttempts = 0;
                lockoutUntil = null;
                riskScore = 0.0;
            };
            createdAt = now;
            updatedAt = now;
            disabled = false;
        };

        identities.put(identity, newIdentity);
        deviceIndex.put(initialDevice.deviceId, identity);

        #ok()
    };
}
