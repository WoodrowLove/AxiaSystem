# Frontend Integration Guide for AxiaSystem User Canister

## 🎯 Purpose
This guide provides step-by-step instructions for integrating a Svelte + TypeScript frontend with the AxiaSystem User Canister. Follow this guide to implement user authentication, profile management, and admin interfaces.

## 📋 Prerequisites

### Required Dependencies
```bash
npm install @dfinity/agent @dfinity/candid @dfinity/principal @dfinity/identity @dfinity/auth-client
npm install --save-dev @types/node
```

### Project Structure Setup
```
src/
├── lib/
│   ├── stores/           # Svelte stores for state management
│   ├── services/         # Canister interface services
│   ├── components/       # Reusable UI components
│   ├── types/           # TypeScript type definitions
│   └── utils/           # Helper utilities
├── declarations/        # Generated Candid declarations (copy from backend)
└── routes/             # SvelteKit routes (if using SvelteKit)
```

## 🔧 Step 1: Copy Generated Declarations

Copy the generated Candid files from your backend:

```bash
# From your AxiaSystem backend
cp -r src/declarations/user/* [your-frontend]/src/declarations/user/
```

Required files:
- `user.did` - Candid interface definition
- `user.did.js` - JavaScript bindings
- `user.did.d.ts` - TypeScript declarations
- `index.js` - Main export
- `index.d.ts` - TypeScript exports

## 🔧 Step 2: Environment Configuration

Create environment configuration:

```typescript
// src/lib/config/environment.ts
export const ENV_CONFIG = {
  NETWORK: import.meta.env.VITE_DFX_NETWORK || 'local',
  
  // Canister IDs
  USER_CANISTER_ID: import.meta.env.VITE_DFX_NETWORK === 'local'
    ? 'xobql-2x777-77774-qaaja-cai'  // Local canister ID
    : 'xad5d-bh777-77774-qaaia-cai',  // Production canister ID
  
  // Network hosts
  IC_HOST: import.meta.env.VITE_DFX_NETWORK === 'local'
    ? 'http://localhost:4943'
    : 'https://ic0.app',
  
  // Internet Identity
  II_URL: import.meta.env.VITE_DFX_NETWORK === 'local'
    ? 'http://localhost:4943/?canisterId=rdmx6-jaaaa-aaaah-qdrqq-cai'
    : 'https://identity.ic0.app'
};
```

Create `.env` file:
```env
VITE_DFX_NETWORK=local
# Set to 'ic' for production
```

## 🔧 Step 3: Create Type Definitions

```typescript
// src/lib/types/user.ts
import type { Principal } from '@dfinity/principal';

export interface User {
  id: Principal;
  username: string;
  email: string;
  deviceKeys: Principal[];
  createdAt: bigint;
  updatedAt: bigint;
  icpWallet?: string;
  tokens: TokenBalance[];
  isActive: boolean;
}

export interface TokenBalance {
  tokenId: number;
  amount: number;
}

export interface CreateUserRequest {
  username: string;
  email: string;
  password: string;
}

export interface UpdateUserRequest {
  username?: string;
  email?: string;
  password?: string;
}

export interface LoginCredentials {
  email?: string;
  password?: string;
  principal?: Principal;
}

export type ApiResult<T> = { ok: T } | { err: string };
```

## 🔧 Step 4: Create User Service

