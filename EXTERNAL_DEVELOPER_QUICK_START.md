# 🔗 External Developer API Quick Reference

**For Frontend Teams & External Integrators**

---

## 🎯 **TL;DR: What Type of API?**

**AxiaSystem is NOT REST or GraphQL.** It uses:

1. **🏆 Primary: ICP Candid Protocol** (Blockchain-native)
2. **🌐 Secondary: HTTP/JSON** (Bridge monitoring)
3. **⚡ Real-time: WebSocket** (Live updates)

---

## 🚀 **Getting Started in 5 Minutes**

### **1. Install Dependencies**
```bash
npm install @dfinity/agent @dfinity/auth-client @dfinity/principal
```

### **2. Basic Connection**
```typescript
import { Actor, HttpAgent } from '@dfinity/agent';

// Connect to AxiaSystem
const agent = new HttpAgent({ host: 'https://ic0.app' });
const userActor = Actor.createActor(userIdlFactory, {
  agent,
  canisterId: 'xad5d-bh777-77774-qaaia-cai' // User system
});

// Make API call
const result = await userActor.createUser('alice', 'alice@example.com', 'password123');
```

### **3. Complete Integration Example**
```typescript
class AxiaSystemClient {
  private actors = new Map();
  
  async initialize() {
    const agent = new HttpAgent({ host: 'https://ic0.app' });
    
    // Initialize all systems
    this.actors.set('user', Actor.createActor(userIdl, {
      agent, canisterId: 'xad5d-bh777-77774-qaaia-cai'
    }));
    
    this.actors.set('wallet', Actor.createActor(walletIdl, {
      agent, canisterId: 'cuj6u-c4aaa-aaaaa-qaajq-cai'
    }));
  }
  
  // Create user (auto-creates wallet + identity)
  async createUser(username, email, password) {
    const userActor = this.actors.get('user');
    return await userActor.createUser(username, email, password);
  }
  
  // Get user balance
  async getBalance(userPrincipal) {
    const walletActor = this.actors.get('wallet');
    return await walletActor.getWalletBalance(userPrincipal);
  }
}
```

---

## 📊 **Core APIs Available**

| System | Canister ID | Key Methods |
|--------|-------------|-------------|
| **User Management** | `xad5d-bh777-77774-qaaia-cai` | `createUser()`, `validateLogin()`, `getUserById()` |
| **Wallet System** | `cuj6u-c4aaa-aaaaa-qaajq-cai` | `getWalletBalance()`, `transferTokens()`, `getTransactionHistory()` |
| **AI Router** | `ucwa4-rx777-77774-qaada-cai` | `submit()`, `poll()`, `deliver()`, `pullMessages()` |
| **Identity System** | `asrmz-lmaaa-aaaaa-qaaeq-cai` | `getIdentity()`, `createIdentity()`, `addDeviceKey()` |
| **Payment System** | `a4tbr-q4aaa-aaaaa-qaafq-cai` | `processPayment()`, `getPaymentHistory()` |

---

## 🔐 **Authentication Options**

### **Option 1: Internet Identity (Recommended)**
```typescript
import { AuthClient } from '@dfinity/auth-client';

const authClient = await AuthClient.create();
await authClient.login({
  identityProvider: 'https://identity.ic0.app',
  onSuccess: () => {
    const principal = authClient.getIdentity().getPrincipal();
    // Use principal for API calls
  }
});
```

### **Option 2: Traditional Login**
```typescript
// Login with username/email + password
const result = await userActor.validateLogin(
  [], // principal (optional)
  ['alice@example.com'], // email
  ['password123'] // password
);

if ('ok' in result) {
  const user = result.ok;
  const principal = user.id;
  // Use principal for subsequent API calls
}
```

---

## 🌐 **HTTP/JSON APIs (Bridge Monitoring)**

### **System Health**
```bash
GET https://your-domain.com/api/bridge/health
```
```json
{
  "status": "healthy",
  "uptime": 1755542140098,
  "lastCall": "2024-12-20T10:30:45Z",
  "errorCount": 0
}
```

### **Recent API Calls**
```bash
GET https://your-domain.com/api/bridge/calls
```
```json
{
  "recentCalls": [
    {
      "timestamp": "2024-12-20T10:30:45Z",
      "function": "createUser",
      "success": true,
      "responseTime": 150
    }
  ]
}
```

---

## 💡 **Common Integration Patterns**

### **React Hook**
```typescript
function useAxiaSystem() {
  const [client, setClient] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    async function init() {
      const axiaClient = new AxiaSystemClient();
      await axiaClient.initialize();
      setClient(axiaClient);
      setLoading(false);
    }
    init();
  }, []);
  
  return { client, loading };
}
```

