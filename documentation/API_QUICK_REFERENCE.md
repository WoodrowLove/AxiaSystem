# API Quick Reference for AxiaSystem User Canister

## 🚀 Quick Start

```typescript
// 1. Initialize service
import { userService } from './lib/services/userService';
await userService.initialize();

// 2. Create user
const result = await userService.createUser({
  username: 'alice',
  email: 'alice@example.com', 
  password: 'securePassword123'
});

// 3. Login
const loginResult = await userService.validateLogin({
  email: 'alice@example.com',
  password: 'securePassword123'
});
```

## 📋 Complete API Reference

### User Management

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `createUser` | `username: string`<br/>`email: string`<br/>`password: string` | `ApiResult<User>` | Create new user account |
| `getUserById` | `userId: Principal` | `ApiResult<User>` | Get user by Principal ID |
| `updateUser` | `userId: Principal`<br/>`username?: string`<br/>`email?: string`<br/>`password?: string` | `ApiResult<User>` | Update user profile |
| `listAllUsers` | `includeInactive: boolean` | `ApiResult<User[]>` | List all users |
| `isUserRegistered` | `userId: Principal` | `boolean` | Check if user exists |

### Authentication

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `validateLogin` | `principal?: Principal`<br/>`email?: string`<br/>`password?: string` | `ApiResult<User>` | Authenticate user |
| `loginWithInternetIdentity` | - | `Principal \| null` | II authentication |
| `logout` | - | `void` | Logout user |
| `resetPassword` | `userId: Principal`<br/>`newPassword: string` | `VoidResult` | Reset user password |

### Account Management

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `deactivateUser` | `userId: Principal` | `VoidResult` | Deactivate account |
| `reactivateUser` | `userId: Principal` | `VoidResult` | Reactivate account |
| `deleteUser` | `userId: Principal` | `VoidResult` | Delete account |
| `registerDevice` | `userId: Principal`<br/>`deviceKey: Principal` | `VoidResult` | Register device |

### Token Operations

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `attachTokensToUser` | `userId: Principal`<br/>`tokenId: number`<br/>`amount: number` | `VoidResult` | Attach tokens to user |

## 🏷️ Type Definitions

```typescript
// Core interfaces
interface User {
  id: Principal;
  username: string;
  email: string;
  deviceKeys: Principal[];
  createdAt: bigint;
  updatedAt: bigint;
  icpWallet?: string;
  tokens: Array<[number, number]>;
  isActive: boolean;
}

// Result types
type ApiResult<T> = { ok: T } | { err: string };
type VoidResult = { ok: null } | { err: string };

// Request interfaces
interface CreateUserRequest {
  username: string;
  email: string;
  password: string;
}

interface UpdateUserRequest {
  username?: string;
  email?: string;
  password?: string;
}

interface LoginCredentials {
  email?: string;
  password?: string;
  principal?: Principal;
}
```

## ⚡ Common Usage Patterns

### Pattern 1: User Registration Flow
```typescript
async function registerNewUser(userData: CreateUserRequest) {
  const result = await userService.createUser(userData);
  
  if ('ok' in result) {
    // Registration successful
    const user = result.ok;
    userActions.setUser(user);
    return { success: true, user };
  } else {
    // Registration failed
    return { success: false, error: result.err };
  }
}
```

### Pattern 2: Multi-method Authentication
```typescript
async function authenticateUser(credentials: LoginCredentials) {
  const result = await userService.validateLogin(credentials);
  
  if ('ok' in result) {
    const user = result.ok;
    
    // Store session
    sessionManager.saveSession(user, 
      credentials.principal ? 'ii' : 'email'
    );
    
    // Update state
    userActions.setUser(user);
    
    return { success: true, user };
  } else {
    return { success: false, error: result.err };
  }
}
```

### Pattern 3: Admin User Management
```typescript
async function loadUsersDashboard(includeInactive = false) {
  const result = await userService.listAllUsers(includeInactive);
  
  if ('ok' in result) {
    const users = result.ok;
    
    // Categorize users
    const activeUsers = users.filter(u => u.isActive);
    const inactiveUsers = users.filter(u => !u.isActive);
    
    return {
      success: true,
      data: { users, activeUsers, inactiveUsers }
    };
  } else {
    return { success: false, error: result.err };
  }
}
```

### Pattern 4: Device Registration
```typescript
async function linkNewDevice(userId: Principal) {
  // Get current device principal from II
  const devicePrincipal = await userService.loginWithInternetIdentity();
  
  if (devicePrincipal) {
    const result = await userService.registerDevice(userId, devicePrincipal);
    
    if ('ok' in result) {
      return { success: true, message: 'Device linked successfully' };
    } else {
      return { success: false, error: result.err };
    }
  }
  
  return { success: false, error: 'Failed to get device principal' };
}
```

