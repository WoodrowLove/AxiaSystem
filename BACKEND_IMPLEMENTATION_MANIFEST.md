# BACKEND IMPLEMENTATION MANIFEST — Wallet/Token Corrections + Auto‑Provision Triad

## 0) Required Review (Do This First)

**Claude must open each of the paths below by reading the actual files in the current project:**

1. `/home/woodrowlove/AxiaSystem/src/AxiaSystem_backend/wallet`
2. `/home/woodrowlove/AxiaSystem/src/AxiaSystem_backend/token`
3. `/home/woodrowlove/AxiaSystem/src/AxiaSystem_backend/user`
4. `/home/woodrowlove/AxiaSystem/src/AxiaSystem_backend/identity`
5. `/home/woodrowlove/AxiaSystem/.dfx/local/canisters/token/token.did`
6. `/home/woodrowlove/AxiaSystem/.dfx/local/canisters/wallet/wallet.did`
7. `/home/woodrowlove/AxiaSystem/.dfx/local/canisters/user/user.did`
8. `/home/woodrowlove/AxiaSystem/.dfx/local/canisters/identity/identity.did`

Use context clues from the Motoko backend; names may not match perfectly, but CRUD exists for each module. If something is missing, produce a follow‑up manifest that lists the exact additions.

## 1) What's Wrong Today (And Why Fix It Now)

### A. Token supply vs balances are inconsistent
- `TokenState.attachTokensToUser(...)` increments both the user balance and totalSupply
- `TokenModule.mintTokens(...)` also increments totalSupply, and then may attach to user via `userProxy.attachTokensToUser(...)`
- **Result**: A mint followed by attach can double‑count supply

### B. Wallet "balance" mirrors token balances
- `Wallet.attachTokenBalance(...)` adds to wallet.balance
- Makes wallet.balance ambiguous (is it "native/app credits" or "sum of token balances"?)
- Will drift from the truth in TokenState

### C. Minor correctness issues in Token module
- `updateTokenMetadata` validation branches appear inverted
- `burnToken` constructs updatedToken using `let newSupply = ...` inline in the record literal (invalid/fragile pattern)

### D. Missing consolidated queries for the frontend
We need reliable read APIs:
- User's wallet (native/app credits)
- User's token balances (across all tokens)
- A single "wallet overview" response the UI can bind to

