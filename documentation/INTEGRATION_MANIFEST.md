# AxiaSystem User Canister Integration Manifest

## 🎯 Overview
This manifest provides comprehensive guidance for AI agents and developers to integrate with the AxiaSystem User Management Canister. The system is built on the Internet Computer Protocol (ICP) using Motoko and provides user authentication, profile management, and token attachment capabilities.

## 📋 System Architecture

### Core Components
- **User Canister**: `xad5d-bh777-77774-qaaia-cai` (local: `xobql-2x777-77774-qaaja-cai`)
- **Backend Language**: Motoko
- **Frontend Support**: Svelte + TypeScript
- **Network**: Internet Computer Protocol (ICP)
- **Authentication**: Internet Identity + Traditional Email/Password

### Key Features
- ✅ User Registration & Authentication
- ✅ Profile Management (CRUD operations)
- ✅ Token Attachment System
- ✅ Device Registration for Multi-device Access
- ✅ User Activation/Deactivation
- ✅ Password Reset Functionality
- ✅ NamoraAI Observability Integration

## 🔗 Canister Interface

### Public API Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `createUser` | `(text, text, text) -> (Result)` | Create new user account |
| `getUserById` | `(principal) -> (Result)` | Retrieve user by Principal ID |
| `updateUser` | `(principal, opt text, opt text, opt text) -> (Result)` | Update user profile |
| `validateLogin` | `(opt principal, opt text, opt text) -> (Result)` | Authenticate user login |
| `listAllUsers` | `(bool) -> (Result_2)` | List all users (with/without inactive) |
| `deactivateUser` | `(principal) -> (Result_1)` | Deactivate user account |
| `reactivateUser` | `(principal) -> (Result_1)` | Reactivate user account |
| `deleteUser` | `(principal) -> (Result_1)` | Permanently delete user |
| `resetPassword` | `(principal, text) -> (Result_1)` | Reset user password |
| `registerDevice` | `(principal, principal) -> (Result_1)` | Register device for user |
| `attachTokensToUser` | `(principal, nat, nat) -> (Result_1)` | Attach tokens to user account |
| `isUserRegistered` | `(principal) -> (bool)` | Check if user exists |

### Data Structures

#### User Record
```candid
type User = record {
  id: principal;                    // Unique user identifier
  username: text;                   // Display name
  email: text;                     // Email address (unique)
  hashedPassword: text;            // Hashed password
  deviceKeys: vec principal;       // Registered device principals
  createdAt: int;                  // Creation timestamp (nanoseconds)
  updatedAt: int;                  // Last update timestamp
  icpWallet: opt text;            // Optional ICP wallet address
  tokens: Trie;                   // Token balances (tokenId -> amount)
  isActive: bool;                 // Account status
};
```

#### Result Types
```candid
type Result = variant { ok: User; err: text };
type Result_1 = variant { ok; err: text };
type Result_2 = variant { ok: vec User; err: text };
```

## 🛠 Integration Requirements

### Dependencies
```json
{
  "@dfinity/agent": "^0.19.0",
  "@dfinity/candid": "^0.19.0", 
  "@dfinity/principal": "^0.19.0",
  "@dfinity/identity": "^0.19.0",
  "@dfinity/auth-client": "^0.19.0"
}
```

### Environment Configuration
- **Local Development**: `http://localhost:4943`
- **Production**: `https://ic0.app`
- **Canister ID**: Use environment variable `CANISTER_ID_USER`

### Required Permissions
- Read access to user data
- Write access for user creation/updates
- Principal validation for authentication

## 🔐 Authentication Flow

### Internet Identity Integration
1. Initialize AuthClient
2. Trigger Internet Identity login
3. Extract Principal from identity
4. Call `validateLogin` with Principal
5. Handle success/error responses

### Email/Password Authentication
1. Collect email and password from user
2. Call `validateLogin` with email and password
3. Handle authentication result
4. Store user session data

## 📊 Error Handling

### Common Error Scenarios
- **"User not found"**: Principal/email doesn't exist
- **"Invalid email format"**: Email validation failed
- **"User with this email already exists"**: Duplicate email during registration
- **"Login failed: Invalid email or password"**: Authentication failure
- **"Missing credentials"**: Incomplete login data