### **Vue Composable**
```typescript
export function useAxiaSystem() {
  const client = ref(null);
  const isConnected = ref(false);
  
  onMounted(async () => {
    client.value = new AxiaSystemClient();
    await client.value.initialize();
    isConnected.value = true;
  });
  
  return { client, isConnected };
}
```

---

## 🎯 **Real-World Usage Examples**

### **User Registration Flow**
```typescript
async function registerUser(userData) {
  // 1. Create user (auto-creates wallet + identity)
  const userResult = await client.createUser(
    userData.username,
    userData.email,
    userData.password
  );
  
  if ('ok' in userResult) {
    const user = userResult.ok;
    
    // 2. Verify complete setup
    const identity = await client.getIdentity(user.id);
    const balance = await client.getBalance(user.id);
    
    return {
      success: true,
      user,
      identity,
      balance
    };
  }
  
  return { success: false, error: userResult.err };
}
```

### **Payment Processing**
```typescript
async function processPayment(fromPrincipal, toPrincipal, amount) {
  // 1. Check balance
  const balance = await client.getBalance(fromPrincipal);
  if (balance < amount) {
    return { success: false, error: 'Insufficient funds' };
  }
  
  // 2. Process payment
  const paymentResult = await client.processPayment(
    fromPrincipal,
    toPrincipal,
    amount
  );
  
  return paymentResult;
}
```

### **AI-Powered Analysis**
```typescript
async function requestAIAnalysis(userPrincipal, analysisData) {
  // 1. Create session
  const sessionResult = await client.createAISession('AISubmitter');
  if ('err' in sessionResult) return sessionResult;
  
  const sessionId = sessionResult.ok;
  
  // 2. Submit analysis request
  const message = {
    id: generateId(),
    correlation_id: generateCorrelationId(),
    message_type: { IntelligenceRequest: null },
    payload: {
      content_type: 'application/json',
      data: new TextEncoder().encode(JSON.stringify(analysisData)),
      encoding: 'utf-8',
      compression: []
    },
    priority: { High: null },
    timestamp: Date.now() * 1000000,
    security_context: {
      principal_id: userPrincipal.toString(),
      permissions: ['ai:analyze'],
      encryption_key: [],
      signature: [],
      timestamp: Date.now() * 1000000
    },
    metadata: []
  };
  
  const submitResult = await client.submitAIMessage(message, sessionId);
  return submitResult;
}
```

---

## 🛠️ **Development Tools**

### **Type Definitions**
All APIs are fully typed with TypeScript. Copy these files:
- `/src/declarations/user/user.did.js` - User system types
- `/src/declarations/wallet/wallet.did.js` - Wallet types  
- `/src/declarations/ai_router/ai_router.did.js` - AI system types

### **Testing**
```typescript
// Test environment setup
const testClient = new AxiaSystemClient();
await testClient.initialize({
  host: 'http://localhost:4943', // Local development
  fetchRootKey: true // Required for local testing
});
```

### **Error Handling**
```typescript
try {
  const result = await client.createUser(username, email, password);
  
  if ('ok' in result) {
    // Success case
    const user = result.ok;
  } else {
    // Error case
    console.error('API Error:', result.err);
  }
} catch (error) {
  // Network/connection error
  console.error('Connection Error:', error);
}
```

---

## 📞 **Support & Resources**

### **Complete Documentation**
- `FRONTEND_API_ARCHITECTURE_GUIDE.md` - Full technical details
- `FRONTEND_INTEGRATION_GUIDE.md` - Step-by-step setup
- `FRONTEND_API_REFERENCE.md` - Complete method reference

### **Live Examples**
- User management dashboard
- Real-time wallet interface
- AI integration examples
- System monitoring panels

### **Development Environment**
```bash
# Clone and run locally
git clone <repository>
cd AxiaSystem
dfx start --background
dfx deploy
npm start
```

---

## 🌟 **Why Not REST/GraphQL?**

**AxiaSystem uses blockchain-native ICP Candid because:**

✅ **Direct blockchain communication** - No intermediary servers  
✅ **Built-in authentication** - Internet Identity integration  
✅ **Type safety** - Compile-time API validation  
✅ **Real-time capabilities** - Native WebSocket support  
✅ **Decentralized** - No single point of failure  
✅ **Auto-provisioning** - One call creates complete user ecosystem  

**The result**: More secure, faster, and more reliable than traditional APIs!

---

**🚀 Ready to integrate? Start with the basic connection example above!**