### E. Auto‑provision triad
When a user exists (or is created), we want deterministic provisioning:
- Identity exists (or is created)
- Wallet exists (or is created)
- (XRPL: deferred; see §6, we won't generate keys/custody)

## 2) Design Decisions (Clean Model)

### Supply Authority
- `mintToUser(tokenId, amount, user)` (new) increments supply and the user's balance atomically in one call
- `attachTokensToUser(tokenId, user, amount)` becomes balance‑only, does not change supply

### Wallet Native vs Token Balances
- `Wallet.balance` is native/app credits only. Do not mirror token balances here
- Token balances remain canonical in `TokenState.balances`

### Auto‑provision
- Add a small orchestration entrypoint (either in User canister or a new Provisioner module) to ensure identity + wallet on demand and after successful user creation

## 3) Exact Changes to Implement

### 3.1 Token Canister

#### (1) Fix metadata validation logic

```motoko
// In TokenModule.updateTokenMetadata(...)
if (not ValidationUtils.isValidTokenName(newName)) {
  return #err("Invalid token name.");
};
if (not ValidationUtils.isValidTokenSymbol(newSymbol)) {
  return #err("Invalid token symbol.");
};
```

#### (2) Fix burn implementation

```motoko
public func burnToken(tokenId: Nat, amount: Nat): Result.Result<(), Text> {
  switch (getToken(tokenId)) {
    case (#err(e)) { return #err(e) };
    case (#ok(token)) {
      if (amount > token.totalSupply) return #err("Insufficient token supply to burn.");
      let newSupply = Nat.sub(token.totalSupply, amount);
      let updatedToken = { token with totalSupply = newSupply };
      switch (tokenState.updateToken(updatedToken)) {
        case (#ok(())) { return #ok(()) };
        case (#err(e)) { return #err(e) };
      }
    }
  }
}
```

#### (3) Make TokenState.attachTokensToUser balance‑only
- Remove `totalSupply = token.totalSupply + amount` from the updated token
- Only update the per‑user balance

```motoko
// TokenState.attachTokensToUser(...)
// ... compute newBalance ...
let updatedBalances = Trie.put(token.balances, { key = userId; hash = Principal.hash(userId) }, Principal.equal, newBalance).0;
let updatedToken = { token with balances = updatedBalances };
// DO NOT mutate totalSupply here.
```

#### (4) Add mintToUser for atomic issuance

```motoko
public func mintToUser(tokenId: Nat, amount: Nat, recipient: Principal): async Result.Result<(), Text> {
  switch (getToken(tokenId)) {
    case (#err(e)) { return #err(e) };
    case (#ok(token)) {
      // owner / active checks as you prefer
      let supplyInc = tokenState.mintTokens(tokenId, amount);
      switch (supplyInc) {
        case (#err(e)) return #err(e);
        case (#ok(())) {
          let balInc = tokenState.attachTokensToUser(tokenId, recipient, amount); // now balance-only
          switch (balInc) {
            case (#err(e)) return #err(e);
            case (#ok(())) {
              // Optional cross-canister linkage:
              // ignore failure or bubble it up — your choice
              let _ = await userManager.attachTokensToUser(recipient, tokenId, amount);
              return #ok(());
            }
          }
        }
      }
    }
  }
}
```

#### (5) Add read APIs for balances

```motoko
public query func getBalanceOf(tokenId: Nat, user: Principal): async Nat {
  switch (tokenState.getToken(tokenId)) {
    case null 0;
    case (?token) {
      switch (Trie.get(token.balances, { key = user; hash = Principal.hash(user) }, Principal.equal)) {
        case null 0;
        case (?b) b;
      }
    }
  }
};

public query func getBalancesForUser(user: Principal): async [(Nat, Nat)] {
  // Iterate all tokens and collect (>0) balances
  let all = tokenState.getAllTokens();
  var out : [(Nat, Nat)] = [];
  for (t in all.vals()) {
    let bal = switch (Trie.get(t.balances, { key = user; hash = Principal.hash(user) }, Principal.equal)) {
      case null 0;
      case (?b) b;
    };
    if (bal > 0) {
      out := Array.append(out, [(t.id, bal)]);
    }
  };
  out
};
```

#### (6) DID updates (TokenActor)

```candid
service : {
  getBalanceOf: (nat, principal) -> (nat) query;
  getBalancesForUser: (principal) -> (vec record { nat; nat }) query;
  mintToUser: (nat, nat, principal) -> (variant { ok; err: text });
  // existing methods remain (createToken, getToken, getAllTokens, mintTokens, burnTokens, ...),
  // but remember: TokenState.attachTokensToUser becomes balance-only
}
```

### 3.2 Wallet Canister

#### (1) Stop mirroring token balances into wallet.balance
- Treat `wallet.balance` as native/app credits only
- In `attachTokenBalance(...)`, remove the line that increments `wallet.balance`

```motoko
// In WalletModule.attachTokenBalance(...)
switch (Trie.find(wallets, userIdKey, Principal.equal)) {
  case (?wallet) {
    // REMOVE: let updatedWallet = { wallet with balance = wallet.balance + amount };
    // Keep wallet untouched; token balances live in Token canister.
    // You can still emit an insight/event here.
    #ok(());
  };
  case null #err("Wallet not found.");
};
```

#### (2) Add "ensure" + read APIs for the frontend

```motoko
public func ensureWallet(owner: Principal): async Result.Result<Wallet, Text> {
  let key = { key = owner; hash = Principal.hash(owner) };
  switch (Trie.find(wallets, key, Principal.equal)) {
    case (?w) #ok(w);
    case null {
      await createWallet(owner, 0);
    }
  }
};

public func getWalletOverview(owner: Principal): async Result.Result<{ native_balance : Nat; token_balances : [(Nat, Nat)] }, Text> {
  let key = { key = owner; hash = Principal.hash(owner) };
  switch (Trie.find(wallets, key, Principal.equal)) {
    case null #err("Wallet not found");
    case (?w) {
      let tokenBalances = await tokenCanisterProxy.getBalancesForUser(owner);
      #ok({ native_balance = w.balance; token_balances = tokenBalances })
    }
  }
}
```

#### (3) DID updates (Wallet)

```candid
service : {
  ensureWallet: (principal) -> (variant { ok: Wallet; err: text });
  getWalletOverview: (principal) -> (variant { ok: record { native_balance: nat; token_balances: vec record { nat; nat } }; err: text }) query;
  // existing methods remain (createWallet, getWalletByOwner, creditWallet, debitWallet, ...)
}
```

### 3.3 User + Identity (Auto‑provision Triad)

**Goal**: When we have a valid user principal, we can ensure identity and wallet.

**Option A) In the User canister:**

