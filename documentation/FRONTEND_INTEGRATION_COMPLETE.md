# Frontend Integration Guide - Complete User System

## Overview
This guide provides everything your frontend needs to integrate with the AxiaSystem backend, including real-time status checking for User + Identity + Wallet connections.

## System Architecture

```
User Principal ID (Common Key)
├── User Canister    → Profile, Authentication, Registration
├── Identity Canister → Device Management, Security
└── Wallet Canister  → Balance, Transactions, Token Management
```

## Core Integration Methods

### 1. User Authentication & Registration

#### Create New User (Auto-Triad)
```typescript
// Creates User + Identity + Wallet automatically
const createUser = async (username: string, email: string, password: string) => {
  const result = await actor.user.createUser(username, email, password);
  if ('ok' in result) {
    return {
      user: result.ok,
      principalId: result.ok.id.toString(),
      status: 'complete_triad_created'
    };
  }
  throw new Error(result.err);
};
```

#### Login Validation
```typescript
const validateLogin = async (
  principalId?: string, 
  username?: string, 
  password?: string
) => {
  const principal = principalId ? Principal.fromText(principalId) : null;
  const result = await actor.user.validateLogin(
    principal ? [principal] : [], 
    username ? [username] : [], 
    password ? [password] : []
  );
  
  if ('ok' in result) {
    return {
      user: result.ok,
      principalId: result.ok.id.toString()
    };
  }
  throw new Error(result.err);
};
```

### 2. Real-Time Status Checking

#### Complete User Status Check
```typescript
interface UserStatus {
  hasUser: boolean;
  hasIdentity: boolean;
  hasWallet: boolean;
  isComplete: boolean;
  user?: User;
  identity?: Identity;
  wallet?: Wallet;
  walletBalance: number;
  tokenBalances: Array<{tokenId: number, balance: number}>;
}

const getUserCompleteStatus = async (principalId: string): Promise<UserStatus> => {
  const principal = Principal.fromText(principalId);
  
  // Check all three components in parallel
  const [userResult, identityResult, walletResult] = await Promise.allSettled([
    actor.user.getUserById(principal),
    actor.identity.getIdentity(principal),
    actor.wallet.getWalletByOwner(principal)
  ]);
  
  const hasUser = userResult.status === 'fulfilled' && 'ok' in userResult.value;
  const hasIdentity = identityResult.status === 'fulfilled' && identityResult.value !== null;
  const hasWallet = walletResult.status === 'fulfilled' && 'ok' in walletResult.value;
  
  // Get wallet overview for balances
  let walletOverview = null;
  if (hasWallet) {
    try {
      const overviewResult = await actor.wallet.getWalletOverview(principal);
      if ('ok' in overviewResult) {
        walletOverview = overviewResult.ok;
      }
    } catch (e) {
      console.warn('Could not fetch wallet overview:', e);
    }
  }
  
  return {
    hasUser,
    hasIdentity,
    hasWallet,
    isComplete: hasUser && hasIdentity && hasWallet,
    user: hasUser ? (userResult.value as any).ok : undefined,
    identity: hasIdentity ? identityResult.value : undefined,
    wallet: hasWallet ? (walletResult.value as any).ok : undefined,
    walletBalance: walletOverview?.nativeBalance || 0,
    tokenBalances: walletOverview?.tokenBalances || []
  };
};
```

#### Quick Connection Check
```typescript
const checkUserConnections = async (principalId: string) => {
  const principal = Principal.fromText(principalId);
  
  const [isRegistered, hasIdentity, hasWallet] = await Promise.all([
    actor.user.isUserRegistered(principal),
    actor.identity.getIdentity(principal).then(result => result !== null).catch(() => false),
    actor.wallet.getWalletByOwner(principal).then(result => 'ok' in result).catch(() => false)
  ]);
  
  return {
    isRegistered,
    hasIdentity,
    hasWallet,
    isComplete: isRegistered && hasIdentity && hasWallet,
    needsRepair: isRegistered && (!hasIdentity || !hasWallet)
  };
};
```

### 3. Auto-Repair Missing Components