## 🚨 Error Handling

### Common Error Messages
```typescript
const ERROR_MESSAGES = {
  'User not found.': 'The user account does not exist.',
  'Invalid email format': 'Please enter a valid email address.',
  'User with this email already exists.': 'An account with this email already exists.',
  'Login failed: Invalid email or password.': 'Invalid credentials. Please try again.',
  'Missing credentials.': 'Please provide email and password.',
  'Principal not recognized.': 'This device is not registered.',
  'User is already active.': 'The user account is already active.'
};

function getUserFriendlyError(error: string): string {
  return ERROR_MESSAGES[error] || error;
}
```

### Error Handling Pattern
```typescript
async function safeApiCall<T>(
  apiCall: () => Promise<ApiResult<T>>,
  errorContext: string
): Promise<{ success: boolean; data?: T; error?: string }> {
  try {
    const result = await apiCall();
    
    if ('ok' in result) {
      return { success: true, data: result.ok };
    } else {
      const friendlyError = getUserFriendlyError(result.err);
      console.error(`${errorContext}:`, result.err);
      return { success: false, error: friendlyError };
    }
  } catch (error) {
    console.error(`${errorContext} - Network error:`, error);
    return { 
      success: false, 
      error: 'Network error. Please check your connection.' 
    };
  }
}
```

## 🔧 Configuration

### Environment Setup
```typescript
// Required environment variables
const CONFIG = {
  // Network configuration
  DFX_NETWORK: process.env.VITE_DFX_NETWORK || 'local',
  
  // Canister IDs (Currently Deployed)
  USER_CANISTER_ID: process.env.VITE_DFX_NETWORK === 'local'
    ? 'xobql-2x777-77774-qaaja-cai'  // ✅ Currently Active
    : 'xad5d-bh777-77774-qaaia-cai', // Production ID
  
  // Network endpoints
  IC_HOST: process.env.VITE_DFX_NETWORK === 'local'
    ? 'http://localhost:4943'
    : 'https://ic0.app',
  
  // Identity provider
  II_URL: process.env.VITE_DFX_NETWORK === 'local'
    ? 'http://localhost:4943/?canisterId=rdmx6-jaaaa-aaaah-qdrqq-cai'
    : 'https://identity.ic0.app'
};
```

### Package Dependencies
```json
{
  "dependencies": {
    "@dfinity/agent": "^0.19.0",
    "@dfinity/candid": "^0.19.0",
    "@dfinity/principal": "^0.19.0",
    "@dfinity/identity": "^0.19.0",
    "@dfinity/auth-client": "^0.19.0"
  }
}
```

## 🎯 Integration Checklist

### Setup Checklist
- [ ] Install required dependencies
- [ ] Copy Candid declarations
- [ ] Configure environment variables
- [ ] Initialize user service
- [ ] Set up error handling
- [ ] Implement authentication flows

### Testing Checklist
- [ ] Test user registration
- [ ] Test email/password login
- [ ] Test Internet Identity login
- [ ] Test user profile updates
- [ ] Test admin operations
- [ ] Test error scenarios
- [ ] Test session management

### Security Checklist
- [ ] Validate all user inputs
- [ ] Implement secure session storage
- [ ] Use HTTPS in production
- [ ] Implement proper error handling
- [ ] Test authentication flows
- [ ] Verify principal validation

## 📚 Example Components

### Complete Authentication Component
```svelte
<!-- UserAuth.svelte -->
<script lang="ts">
  import { userService } from '../services/userService';
  import { userActions, isLoading, userError } from '../stores/userStore';

  let mode: 'login' | 'register' = 'login';
  let formData = { username: '', email: '', password: '' };

  async function handleSubmit() {
    if (mode === 'register') {
      await userActions.registerUser(formData);
    } else {
      await userActions.loginWithEmail(formData.email, formData.password);
    }
  }

  async function handleIILogin() {
    await userActions.loginWithII();
  }
</script>

<form on:submit|preventDefault={handleSubmit}>
  {#if mode === 'register'}
    <input bind:value={formData.username} placeholder="Username" required />
  {/if}
  
  <input bind:value={formData.email} type="email" placeholder="Email" required />
  <input bind:value={formData.password} type="password" placeholder="Password" required />
  
  <button type="submit" disabled={$isLoading}>
    {mode === 'register' ? 'Register' : 'Login'}
  </button>
  
  <button type="button" on:click={handleIILogin}>
    Login with Internet Identity
  </button>
</form>

{#if $userError}
  <div class="error">{$userError}</div>
{/if}
```

This API reference provides everything needed to integrate with the AxiaSystem User Canister efficiently and securely.
