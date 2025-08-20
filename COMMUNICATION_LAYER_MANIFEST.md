# 📨 Namora Communication Layer — Triad‑Native Messaging & Approvals

**Version:** 1.0 • **Date:** Aug 20, 2025  
**Scope:** Internal notifications, approvals (HIL), system alerts, and service‑to‑human messaging for Namora AI and all AxiaSystem modules.

---

## 0) Design principles
- **Triad everywhere.** All comms addressed by Identity (optionally userId, walletId for context).
- **Zero‑PII boundary.** Only reference IDs + hashed features cross canister boundaries; content templates avoid raw PII.
- **Advisory → Deterministic.** Messages can request approvals; actual state changes remain deterministic and policy‑gated.
- **Deliverability over channels.** In‑app inbox is the source of truth; other channels (webhook/email/SMS/push) are mirrors.
- **At‑least‑once delivery, idempotent actions.** Global corrId and optional idempotencyKey ensure safe retries.
- **Ops‑friendly.** Quotas, rate limits, quiet hours, digests, circuit breakers, retention, audit.

---

## 1) Architecture (canisters & adapters)

```
+------------------+        +------------------+
|  Producer Canrs  |        |   Namora  AI     |
| (Payments/Escrow |        | (via AI Router)  |
+--------+---------+        +---------+--------+
         | Triad msg env.             |
         v                            v
+----------------------------------------------+
|         Notification Canister (core)          |
| - API (send/list/ack/prefs)                  |
| - Router (routing rules, quiet hours)        |
| - Dedupe (corrId, idempotencyKey)            |
| - Scheduler (retries, digests, escalations)  |
| - Delivery Log (audit)                       |
| - Retention Worker (purges)                  |
+--------+----------------+--------------------+
         |                |
   In‑App Inbox      Delivery Adapters (optional)
         |                |
         v                v
   Clients (Swift)   Webhook -> off‑chain relays (Email/SMS/Push)
```

**Why one core canister?** Centralizes policy enforcement (Q1–Q5), gives a single auditable surface, and keeps adapters optional/replaceable.

---

## 2) Data contracts (types)

### 2.1 Triad context & correlation (shared)

```motoko
module Types {
  public type TriadCtx = {
    identityId : Principal;
    userId     : ?Principal;
    walletId   : ?Principal;
  };

  public type Corr = {
    id              : Text;           // global correlation id (UUIDv4 or similar)
    parent          : ?Text;
    idempotencyKey  : ?Text;          // dedupe across retries
    ttlSecs         : Nat32;          // optional expiry
  };

  public type Severity = { #info; #warn; #critical };

  public type Channel = { #InApp; #Webhook; #Email; #SMS; #Push };

  public type Recipient = { #Identity : Principal; #User : Principal };

  public type Prefs = {
    channels     : [Channel];
    quietHours   : ?{ startMin : Nat16; endMin : Nat16 }; // local day minutes
    minSeverity  : Severity;
    locale       : ?Text;    // e.g., "en-US"
    digest       : ?{ scheduleCron : Text; minSeverity : Severity };
  };
}
```

### 2.2 Message & action

```motoko
module MessageTypes {
  public type Action = {
    label   : Text;                      // "Approve", "Deny"
    command : {                          // deterministic action hook
      scope   : Text;                    // e.g., "gov:approve", "payment:approve"
      name    : Text;                    // method alias
      args    : Blob;                    // CBOR/JSON args (no PII)
    };
    url     : ?Text;                     // optional deep link (app://...)
  };

  public type MsgBody = {
    // MINIMIZED CONTENT. No raw PII; use references and redacted text.
    title       : Text;
    body        : Text;                  // templated, safe content only
    variables   : [(Text, Text)];        // redacted strings; validated by validator
    templateId  : ?Text;                 // for i18n rendering on client
    attachments : ?[Blob];               // discouraged; disable by default
  };

  public type Message = {
    id        : Text;                    // message id (server-generated)
    to        : Types.Recipient;
    from      : Types.Recipient;         // usually Namora AI Identity
    severity  : Types.Severity;
    triad     : Types.TriadCtx;
    corr      : Types.Corr;
    createdAt : Nat64;
    ttlSecs   : Nat32;
    body      : MsgBody;
    actions   : [Action];
    tags      : [Text];                  // "approval", "security", "compliance"
  };
}
```

