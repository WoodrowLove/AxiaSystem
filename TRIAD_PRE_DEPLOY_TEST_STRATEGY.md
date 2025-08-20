# Triad Pre-Deploy Test Strategy

**Goal**: Prove atomic creation, linkage integrity, auth correctness, event/audit completeness, and safe failure behavior before mainnet/stage deploy.

## A. Test Identities & Fixtures

### Actors
- **tester_a** (happy-path human)
- **tester_b** (secondary human)  
- **service_bot** (system principal for future modules)

### Tokens/Currencies
- Mock or devnet: NATIVE, USDC, TEST

### Amount Tiers
- **Tier 1**: ≤$10 equivalent
- **Tier 3**: ≈$500 equivalent  
- **Tier 5**: >$50k equivalent

---

## B. Core Invariants (must always hold)

1. **Atomic Triad Create**: `createUser()` results in User+Identity+Wallet created or none (no partials)
2. **Canonical Linkage**: `User.identityId == Identity.id` and `Wallet.owner == Identity.id`
3. **Identity Persistence**: Deleting a User does not delete Identity or Wallet (wallet may be disabled, not destroyed)
4. **Auth Defense**: All value ops require Identity session, not just a raw principal
5. **Event Completeness**: Every operation emits Triad context `{identityId, userId?, walletId?}` with a correlationId
6. **Idempotency**: Retrying `createUser()` with same external idempotency key returns the same Triad references
7. **PII Safety**: No emails/names/exact amounts appear in cross-canister messages (only refs/tiers)

---

## C. Test Matrix

### 1) Creation & Idempotency
- **T1.1**: `createUser(email, username, …)` → assert 3 IDs returned; verify all cross-references
- **T1.2**: Retry `createUser()` with same idempotencyKey → same IDs; with new key → new Triad
- **T1.3**: Inject failure between Identity and Wallet creation → expect full rollback (no stray canisters/records)

### 2) Sessions & RBAC  
- **T2.1**: Start Identity session for tester_a with scope `wallet:transfer` → call `wallet.transfer()` succeeds
- **T2.2**: Try transfer with expired session → fail `session_expired`
- **T2.3**: Try transfer with no scope → fail `insufficient_scope`
- **T2.4**: Use service_bot to call user-only endpoint → fail `forbidden_role`

### 3) Wallet Operations (deterministic)
- **T3.1**: Credit tester_a wallet (mint in dev) → balance updated; event emitted with Triad context
- **T3.2**: Debit within balance → success; event chain consistent
- **T3.3**: Overdraft attempt → deterministic fail; no balance change; audit record present
- **T3.4**: Concurrent debits (race of 5 requests) → exactly one succeeds up to balance, others fail cleanly

### 4) Deletion & Lifecycle
- **T4.1**: Delete/disable User → Identity+Wallet remain; User login fails; Identity session still valid (unless policy-disabled)
- **T4.2**: Disable Wallet via policy → transfers fail; queries still work
- **T4.3**: Attempt to delete Identity with live wallet → should be refused (only disable allowed)

### 5) Cross-Canister Auth & Events
- **T5.1**: Call a sample module (e.g., Asset/Payment) using userPrincipal only → must fail until it validates Identity session
- **T5.2**: Same call with valid session → success; event contains `{identityId, userId?, walletId?}` and correlationId
- **T5.3**: Verify event ordering for a multi-step op (e.g., payment: authorize → capture) shares the same correlationId

### 6) Security (LinkProof, replay, boundaries)
- **T6.1**: LinkProof happy path: signature verified against stored device key
- **T6.2**: Replay same proof (same nonce) → rejected
- **T6.3**: Proof signed by non-registered device → rejected
- **T6.4**: Oversized payloads / invalid types → rejected with safe errors (no panics)

### 7) PII Minimization & Logging
- **T7.1**: Inspect logs/events/messages for email, name, exactAmount → must not appear; only references, tiers, hashes
- **T7.2**: Structured logs include corrId, Triad IDs, deterministic error codes

### 8) Performance & Limits (smoke)
- **T8.1**: p95 latency under budget for `createUser` and `wallet.transfer` (record numbers now; track drift later)
- **T8.2**: Rate limit behavior: exceed per-identity quota → get `rate_limited`, no state change

### 9) Chaos / Failure Injection
- **T9.1**: Temporarily make Wallet canister return an error during create → assert Triad transaction aborts
- **T9.2**: Kill session store mid-transfer → operation fails safely; no partial ledger write

---

## D. Suggested Test Harness Calls

```bash
# Create user (with idempotency)
dfx canister call user createUser '(record { 
  email="a@x.io"; 
  username="tester_a"; 
  idempotencyKey="seed-001" 
})'

# Start session (Identity)
dfx canister call identity startSession '(
  principal "aaaa-bbbb...", 
  "wallet:transfer", 
  900
)'

# Transfer
dfx canister call wallet transfer '(record { 
  to=principal "cccc-dddd..."; 
  token="TEST"; 
  amount=1_000 
})'

# Delete user
dfx canister call user deleteUser '(principal "aaaa-bbbb...")'
```

---

## E. Pass/Fail Gates

### Must pass before deploy:
- 100% of T1–T7 pass
- T8: p95 latency within current budgets; no panics
- T9: rollback/abort behavior verified

### Known-good artifacts to capture:
- Triad IDs for tester_a, tester_b
- Session tokens redacted; their scopes and expiries logged
- Event samples for each category with correlationId

---

## F. Rollback Plan (if anything goes sideways)

- Flip kill-switch flags in Admin for Payments/Escrow
- Revoke `ai:submit`/`ai:deliver` sessions for Namora AI
- Disable (do not delete) any Triad entities that were mis-provisioned
- Re-run T1–T7 on a fresh namespace