```typescript
// src/lib/services/userService.ts
import { Actor, HttpAgent } from '@dfinity/agent';
import { AuthClient } from '@dfinity/auth-client';
import { Principal } from '@dfinity/principal';
import { idlFactory } from '../declarations/user';
import { ENV_CONFIG } from '../config/environment';
import type { 
  User, 
  CreateUserRequest, 
  UpdateUserRequest, 
  LoginCredentials,
  ApiResult 
} from '../types/user';

class UserService {
  private actor: any = null;
  private authClient: AuthClient | null = null;

  async initialize() {
    // Initialize auth client
    this.authClient = await AuthClient.create();
    
    // Create agent
    const agent = new HttpAgent({
      host: ENV_CONFIG.IC_HOST,
    });

    // Fetch root key for local development
    if (ENV_CONFIG.NETWORK === 'local') {
      await agent.fetchRootKey();
    }

    // Create actor
    this.actor = Actor.createActor(idlFactory, {
      agent,
      canisterId: ENV_CONFIG.USER_CANISTER_ID,
    });
  }

  // User management methods
  async createUser(userData: CreateUserRequest): Promise<ApiResult<User>> {
    if (!this.actor) throw new Error('Service not initialized');
    
    try {
      const result = await this.actor.createUser(
        userData.username,
        userData.email,
        userData.password
      );
      return result;
    } catch (error) {
      return { err: `Failed to create user: ${error}` };
    }
  }

  async getUserById(userId: Principal): Promise<ApiResult<User>> {
    if (!this.actor) throw new Error('Service not initialized');
    
    try {
      return await this.actor.getUserById(userId);
    } catch (error) {
      return { err: `Failed to get user: ${error}` };
    }
  }

  async validateLogin(credentials: LoginCredentials): Promise<ApiResult<User>> {
    if (!this.actor) throw new Error('Service not initialized');
    
    try {
      return await this.actor.validateLogin(
        credentials.principal ? [credentials.principal] : [],
        credentials.email ? [credentials.email] : [],
        credentials.password ? [credentials.password] : []
      );
    } catch (error) {
      return { err: `Login failed: ${error}` };
    }
  }

  async listAllUsers(includeInactive: boolean = false): Promise<ApiResult<User[]>> {
    if (!this.actor) throw new Error('Service not initialized');
    
    try {
      return await this.actor.listAllUsers(includeInactive);
    } catch (error) {
      return { err: `Failed to list users: ${error}` };
    }
  }

  // Internet Identity authentication
  async loginWithInternetIdentity(): Promise<Principal | null> {
    if (!this.authClient) return null;

    return new Promise((resolve) => {
      this.authClient!.login({
        identityProvider: ENV_CONFIG.II_URL,
        onSuccess: () => {
          const identity = this.authClient!.getIdentity();
          resolve(identity.getPrincipal());
        },
        onError: () => resolve(null)
      });
    });
  }

  async logout(): Promise<void> {
    if (this.authClient) {
      await this.authClient.logout();
    }
  }
}

export const userService = new UserService();
```

## 🔧 Step 5: Create Svelte Stores

```typescript
// src/lib/stores/userStore.ts
import { writable, derived } from 'svelte/store';
import type { User } from '../types/user';

// User state management
interface UserState {
  currentUser: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

const initialState: UserState = {
  currentUser: null,
  isAuthenticated: false,
  isLoading: false,
  error: null
};

export const userState = writable<UserState>(initialState);

// Derived stores for easier access
export const currentUser = derived(userState, $state => $state.currentUser);
export const isAuthenticated = derived(userState, $state => $state.isAuthenticated);
export const isLoading = derived(userState, $state => $state.isLoading);
export const userError = derived(userState, $state => $state.error);

// Actions
export const userActions = {
  setUser: (user: User) => {
    userState.update(state => ({
      ...state,
      currentUser: user,
      isAuthenticated: true,
      error: null
    }));
  },

  clearUser: () => {
    userState.update(state => ({
      ...state,
      currentUser: null,
      isAuthenticated: false,
      error: null
    }));
  },

  setLoading: (loading: boolean) => {
    userState.update(state => ({ ...state, isLoading: loading }));
  },

  setError: (error: string) => {
    userState.update(state => ({ ...state, error, isLoading: false }));
  }
};
```

## 🔧 Step 6: Create Authentication Component

