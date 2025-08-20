//! Admin Canister Main Entry Point - Triad-Native Control Plane

import Result "mo:base/Result";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";
import Bool "mo:base/Bool";
import Int "mo:base/Int";
import Iter "mo:base/Iter";

persistent actor Admin {
    type Result<T, E> = Result.Result<T, E>;
    
    // Core data types
    public type RoleName = Text;
    public type Scope = Text;

    public type Role = {
        name: RoleName;
        scopes: [Scope];
        canDelegate: Bool;
        description: Text;
    };

    public type Grant = {
        identity: Principal;
        role: RoleName;
        grantedBy: Principal;
        expiresAt: ?Nat64;
        reason: Text;
    };

    public type FlagValue = { 
        #bool: Bool; 
        #int: Int; 
        #text: Text; 
        #pct: Nat8 
    };

    public type Flag = {
        canisterModule: Text;
        key: Text;
        value: FlagValue;
        conditions: ?[(Text, Text)];
        version: Nat;
        updatedAt: Nat64;
        updatedBy: Principal;
    };

    public type Config = {
        canisterModule: Text;
        key: Text;
        value: Blob;
        schemaId: Text;
        version: Nat;
        updatedAt: Nat64;
        updatedBy: Principal;
    };

    public type EmergencyState = {
        canisterModule: Text;
        readOnly: Bool;
        killSwitch: Bool;
        maxRps: ?Nat;
        note: ?Text;
        updatedAt: Nat64;
        updatedBy: Principal;
    };

    public type AuditEvent = {
        ts: Nat64;
        actorPrincipal: Principal;
        corrId: Text;
        action: Text;
        target: Text;
        before: ?Blob;
        after: ?Blob;
        note: ?Text;
    };

    // Stable storage
    private var roleDefinitions: [(Text, Role)] = [];
    private var roleGrants: [(Text, Grant)] = [];
    private var featureFlags: [(Text, Flag)] = [];
    private var configurations: [(Text, Config)] = [];
    private var emergencyStates: [(Text, EmergencyState)] = [];
    private var auditEvents: [AuditEvent] = [];

    // Runtime storage
    private transient var roles = HashMap.HashMap<Text, Role>(0, Text.equal, Text.hash);
    private transient var grants = HashMap.HashMap<Text, Grant>(0, Text.equal, Text.hash);
    private transient var flags = HashMap.HashMap<Text, Flag>(0, Text.equal, Text.hash);
    private transient var configs = HashMap.HashMap<Text, Config>(0, Text.equal, Text.hash);
    private transient var emergency = HashMap.HashMap<Text, EmergencyState>(0, Text.equal, Text.hash);
    private transient var auditLog = Buffer.Buffer<AuditEvent>(0);

    // System initialization
    system func preupgrade() {
        roleDefinitions := roles.entries() |> Iter.toArray(_);
        roleGrants := grants.entries() |> Iter.toArray(_);
        featureFlags := flags.entries() |> Iter.toArray(_);
        configurations := configs.entries() |> Iter.toArray(_);
        emergencyStates := emergency.entries() |> Iter.toArray(_);
        auditEvents := Buffer.toArray(auditLog);
    };

    system func postupgrade() {
        roles := HashMap.fromIter<Text, Role>(
            roleDefinitions.vals(), 
            roleDefinitions.size(), 
            Text.equal, 
            Text.hash
        );
        grants := HashMap.fromIter<Text, Grant>(
            roleGrants.vals(), 
            roleGrants.size(), 
            Text.equal, 
            Text.hash
        );
        flags := HashMap.fromIter<Text, Flag>(
            featureFlags.vals(), 
            featureFlags.size(), 
            Text.equal, 
            Text.hash
        );
        configs := HashMap.fromIter<Text, Config>(
            configurations.vals(), 
            configurations.size(), 
            Text.equal, 
            Text.hash
        );
        emergency := HashMap.fromIter<Text, EmergencyState>(
            emergencyStates.vals(), 
            emergencyStates.size(), 
            Text.equal, 
            Text.hash
        );
        
        auditLog := Buffer.Buffer<AuditEvent>(auditEvents.size());
        for (event in auditEvents.vals()) {
            auditLog.add(event);
        };
        
        // Clear stable storage
        roleDefinitions := [];
        roleGrants := [];
        featureFlags := [];
        configurations := [];
        emergencyStates := [];
        auditEvents := [];
    };

    // Helper functions
    private func logAudit(actorPrincipal: Principal, corrId: Text, action: Text, target: Text, before: ?Blob, after: ?Blob, note: ?Text) {
        let event: AuditEvent = {
            ts = Nat64.fromNat(Int.abs(Time.now()));
            actorPrincipal = actorPrincipal;
            corrId = corrId;
            action = action;
            target = target;
            before = before;
            after = after;
            note = note;
        };
        auditLog.add(event);
    };

    private func generateCorrelationId(): Text {
        "admin_" # Nat.toText(Nat64.toNat(Nat64.fromNat(Int.abs(Time.now()))));
    };

    // Identity Canister Integration
    private let IDENTITY_CANISTER_ID = "asrmz-lmaaa-aaaaa-qaaeq-cai";
    
    // Types from Identity System
    public type SessionValidation = {
        valid : Bool;
        identity : Principal;
        deviceId : Principal;
        expiresAt : Nat64;
    };

    private func validateSession(sessionId: Text, requiredScope: Text, caller: Principal): async Result<Principal, Text> {
        // Allow bootstrap calls without session validation
        if (roles.size() == 0 and requiredScope == "admin.bootstrap") {
            return #ok(caller);
        };
        
        // Call Identity Canister to validate session and check scopes
        let identityCanister = actor(IDENTITY_CANISTER_ID) : actor {
            validateSession : (Text, Text) -> async Result<SessionValidation, Text>;
        };
        
        try {
            let result = await identityCanister.validateSession(sessionId, requiredScope);
            switch (result) {
                case (#ok(validation)) {
                    if (validation.valid and Principal.equal(validation.identity, caller)) {
                        #ok(caller)
                    } else {
                        #err("session_validation_failed")
                    }
                };
                case (#err(error)) {
                    #err("identity_canister_error: " # error)
                };
            };
        } catch (_e) {
            #err("identity_canister_call_failed")
        };
    };

    // RBAC Directory Methods
    public shared(msg) func defineRole(role: Role, sessionId: Text): async Result<(), Text> {
        let corrId = generateCorrelationId();
        
        switch (await validateSession(sessionId, "admin.roles.define", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok(actorPrincipal)) {
                let key = role.name;
                let before = switch (roles.get(key)) {
                    case (?existing) { ?Text.encodeUtf8(existing.name # ":" # existing.description) };
                    case null { null };
                };
                
                roles.put(key, role);
                
                let after = ?Text.encodeUtf8(role.name # ":" # role.description);
                logAudit(actorPrincipal, corrId, "role.define", key, before, after, null);
                
                #ok(())
            };
        };
    };

    public shared(msg) func grantRole(grant: Grant, sessionId: Text): async Result<(), Text> {
        let corrId = generateCorrelationId();
        
        switch (await validateSession(sessionId, "admin.roles.grant", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok(actorPrincipal)) {
                // Check if role exists
                switch (roles.get(grant.role)) {
                    case (null) { #err("role_not_found: " # grant.role) };
                    case (?_role) {
                        let key = Principal.toText(grant.identity) # ":" # grant.role;
                        
                        let before = switch (grants.get(key)) {
                            case (?existing) { ?Text.encodeUtf8("granted_by:" # Principal.toText(existing.grantedBy)) };
                            case null { null };
                        };
                        
                        grants.put(key, grant);
                        
                        let after = ?Text.encodeUtf8("granted_by:" # Principal.toText(grant.grantedBy));
                        logAudit(actorPrincipal, corrId, "role.grant", key, before, after, ?grant.reason);
                        
                        #ok(())
                    };
                };
            };
        };
    };

    public shared(msg) func revokeRole(identity: Principal, roleName: RoleName, sessionId: Text): async Result<(), Text> {
        let corrId = generateCorrelationId();
        
        switch (await validateSession(sessionId, "admin.roles.revoke", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok(actorPrincipal)) {
                let key = Principal.toText(identity) # ":" # roleName;
                
                switch (grants.remove(key)) {
                    case (null) { #err("grant_not_found") };
                    case (?removed) {
                        let before = ?Text.encodeUtf8("granted_by:" # Principal.toText(removed.grantedBy));
                        logAudit(actorPrincipal, corrId, "role.revoke", key, before, null, null);
                        #ok(())
                    };
                };
            };
        };
    };

    public query func listRoles(): async [Role] {
        roles.vals() |> Iter.toArray(_);
    };

    public query func listGrants(identity: Principal): async [Grant] {
        let identityText = Principal.toText(identity);
        grants.vals()
        |> Iter.filter(_, func (grant: Grant): Bool {
            Principal.toText(grant.identity) == identityText
        })
        |> Iter.toArray(_);
    };

    // Feature Flags Methods
    public shared(msg) func setFlag(flag: Flag, sessionId: Text): async Result<Flag, Text> {
        let corrId = generateCorrelationId();
        
        switch (await validateSession(sessionId, "admin.flags.write", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok(actorPrincipal)) {
                let key = flag.canisterModule # "." # flag.key;
                
                let before = switch (flags.get(key)) {
                    case (?existing) { 
                        switch (existing.value) {
                            case (#bool(b)) { ?Text.encodeUtf8("bool:" # Bool.toText(b)) };
                            case (#int(i)) { ?Text.encodeUtf8("int:" # Int.toText(i)) };
                            case (#text(t)) { ?Text.encodeUtf8("text:" # t) };
                            case (#pct(p)) { ?Text.encodeUtf8("pct:" # Nat.toText(Nat8.toNat(p))) };
                        };
                    };
                    case null { null };
                };
                
                let updatedFlag = {
                    flag with
                    version = switch (flags.get(key)) {
                        case (?existing) { existing.version + 1 };
                        case null { 1 };
                    };
                    updatedAt = Nat64.fromNat(Int.abs(Time.now()));
                    updatedBy = actorPrincipal;
                };
                
                flags.put(key, updatedFlag);
                
                let after = switch (updatedFlag.value) {
                    case (#bool(b)) { ?Text.encodeUtf8("bool:" # Bool.toText(b)) };
                    case (#int(i)) { ?Text.encodeUtf8("int:" # Int.toText(i)) };
                    case (#text(t)) { ?Text.encodeUtf8("text:" # t) };
                    case (#pct(p)) { ?Text.encodeUtf8("pct:" # Nat.toText(Nat8.toNat(p))) };
                };
                
                logAudit(actorPrincipal, corrId, "flag.set", key, before, after, null);
                
                #ok(updatedFlag)
            };
        };
    };

    public query func getFlag(canisterModule: Text, key: Text): async ?Flag {
        flags.get(canisterModule # "." # key);
    };

    // Configuration Methods
    public shared(msg) func setConfig(cfg: Config, sessionId: Text): async Result<Config, Text> {
        let corrId = generateCorrelationId();
        
        switch (await validateSession(sessionId, "admin.config.write", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok(actorPrincipal)) {
                let key = cfg.canisterModule # "." # cfg.key;
                
                let before = switch (configs.get(key)) {
                    case (?existing) { ?existing.value };
                    case null { null };
                };
                
                let updatedConfig = {
                    cfg with
                    version = switch (configs.get(key)) {
                        case (?existing) { existing.version + 1 };
                        case null { 1 };
                    };
                    updatedAt = Nat64.fromNat(Int.abs(Time.now()));
                    updatedBy = actorPrincipal;
                };
                
                configs.put(key, updatedConfig);
                
                logAudit(actorPrincipal, corrId, "config.set", key, before, ?updatedConfig.value, null);
                
                #ok(updatedConfig)
            };
        };
    };

    public query func getConfig(canisterModule: Text, key: Text): async ?Config {
        configs.get(canisterModule # "." # key);
    };

    // Emergency Controls Methods
    public shared(msg) func setEmergency(state: EmergencyState, sessionId: Text): async Result<EmergencyState, Text> {
        let corrId = generateCorrelationId();
        
        switch (await validateSession(sessionId, "admin.emergency.write", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok(actorPrincipal)) {
                let key = state.canisterModule;
                
                let before = switch (emergency.get(key)) {
                    case (?existing) { 
                        ?Text.encodeUtf8("kill:" # Bool.toText(existing.killSwitch) # ",ro:" # Bool.toText(existing.readOnly));
                    };
                    case null { null };
                };
                
                let updatedState = {
                    state with
                    updatedAt = Nat64.fromNat(Int.abs(Time.now()));
                    updatedBy = actorPrincipal;
                };
                
                emergency.put(key, updatedState);
                
                let after = ?Text.encodeUtf8("kill:" # Bool.toText(updatedState.killSwitch) # ",ro:" # Bool.toText(updatedState.readOnly));
                logAudit(actorPrincipal, corrId, "emergency.set", key, before, after, updatedState.note);
                
                #ok(updatedState)
            };
        };
    };

    public query func getEmergency(canisterModule: Text): async ?EmergencyState {
        emergency.get(canisterModule);
    };

    // Audit Methods
    public query func tailAudit(limit: Nat): async [AuditEvent] {
        let events = Buffer.toArray(auditLog);
        let size = events.size();
        if (size <= limit) {
            events
        } else {
            Array.tabulate<AuditEvent>(limit, func(i: Nat): AuditEvent {
                events[size - limit + i]
            })
        }
    };

    // Health and status endpoints
    public query func healthCheck(): async { 
        status: Text; 
        uptime: Nat64; 
        auditEntries: Nat; 
        roles: Nat; 
        flags: Nat; 
        configs: Nat 
    } {
        {
            status = "healthy";
            uptime = Nat64.fromNat(Int.abs(Time.now()));
            auditEntries = auditLog.size();
            roles = roles.size();
            flags = flags.size();
            configs = configs.size();
        }
    };

    // Bootstrap method for initial setup (no session required)
    public shared(msg) func bootstrap(): async Result<(), Text> {
        // Only allow bootstrap if no roles exist yet
        if (roles.size() > 0) {
            return #err("already_bootstrapped");
        };

        // Use special bootstrap validation 
        switch (await validateSession("", "admin.bootstrap", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok(actorPrincipal)) {
                // Create foundational roles
                let adminSecurityRole: Role = {
                    name = "admin.security";
                    scopes = [
                        "admin.emergency.write",
                        "admin.roles.grant",
                        "admin.flags.write",
                        "admin.audit.read"
                    ];
                    canDelegate = false;
                    description = "Security administration role with emergency controls";
                };

                let adminOpsRole: Role = {
                    name = "admin.ops";
                    scopes = [
                        "admin.flags.write",
                        "admin.config.write",
                        "admin.audit.read"
                    ];
                    canDelegate = false;
                    description = "Operations administration for flags and configuration";
                };

                let aiAdminRole: Role = {
                    name = "ai.admin";
                    scopes = [
                        "ai_router.config.write",
                        "ai_router.emergency.write",
                        "ai_router.quota.write"
                    ];
                    canDelegate = false;
                    description = "AI Router administration";
                };

                let paymentsAdminRole: Role = {
                    name = "payments.admin";
                    scopes = [
                        "payments.config.write",
                        "payments.emergency.write",
                        "payments.limits.write"
                    ];
                    canDelegate = false;
                    description = "Payments system administration";
                };

                // Store roles
                roles.put("admin.security", adminSecurityRole);
                roles.put("admin.ops", adminOpsRole);
                roles.put("ai.admin", aiAdminRole);
                roles.put("payments.admin", paymentsAdminRole);

                // Grant admin.security role to bootstrap caller
                let adminGrant: Grant = {
                    identity = msg.caller;
                    role = "admin.security";
                    grantedBy = msg.caller;
                    expiresAt = null;
                    reason = "Bootstrap initialization";
                };

                let key = Principal.toText(msg.caller) # ":admin.security";
                grants.put(key, adminGrant);

                // Log bootstrap event
                logAudit(actorPrincipal, generateCorrelationId(), "system.bootstrap", "admin_canister", null, null, ?"System initialized with foundational roles");

                #ok(())
            };
        };
    };
}
