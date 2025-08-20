# 🛡️ Admin Canister — Triad-Native Control Plane

**Date**: December 2024  
**Status**: ✅ **IMPLEMENTATION READY**  
**Integration**: **Complete Triad-Native Control Plane**

---

## 🎯 **Goal**

Centralize roles, feature flags, config, allowlists, and emergency controls for all canisters (User, Identity, Wallet, Payments, Escrow, AI Router, Notification, etc.) while keeping business logic out. Admin enforces who can change what, when, and how it's audited.

---

## 🏗️ **0) Principles**

- **Triad-native**: All admin actions are anchored to Identity (not ad-hoc principals)
- **Deterministic & auditable**: Every change is logged with actor, diff, reason, and correlation ID
- **Separation of concerns**: Admin sets policy and config, modules execute business logic
- **Least privilege**: Fine-grained scopes; short-lived sessions; time-boxed delegations
- **Governance-aware**: High-risk changes require Governance approval or multi-sig

---

## 📊 **1) Scope & Responsibilities**

### **Owns**
- **RBAC Directory**: role definitions, grants, expirations
- **Feature Flags**: per-module, per-environment, with rollout % and conditions
- **Config Registry**: typed, versioned settings (thresholds, URLs, cron specs)
- **Allow/deny Lists**: service principals, canister principals, IP/ASN policies (if applicable)
- **Emergency Controls**: kill switches, rate-limit overrides, read-only modes
- **Change Proposals**: optional 2-step approve/execute, or Governance binding
- **Audit Trail**: append-only logs; integrity checked; 7-year retention metadata

### **Explicitly does not own**
- Funds movement, balance math, escrow release logic, voting tallies, etc. (Business canisters stay deterministic and independent)

---

## 🔧 **2) Data Model (stable types)**

```motoko
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

  public type Flag = {
    module     : Text;                  // "payments", "escrow", "ai_router", "notification"
    key        : Text;                  // "ai.enabled", "kill_switch"
    value      : { #bool : Bool; #int : Int; #text : Text; #pct : Nat8 };
    conditions : ?[(Text, Text)];       // e.g., ("env","prod"), ("risk","low")
    version    : Nat;
    updatedAt  : Nat64;
    updatedBy  : Principal;
  };

  public type Config = {
    module     : Text;
    key        : Text;                  // "latency.budget.ms"
    value      : Blob;                  // CBOR/JSON packed; schema id below
    schemaId   : Text;                  // e.g., "payments.v1"
    version    : Nat;
    updatedAt  : Nat64;
    updatedBy  : Principal;
  };

  public type EmergencyState = {
    module     : Text;
    readOnly   : Bool;
    killSwitch : Bool;
    maxRps     : ?Nat;
    note       : ?Text;
    updatedAt  : Nat64;
    updatedBy  : Principal;
  };

  public type Proposal = {
    id         : Nat;
    kind       : { #FlagChange : Flag; #ConfigChange : Config; #Emergency : EmergencyState; #RoleGrant : Grant; #RoleRevoke : { identity: Principal; role: RoleName } };
    createdBy  : Principal;
    createdAt  : Nat64;
    status     : { #Draft; #PendingApproval; #Approved; #Rejected; #Executed; #RolledBack };
    approvals  : [Principal];
    reason     : Text;
    corrId     : Text;
    expiresAt  : ?Nat64;
  };

  public type AuditEvent = {
    ts         : Nat64;
    actor      : Principal;
    corrId     : Text;
    action     : Text;                  // "flag.set", "role.grant", "emergency.enable"
    target     : Text;                  // "payments.ai.enabled", "identity:aaaa-bbbb..."
    before     : ?Blob;                 // CBOR snapshot
    after      : ?Blob;
    note       : ?Text;
  };
}
```

---

## 🔗 **3) Public API (Candid)**