```motoko
public func ensureIdentityAndWallet(user: Principal): async Result.Result<(), Text> {
  // 1) Identity
  let _ = await identityProxy.ensureIdentity(user);
  // 2) Wallet
  let _ = await walletProxy.ensureWallet(user);
  #ok(())
}
```

**Option B) New small Provisioner canister:** same method there, callable by frontend (auth‑gated), to decouple concerns.

**Identity canister expectation** (if not present, add):

```candid
service : {
  ensureIdentity: (principal) -> (variant { ok; err: text });
  // (and/or getIdentityByOwner, createIdentity, etc.)
}
```

**Server‑side guard**:
- Restrict `ensureIdentityAndWallet` to the user themselves (`caller == user`) or to admins (use your Admin canister's `isAdmin(caller)`)

## 4) Security & Access

- This admin interface is not public‑facing
- For write ops (`mintToUser`, `creditWallet`, `debitWallet`, `attachTokensToUser` if privileged), enforce:
  - `caller == token.owner` or `Admin.isAdmin(caller)` as appropriate
- For read ops (`getWalletOverview`, `getBalancesForUser`), allow self or admins; deny others

## 5) Data Migration Notes

- If you've previously mirrored token amounts into `wallet.balance`, you may want to zero out any such mirrored credits or reclassify them as true native-app credits
- If `TokenState.attachTokensToUser` has already increased `totalSupply` for past operations and you also called `mintTokens`, you could have inflated supply
  - **Easiest in dev**: clear state
  - **In prod**: add a one‑off reconciliation script that recomputes `totalSupply = Σ balances + unlocked supply` per token

## 6) XRPL (Deferred But Ready)

- We will not auto‑create XRPL keys or store secrets (custody concerns)
- Keep the XRPL Bridge as its own microservice (already built) and add optional callback endpoints in a payment/tip canister when we're ready (e.g., `handleTipFromXRPL(artist, amount, uuid)`), idempotent by uuid
- Frontend will only visualize XRPL status via read‑only canister logs later

## 7) Frontend Contracts This Enables

- `GET /wallet/overview` (via canister call `getWalletOverview(principal)`)
- `GET /token/balances` (via `getBalancesForUser(principal)`)
- `POST /user/ensure-primitives` (via `ensureIdentityAndWallet(principal)`)
- Reliable "single source of truth" for token balances; native credits are cleanly separated

## 8) Test Checklist (Local)

1. **Create user** → call `ensureIdentityAndWallet(user)`
2. **ensureWallet(user)** returns a wallet with balance = 0
3. **mintToUser(tokenId, 50, user)**:
   - `getBalanceOf(tokenId, user) == 50`
   - `getToken(tokenId).totalSupply` increased by 50
   - `getWalletOverview(user)` shows `native_balance = 0`, `token_balances` includes `(tokenId, 50)`
4. **attachTokensToUser(tokenId, user, 10)**:
   - User balance +10
   - totalSupply unchanged
5. **creditWallet(user, 25)**:
   - `getWalletOverview(user).native_balance == 25`
   - Token balances unchanged
6. **Guards**: non‑owner cannot `mintToUser`; non‑self/non‑admin cannot read another user's overview

## 9) What to Change in Code (Summary List)

- **TokenState.attachTokensToUser**: remove supply mutation
- **TokenModule**:
  - Fix validation in `updateTokenMetadata`
  - Fix `burnToken` literal
  - Add `mintToUser`
  - Add queries `getBalanceOf`, `getBalancesForUser` (exposed on TokenActor)
- **WalletModule**:
  - Stop incrementing `wallet.balance` in `attachTokenBalance`
  - Add `ensureWallet`, `getWalletOverview`
- **User/Provisioning**:
  - Add `ensureIdentityAndWallet` orchestration
  - Add identity proxy `ensureIdentity` if missing
- **DID files**: update token + wallet + user/provisioner accordingly

---

**If anything above isn't present in the codebase after reviewing the paths, generate a quick delta patch list and refine the manifest.**
