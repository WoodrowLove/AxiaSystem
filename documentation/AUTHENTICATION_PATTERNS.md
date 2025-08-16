# Authentication Patterns for AxiaSystem User Canister

## 🔐 Overview
This document outlines the authentication patterns and implementation strategies for integrating with the AxiaSystem User Canister. It covers both traditional email/password authentication and Internet Identity integration.

## 🏗️ Authentication Architecture

### Supported Authentication Methods

1. **Email/Password Authentication**
   - Traditional credentials-based login
   - Password hashing handled by canister
   - Email validation and uniqueness enforcement

2. **Internet Identity (II) Authentication**
   - Decentralized identity on Internet Computer
   - Principal-based authentication
   - Device registration for multi-device access

3. **Hybrid Authentication**
   - Users can link both email/password and II
   - Device keys for multiple authentication methods
   - Seamless switching between auth methods

## 🔑 Authentication Flow Patterns

### Pattern 1: Email/Password Authentication

```typescript
// 1. Initialize service
await userService.initialize();

// 2. Collect credentials
const credentials = {
  email: 'user@example.com',
  password: 'userPassword123'
};

// 3. Validate login
const result = await userService.validateLogin(credentials);

// 4. Handle response
if ('ok' in result) {
  // Authentication successful
  const user = result.ok;
  userActions.setUser(user);
  
  // Optional: Store session info
  localStorage.setItem('userSession', JSON.stringify({
    userId: user.id.toString(),
    lastLogin: Date.now()
  }));
} else {
  // Authentication failed
  userActions.setError(result.err);
}
```

### Pattern 2: Internet Identity Authentication

```typescript
// 1. Initialize auth client
const authClient = await AuthClient.create();

// 2. Trigger II login
const principal = await new Promise((resolve) => {
  authClient.login({
    identityProvider: ENV_CONFIG.II_URL,
    onSuccess: () => {
      const identity = authClient.getIdentity();
      resolve(identity.getPrincipal());
    },
    onError: () => resolve(null)
  });
});

// 3. Validate with canister
if (principal) {
  const result = await userService.validateLogin({ principal });
  
  if ('ok' in result) {
    userActions.setUser(result.ok);
  } else {
    // User not registered with this principal
    // Option 1: Register new user
    // Option 2: Link to existing account
    handleUnregisteredPrincipal(principal);
  }
}
```

### Pattern 3: Account Linking

```typescript
// Link Internet Identity to existing email account
async function linkInternetIdentity(email: string, password: string) {
  // 1. Authenticate with email/password
  const loginResult = await userService.validateLogin({ email, password });
  
  if ('ok' in loginResult) {
    const user = loginResult.ok;
    
    // 2. Get II principal
    const principal = await userService.loginWithInternetIdentity();
    
    if (principal) {
      // 3. Register device (II principal) for user
      const linkResult = await userService.registerDevice(user.id, principal);
      
      if ('ok' in linkResult) {
        console.log('Internet Identity linked successfully');
      } else {
        console.error('Failed to link II:', linkResult.err);
      }
    }
  }
}
```

## 🛡️ Security Patterns

### Secure Session Management

```typescript
// Session interface
interface UserSession {
  userId: string;
  principal?: string;
  email?: string;
  loginMethod: 'email' | 'ii' | 'hybrid';
  loginTime: number;
  expiresAt: number;
}

class SessionManager {
  private readonly SESSION_KEY = 'axia_user_session';
  private readonly SESSION_DURATION = 24 * 60 * 60 * 1000; // 24 hours

  saveSession(user: User, loginMethod: 'email' | 'ii' | 'hybrid'): void {
    const session: UserSession = {
      userId: user.id.toString(),
      principal: user.deviceKeys.length > 0 ? user.deviceKeys[0].toString() : undefined,
      email: user.email,
      loginMethod,
      loginTime: Date.now(),
      expiresAt: Date.now() + this.SESSION_DURATION
    };

    // Encrypt session data (implement encryption)
    const encryptedSession = this.encryptSession(session);
    localStorage.setItem(this.SESSION_KEY, encryptedSession);
  }

  getSession(): UserSession | null {
    const encrypted = localStorage.getItem(this.SESSION_KEY);
    if (!encrypted) return null;

    try {
      const session = this.decryptSession(encrypted);
      
      // Check expiration
      if (Date.now() > session.expiresAt) {
        this.clearSession();
        return null;
      }

      return session;
    } catch {
      this.clearSession();
      return null;
    }
  }

  clearSession(): void {
    localStorage.removeItem(this.SESSION_KEY);
  }

  private encryptSession(session: UserSession): string {
    // Implement proper encryption
    return btoa(JSON.stringify(session));
  }

  private decryptSession(encrypted: string): UserSession {
    // Implement proper decryption
    return JSON.parse(atob(encrypted));
  }
}
```

### Principal Validation

