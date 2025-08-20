# 🚀 AxiaSystem API Architecture & Frontend Integration Guide

**Date**: December 2024  
**Status**: ✅ **PRODUCTION READY**  
**Integration**: **Complete Multi-Protocol Support**

---

## 🏗️ **API ARCHITECTURE OVERVIEW**

AxiaSystem is **NOT a traditional REST or GraphQL API**. It uses the **Internet Computer Protocol (ICP)** with **Candid interface definitions** for blockchain-native communication.

### **🔗 Primary API Protocol: ICP Candid**

```typescript
// Connection Pattern
import { Actor, HttpAgent } from '@dfinity/agent';
import { idlFactory } from './declarations/user';

const agent = new HttpAgent({ host: 'https://ic0.app' });
const actor = Actor.createActor(idlFactory, {
  agent,
  canisterId: 'xad5d-bh777-77774-qaaia-cai'
});

// API Call
const result = await actor.createUser(username, email, password);
```

### **🌐 Secondary API Protocols**

| Protocol | Usage | Endpoint Examples |
|----------|--------|-------------------|
| **ICP Candid** | Primary blockchain API | All canister methods |
| **HTTP/JSON** | Bridge monitoring | `/api/bridge/health`, `/api/bridge/calls` |
| **WebSocket** | Real-time updates | Status monitoring, live feeds |
| **FFI Interface** | XRPL Bridge | Native C-compatible functions |

---

## 🎯 **CORE CANISTER APIs**

### **1. User Management System**

**Canister ID**: `xad5d-bh777-77774-qaaia-cai`

```typescript
// Authentication & Registration
createUser(username: text, email: text, password: text) -> Result<User>
validateLogin(principal?: principal, username?: text, password?: text) -> Result<User>
isUserRegistered(principal: principal) -> bool

// User Management
getUserById(principal: principal) -> Result<User>
updateUser(principal: principal, username?: text, email?: text, password?: text) -> Result<User>
listAllUsers(includeInactive: bool) -> Result<User[]>

// Auto-Provisioning (Creates complete user ecosystem)
ensureIdentityAndWallet(principal: principal, email?: text, username?: text) -> Result<(User, text)>

// Device Management
registerDevice(userPrincipal: principal, devicePrincipal: principal) -> Result<void>
```

### **2. Wallet System**

**Canister ID**: `cuj6u-c4aaa-aaaaa-qaajq-cai`

```typescript
// Wallet Operations
getWalletBalance(principal: principal) -> Result<number>
getWalletOverview(principal: principal) -> Result<WalletOverview>
getTransactionHistory(principal: principal) -> Result<WalletTransaction[]>

// Token Management
transferTokens(fromPrincipal: principal, toPrincipal: principal, amount: number) -> Result<text>
```

### **3. Identity System**

**Canister ID**: `asrmz-lmaaa-aaaaa-qaaeq-cai`

```typescript
// Identity Management
getIdentity(principal: principal) -> ?Identity
createIdentity(principal: principal, publicKey: text) -> Result<Identity>
addDeviceKey(principal: principal, deviceKey: text) -> Result<void>
```

### **4. AI Router System**

**Canister ID**: `ucwa4-rx777-77774-qaada-cai`

```typescript
// AI Communication
submit(message: AIMessage, sessionId: text) -> Result<text>
poll(correlationId: text) -> ?AIResponse
deliver(response: AIResponse, sessionId: text) -> Result<void>
pullMessages(sessionId: text, maxCount: ?number) -> Result<AIMessage[]>

// Session Management
createSession(role: SessionRole) -> Result<text>
healthCheck() -> HashMap<text, Value>
```

### **5. Payment System**

**Canister ID**: `a4tbr-q4aaa-aaaaa-qaafq-cai`

```typescript
// Payment Processing
processPayment(fromPrincipal: principal, toPrincipal: principal, amount: number) -> Result<text>
getPaymentHistory(principal: principal) -> Result<PaymentRecord[]>
```

---

## 🔗 **SECONDARY API INTERFACES**

### **HTTP/JSON Bridge APIs**

```typescript
// Bridge Health Monitoring
GET /api/bridge/health
{
  "status": "healthy",
  "uptime": 1755542140098,
  "lastCall": "2024-12-20T10:30:45Z",
  "errorCount": 0
}

// Bridge Call History
GET /api/bridge/calls
{
  "recentCalls": [
    {
      "timestamp": "2024-12-20T10:30:45Z",
      "function": "process_payment",
      "success": true,
      "responseTime": 150
    }
  ],
  "failedCalls": []
}

// Bridge Metadata
GET /api/bridge/metadata
{
  "version": "1.0.0",
  "capabilities": ["payment_processing", "user_management"],
  "buildTime": "2024-12-20T08:00:00Z"
}
```

### **XRPL Bridge FFI Interface**

```c
// C-Compatible Functions for External Integration
extern "C" {
    char* rust_tip_artist_via_xrpl(const char* artist_id, const char* amount);
    char* rust_check_bridge_status();
    char* rust_submit_raw_xrpl_tx(const char* transaction_data);
}
```

