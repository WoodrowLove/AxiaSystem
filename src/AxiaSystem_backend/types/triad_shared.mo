// AxiaSystem Shared Triad Types - Universal Type Definitions
// Core types shared across all triad-compliant modules for consistency and type safety

import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Time "mo:base/Time";

import EventTypes "../heartbeat/event_types";

module {
    // ================================
    // TRIAD IDENTITY SYSTEM
    // ================================

    // Universal identity structure used across all triad systems
    public type TriadIdentity = {
        identityId: Principal;          // Core IC identity
        userId: ?Principal;             // Optional user account principal
        walletId: ?Principal;           // Optional wallet canister principal
        deviceId: ?Blob;                // Optional device fingerprint
        verified: Bool;                 // Triad verification status
        version: Nat;                   // Identity schema version
        createdAt: Nat64;              // Registration timestamp
        lastVerified: ?Nat64;          // Last verification check
    };

    // Identity verification proof structure
    public type LinkProof = { 
        signature: Blob; 
        challenge: Blob; 
        device: ?Blob;
        timestamp: Nat64;
    };

    // Identity verification levels
    public type VerificationLevel = {
        #unverified;                    // No verification completed
        #basic;                         // Basic principal verification
        #enhanced;                      // Multi-factor verification
        #triad;                         // Full triad verification (identity + user + wallet)
    };

    // ================================
    // CORRELATION & CAUSATION TRACKING
    // ================================

    // Correlation context for tracking operations across systems
    public type CorrelationContext = {
        correlationId: Nat64;           // Unique operation identifier
        parentId: ?Nat64;              // Parent operation (for nested operations)
        rootId: ?Nat64;                // Root operation (for deep nesting)
        flow: Text;                     // Operation flow identifier
        initiatedBy: Principal;        // Who started this operation chain
        createdAt: Nat64;              // When correlation was created
        systemName: Text;               // Originating system (renamed from 'system')
        operationType: Text;            // Operation type (renamed from 'operation')
    };

    // Operation flow tracking
    public type FlowStep = {
        stepId: Nat;
        systemName: Text;               // Renamed from 'system'
        operationType: Text;            // Renamed from 'operation'
        status: OperationStatus;
        startedAt: Nat64;
        completedAt: ?Nat64;
        errorMsg: ?Text;
    };

    // ================================
    // ERROR MODELING
    // ================================

    // Structured error types for programmatic handling
    public type TriadError = {
        #NotFound: { resource: Text; id: Text };
        #Unauthorized: { principal: Principal; operationType: Text };
        #Conflict: { reason: Text; currentState: Text };
        #Invalid: { field: Text; value: Text; reason: Text };
        #Upstream: { systemName: Text; error: Text };
        #Transient: { operationType: Text; retryAfter: ?Nat64 };
        #Internal: { code: Text; message: Text };
        #Capacity: { resource: Text; current: Nat; limit: Nat };
        #Timeout: { operationType: Text; duration: Nat64 };
    };

    // Error severity levels
    public type ErrorSeverity = {
        #info;
        #warning;
        #error;
        #critical;
        #fatal;
    };

    // ================================
    // OPERATION STATUS & PRIORITY
    // ================================

    // Universal operation status
    public type OperationStatus = {
        #pending;
        #queued;
        #inProgress;
        #retrying;
        #completed;
        #failed;
        #cancelled;
        #timeout;
    };

    // Operation priority levels
    public type Priority = {
        #low;
        #normal;
        #high;
        #critical;
        #emergency;
    };

    // ================================
    // ENHANCED EVENT SYSTEM
    // ================================

    // Enhanced event envelope wrapping base events
    public type TriadEventEnvelope = {
        base: EventTypes.Event;         // Original event
        correlation: CorrelationContext; // Tracking context
        priority: ?Priority;            // Event priority
        systems: [Text];                // Affected systems
        retryCount: Nat;               // Retry attempts
        tags: [Text];                  // Event tags for filtering
        metadata: [(Text, Text)];      // Additional metadata
    };

    // Event routing configuration
    public type EventRoute = {
        eventType: EventTypes.EventType;
        targetSystems: [Text];
        priority: Priority;
        retryPolicy: RetryPolicy;
    };

    // ================================
    // RETRY & RESILIENCE
    // ================================

    // Retry policy configuration
    public type RetryPolicy = {
        maxAttempts: Nat;
        backoffStrategy: BackoffStrategy;
        retryableErrors: [TriadError];
        timeout: Nat64;
    };

    // Backoff strategies
    public type BackoffStrategy = {
        #linear: { increment: Nat64 };
        #exponential: { base: Nat64; multiplier: Nat };
        #fixed: { interval: Nat64 };
        #custom: { intervals: [Nat64] };
    };

    // ================================
    // METRICS & MONITORING
    // ================================

    // Unified metrics structure
    public type TriadMetrics = {
        // Operation metrics
        opTotals: [(Text, Nat)];        // [(operation, count)]
        failuresByType: [(Text, Nat)];  // [(errorType, count)]
        p95OpDuration: [(Text, Nat64)]; // [(operation, duration)]
        
        // System health
        queueDepths: [(Text, Nat)];     // [(queue, depth)]
        lastValidationAt: ?Nat64;       // Last validation timestamp
        coordinatorRollbackCount: Nat;  // Rollback operations
        
        // Performance indicators
        throughputPerSecond: Nat;
        errorRate: Nat;                 // Errors per 1000 operations
        avgResponseTime: Nat64;
        
        // Resource utilization
        memoryUsage: Nat64;
        cyclesConsumed: Nat64;
        
        // Timestamp
        collectedAt: Nat64;
    };

    // Health status indicators
    public type HealthStatus = {
        #healthy;
        #degraded: { reason: Text };
        #critical: { issues: [Text] };
        #offline: { since: Nat64 };
    };

    // System component health
    public type ComponentHealth = {
        component: Text;
        status: HealthStatus;
        lastCheck: Nat64;
        metrics: ?TriadMetrics;
        alerts: [Text];
    };

    // ================================
    // IDEMPOTENCY
    // ================================

    // Idempotency key structure
    public type IdempotencyKey = {
        key: Text;
        operation: Text;
        principal: Principal;
        createdAt: Nat64;
        expiresAt: Nat64;
    };

    // Idempotency result
    public type IdempotencyResult<T> = {
        #new: T;                        // New operation, result created
        #existing: T;                   // Duplicate operation, existing result
        #expired: { key: Text };        // Key expired, operation needed
    };

    // ================================
    // VALIDATION & COMPLIANCE
    // ================================

    // Validation issue types
    public type ValidationIssueType = {
        #TRIAD_MIGRATION;              // Triad compliance issues
        #ORPHAN;                       // Orphaned data
        #CONSISTENCY;                  // Cross-system consistency
        #PERFORMANCE;                  // Performance issues
        #SECURITY;                     // Security vulnerabilities
        #CAPACITY;                     // Capacity issues
        #INTEGRATION;                  // Integration problems
    };

    // Enhanced validation issue
    public type ValidationIssue = {
        issueId: Nat;
        issueType: ValidationIssueType;
        severity: ErrorSeverity;
        component: Text;
        description: Text;
        recommendation: Text;
        autoFixable: Bool;
        detectedAt: Nat64;
        correlation: ?CorrelationContext;
        affectedResources: [Text];
        estimatedImpact: Text;
    };

    // ================================
    // CONFIGURATION
    // ================================

    // System configuration
    public type TriadConfig = {
        // Event system
        maxEventQueueSize: Nat;
        eventRetentionDays: Nat;
        
        // Correlation
        correlationRetentionHours: Nat;
        maxCorrelationDepth: Nat;
        
        // Retry policies
        defaultRetryPolicy: RetryPolicy;
        
        // Validation
        validationIntervalHours: Nat;
        autoFixEnabled: Bool;
        
        // Metrics
        metricsRetentionDays: Nat;
        metricsCollectionInterval: Nat64;
        
        // Idempotency
        idempotencyWindowHours: Nat;
        maxIdempotencyKeys: Nat;
    };

    // ================================
    // UTILITY FUNCTIONS
    // ================================

    // Create a basic triad identity
    public func createTriadIdentity(
        identityId: Principal,
        userId: ?Principal,
        walletId: ?Principal
    ): TriadIdentity {
        {
            identityId = identityId;
            userId = userId;
            walletId = walletId;
            deviceId = null;
            verified = false;
            version = 1;
            createdAt = Nat64.fromIntWrap(Time.now());
            lastVerified = null;
        }
    };

    // Create correlation context
    public func createCorrelationContext(
        flow: Text,
        initiatedBy: Principal,
        systemName: Text,
        operationType: Text
    ): CorrelationContext {
        {
            correlationId = Nat64.fromIntWrap(Time.now()) + Nat64.fromNat(1000); // Simple ID generation
            parentId = null;
            rootId = null;
            flow = flow;
            initiatedBy = initiatedBy;
            createdAt = Nat64.fromIntWrap(Time.now());
            systemName = systemName;
            operationType = operationType;
        }
    };

    // Create child correlation context
    public func createChildCorrelation(
        parent: CorrelationContext,
        systemName: Text,
        operationType: Text
    ): CorrelationContext {
        {
            correlationId = Nat64.fromIntWrap(Time.now()) + Nat64.fromNat(2000);
            parentId = ?parent.correlationId;
            rootId = switch (parent.rootId) {
                case (?rootId) ?rootId;
                case null ?parent.correlationId;
            };
            flow = parent.flow;
            initiatedBy = parent.initiatedBy;
            createdAt = Nat64.fromIntWrap(Time.now());
            systemName = systemName;
            operationType = operationType;
        }
    };

    // Default retry policy
    public func defaultRetryPolicy(): RetryPolicy {
        {
            maxAttempts = 3;
            backoffStrategy = #exponential({ base = 1000; multiplier = 2 });
            retryableErrors = [
                #Transient({ operationType = ""; retryAfter = null }),
                #Upstream({ systemName = ""; error = "" }),
                #Timeout({ operationType = ""; duration = 0 })
            ];
            timeout = 30_000_000_000; // 30 seconds
        }
    };

    // Check if error is retryable
    public func isRetryable(error: TriadError, _policy: RetryPolicy): Bool {
        switch (error) {
            case (#Transient(_)) true;
            case (#Upstream(_)) true;
            case (#Timeout(_)) true;
            case (#Capacity(_)) true;
            case (_) false;
        }
    };

    // Get error severity
    public func getErrorSeverity(error: TriadError): ErrorSeverity {
        switch (error) {
            case (#NotFound(_)) #warning;
            case (#Unauthorized(_)) #error;
            case (#Conflict(_)) #warning;
            case (#Invalid(_)) #error;
            case (#Upstream(_)) #warning;
            case (#Transient(_)) #info;
            case (#Internal(_)) #critical;
            case (#Capacity(_)) #error;
            case (#Timeout(_)) #warning;
        }
    };

    // Error to text conversion
    public func errorToText(error: TriadError): Text {
        switch (error) {
            case (#NotFound({ resource; id })) "Resource not found: " # resource # " with ID " # id;
            case (#Unauthorized({ principal; operationType })) "Unauthorized: " # Principal.toText(principal) # " cannot perform " # operationType;
            case (#Conflict({ reason; currentState })) "Conflict: " # reason # " (current state: " # currentState # ")";
            case (#Invalid({ field; value; reason })) "Invalid " # field # ": " # value # " - " # reason;
            case (#Upstream({ systemName; error })) "Upstream error from " # systemName # ": " # error;
            case (#Transient({ operationType; retryAfter = _ })) "Transient error in " # operationType # " - retry recommended";
            case (#Internal({ code; message })) "Internal error [" # code # "]: " # message;
            case (#Capacity({ resource; current; limit })) "Capacity exceeded for " # resource # ": " # Nat.toText(current) # "/" # Nat.toText(limit);
            case (#Timeout({ operationType; duration })) "Timeout in " # operationType # " after " # Nat64.toText(duration) # "ns";
        }
    };
};