```typescript
// Validate principal format and authenticity
function validatePrincipal(principalText: string): boolean {
  try {
    const principal = Principal.fromText(principalText);
    
    // Basic validation
    if (principal.isAnonymous()) {
      return false;
    }

    // Additional checks
    const text = principal.toString();
    return text.length > 10 && text.includes('-');
  } catch {
    return false;
  }
}

// Verify principal ownership
async function verifyPrincipalOwnership(principal: Principal): Promise<boolean> {
  try {
    // Check if user can perform authenticated action with this principal
    const result = await userService.isUserRegistered(principal);
    return result;
  } catch {
    return false;
  }
}
```

## 🔄 State Management Patterns

### Authentication State Store

```typescript
// Authentication store with comprehensive state
interface AuthState {
  // User data
  currentUser: User | null;
  isAuthenticated: boolean;
  
  // Authentication method
  authMethod: 'email' | 'ii' | 'hybrid' | null;
  
  // Session management
  sessionExpiry: number | null;
  lastActivity: number;
  
  // Loading states
  isLoggingIn: boolean;
  isRegistering: boolean;
  isLinking: boolean;
  
  // Error handling
  authError: string | null;
  
  // Device management
  registeredDevices: Principal[];
  currentDevice: Principal | null;
}

const authStore = writable<AuthState>({
  currentUser: null,
  isAuthenticated: false,
  authMethod: null,
  sessionExpiry: null,
  lastActivity: Date.now(),
  isLoggingIn: false,
  isRegistering: false,
  isLinking: false,
  authError: null,
  registeredDevices: [],
  currentDevice: null
});

// Authentication actions
export const authActions = {
  async loginWithEmail(email: string, password: string) {
    authStore.update(state => ({ ...state, isLoggingIn: true, authError: null }));
    
    try {
      const result = await userService.validateLogin({ email, password });
      
      if ('ok' in result) {
        authStore.update(state => ({
          ...state,
          currentUser: result.ok,
          isAuthenticated: true,
          authMethod: 'email',
          sessionExpiry: Date.now() + SESSION_DURATION,
          lastActivity: Date.now(),
          isLoggingIn: false
        }));
        
        sessionManager.saveSession(result.ok, 'email');
      } else {
        authStore.update(state => ({
          ...state,
          authError: result.err,
          isLoggingIn: false
        }));
      }
    } catch (error) {
      authStore.update(state => ({
        ...state,
        authError: `Login failed: ${error}`,
        isLoggingIn: false
      }));
    }
  },

  async loginWithII() {
    authStore.update(state => ({ ...state, isLoggingIn: true, authError: null }));
    
    try {
      const principal = await userService.loginWithInternetIdentity();
      
      if (principal) {
        const result = await userService.validateLogin({ principal });
        
        if ('ok' in result) {
          authStore.update(state => ({
            ...state,
            currentUser: result.ok,
            isAuthenticated: true,
            authMethod: 'ii',
            currentDevice: principal,
            sessionExpiry: Date.now() + SESSION_DURATION,
            lastActivity: Date.now(),
            isLoggingIn: false
          }));
          
          sessionManager.saveSession(result.ok, 'ii');
        } else {
          authStore.update(state => ({
            ...state,
            authError: result.err,
            isLoggingIn: false
          }));
        }
      } else {
        authStore.update(state => ({
          ...state,
          authError: 'Internet Identity login cancelled',
          isLoggingIn: false
        }));
      }
    } catch (error) {
      authStore.update(state => ({
        ...state,
        authError: `II login failed: ${error}`,
        isLoggingIn: false
      }));
    }
  },

  async logout() {
    try {
      await userService.logout();
      sessionManager.clearSession();
      
      authStore.set({
        currentUser: null,
        isAuthenticated: false,
        authMethod: null,
        sessionExpiry: null,
        lastActivity: Date.now(),
        isLoggingIn: false,
        isRegistering: false,
        isLinking: false,
        authError: null,
        registeredDevices: [],
        currentDevice: null
      });
    } catch (error) {
      console.error('Logout error:', error);
    }
  }
};
```

## 🎯 Advanced Authentication Patterns

### Auto-login on App Start

```typescript
// Auto-authenticate user on app initialization
async function initializeAuth() {
  const session = sessionManager.getSession();
  
  if (session) {
    try {
      // Verify session is still valid
      const principal = Principal.fromText(session.userId);
      const isRegistered = await userService.isUserRegistered(principal);
      
      if (isRegistered) {
        const result = await userService.getUserById(principal);
        
        if ('ok' in result) {
          authActions.restoreSession(result.ok, session.loginMethod);
          return;
        }
      }
    } catch (error) {
      console.error('Session restoration failed:', error);
    }
  }
  
  // Clear invalid session
  sessionManager.clearSession();
}
```

### Multi-Device Authentication

