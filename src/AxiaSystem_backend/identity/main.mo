import IdentityModule "../identity/modules/identity_module";
import SessionManager "./session_manager";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";
import Principal "mo:base/Principal";
import Trie "mo:base/Trie";
import Result "mo:base/Result";
import Text "mo:base/Text";
import _Array "mo:base/Array";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";

// 🧠 NamoraAI Observability Imports
import Insight "../types/insight";
import Time "mo:base/Time";
import Debug "mo:base/Debug";

persistent actor IdentityCanister {

    // 🧠 NamoraAI Observability Helper
    private func emitInsight(severity: Text, message: Text) : async () {
        let _insight : Insight.SystemInsight = {
            source = "identity";
            severity = severity;
            message = message;
            timestamp = Time.now();
        };
        Debug.print("🧠 IDENTITY INSIGHT [" # severity # "]: " # message);
        // await NamoraAI.pushInsight(insight);
    };

    private transient let eventManager = EventManager.EventManager();
    private transient let identityManager = IdentityModule.IdentityManager(eventManager);
    private transient let sessionManager = SessionManager.SessionManager();

    // Helper function to create a Trie from an array of key-value pairs
    func createTrie(entries: [(Text, Text)]) : Trie.Trie<Text, Text> {
        var trie = Trie.empty<Text, Text>();
        for ((k, v) in entries.vals()) {
            let key = { key = k; hash = Text.hash(k) };
            trie := Trie.put(trie, key, Text.equal, v).0;
        };
        trie
    };

    // Public API: Create a new identity
    public shared func createIdentity(userId: Principal, details: [(Text, Text)]): async Result.Result<IdentityModule.Identity, Text> {
        await emitInsight("info", "Identity creation initiated for user: " # Principal.toText(userId));
        
        let metadata = createTrie(details);
        let result = await identityManager.createIdentity(userId, metadata);
        
        switch (result) {
            case (#ok(_identity)) {
                await emitInsight("info", "Identity successfully created for user: " # Principal.toText(userId));
            };
            case (#err(error)) {
                await emitInsight("error", "Identity creation failed for user: " # Principal.toText(userId) # " - " # error);
            };
        };
        
        result
    };

    // Public API: Update an existing identity
    public func updateIdentity(userId: Principal, details: [(Text, Text)]): async Result.Result<IdentityModule.Identity, Text> {
        let metadata = createTrie(details);
        await identityManager.updateIdentity(userId, metadata);
    };

    // Public API: Delete an identity
    public func deleteIdentity(userId: Principal): async Result.Result<(), Text> {
        await identityManager.deleteIdentity(userId);
    };

    // Public API: Get an identity by user ID
    public func getIdentity(userId: Principal): async ?IdentityModule.Identity {
        await identityManager.getIdentity(userId);
    };

    // Public API: Get all identities
    public func getAllIdentities(): async [IdentityModule.Identity] {
        identityManager.getAllIdentities();
    };

    // Public API: Get stale identities
    public func getStaleIdentities(): async [IdentityModule.Identity] {
        await identityManager.getStaleIdentities();
    };

    // Public API: Find an identity by metadata
    public func findIdentityByMetadata(key: Text, value: Text): async ?IdentityModule.Identity {
        await identityManager.findIdentityByMetadata(key, value);
    };

    // Public API: Batch update metadata for multiple identities
    public func batchUpdateMetadata(updates: [(Principal, Text, Text)]): async Result.Result<(), Text> {
        await identityManager.batchUpdateMetadata(updates);
    };

    // Public API: Search identities by metadata
    public func searchIdentitiesByMetadata(key: Text, value: Text): async [IdentityModule.Identity] {
        await identityManager.searchIdentitiesByMetadata(key, value);
    };

    // Public API: Export all identities
    public func exportAllIdentities(): async Text {
        await identityManager.exportAllIdentities();
    };

    // Public API: Trigger heartbeat for stale identity cleanup
    public func runHeartbeat(): async () {
        await identityManager.runHeartbeat();
    };

    // Public API: Add a device key to an identity
    public func addDeviceKey(userId: Principal, newDeviceKey: Principal): async Result.Result<(), Text> {
        await identityManager.addDeviceKey(userId, newDeviceKey);
    };

    // Event subscription for debugging and monitoring
    public func subscribeToEvents(eventType: EventTypes.EventType, listener: shared EventTypes.Event -> async ()): async () {
        await eventManager.subscribe(eventType, listener);
    };

    // Debug API: List all subscribed event types
    public func listSubscribedEventTypes(): async [EventTypes.EventType] {
        await eventManager.listSubscribedEventTypes();
    };

    public func isUserRegistered(userId: Principal) : async Bool {
        await identityManager.isUserRegistered(userId);
    };

    // NEW: Ensure identity exists, create if it doesn't
    public func ensureIdentity(userId: Principal): async Result.Result<IdentityModule.Identity, Text> {
        await emitInsight("info", "Ensuring identity for user: " # Principal.toText(userId));
        
        let result = await identityManager.ensureIdentity(userId);
        
        switch (result) {
            case (#ok(_identity)) {
                await emitInsight("info", "Identity ensured for user: " # Principal.toText(userId));
            };
            case (#err(error)) {
                await emitInsight("error", "Identity ensure failed for user: " # Principal.toText(userId) # " - " # error);
            };
        };
        
        result
    };

    // === SESSION MANAGEMENT ===

    // Register a device for session management
    public shared func registerDevice(
        identityId: Principal,
        deviceId: Principal,
        deviceType: Text,
        attestation: ?Blob
    ): async Result.Result<SessionManager.DeviceInfo, SessionManager.SessionError> {
        await emitInsight("info", "Device registration for identity: " # Principal.toText(identityId) # ", device: " # Principal.toText(deviceId));
        
        // Verify identity exists
        switch (await identityManager.getIdentity(identityId)) {
            case null {
                await emitInsight("error", "Device registration failed: Identity not found: " # Principal.toText(identityId));
                #err(#identity_not_found)
            };
            case (?_identity) {
                let result = await sessionManager.registerDevice(identityId, deviceId, deviceType, attestation);
                switch (result) {
                    case (#ok(deviceInfo)) {
                        await emitInsight("info", "Device registered successfully: " # Principal.toText(deviceId));
                        #ok(deviceInfo)
                    };
                    case (#err(error)) {
                        await emitInsight("error", "Device registration failed: " # debug_show(error));
                        #err(error)
                    };
                }
            };
        }
    };

    // Start a new session
    public shared func startSession(
        identityId: Principal,
        deviceId: Principal,
        scopes: [SessionManager.SessionScope],
        durationSecs: Nat32,
        correlationId: Text,
        deviceProof: ?Blob,
        context: ?{ ipAddress: Text; userAgent: Text }
    ): async Result.Result<SessionManager.Session, SessionManager.SessionError> {
        await emitInsight("info", "Session start request for identity: " # Principal.toText(identityId) # ", correlation: " # correlationId);
        
        // Verify identity exists
        switch (await identityManager.getIdentity(identityId)) {
            case null {
                await emitInsight("error", "Session start failed: Identity not found: " # Principal.toText(identityId));
                #err(#identity_not_found)
            };
            case (?_identity) {
                let request: SessionManager.SessionRequest = {
                    identityId = identityId;
                    deviceId = deviceId;
                    scopes = scopes;
                    durationSecs = durationSecs;
                    correlationId = correlationId;
                    deviceProof = deviceProof;
                    context = context;
                };
                
                let result = await sessionManager.createSession(request);
                switch (result) {
                    case (#ok(session)) {
                        await emitInsight("info", "Session created successfully: " # session.sessionId # " for identity: " # Principal.toText(identityId));
                        #ok(session)
                    };
                    case (#err(error)) {
                        await emitInsight("error", "Session creation failed: " # debug_show(error));
                        #err(error)
                    };
                }
            };
        }
    };

    // Validate an existing session
    public shared func validateSession(
        sessionId: Text,
        requiredScopes: [SessionManager.SessionScope]
    ): async SessionManager.SessionValidation {
        let validation = await sessionManager.validateSession(sessionId, requiredScopes);
        
        let logLevel = if (validation.valid) { "info" } else { "warning" };
        let message = if (validation.valid) {
            "Session validated successfully: " # sessionId
        } else {
            "Session validation failed: " # sessionId # " - " # (switch (validation.reason) { case (?r) r; case null "unknown" })
        };
        
        await emitInsight(logLevel, message);
        validation
    };

    // Revoke a specific session
    public shared func revokeSession(sessionId: Text): async Result.Result<(), SessionManager.SessionError> {
        await emitInsight("warning", "Session revocation requested: " # sessionId);
        
        let result = await sessionManager.revokeSession(sessionId);
        switch (result) {
            case (#ok(_)) {
                await emitInsight("info", "Session revoked successfully: " # sessionId);
            };
            case (#err(error)) {
                await emitInsight("error", "Session revocation failed: " # debug_show(error));
            };
        };
        result
    };

    // Revoke all sessions for an identity
    public shared func revokeAllSessions(identityId: Principal): async Result.Result<Nat, SessionManager.SessionError> {
        await emitInsight("warning", "All sessions revocation requested for identity: " # Principal.toText(identityId));
        
        let result = await sessionManager.revokeAllSessions(identityId);
        switch (result) {
            case (#ok(count)) {
                await emitInsight("info", "All sessions revoked for identity: " # Principal.toText(identityId) # " (count: " # debug_show(count) # ")");
            };
            case (#err(error)) {
                await emitInsight("error", "Session revocation failed: " # debug_show(error));
            };
        };
        result
    };

    // Get active sessions for an identity
    public shared func getActiveSessions(identityId: Principal): async [SessionManager.Session] {
        await sessionManager.getActiveSessions(identityId)
    };

    // Get session statistics
    public shared func getSessionStats(): async {
        totalSessions: Nat;
        activeSessions: Nat;
        expiredSessions: Nat;
        revokedSessions: Nat;
        devicesRegistered: Nat;
        averageRiskScore: Float;
    } {
        await sessionManager.getSessionStats()
    };

    // Cleanup expired sessions (admin function)
    public shared func cleanupExpiredSessions(): async Nat {
        await emitInsight("info", "Cleaning up expired sessions");
        let cleanedCount = await sessionManager.cleanupExpiredSessions();
        await emitInsight("info", "Session cleanup completed: " # debug_show(cleanedCount) # " sessions removed");
        cleanedCount
    };
};