**PII guardrails (Q1):** A DataContractValidator verifies body.variables only contain reference IDs, hashes, tiers, factors. Email/phone/name/exact amounts: blocked.

---

## 3) Public API (Candid surface)

```motoko
actor Notification {

  // --- Preferences
  public shared func setPrefs(
    who   : Types.Recipient,
    prefs : Types.Prefs,
    proof : IdentityTypes.LinkProof
  ) : async Result.Result<(), Text>;

  public query func getPrefs(who: Types.Recipient) : async ?Types.Prefs;

  // --- Send (from trusted producers)
  public shared func send(
    msg       : MessageTypes.Message,
    sessionId : Text           // must validate scope "notify:send"
  ) : async Result.Result<Text /*msgId*/, Text>;

  // --- Query & ack (recipients)
  public query func listInbox(
    who     : Types.Recipient,
    page    : Nat,
    limit   : Nat
  ) : async [MessageTypes.Message];

  public shared func ack(
    msgId     : Text,
    sessionId : Text          // must validate "notify:ack"
  ) : async Result.Result<(), Text>;

  // --- Admin / ops
  public query func deliveryStatus(msgId: Text) : async ?{ state: Text; attempts: Nat; lastErr: ?Text };
  public shared func purge(category: Text) : async Result.Result<Nat, Text>; // retention worker triggers
}
```

**Auth model:**
- Producers (Payments/Escrow/AI Router) call send() with Identity session scoped notify:send.
- Recipients call listInbox (query) and ack() with notify:ack.
- Admin operations require role notify.admin in Identity.

---

## 4) Core behaviors

### 4.1 Routing & delivery
- **Routing:** Resolve Recipient → target inbox entries; apply preferences (channels, quiet hours, min severity).
- **In‑app is canonical.** Every message lands in inbox; other channels are mirrors.
- **Quiet hours:** Non‑critical messages are deferred to digest; #critical may break through (policy‑controlled).

### 4.2 Dedupe & idempotency
- **Dedupe key:** (from.identity, corr.id) or explicit idempotencyKey.
- **If duplicate within ttlSecs,** return existing msgId.
- **Prevents spam loops** during retries/backoffs.

### 4.3 Escalations (HIL, Q3)
- **For messages tagged approval or security with #critical severity:**
- **Start SLA timer** (15 min approval; 5 min emergencies).
- **If timer elapses:** auto‑escalate to on‑call group (role‑based recipients) and raise severity; if still unattended → enforce conservative action per Policy (e.g., hold).

### 4.4 Digests
- **If prefs contain digest.scheduleCron,** batch messages ≥ minSeverity into summary entries at schedule; include correlation groups.

### 4.5 Retention (Q4)
- **Inbox items:** default 90 days (configurable).
- **Delivery logs** (audit metadata only): 7 years immutable.
- **Sensitive categories:** 30 days.
- **Operational insights:** 2 years (anonymized).
- **Heartbeat purges** per class; supports legal holds.

---

## 5) Security & compliance
- **Identity sessions only** (no raw LinkProof on hot paths); scopes: notify:send, notify:ack, notify:admin.
- **RBAC roles:** notify.sender, notify.admin, notify.escalation.
- **DataContractValidator:** blocks PII (emails, names, phones, exact $) and disallowed variables.
- **Webhook signing:** HMAC‑SHA256 with per‑endpoint secrets; include X-Notify-Id, X-Notify-Signature, X-Notify-Timestamp. Retries with exponential backoff; at‑least‑once.
- **Rate limits:** per sender identity & per recipient (burst + sustained).
- **Audit events:** notify.sent|delivered|ack|failed|escalated|digested|purged (Triad envelope, corrId, version).