```motoko
actor Admin {

  // --- RBAC directory
  public shared func defineRole(role : AdminTypes.Role, sessionId : Text) : async Result.Result<(), Text>;
  public shared func grantRole(grant : AdminTypes.Grant, sessionId : Text) : async Result.Result<(), Text>;
  public shared func revokeRole(identity : Principal, role : AdminTypes.RoleName, sessionId : Text) : async Result.Result<(), Text>;
  public query  func listRoles() : async [AdminTypes.Role];
  public query  func listGrants(identity : Principal) : async [AdminTypes.Grant];

  // --- Flags & config
  public shared func setFlag(flag : AdminTypes.Flag, sessionId : Text) : async Result.Result<AdminTypes.Flag, Text>;
  public query  func getFlag(module : Text, key : Text) : async ?AdminTypes.Flag;

  public shared func setConfig(cfg : AdminTypes.Config, sessionId : Text) : async Result.Result<AdminTypes.Config, Text>;
  public query  func getConfig(module : Text, key : Text) : async ?AdminTypes.Config;

  // --- Emergency controls
  public shared func setEmergency(state : AdminTypes.EmergencyState, sessionId : Text) : async Result.Result<AdminTypes.EmergencyState, Text>;
  public query  func getEmergency(module : Text) : async ?AdminTypes.EmergencyState;

  // --- Proposals (optional two-step)
  public shared func createProposal(p : AdminTypes.Proposal, sessionId : Text) : async Result.Result<Nat, Text>;
  public shared func approveProposal(id : Nat, sessionId : Text) : async Result.Result<(), Text>;
  public shared func executeProposal(id : Nat, sessionId : Text) : async Result.Result<(), Text>;
  public query  func getProposal(id : Nat) : async ?AdminTypes.Proposal;

  // --- Audit
  public query func tailAudit(limit : Nat) : async [AdminTypes.AuditEvent];
}
```

**Auth**: Every shared call requires a valid Identity session and checks scopes (e.g., admin.flags.write, admin.roles.grant, admin.emergency.write).

**High-risk operations** require either:
- one of: gov.finalizer role, or
- quorum approvals via create/approve/executeProposal, or
- binding Governance Canister callback (see §7)

---

## 🔌 **4) How other canisters integrate**

### **1. Runtime reads (fast path):**
- Cache getFlag/getConfig in each canister with TTL (e.g., 30–120s)
- On Admin.change event (see §6), modules can preemptively refresh

### **2. Enforcement examples**
- **Payments** checks payments.kill_switch before processing; if true → reject with deterministic error
- **AI Router** reads ai_router.latency_budget_ms, ai_router.quota_per_identity
- **Notification** reads notification.default_quiet_hours, escalation roles

### **3. Roles**
- Business canisters do not grant roles; they query Identity.hasRole or Admin.listGrants to authorize sensitive endpoints (e.g., approvals, treasury ops)

---

## 🛡️ **5) Security model**

- **Sessions & scopes** via Identity Canister (admin:* scopes)
- **Least privilege**: break large powers into narrow scopes:
  - admin.flags.write, admin.config.write, admin.emergency.write, admin.roles.grant, admin.roles.revoke, admin.proposal.*
- **Time-boxed grants**: every grant may have expiresAt
- **Two-person rule** for critical toggles: proposals with N-of-M approvals
- **Audit immutability**: append-only log; hashed daily segment anchors; 7-year metadata retention
- **Rate limits**: throttle admin-writes; prevent flapping flags

---

## 📡 **6) Events (system-wide)**

Admin emits to EventHub with Triad envelope:
- admin.role.defined|granted|revoked
- admin.flag.set
- admin.config.set
- admin.emergency.set
- admin.proposal.created|approved|executed|rolledback
- admin.audit.anchor (periodic integrity anchor)

Downstream canisters subscribe or poll to refresh caches.

---

## 🏛️ **7) Governance linkage (optional but recommended)**

- For **Class-A changes** (e.g., treasury limits, governance parameters), Admin's executeProposal must call Governance Canister to confirm proposal passed (or require gov.finalizer signature)
- If Governance down: return deterministic "governance_unavailable"; do not execute

---

## 🚀 **8) Migration & Bootstrap**

### **Step 1**: Deploy Admin after Identity is live

### **Step 2**: Seed base roles:
- **admin.security** → scopes: admin.emergency.write, admin.roles.grant (limited), admin.flags.write
- **admin.ops** → admin.flags.write, admin.config.write
- **notify.admin**, **ai.admin**, **payments.admin** (module-scoped)
- **gov.finalizer** (if used) defined here but granted by Governance

### **Step 3**: Move ad-hoc env vars into Config entries (with schema ids)

### **Step 4**: Replace in-code toggles with Flags

### **Step 5**: Add emergency checks in Payments/Escrow/AI Router

---

## 💻 **9) Minimal enforcement stubs (drop-in)**

### **Payments canister guard:**
```motoko
let ks = await Admin.getEmergency("payments");
if (Option.isSome(ks) and Option.get(ks).killSwitch) {
  return #err("payments_disabled_by_admin");
}

switch (await Admin.getFlag("payments","ai.enabled")) {
  case (?{ value = #bool(true); _ }) { /* call AI Router */ };
  case _ { /* skip AI */ };
};
```