```typescript
// Handle multiple device authentication
async function authenticateDevice() {
  const currentPrincipal = userService.getCurrentPrincipal();
  
  if (currentPrincipal) {
    // Check if this device is registered
    const result = await userService.validateLogin({ principal: currentPrincipal });
    
    if ('ok' in result) {
      return result.ok;
    } else {
      // Device not registered, prompt for account linking
      return await promptDeviceRegistration(currentPrincipal);
    }
  }
  
  return null;
}

async function promptDeviceRegistration(devicePrincipal: Principal) {
  // Show UI to link device to existing account
  const credentials = await showDeviceLinkingModal();
  
  if (credentials) {
    const loginResult = await userService.validateLogin(credentials);
    
    if ('ok' in loginResult) {
      const user = loginResult.ok;
      
      // Register this device
      const linkResult = await userService.registerDevice(user.id, devicePrincipal);
      
      if ('ok' in linkResult) {
        return user;
      }
    }
  }
  
  return null;
}
```

### Password Strength Validation

```typescript
interface PasswordPolicy {
  minLength: number;
  requireUppercase: boolean;
  requireLowercase: boolean;
  requireNumbers: boolean;
  requireSpecialChars: boolean;
}

const DEFAULT_PASSWORD_POLICY: PasswordPolicy = {
  minLength: 8,
  requireUppercase: true,
  requireLowercase: true,
  requireNumbers: true,
  requireSpecialChars: true
};

function validatePassword(password: string, policy = DEFAULT_PASSWORD_POLICY): {
  isValid: boolean;
  errors: string[];
} {
  const errors: string[] = [];
  
  if (password.length < policy.minLength) {
    errors.push(`Password must be at least ${policy.minLength} characters long`);
  }
  
  if (policy.requireUppercase && !/[A-Z]/.test(password)) {
    errors.push('Password must contain at least one uppercase letter');
  }
  
  if (policy.requireLowercase && !/[a-z]/.test(password)) {
    errors.push('Password must contain at least one lowercase letter');
  }
  
  if (policy.requireNumbers && !/\d/.test(password)) {
    errors.push('Password must contain at least one number');
  }
  
  if (policy.requireSpecialChars && !/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
    errors.push('Password must contain at least one special character');
  }
  
  return {
    isValid: errors.length === 0,
    errors
  };
}
```

## 🚨 Error Handling Patterns

### Comprehensive Error Types

```typescript
enum AuthErrorType {
  INVALID_CREDENTIALS = 'invalid_credentials',
  USER_NOT_FOUND = 'user_not_found',
  USER_INACTIVE = 'user_inactive',
  NETWORK_ERROR = 'network_error',
  CANISTER_ERROR = 'canister_error',
  SESSION_EXPIRED = 'session_expired',
  DEVICE_NOT_REGISTERED = 'device_not_registered',
  II_LOGIN_FAILED = 'ii_login_failed',
  REGISTRATION_FAILED = 'registration_failed'
}

interface AuthError {
  type: AuthErrorType;
  message: string;
  details?: any;
  timestamp: number;
}

// Error handling with retry logic
async function handleAuthError(error: AuthError): Promise<void> {
  switch (error.type) {
    case AuthErrorType.SESSION_EXPIRED:
      // Clear session and redirect to login
      await authActions.logout();
      window.location.href = '/login';
      break;
      
    case AuthErrorType.NETWORK_ERROR:
      // Retry with exponential backoff
      await retryWithBackoff(() => authActions.refreshSession());
      break;
      
    case AuthErrorType.DEVICE_NOT_REGISTERED:
      // Prompt for device registration
      await promptDeviceRegistration(userService.getCurrentPrincipal());
      break;
      
    default:
      // Show error to user
      authStore.update(state => ({ ...state, authError: error.message }));
  }
}
```

## 📱 Mobile Authentication Considerations

### Touch ID / Face ID Integration

```typescript
// Biometric authentication wrapper
async function authenticateWithBiometrics(): Promise<boolean> {
  if (!window.PublicKeyCredential) {
    console.log('WebAuthn not supported');
    return false;
  }
  
  try {
    // Use WebAuthn for biometric authentication
    const credential = await navigator.credentials.create({
      publicKey: {
        challenge: new Uint8Array(32),
        rp: { name: 'AxiaSystem' },
        user: {
          id: new Uint8Array(16),
          name: 'user@example.com',
          displayName: 'User'
        },
        pubKeyCredParams: [{ alg: -7, type: 'public-key' }],
        authenticatorSelection: {
          userVerification: 'required'
        }
      }
    });
    
    return credential !== null;
  } catch (error) {
    console.error('Biometric auth failed:', error);
    return false;
  }
}
```

## 🔒 Security Best Practices

### 1. **Input Validation**
- Always validate email format
- Enforce strong password policies
- Sanitize all user inputs

### 2. **Session Security**
- Use secure session storage
- Implement session timeouts
- Clear sessions on logout

### 3. **Principal Security**
- Validate principal format
- Verify principal ownership
- Never trust client-side principals

### 4. **Error Information**
- Don't leak sensitive information in errors
- Log security events server-side
- Implement rate limiting

### 5. **Transport Security**
- Use HTTPS in production
- Validate certificate chains
- Implement CSRF protection

This authentication pattern guide provides a comprehensive foundation for implementing secure, user-friendly authentication in your AxiaSystem frontend application.