### Best Practices
- Always wrap canister calls in try/catch blocks
- Validate input data before sending to canister
- Provide meaningful error messages to users
- Implement retry logic for network failures

## 🎨 Frontend Integration Patterns

### State Management
- Use reactive stores for user state
- Implement loading states for async operations
- Cache user data appropriately
- Handle logout scenarios

### Component Architecture
- Separate authentication components
- User profile management components
- Admin user management interfaces
- Token management displays

## 🔍 Observability Integration

The User Canister emits insights to NamoraAI for:
- User creation events
- Login success/failure tracking
- Profile update monitoring
- Error pattern detection

### Insight Categories
- **info**: Normal operations (user creation, updates)
- **warning**: User deactivation, password resets
- **error**: Failed operations, authentication failures

## 🚀 Quick Start Integration

### Step 1: Initialize Connection
```typescript
import { createActor } from './declarations/user';

const userActor = createActor(CANISTER_ID_USER, {
  agentOptions: {
    host: process.env.DFX_NETWORK === "local" 
      ? "http://localhost:4943" 
      : "https://ic0.app"
  }
});
```

### Step 2: Implement Basic Operations
```typescript
// Create user
const result = await userActor.createUser(username, email, password);

// Login
const loginResult = await userActor.validateLogin(null, [email], [password]);

// Get user
const userResult = await userActor.getUserById(principal);
```

### Step 3: Handle Results
```typescript
if ('ok' in result) {
  // Success - use result.ok
  console.log('User created:', result.ok);
} else {
  // Error - handle result.err
  console.error('Error:', result.err);
}
```

## 📁 File Structure Required

```
src/
├── declarations/user/          # Generated Candid declarations
│   ├── index.js
│   ├── index.d.ts
│   ├── user.did
│   ├── user.did.js
│   └── user.did.d.ts
├── lib/
│   ├── stores/
│   │   └── userStore.ts       # User state management
│   ├── services/
│   │   └── userService.ts     # User canister interface
│   ├── types/
│   │   └── user.ts           # TypeScript interfaces
│   └── components/
│       ├── UserAuth.svelte   # Authentication component
│       ├── UserProfile.svelte # Profile management
│       └── UserManagement.svelte # Admin interface
└── config/
    └── canisters.ts          # Canister configuration
```

## 🔧 Testing Strategy

### Unit Testing
- Test individual canister methods
- Mock canister responses
- Validate input/output types
- Test error scenarios

### Integration Testing
- Test complete authentication flows
- Verify user CRUD operations
- Test token attachment functionality
- Validate error handling

### End-to-End Testing
- Complete user registration flow
- Login/logout scenarios
- Profile management workflows
- Admin operations testing

## 📚 Additional Resources

### Documentation Files
- `FRONTEND_INTEGRATION_GUIDE.md` - Detailed frontend setup
- `AUTHENTICATION_PATTERNS.md` - Auth implementation patterns
- `ERROR_HANDLING_GUIDE.md` - Comprehensive error handling
- `TESTING_EXAMPLES.md` - Testing implementation examples

### Example Implementations
- `user-service-example.ts` - Complete service implementation
- `user-auth-component.svelte` - Authentication component
- `user-management-dashboard.svelte` - Admin dashboard

### Deployment Guides
- Local development setup
- Production deployment checklist
- Environment configuration
- Security considerations

## ⚠️ Security Considerations

### Data Protection
- Passwords are hashed (never store plaintext)
- Principal validation for all operations
- Device key verification for multi-device access
- Secure session management

### Access Control
- User can only modify their own data (unless admin)
- Admin functions require appropriate permissions
- Rate limiting on authentication attempts
- Input validation and sanitization

## 🏷️ Versioning & Updates

### Current Version: 1.0.0
- Stable API interface
- All documented methods supported
- Backward compatibility maintained

### Update Strategy
- API versioning for breaking changes
- Migration guides for updates
- Deprecation notices for obsolete methods
- Clear change documentation

---

**Last Updated**: August 7, 2025  
**Canister Version**: 1.0.0  
**Network**: Internet Computer (Local & Mainnet)  
**Status**: ✅ Production Ready