### **AI Router quotas:**
```motoko
let cfg = await Admin.getConfig("ai_router","quota.per_identity");
let perId = decodeNat(cfg?.value);
if (exceedsQuota(identity, perId)) return #err("rate_limited");
```

### **Notification escalation role expansion:**
```motoko
// Admin defines role "notify.escalation". Notification resolves identities by role via Identity.hasRole
```

---

## ⚠️ **10) Failure modes & mitigations**

- **Admin unavailable**: Modules fall back to last cached flags/config within TTL; emergencies default to safe (treat unknown as disabled for kill-switch-gated paths)
- **Flag flapping**: write rate limits + minimal cool-down; proposals preferred
- **Compromised admin account**: short-lived sessions, device attestation, MFA; Admin can enforce two-person rule on high-risk scopes
- **Clock skew**: rely on canister time; avoid absolute deadlines in proposals without safety buffer

---

## 📅 **11) Phased rollout (quick)**

### **Phase A (1–2 weeks) — Core control plane**
- Implement: roles/grants; flags; config; audit; read caching in Payments/Escrow/AI Router
- Wire emergency checks & kill switches
- Seed initial roles (you + Namora AI service principal)

### **Phase B (1 week) — Governance binding & proposals**
- Add 2-step proposals for Class-A items; link Governance approve → execute
- Enforce N-of-M for admin.emergency.write in prod

### **Phase C (1 week) — Notification dependencies**
- Add module configs: notification.default_quiet_hours, escalation role name, digest cron
- Notification canister consumes Admin for prefs defaults & role expansion
- Ship Notification after Admin is stable

---

## 📊 **12) SLOs & Acceptance**

- **Admin read** p95 < 50 ms; **write** p95 < 150 ms
- **Cache freshness** < 120 s or event-triggered refresh
- **Audit completeness** 100%; daily anchor produced
- **Two-person rule** enforced on designated scopes in prod

### **Exit criteria to start Notification build**
- Flags/config for Notification present; roles notify.admin and notify.sender defined; emergency hooks working; audit tail shows test changes

---

## 🎯 **13) What to build first (tickets)**

- **ADM-001** DefineRole/Grant/Revoke + scopes + tests
- **ADM-002** Flags API + versioning + TTL cache example client
- **ADM-003** Config API (+ schemaId, CBOR value) + size limits
- **ADM-004** Emergency API + module guards in Payments/Escrow/AI Router
- **ADM-005** Audit log (append-only), daily anchor job
- **ADM-006** Proposals (create/approve/execute) + Governance hook (optional)
- **ADM-007** SDK helpers for consumers (read-through cache, event listener)

---

## 🚀 **Recommendation on order**

1. **Build & deploy Admin now** (Phase A)
2. **Wire Payments/Escrow/AI Router** to read flags/config + honor kill-switch
3. **(Optional) Add Governance binding** for critical operations (Phase B)
4. **Then implement the Notification canister**, reading defaults/roles from Admin (Phase C)

This sequence gives you a single, auditable switchboard before you introduce messaging and approvals—safer, cleaner, and easier to operate.

---

## 🔗 **Integration with Existing AxiaSystem**

### **Triad Architecture Alignment**
- **Identity Canister**: Provides session validation and role checking for Admin
- **User Canister**: Uses Admin for feature flags and emergency controls
- **Wallet Canister**: Honors Admin emergency states and rate limits
- **AI Router**: Reads quota configs and feature flags from Admin
- **Governance**: Provides approval hooks for Class-A changes
- **Payment/Escrow**: Emergency kill switches and configuration management

### **Frontend Integration**
- Admin panel for role management and system configuration
- Real-time monitoring of emergency states and feature flags
- Audit trail visualization and compliance reporting
- Proposal workflow for governance-required changes

### **SophosAI Integration**
- AI service principal gets specific scoped roles (ai.admin, ai.submit)
- AI Router configuration managed through Admin (quotas, latency budgets)
- Emergency controls for AI system disable/enable
- Audit trail for all AI-related administrative actions

---

**Status**: ✅ **IMPLEMENTATION READY**  
**Architecture**: 🏗️ **TRIAD-NATIVE CONTROL PLANE**  
**Integration**: 🔗 **COMPLETE ECOSYSTEM SUPPORT**
