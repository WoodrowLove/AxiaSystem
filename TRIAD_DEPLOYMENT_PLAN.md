# Triad Deployment Plan

**Objective**: Complete deployment of Triad (User, Identity, Wallet) trio with communication layer integration for AxiaSystem mainnet readiness.

## A. Pre-Deploy Checklist

### Mainnet Environment Setup
- [x] Networks.json configured for mainnet
- [x] Canister IDs reserved for User/Identity/Wallet
- [x] Identity.pem for deployment principal ready
- [x] Circuit breakers configured and tested
- [x] Admin canister integration complete
- [x] AI Router integration validated
- [x] Communication layer notification system deployed

### Code Readiness
- [x] All compilation warnings resolved
- [x] 49/50 communication layer tests passing
- [x] Chaos engineering scenarios tested
- [x] PII protection Q1 policy implemented
- [x] Audit retention and RTBF compliance verified

---

## B. Deployment Sequence

### Phase 1: Core Infrastructure
1. **Identity Canister**: Deploy first as other canisters depend on it
2. **User Canister**: Links to Identity for session management
3. **Wallet Canister**: Authenticates via Identity sessions
4. **Admin Canister**: Configure permissions and operational controls

### Phase 2: Communication Integration  
1. **Notification System**: Deploy communication layer components
2. **AI Router**: Enable AI integration with notification routing
3. **Bridge Components**: Connect external systems via notification bridge
4. **Monitoring**: Deploy observability dashboard

### Phase 3: Validation & Smoke Testing
1. **Triad Creation**: Execute T1.1-T1.3 from test strategy
2. **Session Management**: Execute T2.1-T2.4 from test strategy  
3. **Wallet Operations**: Execute T3.1-T3.4 from test strategy
4. **Integration Testing**: Execute T5.1-T5.3 from test strategy

---

## C. Deployment Commands

### Environment Preparation
```bash
# Switch to mainnet configuration
dfx identity use woodrowlove
dfx --network ic canister create --all

# Build all canisters
dfx build

# Deploy in dependency order
dfx deploy --network ic identity
dfx deploy --network ic user  
dfx deploy --network ic wallet
dfx deploy --network ic admin
dfx deploy --network ic notification
dfx deploy --network ic ai_router
```

### Smoke Tests Post-Deploy
```bash
# Test 1: Verify canister status
dfx canister --network ic status identity
dfx canister --network ic status user
dfx canister --network ic status wallet

# Test 2: Create test Triad
dfx canister --network ic call user createUser '(record { 
  email="deploy-test@axia.io"; 
  username="deployment_validator"; 
  idempotencyKey="deploy-001" 
})'

# Test 3: Validate session system
dfx canister --network ic call identity startSession '(
  principal "[USER_PRINCIPAL]", 
  "wallet:read", 
  300
)'

# Test 4: Test notification system
dfx canister --network ic call notification validateMessage '(record {
  content="Deploy test notification";
  category=#system;
  priority=#medium;
  userId="[TEST_USER_ID]"
})'
```

---

## D. Monitoring & Observability

### Key Metrics to Track
- **Triad Creation Rate**: createUser() calls per minute
- **Session Success Rate**: Valid vs invalid session attempts
- **Wallet Operation Latency**: p50, p95, p99 response times
- **Notification Throughput**: Messages processed per second
- **Error Rates**: Failed operations by category
- **Circuit Breaker Status**: Open/closed state monitoring

### Alert Thresholds
- Error rate >5% for any operation
- p95 latency >2s for Triad creation
- >100 failed login attempts per minute
- Circuit breaker open for >5 minutes
- Audit log gaps >1 minute

---

## E. Configuration Management

### Mainnet Parameters
```motoko
// Production rate limits
let RATE_LIMIT_PER_IDENTITY = 100; // ops per minute
let SESSION_TIMEOUT_SECONDS = 3600; // 1 hour
let MAX_WALLET_BALANCE = 1_000_000_000; // $1M equivalent

// Notification settings  
let MAX_NOTIFICATION_BATCH = 50;
let NOTIFICATION_RETRY_ATTEMPTS = 3;
let WEBHOOK_TIMEOUT_MS = 5000;

// Audit retention
let AUDIT_RETENTION_DAYS = 2555; // 7 years
let LEGAL_HOLD_MAX_ITEMS = 10000;
```

### Security Hardening
- All sensitive operations require Identity session validation
- PII data encrypted at rest and in transit
- Correlation IDs for all cross-canister operations
- Rate limiting on all public endpoints
- Comprehensive audit logging for compliance

---

## F. Rollback Procedures

### Immediate Rollback Triggers
- >10% error rate on core operations
- Data corruption detected in Triad linkages
- Security breach or unauthorized access
- Performance degradation >300% of baseline

### Rollback Steps
1. **Circuit Breaker Activation**: Disable new operations
2. **Admin Override**: Switch to maintenance mode
3. **Data Preservation**: Snapshot current state
4. **Version Revert**: Deploy previous stable version
5. **Validation**: Run core smoke tests
6. **Re-enable**: Gradual traffic restoration

### Recovery Validation
- All existing Triads remain accessible
- Session authentication restored
- Wallet balances unchanged
- Audit trail integrity maintained
- Notification delivery resumed

---

## G. Success Criteria

### Deployment Success
- All canisters deployed and responding
- Core Triad operations functional
- Communication layer integration working
- Monitoring dashboard operational
- All smoke tests passing

### Production Readiness
- p95 latency <2s for all operations
- >99.9% uptime for core services
- Zero data loss or corruption
- Security audit findings addressed
- Performance within capacity planning

---

## H. Post-Deploy Actions

### Week 1: Intensive Monitoring
- 24/7 on-call rotation
- Daily performance reviews
- Immediate issue escalation
- User feedback collection

### Week 2-4: Stabilization
- Performance optimization
- Bug fixes and minor improvements
- Documentation updates
- Training completion

### Month 2+: Optimization
- Capacity planning updates
- Advanced feature rollout
- Integration with additional systems
- Long-term monitoring baseline establishment
