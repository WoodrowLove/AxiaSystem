import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Int "mo:base/Int";
import Nat "mo:base/Nat";

import AI "../types/ai_envelope";
import DCV "./data_contract_validator";
import LM "./data_lifecycle_manager";
import CB "./circuit_breaker";
import _PE "../policy/policy_engine";

persistent actor AIRouter {
    
    // Types
    type AIRequest = AI.AIRequest;
    type AIResponse = AI.AIResponse;
    type AIStatus = AI.AIStatus;
    type AuditEntry = AI.AuditEntry;
    
    // Session management
    private var sessionStore: [(Text, SessionInfo)] = [];
    private transient var sessions = HashMap.fromIter<Text, SessionInfo>(sessionStore.vals(), 10, Text.equal, Text.hash);
    
    private var requestStore: [(Text, StoredRequest)] = [];
    private transient var pendingRequests = HashMap.fromIter<Text, StoredRequest>(requestStore.vals(), 100, Text.equal, Text.hash);
    
    private var auditLogStore: [AuditEntry] = [];
    private transient let auditLog = Buffer.fromArray<AuditEntry>(auditLogStore);
    
    // Configuration
    private transient let MAX_SESSION_DURATION_MS: Nat = 4 * 60 * 60 * 1000; // 4 hours
    private transient let _MAX_REQUEST_TIMEOUT_MS: Nat = 150; // 150ms budget
    private transient let _MAX_RETRY_COUNT: Nat = 3;
    
    // Circuit breaker configuration
    private var circuitBreaker = CB.createCircuitBreaker({
        failureThreshold = 5;     // Open circuit after 5 failures
        successThreshold = 3;     // Close circuit after 3 successes in half-open
        timeoutThreshold = 10;    // Timeout threshold
        resetTimeoutMs = 60_000;  // 1 minute cooldown before half-open
    });

    // Quota management
    private var rateLimitStore: [(Text, RateLimitInfo)] = [];
    private transient var rateLimits = HashMap.fromIter<Text, RateLimitInfo>(rateLimitStore.vals(), 10, Text.equal, Text.hash);
    
    private type RateLimitInfo = {
        requestCount: Nat;
        windowStartMs: Int;
        lastRequestMs: Int;
    };
    
    // Core types
    private type SessionInfo = {
        principalId: Text;
        role: SessionRole;
        createdAt: Time.Time;
        expiresAt: Time.Time;
        rotationToken: Text;
    };
    
    private type SessionRole = {
        #AISubmitter;
        #AIDeliverer;
        #AIService;
    };
    
    private type StoredRequest = {
        request: AIRequest;
        submittedAt: Time.Time;
        status: RequestStatus;
        retryCount: Nat;
    };
    
    private type RequestStatus = {
        #Pending;
        #Processing;
        #Completed: AIResponse;
        #Failed: Text;
        #TimedOut;
    };
    
    // AI Router Core Interface
    public shared(msg) func submit(request: AIRequest) : async Result.Result<Text, Text> {
        let caller = Principal.toText(msg.caller);
        let now = Time.now();
        
        // 0. Circuit breaker check
        if (not CB.shouldAllowRequest(circuitBreaker)) {
            auditAction("SUBMIT_CIRCUIT_OPEN", caller, request.correlationId, "Circuit breaker is open");
            return #err("Service temporarily unavailable - circuit breaker is open");
        };
        
        // 1. Rate limiting check
        switch (checkRateLimit(caller, now)) {
            case (#err(error)) {
                auditAction("SUBMIT_RATE_LIMITED", caller, request.correlationId, error);
                return #err("Rate limit exceeded: " # error);
            };
            case (#ok(_)) {};
        };
        
        // 2. Validate session
        switch (validateSessionWithRole(request.sessionId, #AISubmitter)) {
            case (#err(error)) { return #err("Session validation failed: " # error) };
            case (#ok(_)) {};
        };
        
        // 3. Validate data contract (Q1 policy enforcement)
        switch (DCV.validateRequest(request)) {
            case (#err(error)) { 
                auditAction("SUBMIT_REJECTED", caller, "PII_VIOLATION", error);
                return #err("Data contract violation: " # error) 
            };
            case (#ok(_)) {};
        };
        
        // 4. Check idempotency
        switch (pendingRequests.get(request.idempotencyKey)) {
            case (?existing) {
                auditAction("SUBMIT_IDEMPOTENT", caller, request.correlationId, "Returning existing request");
                return #ok(existing.request.correlationId);
            };
            case null {};
        };
        
        // 5. Store request
        let storedRequest: StoredRequest = {
            request = request;
            submittedAt = Time.now();
            status = #Pending;
            retryCount = 0;
        };
        
        pendingRequests.put(request.correlationId, storedRequest);
        pendingRequests.put(request.idempotencyKey, storedRequest);
        
        auditAction("SUBMIT_SUCCESS", caller, request.correlationId, "Request submitted for AI processing");
        
        #ok(request.correlationId)
    };
    
    public shared(msg) func poll(correlationId: Text) : async Result.Result<AIResponse, Text> {
        let caller = Principal.toText(msg.caller);
        
        switch (pendingRequests.get(correlationId)) {
            case null { return #err("Request not found: " # correlationId) };
            case (?storedRequest) {
                switch (storedRequest.status) {
                    case (#Pending or #Processing) {
                        // Check for timeout
                        let elapsedMs = (Time.now() - storedRequest.submittedAt) / 1000000; // Convert to milliseconds
                        let elapsedMsNat = Int.abs(elapsedMs);
                        if (elapsedMsNat > storedRequest.request.timeoutMs) {
                            let timeoutStatus = #TimedOut;
                            let updatedRequest = { storedRequest with status = timeoutStatus };
                            pendingRequests.put(correlationId, updatedRequest);
                            
                            // Record circuit breaker timeout
                            CB.recordRequest(circuitBreaker, #Timeout({ durationMs = elapsedMsNat }));
                            
                            auditAction("POLL_TIMEOUT", caller, correlationId, "Request timed out after " # Nat.toText(elapsedMsNat) # "ms");
                            return #err("Request timed out");
                        };
                        
                        #err("Request still processing")
                    };
                    case (#Completed(response)) {
                        auditAction("POLL_SUCCESS", caller, correlationId, "Response delivered");
                        #ok(response)
                    };
                    case (#Failed(error)) {
                        // Record circuit breaker failure
                        let duration = Time.now() - storedRequest.submittedAt;
                        CB.recordRequest(circuitBreaker, #Failure({ error = error; durationMs = Int.abs(duration) / 1_000_000 }));
                        
                        auditAction("POLL_FAILED", caller, correlationId, error);
                        #err("Request failed: " # error)
                    };
                    case (#TimedOut) {
                        auditAction("POLL_TIMEOUT", caller, correlationId, "Request previously timed out");
                        #err("Request timed out")
                    };
                }
            }
        }
    };
    
    public shared(msg) func deliver(correlationId: Text, response: AIResponse) : async Result.Result<(), Text> {
        let caller = Principal.toText(msg.caller);
        
        // 1. Validate AI service session
        switch (validateAIServiceAccess(msg.caller)) {
            case (#err(error)) { return #err("AI service validation failed: " # error) };
            case (#ok(_)) {};
        };
        
        // 2. Find and update request
        switch (pendingRequests.get(correlationId)) {
            case null { return #err("Request not found: " # correlationId) };
            case (?storedRequest) {
                // Validate response matches request
                if (response.correlationId != correlationId) {
                    return #err("Correlation ID mismatch");
                };
                
                let updatedRequest = { 
                    storedRequest with 
                    status = #Completed(response) 
                };
                pendingRequests.put(correlationId, updatedRequest);
                
                auditAction("DELIVER_SUCCESS", caller, correlationId, "Response delivered by AI service");
                
                // Record circuit breaker success
                let duration = Time.now() - storedRequest.submittedAt;
                CB.recordRequest(circuitBreaker, #Success({ durationMs = Int.abs(duration) / 1_000_000 }));
                
                // Schedule cleanup
                let retentionRecord = LM.createRetentionRecord(correlationId, storedRequest.request);
                let _cleanupJob = LM.createCleanupJob(correlationId, retentionRecord.category, retentionRecord.expiresAt);
                
                #ok()
            };
        }
    };
    
    // Session Management
    public shared(msg) func createSession(role: SessionRole) : async Result.Result<Text, Text> {
        let caller = Principal.toText(msg.caller);
        let now = Time.now();
        let sessionId = generateSessionId(caller, now);
        
        let sessionInfo: SessionInfo = {
            principalId = caller;
            role = role;
            createdAt = now;
            expiresAt = now + (MAX_SESSION_DURATION_MS * 1000000); // Convert to nanoseconds
            rotationToken = generateRotationToken(caller, now);
        };
        
        sessions.put(sessionId, sessionInfo);
        auditAction("SESSION_CREATED", caller, sessionId, "Session created with role: " # debug_show(role));
        
        #ok(sessionId)
    };
    
    public shared(msg) func validateSession(sessionId: Text) : async Result.Result<(), Text> {
        let caller = Principal.toText(msg.caller);
        
        switch (sessions.get(sessionId)) {
            case null { 
                auditAction("SESSION_INVALID", caller, sessionId, "Session not found");
                #err("Session not found") 
            };
            case (?session) {
                if (Time.now() > session.expiresAt) {
                    sessions.delete(sessionId);
                    auditAction("SESSION_EXPIRED", caller, sessionId, "Session expired");
                    #err("Session expired");
                } else {
                    auditAction("SESSION_VALID", caller, sessionId, "Session validated");
                    #ok()
                }
            }
        }
    };
    
    // Metrics and monitoring
    public query func health() : async { status: Text; timestamp: Int; circuitBreaker: Text } {
        let cbStatus = switch (circuitBreaker.state) {
            case (#Closed) { "closed" };
            case (#Open) { "open" };
            case (#HalfOpen) { "half-open" };
        };
        
        {
            status = if (killSwitchEnabled) { "disabled" } else { "healthy" };
            timestamp = Time.now();
            circuitBreaker = cbStatus;
        }
    };
    
    public query func metrics() : async {
        totalRequests: Nat;
        pendingRequests: Nat;
        completedRequests: Nat;
        failedRequests: Nat;
        auditEntries: Nat;
        circuitBreaker: {
            state: Text;
            failureCount: Nat;
            successCount: Nat;
            timeoutCount: Nat;
            lastStateChange: Int;
        };
        rateLimits: {
            activeUsers: Nat;
        };
    } {
        let total = pendingRequests.size();
        var completed = 0;
        var failed = 0;
        var pending = 0;
        
        for ((_, storedRequest) in pendingRequests.entries()) {
            switch (storedRequest.status) {
                case (#Completed(_)) { completed += 1 };
                case (#Failed(_) or #TimedOut) { failed += 1 };
                case (#Pending or #Processing) { pending += 1 };
            }
        };
        
        let cbMetrics = CB.getMetrics(circuitBreaker);
        let cbState = switch (circuitBreaker.state) {
            case (#Closed) { "closed" };
            case (#Open) { "open" };
            case (#HalfOpen) { "half-open" };
        };
        
        {
            totalRequests = total;
            pendingRequests = pending;
            completedRequests = completed;
            failedRequests = failed;
            auditEntries = auditLog.size();
            circuitBreaker = {
                state = cbState;
                failureCount = cbMetrics.failureCount;
                successCount = cbMetrics.successCount;
                timeoutCount = cbMetrics.timeoutCount;
                lastStateChange = cbMetrics.lastStateChange;
            };
            rateLimits = {
                activeUsers = rateLimits.size();
            };
        }
    };

    // Heartbeat for cleanup and monitoring
    system func heartbeat() : async () {
        let now = Time.now();
        
        // 1. Clean up old rate limit entries (older than 2 minutes)
        let rateLimitCleanupBuffer = Buffer.Buffer<Text>(0);
        for ((userId, rateInfo) in rateLimits.entries()) {
            if (now - rateInfo.lastRequestMs > 120_000_000_000) { // 2 minutes in nanoseconds
                rateLimitCleanupBuffer.add(userId);
            };
        };
        for (userId in rateLimitCleanupBuffer.vals()) {
            rateLimits.delete(userId);
        };
        
        // 2. Clean up completed requests older than 1 hour
        let requestCleanupBuffer = Buffer.Buffer<Text>(0);
        for ((correlationId, storedRequest) in pendingRequests.entries()) {
            let ageMs = Int.abs(now - storedRequest.submittedAt) / 1_000_000;
            switch (storedRequest.status) {
                case (#Completed(_) or #Failed(_) or #TimedOut) {
                    if (ageMs > 3_600_000) { // 1 hour
                        requestCleanupBuffer.add(correlationId);
                    };
                };
                case (_) {}; // Keep pending/processing requests
            };
        };
        for (correlationId in requestCleanupBuffer.vals()) {
            pendingRequests.delete(correlationId);
        };
        
        // 3. Circuit breaker health check - using getHealthStatus instead
        let healthStatus = CB.getHealthStatus(circuitBreaker);
        if (not healthStatus.isHealthy) {
            Debug.print("Circuit breaker health warning: " # healthStatus.recommendation);
        };
    };
    
    // Private helper functions
    private func checkRateLimit(userId: Text, now: Int) : Result.Result<(), Text> {
        let REQUESTS_PER_MINUTE = 60;
        let WINDOW_SIZE_MS = 60 * 1000; // 1 minute
        
        switch (rateLimits.get(userId)) {
            case null {
                // First request from this user
                rateLimits.put(userId, {
                    requestCount = 1;
                    windowStartMs = now;
                    lastRequestMs = now;
                });
                #ok(());
            };
            case (?existing) {
                // Check if we need to reset the window
                if (now - existing.windowStartMs > WINDOW_SIZE_MS) {
                    // Reset window
                    rateLimits.put(userId, {
                        requestCount = 1;
                        windowStartMs = now;
                        lastRequestMs = now;
                    });
                    #ok(());
                } else if (existing.requestCount >= REQUESTS_PER_MINUTE) {
                    // Rate limit exceeded
                    #err("Rate limit of " # debug_show(REQUESTS_PER_MINUTE) # " requests per minute exceeded");
                } else {
                    // Update count
                    rateLimits.put(userId, {
                        requestCount = existing.requestCount + 1;
                        windowStartMs = existing.windowStartMs;
                        lastRequestMs = now;
                    });
                    #ok(());
                };
            };
        };
    };

    private func validateSessionWithRole(sessionId: Text, requiredRole: SessionRole) : Result.Result<(), Text> {
        if (killSwitchEnabled) {
            return #err("Service unavailable: Kill switch enabled");
        };
        
        switch (sessions.get(sessionId)) {
            case null { #err("Session not found") };
            case (?session) {
                if (Time.now() > session.expiresAt) {
                    sessions.delete(sessionId);
                    #err("Session expired");
                } else if (session.role != requiredRole) {
                    #err("Insufficient permissions for role");
                } else {
                    #ok()
                }
            }
        }
    };
    
    private func validateAIServiceAccess(caller: Principal) : Result.Result<(), Text> {
        if (killSwitchEnabled) {
            return #err("Service unavailable: Kill switch enabled");
        };
        
        // Validate caller is authorized AI service principal
        let callerText = Principal.toText(caller);
        
        // Check if caller has active AI service session
        for ((sessionId, session) in sessions.entries()) {
            if (session.principalId == callerText and session.role == #AIService) {
                if (Time.now() <= session.expiresAt) {
                    return #ok();
                }
            }
        };
        
        #err("Unauthorized AI service access")
    };
    
    // Kill switch functionality
    private var killSwitchEnabled: Bool = false;
    
    public shared(msg) func enableKillSwitch() : async Result.Result<(), Text> {
        switch (isAdmin(msg.caller)) {
            case false { #err("Unauthorized: Only admins can enable kill switch") };
            case true {
                killSwitchEnabled := true;
                auditAction("KILL_SWITCH_ENABLED", Principal.toText(msg.caller), "SYSTEM", "Kill switch activated");
                #ok()
            }
        }
    };
    
    public shared(msg) func disableKillSwitch() : async Result.Result<(), Text> {
        switch (isAdmin(msg.caller)) {
            case false { #err("Unauthorized: Only admins can disable kill switch") };
            case true {
                killSwitchEnabled := false;
                auditAction("KILL_SWITCH_DISABLED", Principal.toText(msg.caller), "SYSTEM", "Kill switch deactivated");
                #ok()
            }
        }
    };
    
    private func isAdmin(caller: Principal) : Bool {
        // Simple admin check - in production this would be more sophisticated
        let adminPrincipal = "rrkah-fqaaa-aaaaa-aaaaq-cai"; // Replace with actual admin principal
        Principal.toText(caller) == adminPrincipal
    };
    
    private func generateSessionId(principalId: Text, timestamp: Time.Time) : Text {
        // Simple ID generation - in production use proper UUID/cryptographic methods
        principalId # "-" # Int.toText(timestamp) # "-session"
    };
    
    private func generateRotationToken(principalId: Text, timestamp: Time.Time) : Text {
        // Simple token generation - in production use proper cryptographic methods
        principalId # "-" # Int.toText(timestamp) # "-rotation"
    };
    
    private func auditAction(action: Text, actionBy: Text, context: Text, result: Text) {
        let entry = AI.createAuditEntry(action, actionBy, context, result);
        auditLog.add(entry);
    };
    
    // Upgrade functionality
    system func preupgrade() {
        sessionStore := Iter.toArray(sessions.entries());
        requestStore := Iter.toArray(pendingRequests.entries());
        auditLogStore := Buffer.toArray(auditLog);
        rateLimitStore := Iter.toArray(rateLimits.entries());
    };
    
    system func postupgrade() {
        sessionStore := [];
        requestStore := [];
        auditLogStore := [];
        rateLimitStore := [];
    };
}