---

## 🛠️ **FRONTEND INTEGRATION PATTERNS**

### **1. React/TypeScript Integration**

```typescript
// Service Layer
class AxiaSystemService {
  private actors: Map<string, any> = new Map();

  async initialize() {
    const agent = new HttpAgent({
      host: process.env.IC_HOST || 'https://ic0.app'
    });

    if (process.env.NODE_ENV === 'development') {
      await agent.fetchRootKey();
    }

    // Initialize all canister actors
    this.actors.set('user', Actor.createActor(userIdlFactory, {
      agent, canisterId: 'xad5d-bh777-77774-qaaia-cai'
    }));

    this.actors.set('wallet', Actor.createActor(walletIdlFactory, {
      agent, canisterId: 'cuj6u-c4aaa-aaaaa-qaajq-cai'
    }));

    this.actors.set('ai_router', Actor.createActor(aiRouterIdlFactory, {
      agent, canisterId: 'ucwa4-rx777-77774-qaada-cai'
    }));
  }

  // Unified API methods
  async createUser(userData: CreateUserRequest) {
    const userActor = this.actors.get('user');
    return await userActor.createUser(
      userData.username,
      userData.email,
      userData.password
    );
  }

  async getWalletBalance(principal: Principal) {
    const walletActor = this.actors.get('wallet');
    return await walletActor.getWalletBalance(principal);
  }
}
```

### **2. Vue.js Integration**

```typescript
// composables/useAxiaSystem.ts
import { ref, onMounted } from 'vue';
import { AxiaSystemService } from '../services/axiaSystem';

export function useAxiaSystem() {
  const service = ref<AxiaSystemService | null>(null);
  const isConnected = ref(false);
  const loading = ref(true);

  onMounted(async () => {
    try {
      service.value = new AxiaSystemService();
      await service.value.initialize();
      isConnected.value = true;
    } catch (error) {
      console.error('Failed to initialize AxiaSystem:', error);
    } finally {
      loading.value = false;
    }
  });

  return {
    service: service.value,
    isConnected,
    loading
  };
}
```

### **3. Svelte Integration**

```typescript
// stores/axiaSystem.ts
import { writable } from 'svelte/store';
import { AxiaSystemService } from '../services/axiaSystem';

function createAxiaSystemStore() {
  const { subscribe, set, update } = writable({
    service: null as AxiaSystemService | null,
    isConnected: false,
    users: [],
    currentUser: null
  });

  return {
    subscribe,
    async initialize() {
      const service = new AxiaSystemService();
      await service.initialize();
      
      update(state => ({
        ...state,
        service,
        isConnected: true
      }));
    },
    async createUser(userData: CreateUserRequest) {
      // Implementation
    }
  };
}

export const axiaSystem = createAxiaSystemStore();
```

---

## 🔐 **AUTHENTICATION PATTERNS**

### **1. Internet Identity Integration**

```typescript
import { AuthClient } from '@dfinity/auth-client';

class AuthService {
  private authClient: AuthClient | null = null;

  async initialize() {
    this.authClient = await AuthClient.create();
  }

  async loginWithInternetIdentity(): Promise<Principal | null> {
    if (!this.authClient) return null;

    return new Promise((resolve) => {
      this.authClient!.login({
        identityProvider: 'https://identity.ic0.app',
        onSuccess: () => {
          const identity = this.authClient!.getIdentity();
          resolve(identity.getPrincipal());
        },
        onError: () => resolve(null)
      });
    });
  }

  async logout() {
    if (this.authClient) {
      await this.authClient.logout();
    }
  }
}
```

### **2. Traditional Login Integration**

```typescript
// Combined authentication approach
async function authenticateUser(credentials: LoginCredentials) {
  const userService = new UserService();
  await userService.initialize();

  // Try traditional login first
  const loginResult = await userService.validateLogin(credentials);
  
  if ('ok' in loginResult) {
    // Ensure complete user ecosystem exists
    const principal = loginResult.ok.id;
    await userService.ensureIdentityAndWallet(principal, [credentials.email], [credentials.username]);
    
    return {
      success: true,
      user: loginResult.ok,
      principal
    };
  }

  return { success: false, error: loginResult.err };
}
```

---

## 📊 **REAL-TIME MONITORING APIS**

### **System Health Dashboard**