```typescript
const ensureCompleteUser = async (principalId: string, email?: string, username?: string) => {
  const principal = Principal.fromText(principalId);
  
  // This method auto-creates missing Identity and Wallet
  const result = await actor.user.ensureIdentityAndWallet(
    principal, 
    email ? [email] : [], 
    username ? [username] : []
  );
  
  if ('ok' in result) {
    return {
      user: result.ok[0],
      message: result.ok[1],
      status: 'repaired'
    };
  }
  throw new Error(result.err);
};
```

### 4. Multi-Directional User Lookup

#### By Username
```typescript
const findUserByUsername = async (username: string) => {
  // Get all users and find by username (or implement dedicated method)
  const usersResult = await actor.user.listAllUsers(true);
  if ('ok' in usersResult) {
    const user = usersResult.ok.find(u => u.username === username);
    if (user) {
      return await getUserCompleteStatus(user.id.toString());
    }
  }
  throw new Error(`User not found: ${username}`);
};
```

#### By Wallet ID
```typescript
const findUserByWalletId = async (walletId: number) => {
  // Would need a method to get wallet by ID, then lookup user by owner
  // For now, you'd need to implement getWalletById in the wallet canister
  throw new Error('Method not yet implemented - needs getWalletById');
};
```

### 5. Wallet Management

#### Get Wallet Balance & Tokens
```typescript
const getWalletInfo = async (principalId: string) => {
  const principal = Principal.fromText(principalId);
  
  const [balanceResult, overviewResult, transactionsResult] = await Promise.allSettled([
    actor.wallet.getWalletBalance(principal),
    actor.wallet.getWalletOverview(principal),
    actor.wallet.getTransactionHistory(principal)
  ]);
  
  return {
    balance: balanceResult.status === 'fulfilled' && 'ok' in balanceResult.value 
      ? balanceResult.value.ok : 0,
    overview: overviewResult.status === 'fulfilled' && 'ok' in overviewResult.value 
      ? overviewResult.value.ok : null,
    transactions: transactionsResult.status === 'fulfilled' && 'ok' in transactionsResult.value 
      ? transactionsResult.value.ok : []
  };
};
```

#### Credit/Debit Wallet
```typescript
const creditWallet = async (principalId: string, amount: number) => {
  const principal = Principal.fromText(principalId);
  const result = await actor.wallet.creditWallet(principal, amount);
  if ('ok' in result) {
    return result.ok;
  }
  throw new Error(result.err);
};

const debitWallet = async (principalId: string, amount: number) => {
  const principal = Principal.fromText(principalId);
  const result = await actor.wallet.debitWallet(principal, amount);
  if ('ok' in result) {
    return result.ok;
  }
  throw new Error(result.err);
};
```

### 6. Identity Management

#### Check Identity Status
```typescript
const getIdentityInfo = async (principalId: string) => {
  const principal = Principal.fromText(principalId);
  const identity = await actor.identity.getIdentity(principal);
  
  return {
    exists: identity !== null,
    identity: identity,
    deviceCount: identity?.deviceKeys?.length || 0
  };
};
```

#### Register Device
```typescript
const registerDevice = async (userPrincipal: string, devicePrincipal: string) => {
  const user = Principal.fromText(userPrincipal);
  const device = Principal.fromText(devicePrincipal);
  
  const result = await actor.user.registerDevice(user, device);
  if ('ok' in result) {
    return { success: true };
  }
  throw new Error(result.err);
};
```

## Real-Time Status Monitoring

### React Hook Example
```typescript
import { useEffect, useState } from 'react';

export const useUserStatus = (principalId: string | null) => {
  const [status, setStatus] = useState<UserStatus | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const refreshStatus = async () => {
    if (!principalId) return;
    
    setLoading(true);
    setError(null);
    
    try {
      const userStatus = await getUserCompleteStatus(principalId);
      setStatus(userStatus);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };
  
  useEffect(() => {
    refreshStatus();
  }, [principalId]);
  
  return { status, loading, error, refresh: refreshStatus };
};
```

