//! Admin Types Module for Triad-Native Control Plane

import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Bool "mo:base/Bool";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";

module AdminTypes {
    public type RoleName = Text;          // "admin.security", "notify.admin", "gov.finalizer"
    public type Scope    = Text;          // granular permission, e.g. "payments.flags.write"

    public type Role = {
        name       : RoleName;
        scopes     : [Scope];
        canDelegate: Bool;
        description: Text;
    };

    public type Grant = {
        identity   : Principal;
        role       : RoleName;
        grantedBy  : Principal;
        expiresAt  : ?Nat64;                // unix ns, optional
        reason     : Text;
    };

    public type FlagValue = { 
        #bool : Bool; 
        #int : Int; 
        #text : Text; 
        #pct : Nat8 
    };

    public type Flag = {
        canisterModule : Text;              // "payments", "escrow", "ai_router", "notification"
        key        : Text;                  // "ai.enabled", "kill_switch"
        value      : FlagValue;
        conditions : ?[(Text, Text)];       // e.g., ("env","prod"), ("risk","low")
        version    : Nat;
        updatedAt  : Nat64;
        updatedBy  : Principal;
    };

    public type Config = {
        canisterModule : Text;
        key        : Text;                  // "latency.budget.ms"
        value      : Blob;                  // CBOR/JSON packed; schema id below
        schemaId   : Text;                  // e.g., "payments.v1"
        version    : Nat;
        updatedAt  : Nat64;
        updatedBy  : Principal;
    };

    public type EmergencyState = {
        canisterModule : Text;
        readOnly   : Bool;
        killSwitch : Bool;
        maxRps     : ?Nat;
        note       : ?Text;
        updatedAt  : Nat64;
        updatedBy  : Principal;
    };

    public type ProposalKind = { 
        #FlagChange : Flag; 
        #ConfigChange : Config; 
        #Emergency : EmergencyState; 
        #RoleGrant : Grant; 
        #RoleRevoke : { identity: Principal; role: RoleName } 
    };

    public type ProposalStatus = { 
        #Draft; 
        #PendingApproval; 
        #Approved; 
        #Rejected; 
        #Executed; 
        #RolledBack 
    };

    public type Proposal = {
        id         : Nat;
        kind       : ProposalKind;
        createdBy  : Principal;
        createdAt  : Nat64;
        status     : ProposalStatus;
        approvals  : [Principal];
        reason     : Text;
        corrId     : Text;
        expiresAt  : ?Nat64;
    };

    public type AuditEvent = {
        ts         : Nat64;
        actorPrincipal : Principal;
        corrId     : Text;
        action     : Text;                  // "flag.set", "role.grant", "emergency.enable"
        target     : Text;                  // "payments.ai.enabled", "identity:aaaa-bbbb..."
        before     : ?Blob;                 // CBOR snapshot
        after      : ?Blob;
        note       : ?Text;
    };
};