---

## 6) Channel adapters

Adapters are optional, off‑chain or edge canisters that mirror the in‑app message.

### 6.1 Webhook Adapter (recommended first)
- **Register endpoint:** per recipient (or group) with secret & retry policy.
- **Payload:** minimized message + action tokens (short‑lived; single‑use).
- **Semantics:** at‑least‑once; consumer must dedupe on id.

### 6.2 Email/SMS/Push Relays (later)
- **Off‑chain services** called by a backend that listens to Webhook events.
- **Respect quiet hours** and minSeverity; no PII in body; use references and deep links to secure app.

---

## 7) Integration points

### 7.1 AI Router → Notification
When Policy Engine returns #RequireMFA or #HoldForReview or an approval is needed, AI Router sends a message:

```motoko
ignore Notification.send({
  id = ""; // server fills
  to = #Identity(yourIdentity);
  from = #Identity(aiServiceIdentity);
  severity = #critical;
  triad = { identityId = userIdentity; userId = ?userP; walletId = ?walletP };
  corr = { id = corrId; parent = null; idempotencyKey = ?corrId; ttlSecs = 3600 };
  createdAt = now64();
  ttlSecs = 3600;
  body = {
    title = "High‑value payout requires approval";
    body  = "Payment @{paymentRef} (tier @{amountTier}) flagged.";
    variables = [("paymentRef","P-48271"), ("amountTier","5")];
    templateId = ?"approval.high_value"; attachments = null;
  };
  actions = [
    { label = "Approve", command = { scope="payment:approve"; name="approveHighValue"; args=encodeArgs(corrId) }, url=?("app://approve?corr=" # corrId) },
    { label = "Deny",    command = { scope="payment:deny";    name="denyHighValue";    args=encodeArgs(corrId) }, url=?("app://deny?corr="    # corrId) }
  ];
  tags = ["approval","payments"];
}, aiSessionId);
```

### 7.2 Approvals flow (deterministic)
- **Client (or internal tool)** calls Payments approveHighValue(corrId, sessionId) with the human's Identity session scoped gov:approve or payment:approve.
- **On success,** Payments emits payment.approved, and Notification auto‑acks related message via corrId.

### 7.3 On‑call groups (roles → recipients)
- **Dynamic groups** resolved by role (e.g., notify.escalation). Notification expands group to identities at send‑time.

---

## 8) Storage & indexes
- **Inbox:** byRecipient : Trie<Principal, Vec<MsgRef>> (newest first), byCorr : Trie<Text, MsgRef> for dedupe, unread : Trie<Principal, LruSet<Text>>.
- **Delivery log:** append‑only, compacted by day.
- **Scheduler queues:** delayed delivery, retries, digests, SLAs.

---

## 9) SLOs & KPIs

### SLOs
- **In‑app enqueue** p95 < 50 ms.
- **Webhook dispatch** p95 < 200 ms (excluding receiver).
- **SLA timers** accurate to ±5 s.
- **Retention purges** within 24 h of due time.

### KPIs
- **Delivery success rate** > 99.9% (in‑app).
- **PII blocks:** 100% of violations caught by validator.
- **Escalation SLA hit rate** ≥ 95%.
- **Duplicate suppression effectiveness** > 99%.

---

## 10) Failure modes & mitigation
- **Adapter down** → in‑app still delivers; retries/backoff; escalate only if severity=critical.
- **Spam / loops** → per‑sender quotas; dedupe by corrId; circuit breaker on burst.
- **Approval spoofing** → actions require Identity session with correct scope; server verifies role; idempotent endpoints.
- **Clock skew** → timers use canister time; signed webhooks enforce timestamp windows.

---

