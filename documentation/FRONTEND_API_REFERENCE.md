# Frontend Integration API Quick Reference

## Canister Method Reference

### User Canister Methods
```typescript
// Authentication & Registration
createUser(username: text, email: text, password: text) -> Result<User>
validateLogin(principal?: principal, username?: text, password?: text) -> Result<User>
isUserRegistered(principal: principal) -> bool

// User Management
getUserById(principal: principal) -> Result<User>
updateUser(principal: principal, username?: text, email?: text, password?: text) -> Result<User>
listAllUsers(includeInactive: bool) -> Result<User[]>

// Auto-Provisioning
ensureIdentityAndWallet(principal: principal, email?: text, username?: text) -> Result<(User, text)>

// Device Management
registerDevice(userPrincipal: principal, devicePrincipal: principal) -> Result<void>

// Account Management
deactivateUser(principal: principal) -> Result<void>
reactivateUser(principal: principal) -> Result<void>
resetPassword(principal: principal, newPassword: text) -> Result<void>

// Token Management
attachTokensToUser(principal: principal, tokenId: nat, amount: nat) -> Result<void>
```

### Identity Canister Methods
```typescript
// Identity Management
getIdentity(principal: principal) -> ?Identity
createIdentity(principal: principal) -> Result<Identity>
deleteIdentity(principal: principal) -> Result<void>

// Device Management
addDevice(principal: principal, deviceKey: principal) -> Result<void>
removeDevice(principal: principal, deviceKey: principal) -> Result<void>
listDevices(principal: principal) -> Result<principal[]>

// Metadata Management
updateMetadata(principal: principal, key: text, value: text) -> Result<void>
getMetadata(principal: principal, key: text) -> ?text
```

### Wallet Canister Methods
```typescript
// Wallet Management
createWallet(owner: principal, initialBalance: nat) -> Result<Wallet>
getWalletByOwner(owner: principal) -> Result<Wallet>
deleteWallet(owner: principal) -> Result<void>
ensureWallet(owner: principal) -> Result<Wallet>

// Balance Operations
getWalletBalance(owner: principal) -> Result<nat>
creditWallet(owner: principal, amount: nat) -> Result<nat>
debitWallet(owner: principal, amount: nat) -> Result<nat>
updateBalance(owner: principal, change: int) -> Result<nat>

// Token Management
attachTokenBalance(owner: principal, tokenId: nat, amount: nat) -> Result<void>
getWalletOverview(owner: principal) -> Result<{nativeBalance: nat, tokenBalances: (nat, nat)[]}

// Transaction History
getTransactionHistory(owner: principal) -> Result<WalletTransaction[]>
```

## Data Types

### User
```typescript
type User = {
  id: principal;
  username: text;
  email: text;
  hashedPassword: text;
  createdAt: int;
  updatedAt: int;
  isActive: bool;
  deviceKeys: principal[];
  icpWallet: ?text;
  tokens: Trie; // Token balances
};
```

### Identity
```typescript
type Identity = {
  id: principal;
  deviceKeys: principal[];
  metadata: Trie;
  createdAt: int;
  updatedAt: int;
};
```

### Wallet
```typescript
type Wallet = {
  id: int;
  owner: principal;
  balance: nat;
  transactions: ?List<WalletTransaction>;
};

type WalletTransaction = {
  id: nat;
  amount: int;
  description: text;
  timestamp: nat;
};

type WalletOverview = {
  nativeBalance: nat;
  tokenBalances: (nat, nat)[]; // (tokenId, balance) pairs
};
```

## Essential Frontend Flows

### 1. User Registration Flow
```typescript
// Step 1: Create user (auto-creates Identity + Wallet)
const user = await actor.user.createUser(username, email, hashedPassword);

// Step 2: Verify complete triad was created
const status = await getUserCompleteStatus(user.ok.id.toString());

// Result: status.isComplete should be true
```

### 2. User Login Flow
```typescript
// Step 1: Validate login
const user = await actor.user.validateLogin(null, username, hashedPassword);

// Step 2: Check system status
const status = await getUserCompleteStatus(user.ok.id.toString());

// Step 3: Auto-repair if needed
if (!status.isComplete) {
  await actor.user.ensureIdentityAndWallet(user.ok.id, [email], [username]);
}
```

### 3. Wallet Balance Check
```typescript
// Method 1: Direct balance
const balance = await actor.wallet.getWalletBalance(principal);

// Method 2: Complete overview with tokens
const overview = await actor.wallet.getWalletOverview(principal);
// Returns: { nativeBalance: number, tokenBalances: [tokenId, balance][] }
```

### 4. Transaction History
```typescript
const transactions = await actor.wallet.getTransactionHistory(principal);
// Returns: WalletTransaction[]
```

### 5. Identity Status Check
```typescript
const identity = await actor.identity.getIdentity(principal);
const hasIdentity = identity !== null;
const deviceCount = identity?.deviceKeys?.length || 0;
```

## Error Handling Patterns

### Standard Result Pattern
```typescript
// All methods return Result<T> or ?T
type Result<T> = { ok: T } | { err: string };

// Usage:
const result = await actor.user.getUserById(principal);
if ('ok' in result) {
  const user = result.ok;
  // Success
} else {
  const error = result.err;
  // Handle error
}
```

### Common Error Messages
- `"User not found"` - User doesn't exist
- `"Wallet not found"` - Wallet doesn't exist for user
- `"Identity not found"` - Identity doesn't exist for user
- `"Insufficient balance"` - Not enough funds for operation
- `"Invalid principal"` - Principal format is incorrect

## Connection Status Checking

### Quick Status Check
```typescript
const checkUserStatus = async (principalId: string) => {
  const principal = Principal.fromText(principalId);
  
  const [hasUser, hasIdentity, hasWallet] = await Promise.all([
    actor.user.isUserRegistered(principal),
    actor.identity.getIdentity(principal).then(id => id !== null),
    actor.wallet.getWalletByOwner(principal).then(w => 'ok' in w)
  ]);
  
  return {
    hasUser,
    hasIdentity, 
    hasWallet,
    isComplete: hasUser && hasIdentity && hasWallet
  };
};
```

### Auto-Repair Missing Components
```typescript
const repairUser = async (principalId: string, email?: string, username?: string) => {
  const principal = Principal.fromText(principalId);
  
  const result = await actor.user.ensureIdentityAndWallet(
    principal,
    email ? [email] : [],
    username ? [username] : []
  );
  
  if ('ok' in result) {
    return {
      user: result.ok[0],
      message: result.ok[1] // Status message
    };
  }
  throw new Error(result.err);
};
```

## Principal ID Management

### Working with Principals
```typescript
import { Principal } from '@dfinity/principal';

// Convert string to Principal
const principal = Principal.fromText("gae6d-zoxlc-b73dg-ov634-7zqb4-hjjed-fc4g2-i6yfi-ffb4a-3wzim");

// Convert Principal to string
const principalString = principal.toString();

// Check if Principal is valid
const isValid = Principal.fromText(principalString).toString() === principalString;
```

### Current Canister IDs (Local Development)
```typescript
const CANISTER_IDS = {
  user: "xobql-2x777-77774-qaaja-cai",
  identity: "vpyes-67777-77774-qaaeq-cai", 
  wallet: "xjaw7-xp777-77774-qaajq-cai",
  token: "xad5d-bh777-77774-qaaia-cai"
};
```

This reference provides all the essential methods and patterns your frontend needs to maintain real-time connection status and manage the complete User + Identity + Wallet ecosystem.