```svelte
<!-- src/lib/components/UserAuth.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { userService } from '../services/userService';
  import { userActions, isLoading, userError, isAuthenticated, currentUser } from '../stores/userStore';
  import type { CreateUserRequest, LoginCredentials } from '../types/user';

  let activeTab: 'login' | 'register' = 'login';
  
  // Form data
  let registerData: CreateUserRequest = {
    username: '',
    email: '',
    password: ''
  };
  
  let loginData: LoginCredentials = {
    email: '',
    password: ''
  };

  onMount(async () => {
    await userService.initialize();
  });

  async function handleRegister() {
    userActions.setLoading(true);
    
    const result = await userService.createUser(registerData);
    
    if ('ok' in result) {
      userActions.setUser(result.ok);
      // Reset form
      registerData = { username: '', email: '', password: '' };
    } else {
      userActions.setError(result.err);
    }
    
    userActions.setLoading(false);
  }

  async function handleLogin() {
    userActions.setLoading(true);
    
    const result = await userService.validateLogin(loginData);
    
    if ('ok' in result) {
      userActions.setUser(result.ok);
    } else {
      userActions.setError(result.err);
    }
    
    userActions.setLoading(false);
  }

  async function handleInternetIdentityLogin() {
    userActions.setLoading(true);
    
    const principal = await userService.loginWithInternetIdentity();
    if (principal) {
      const result = await userService.validateLogin({ principal });
      if ('ok' in result) {
        userActions.setUser(result.ok);
      } else {
        userActions.setError(result.err);
      }
    } else {
      userActions.setError('Internet Identity login failed');
    }
    
    userActions.setLoading(false);
  }

  async function handleLogout() {
    await userService.logout();
    userActions.clearUser();
  }
</script>

<div class="auth-container">
  {#if $isAuthenticated}
    <!-- Authenticated state -->
    <div class="user-profile">
      <h2>Welcome, {$currentUser?.username}!</h2>
      <p>Email: {$currentUser?.email}</p>
      <p>User ID: {$currentUser?.id.toString()}</p>
      <button on:click={handleLogout} class="btn btn-secondary">
        Logout
      </button>
    </div>
  {:else}
    <!-- Authentication forms -->
    <div class="auth-tabs">
      <button 
        class="tab {activeTab === 'login' ? 'active' : ''}"
        on:click={() => activeTab = 'login'}
      >
        Login
      </button>
      <button 
        class="tab {activeTab === 'register' ? 'active' : ''}"
        on:click={() => activeTab = 'register'}
      >
        Register
      </button>
    </div>

    {#if activeTab === 'login'}
      <form on:submit|preventDefault={handleLogin} class="auth-form">
        <h3>Login to Your Account</h3>
        
        <input 
          type="email" 
          placeholder="Email" 
          bind:value={loginData.email}
          required 
        />
        
        <input 
          type="password" 
          placeholder="Password" 
          bind:value={loginData.password}
          required 
        />
        
        <button type="submit" class="btn btn-primary" disabled={$isLoading}>
          {$isLoading ? 'Logging in...' : 'Login'}
        </button>
        
        <div class="divider">or</div>
        
        <button 
          type="button" 
          on:click={handleInternetIdentityLogin}
          class="btn btn-ii"
          disabled={$isLoading}
        >
          Login with Internet Identity
        </button>
      </form>
    {:else}
      <form on:submit|preventDefault={handleRegister} class="auth-form">
        <h3>Create New Account</h3>
        
        <input 
          type="text" 
          placeholder="Username" 
          bind:value={registerData.username}
          required 
        />
        
        <input 
          type="email" 
          placeholder="Email" 
          bind:value={registerData.email}
          required 
        />
        
        <input 
          type="password" 
          placeholder="Password" 
          bind:value={registerData.password}
          required 
        />
        
        <button type="submit" class="btn btn-primary" disabled={$isLoading}>
          {$isLoading ? 'Creating Account...' : 'Create Account'}
        </button>
      </form>
    {/if}
  {/if}

  {#if $userError}
    <div class="error-message">
      {$userError}
    </div>
  {/if}
</div>

<style>
  .auth-container {
    max-width: 400px;
    margin: 0 auto;
    padding: 2rem;
  }

  .auth-tabs {
    display: flex;
    margin-bottom: 2rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  }

  .tab {
    flex: 1;
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.7);
    padding: 1rem;
    cursor: pointer;
    transition: all 0.3s ease;
  }

  .tab.active {
    color: #f7d794;
    border-bottom: 2px solid #f7d794;
  }

  .auth-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .auth-form h3 {
    color: white;
    text-align: center;
    margin-bottom: 1.5rem;
  }

  input {
    padding: 0.75rem;
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 8px;
    background: rgba(255, 255, 255, 0.05);
    color: white;
    font-size: 1rem;
  }

  input::placeholder {
    color: rgba(255, 255, 255, 0.5);
  }

  .btn {
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
  }

  .btn-primary {
    background: linear-gradient(135deg, #f7d794, #f39c12);
    color: #0a0b1e;
  }

  .btn-secondary {
    background: rgba(255, 255, 255, 0.1);
    color: white;
    border: 1px solid rgba(255, 255, 255, 0.2);
  }

  .btn-ii {
    background: #29abe2;
    color: white;
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .divider {
    text-align: center;
    color: rgba(255, 255, 255, 0.5);
    position: relative;
  }

  .divider::before,
  .divider::after {
    content: '';
    position: absolute;
    top: 50%;
    width: 45%;
    height: 1px;
    background: rgba(255, 255, 255, 0.2);
  }

  .divider::before { left: 0; }
  .divider::after { right: 0; }

  .error-message {
    background: rgba(239, 68, 68, 0.2);
    border: 1px solid #ef4444;
    color: #ef4444;
    padding: 1rem;
    border-radius: 8px;
    margin-top: 1rem;
  }

  .user-profile {
    text-align: center;
    padding: 2rem;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
  }

  .user-profile h2 {
    color: #f7d794;
    margin-bottom: 1rem;
  }

  .user-profile p {
    color: rgba(255, 255, 255, 0.8);
    margin-bottom: 0.5rem;
  }
</style>
```