## 11) Deployment & bootstrap
1. **Deploy Notification canister** after Identity/User/Wallet are live.
2. **Register roles:** notify.sender, notify.admin, notify.escalation.
3. **Grant notify.sender** to AI Router, Payments, Escrow canisters' service identities.
4. **Set default prefs** for your Identity (channels: InApp + Webhook; quiet hours; digest schedule).
5. **Configure webhook endpoint** (if used) with secret; verify signature.

---

## 12) Testing matrix
- **Unit:** validator blocks PII; routing honors prefs; idempotency returns same msgId; ack transitions state.
- **Integration:** AI Router → Notification → Approvals → Policy action; SLA timers trigger escalations.
- **Chaos:** drop webhooks; flood with duplicates; slow consumer; retention purge under load.
- **Security:** invalid sessions, expired tokens, scope violations, HMAC mismatches.

---

## 13) File map (new modules)

```
/src/AxiaSystem_backend/notification/
  ├─ main.mo                       # API + routing + persistence
  ├─ types.mo                      # Message, Prefs, TriadCtx, Corr, Severity
  ├─ validator.mo                  # DataContractValidator (Q1)
  ├─ scheduler.mo                  # retries, digests, escalations, SLAs
  ├─ delivery_log.mo               # audit trail
  ├─ retention.mo                  # purge jobs, legal holds
  └─ role_resolver.mo              # role→identity group expansion
```

---

## 14) Swift bridge shapes (FFI)

Return `{ "ok": ... } | { "err": "..." }`.
- `rust_notify_set_prefs(recipient_json_c, prefs_json_c, proof_json_c)`
- `rust_notify_send(message_json_c, session_id_c)` (for system tools; user apps won't call this)
- `rust_notify_list_inbox(recipient_json_c, page_u32, limit_u32)`
- `rust_notify_ack(msg_id_c, session_id_c)`

**Client tips:** Poll list_inbox or run webhook → local cache; always pass Identity session; dedupe locally by id.

---

## 15) Example policies (snap‑in)
- **Quiet hours:** 22:00–07:00 local; only #critical bypass.
- **Escalation:** Approval pending > 15 min → escalate to notify.escalation group; > 30 min → conservative action (hold).
- **Digest:** Daily at 09:00; include #info/#warn, exclude #critical.

---

## 16) Ready‑to‑build acceptance (Phase 1)
- **send/list/ack/setPrefs** implemented with session validation.
- **Validator blocks PII;** unit tests cover forbidden keys.
- **Dedupe works** (same corrId → same msgId).
- **Scheduler runs SLAs + retries;** delivery log records lifecycle.
- **In‑app inbox accessible;** Webhook adapter optional but tested.

---

## Appendix A — Minimal Motoko stubs (compile‑near)

```motoko
public shared func send(msg : MessageTypes.Message, sessionId : Text)
  : async Result.Result<Text, Text> {
  // 1) Auth
  let sess = await Identity.validateSession(sessionId, "notify:send");
  if (!sess.valid) return #err("unauthorized");

  // 2) Validate content (no PII)
  switch (Validator.check(msg)) { case (#err e) return #err("invalid:" # e); case _ {} };

  // 3) Dedupe
  let key = Option.get(msg.corr.idempotencyKey, msg.corr.id);
  switch (dedupeFind(msg.from, key)) {
    case (?existing) return #ok(existing.msgId);
    case null ();
  };

  // 4) Persist + route
  let msgId = generateId();
  persistInbox(msg.to, msgId, msg);
  enqueueDeliveries(msgId, msg);

  // 5) Audit
  DeliveryLog.append("notify.sent", msg.triad.identityId, msg.corr.id);

  #ok(msgId)
}
```

That's the whole backbone. It's small enough to build quickly, strict enough to keep you safe, and flexible enough to grow (webhooks now, email/SMS later).

This is the communication layer between myself and Namora. Be sure it has the hooks needed so when Namora AI is active it connects seamlessly.