### Usage in Component
```typescript
const UserDashboard = ({ principalId }: { principalId: string }) => {
  const { status, loading, error, refresh } = useUserStatus(principalId);
  
  if (loading) return <div>Loading user status...</div>;
  if (error) return <div>Error: {error}</div>;
  if (!status) return null;
  
  return (
    <div>
      <h2>User Status</h2>
      <div>
        <span>User: {status.hasUser ? '✅' : '❌'}</span>
        <span>Identity: {status.hasIdentity ? '✅' : '❌'}</span>
        <span>Wallet: {status.hasWallet ? '✅' : '❌'}</span>
      </div>
      
      {!status.isComplete && (
        <button onClick={() => ensureCompleteUser(principalId)}>
          Repair Missing Components
        </button>
      )}
      
      {status.hasWallet && (
        <div>
          <p>Balance: {status.walletBalance}</p>
          <p>Token Balances: {status.tokenBalances.length}</p>
        </div>
      )}
      
      <button onClick={refresh}>Refresh Status</button>
    </div>
  );
};
```

## Connection Status Indicators

### Status Types
```typescript
type ConnectionStatus = 
  | 'complete'        // All 3 components exist and linked
  | 'partial'         // User exists, missing Identity or Wallet
  | 'missing'         // No user found
  | 'repairing'       // Currently fixing missing components
  | 'error';          // System error

const getConnectionStatus = (status: UserStatus): ConnectionStatus => {
  if (!status.hasUser) return 'missing';
  if (status.isComplete) return 'complete';
  return 'partial';
};
```

### Visual Indicators
```typescript
const ConnectionIndicator = ({ status }: { status: UserStatus }) => {
  const connectionStatus = getConnectionStatus(status);
  
  const indicators = {
    complete: { color: 'green', text: 'All Connected' },
    partial: { color: 'yellow', text: 'Needs Repair' },
    missing: { color: 'red', text: 'Not Registered' },
    repairing: { color: 'blue', text: 'Repairing...' },
    error: { color: 'red', text: 'Error' }
  };
  
  const indicator = indicators[connectionStatus];
  
  return (
    <div style={{ color: indicator.color }}>
      {indicator.text}
      <div>
        User: {status.hasUser ? '✅' : '❌'}
        Identity: {status.hasIdentity ? '✅' : '❌'}
        Wallet: {status.hasWallet ? '✅' : '❌'}
      </div>
    </div>
  );
};
```

## Error Handling & Recovery

### Common Error Scenarios
```typescript
const handleUserErrors = async (principalId: string) => {
  try {
    const status = await getUserCompleteStatus(principalId);
    
    if (!status.hasUser) {
      // User doesn't exist - need to register
      return { action: 'register', message: 'User not found. Please register.' };
    }
    
    if (!status.isComplete) {
      // Missing components - auto-repair
      await ensureCompleteUser(principalId);
      return { action: 'repaired', message: 'Missing components have been restored.' };
    }
    
    return { action: 'none', message: 'All systems operational.' };
    
  } catch (error) {
    return { 
      action: 'error', 
      message: `System error: ${error instanceof Error ? error.message : 'Unknown error'}` 
    };
  }
};
```

## Performance Considerations

### Caching Strategy
```typescript
class UserStatusCache {
  private cache = new Map<string, { status: UserStatus; timestamp: number }>();
  private readonly TTL = 30000; // 30 seconds
  
  async getStatus(principalId: string): Promise<UserStatus> {
    const cached = this.cache.get(principalId);
    
    if (cached && Date.now() - cached.timestamp < this.TTL) {
      return cached.status;
    }
    
    const status = await getUserCompleteStatus(principalId);
    this.cache.set(principalId, { status, timestamp: Date.now() });
    
    return status;
  }
  
  invalidate(principalId: string) {
    this.cache.delete(principalId);
  }
}
```

## Summary

Your frontend now has complete access to:

1. **Real-time status checking** for all 3 components
2. **Auto-repair functionality** for missing components  
3. **Multi-directional user lookup** capabilities
4. **Comprehensive wallet management**
5. **Identity and device management**
6. **Error handling and recovery**
7. **Performance optimization** with caching

The system is designed to be **self-healing** - if any component is missing, the backend can automatically recreate it while maintaining all connections via the shared Principal ID.