## 🔧 Step 7: Create User Management Dashboard

```svelte
<!-- src/lib/components/UserManagement.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { userService } from '../services/userService';
  import type { User } from '../types/user';

  let users: User[] = [];
  let loading = false;
  let error: string | null = null;
  let includeInactive = false;

  async function loadUsers() {
    loading = true;
    error = null;
    
    try {
      const result = await userService.listAllUsers(includeInactive);
      
      if ('ok' in result) {
        users = result.ok;
      } else {
        error = result.err;
      }
    } catch (err) {
      error = `Failed to load users: ${err}`;
    }
    
    loading = false;
  }

  async function deactivateUser(userId: any) {
    // Implementation for user deactivation
    console.log('Deactivating user:', userId);
    await loadUsers(); // Refresh list
  }

  onMount(async () => {
    await userService.initialize();
    await loadUsers();
  });
</script>

<div class="user-management">
  <div class="header">
    <h2>👤 User Management</h2>
    <div class="controls">
      <label class="toggle">
        <input 
          type="checkbox" 
          bind:checked={includeInactive} 
          on:change={loadUsers}
        />
        Include Inactive Users
      </label>
      <button on:click={loadUsers} class="btn btn-secondary">
        Refresh
      </button>
    </div>
  </div>

  {#if error}
    <div class="error-banner">{error}</div>
  {/if}

  {#if loading}
    <div class="loading">Loading users...</div>
  {:else}
    <div class="users-grid">
      {#each users as user (user.id.toString())}
        <div class="user-card" class:inactive={!user.isActive}>
          <div class="user-info">
            <h4>{user.username}</h4>
            <p class="email">{user.email}</p>
            <p class="principal">{user.id.toString()}</p>
            <span class="status {user.isActive ? 'active' : 'inactive'}">
              {user.isActive ? 'Active' : 'Inactive'}
            </span>
          </div>
          
          <div class="user-stats">
            <div class="stat">
              <span>Devices:</span>
              <span class="value">{user.deviceKeys.length}</span>
            </div>
            <div class="stat">
              <span>Tokens:</span>
              <span class="value">{user.tokens?.length || 0}</span>
            </div>
          </div>

          <div class="user-actions">
            <button class="btn btn-small">View</button>
            {#if user.isActive}
              <button 
                class="btn btn-small btn-danger"
                on:click={() => deactivateUser(user.id)}
              >
                Deactivate
              </button>
            {/if}
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .user-management {
    padding: 2rem;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
  }

  .header h2 {
    color: #f7d794;
    font-size: 2rem;
  }

  .controls {
    display: flex;
    gap: 1rem;
    align-items: center;
  }

  .users-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 1.5rem;
  }

  .user-card {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    padding: 1.5rem;
    transition: all 0.3s ease;
  }

  .user-card:hover {
    background: rgba(255, 255, 255, 0.1);
  }

  .user-card.inactive {
    opacity: 0.6;
  }

  .user-info h4 {
    color: white;
    margin-bottom: 0.5rem;
  }

  .email {
    color: #c8d6e5;
    margin-bottom: 0.25rem;
  }

  .principal {
    font-family: monospace;
    font-size: 0.8rem;
    color: #f7d794;
    margin-bottom: 1rem;
  }

  .status {
    display: inline-block;
    padding: 0.25rem 0.75rem;
    border-radius: 12px;
    font-size: 0.8rem;
    font-weight: 600;
  }

  .status.active {
    background: rgba(16, 185, 129, 0.2);
    color: #10b981;
  }

  .status.inactive {
    background: rgba(239, 68, 68, 0.2);
    color: #ef4444;
  }

  .btn {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 600;
  }

  .btn-secondary {
    background: rgba(255, 255, 255, 0.1);
    color: white;
  }

  .btn-small {
    padding: 0.25rem 0.75rem;
    font-size: 0.9rem;
  }

  .btn-danger {
    background: rgba(239, 68, 68, 0.2);
    color: #ef4444;
  }
</style>
```

