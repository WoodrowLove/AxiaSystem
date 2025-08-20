//! Admin Canister Main - Simplified Working Version

import Result "mo:base/Result";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import Int "mo:base/Int";
import Iter "mo:base/Iter";

persistent actor Admin {
    type Result<T, E> = Result.Result<T, E>;
    
    // Simple role and permission system
    public type Role = {
        name: Text;
        scopes: [Text];
        description: Text;
    };

    public type Grant = {
        identity: Principal;
        role: Text;
        grantedBy: Principal;
        reason: Text;
    };

    public type Flag = {
        canisterModule: Text;
        key: Text;
        enabled: Bool;
        updatedAt: Nat64;
        updatedBy: Principal;
    };

    public type EmergencyState = {
        canisterModule: Text;
        killSwitch: Bool;
        readOnly: Bool;
        updatedAt: Nat64;
        updatedBy: Principal;
    };

    // Storage
    private var roleData: [(Text, Role)] = [];
    private var grantData: [(Text, Grant)] = [];
    private var flagData: [(Text, Flag)] = [];
    private var emergencyData: [(Text, EmergencyState)] = [];

    private transient var roles = HashMap.HashMap<Text, Role>(0, Text.equal, Text.hash);
    private transient var grants = HashMap.HashMap<Text, Grant>(0, Text.equal, Text.hash);
    private transient var flags = HashMap.HashMap<Text, Flag>(0, Text.equal, Text.hash);
    private transient var emergency = HashMap.HashMap<Text, EmergencyState>(0, Text.equal, Text.hash);

    // Upgrade hooks
    system func preupgrade() {
        roleData := roles.entries() |> Iter.toArray(_);
        grantData := grants.entries() |> Iter.toArray(_);
        flagData := flags.entries() |> Iter.toArray(_);
        emergencyData := emergency.entries() |> Iter.toArray(_);
    };

    system func postupgrade() {
        roles := HashMap.fromIter<Text, Role>(roleData.vals(), roleData.size(), Text.equal, Text.hash);
        grants := HashMap.fromIter<Text, Grant>(grantData.vals(), grantData.size(), Text.equal, Text.hash);
        flags := HashMap.fromIter<Text, Flag>(flagData.vals(), flagData.size(), Text.equal, Text.hash);
        emergency := HashMap.fromIter<Text, EmergencyState>(emergencyData.vals(), emergencyData.size(), Text.equal, Text.hash);
        
        roleData := [];
        grantData := [];
        flagData := [];
        emergencyData := [];
    };

    // Helper functions
    private func validateSession(_sessionId: Text, _requiredScope: Text, _caller: Principal): async Result<(), Text> {
        // TODO: Implement real validation with Identity canister
        #ok(())
    };

    // Role management
    public shared(msg) func defineRole(role: Role, sessionId: Text): async Result<(), Text> {
        switch (await validateSession(sessionId, "admin.roles.define", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok()) {
                roles.put(role.name, role);
                #ok(())
            };
        };
    };

    public shared(msg) func grantRole(grant: Grant, sessionId: Text): async Result<(), Text> {
        switch (await validateSession(sessionId, "admin.roles.grant", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok()) {
                let key = Principal.toText(grant.identity) # ":" # grant.role;
                grants.put(key, grant);
                #ok(())
            };
        };
    };

    public query func listRoles(): async [Role] {
        roles.vals() |> Iter.toArray(_);
    };

    // Feature flags
    public shared(msg) func setFlag(flag: Flag, sessionId: Text): async Result<(), Text> {
        switch (await validateSession(sessionId, "admin.flags.write", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok()) {
                let key = flag.canisterModule # "." # flag.key;
                let updatedFlag = {
                    flag with
                    updatedAt = Nat64.fromNat(Int.abs(Time.now()));
                    updatedBy = msg.caller;
                };
                flags.put(key, updatedFlag);
                #ok(())
            };
        };
    };

    public query func getFlag(canisterModule: Text, key: Text): async ?Flag {
        flags.get(canisterModule # "." # key);
    };

    // Emergency controls
    public shared(msg) func setEmergency(state: EmergencyState, sessionId: Text): async Result<(), Text> {
        switch (await validateSession(sessionId, "admin.emergency.write", msg.caller)) {
            case (#err(error)) { #err(error) };
            case (#ok()) {
                let updatedState = {
                    state with
                    updatedAt = Nat64.fromNat(Int.abs(Time.now()));
                    updatedBy = msg.caller;
                };
                emergency.put(state.canisterModule, updatedState);
                #ok(())
            };
        };
    };

    public query func getEmergency(canisterModule: Text): async ?EmergencyState {
        emergency.get(canisterModule);
    };

    // Health check
    public query func healthCheck(): async { status: Text; roles: Nat; flags: Nat; emergency: Nat } {
        {
            status = "healthy";
            roles = roles.size();
            flags = flags.size();
            emergency = emergency.size();
        }
    };

    // Bootstrap
    public shared(msg) func bootstrap(): async Result<(), Text> {
        if (roles.size() > 0) {
            return #err("already_bootstrapped");
        };

        let adminRole: Role = {
            name = "admin.security";
            scopes = ["admin.roles.grant", "admin.flags.write", "admin.emergency.write"];
            description = "System administrator";
        };

        roles.put("admin.security", adminRole);

        let adminGrant: Grant = {
            identity = msg.caller;
            role = "admin.security";
            grantedBy = msg.caller;
            reason = "Bootstrap initialization";
        };

        let grantKey = Principal.toText(msg.caller) # ":admin.security";
        grants.put(grantKey, adminGrant);

        #ok(())
    };
}