```typescript
// Real-time health monitoring
class SystemMonitor {
  async getSystemHealth() {
    const health = await Promise.allSettled([
      this.getCanisterHealth('user'),
      this.getCanisterHealth('wallet'),
      this.getCanisterHealth('ai_router'),
      this.getBridgeHealth()
    ]);

    return {
      user: health[0].status === 'fulfilled' ? health[0].value : null,
      wallet: health[1].status === 'fulfilled' ? health[1].value : null,
      aiRouter: health[2].status === 'fulfilled' ? health[2].value : null,
      bridge: health[3].status === 'fulfilled' ? health[3].value : null,
      overall: health.every(h => h.status === 'fulfilled') ? 'healthy' : 'degraded'
    };
  }

  private async getCanisterHealth(canisterName: string) {
    const actor = this.actors.get(canisterName);
    if (!actor.healthCheck) return { status: 'unknown' };
    
    try {
      const health = await actor.healthCheck();
      return { status: 'healthy', data: health };
    } catch (error) {
      return { status: 'error', error: error.toString() };
    }
  }

  private async getBridgeHealth() {
    try {
      const response = await fetch('/api/bridge/health');
      const health = await response.json();
      return { status: 'healthy', data: health };
    } catch (error) {
      return { status: 'error', error: error.toString() };
    }
  }
}
```

---

## 🚀 **DEPLOYMENT CONFIGURATION**

### **Environment Configuration**

```typescript
// config/environment.ts
export const ENV_CONFIG = {
  // Network Configuration
  NETWORK: process.env.NODE_ENV === 'production' ? 'mainnet' : 'local',
  IC_HOST: process.env.NODE_ENV === 'production' 
    ? 'https://ic0.app' 
    : 'http://localhost:4943',

  // Canister IDs (Production)
  CANISTER_IDS: {
    user: 'xad5d-bh777-77774-qaaia-cai',
    wallet: 'cuj6u-c4aaa-aaaaa-qaajq-cai',
    identity: 'asrmz-lmaaa-aaaaa-qaaeq-cai',
    ai_router: 'ucwa4-rx777-77774-qaada-cai',
    payment: 'a4tbr-q4aaa-aaaaa-qaafq-cai'
  },

  // Authentication
  II_URL: 'https://identity.ic0.app',
  
  // Bridge Configuration
  BRIDGE_HEALTH_URL: '/api/bridge/health',
  BRIDGE_CALLS_URL: '/api/bridge/calls'
};
```

### **Build Configuration**

```javascript
// vite.config.js / webpack.config.js
export default defineConfig({
  plugins: [/* your framework plugins */],
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
  optimizeDeps: {
    include: ['@dfinity/agent', '@dfinity/auth-client', '@dfinity/principal']
  }
});
```

---

## 🎯 **QUICK START FOR FRONTEND DEVELOPERS**

### **1. Install Dependencies**

```bash
npm install @dfinity/agent @dfinity/auth-client @dfinity/principal @dfinity/candid
```

### **2. Copy Interface Declarations**

```bash
# Copy Candid declarations for each canister
cp -r src/declarations/ frontend/src/declarations/
```

### **3. Initialize Service**

```typescript
import { AxiaSystemService } from './services/axiaSystem';

const axiaSystem = new AxiaSystemService();
await axiaSystem.initialize();

// Ready to use!
const users = await axiaSystem.listAllUsers(false);
```

### **4. Handle Authentication**

```typescript
// Option 1: Internet Identity
const principal = await authService.loginWithInternetIdentity();

// Option 2: Traditional Login
const result = await axiaSystem.authenticateUser({
  email: 'user@example.com',
  password: 'hashedPassword'
});
```

---

## 🏆 **KEY ADVANTAGES FOR FRONTEND TEAMS**

### **✅ Type Safety**
- Full TypeScript support with Candid-generated types
- Compile-time API validation
- IDE autocomplete for all methods

### **✅ Real-time Capabilities**
- WebSocket connections for live updates
- Reactive state management
- Push notification support

### **✅ Blockchain Native**
- Direct canister communication
- No traditional REST overhead
- Built-in authentication with Internet Identity

### **✅ Multi-Protocol Support**
- Primary: ICP Candid for blockchain operations
- Secondary: HTTP/JSON for monitoring
- Bridge: FFI for external system integration

### **✅ Auto-Provisioning**
- Single user creation automatically sets up complete ecosystem
- Self-healing architecture repairs missing components
- Comprehensive error handling and recovery

---

## 📞 **FRONTEND DEVELOPER SUPPORT**

### **Essential Files to Copy:**
1. `/documentation/FRONTEND_API_REFERENCE.md` - Complete API reference
2. `/documentation/FRONTEND_INTEGRATION_GUIDE.md` - Step-by-step integration
3. `/src/declarations/` - All Candid type definitions
4. `/documentation/API_QUICK_REFERENCE.md` - Quick start examples

### **Live Examples:**
- **User Dashboard**: Complete user management interface
- **Wallet Interface**: Real-time balance and transaction monitoring  
- **Bridge Panel**: System health and monitoring dashboard
- **AI Integration**: Real-time AI communication examples

---

**🌟 AxiaSystem provides a cutting-edge blockchain-native API architecture that's more powerful and secure than traditional REST or GraphQL, with comprehensive frontend integration support!**

**Status**: ✅ **PRODUCTION READY**  
**Integration**: 🔗 **COMPLETE**  
**Support**: 🚀 **COMPREHENSIVE DOCUMENTATION**