## 🔧 Step 8: Integration in Main App

```svelte
<!-- src/App.svelte -->
<script>
  import UserAuth from './lib/components/UserAuth.svelte';
  import UserManagement from './lib/components/UserManagement.svelte';
  import { isAuthenticated, currentUser } from './lib/stores/userStore';

  let activeView = 'auth'; // 'auth' | 'dashboard' | 'admin'
</script>

<main>
  <nav>
    <h1>AxiaSystem</h1>
    {#if $isAuthenticated}
      <div class="nav-links">
        <button on:click={() => activeView = 'dashboard'}>Dashboard</button>
        <button on:click={() => activeView = 'admin'}>Users</button>
      </div>
    {/if}
  </nav>

  <div class="content">
    {#if !$isAuthenticated}
      <UserAuth />
    {:else if activeView === 'dashboard'}
      <div class="dashboard">
        <h2>Welcome back, {$currentUser?.username}!</h2>
        <!-- Add dashboard content here -->
      </div>
    {:else if activeView === 'admin'}
      <UserManagement />
    {/if}
  </div>
</main>

<style>
  main {
    min-height: 100vh;
    background: linear-gradient(135deg, #0a0b1e, #1e3c72);
    color: white;
  }

  nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 2rem;
    background: rgba(0, 0, 0, 0.3);
  }

  .content {
    padding: 2rem;
  }
</style>
```

## 🚀 Final Steps

### 1. Update package.json
```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@dfinity/agent": "^0.19.0",
    "@dfinity/candid": "^0.19.0",
    "@dfinity/principal": "^0.19.0",
    "@dfinity/identity": "^0.19.0",
    "@dfinity/auth-client": "^0.19.0",
    "svelte": "^4.0.0"
  }
}
```

### 2. Configure Vite (vite.config.js)
```javascript
import { defineConfig } from 'vite';
import { sveltekit } from '@sveltejs/kit/vite';

export default defineConfig({
  plugins: [sveltekit()],
  define: {
    global: 'globalThis',
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:4943',
        changeOrigin: true,
      },
    },
  },
});
```

### 3. Start Development
```bash
npm run dev
```

## ✅ Testing Your Integration

1. **User Registration**: Test creating new users
2. **Authentication**: Test both email/password and Internet Identity
3. **User Management**: Test listing, updating, deactivating users
4. **Error Handling**: Test with invalid inputs
5. **Token Attachment**: Test attaching tokens to users

## 🐛 Common Issues & Solutions

### Issue: "Cannot find module" errors
**Solution**: Ensure all `@dfinity` packages are installed and declarations are copied correctly.

### Issue: Principal conversion errors
**Solution**: Use `Principal.fromText()` and `principal.toString()` for conversions.

### Issue: Canister connection fails
**Solution**: Check network configuration and canister IDs in environment config.

### Issue: Internet Identity login fails
**Solution**: Verify Internet Identity URL is correct for your network.

This completes the frontend integration guide. The system provides a complete user management interface that connects to your AxiaSystem User Canister with proper error handling, type safety, and a modern UI.
