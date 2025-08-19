import Time "mo:base/Time";
import Blob "mo:base/Blob";

module AIEnvelope {
    
    // Core AI request/response envelope for cross-system communication
    public type AIRequest = {
        // Identity and correlation
        correlationId: Text;
        idempotencyKey: Text;
        sessionId: Text;
        submitterId: Text; // ai.submitter principal
        timestamp: Time.Time;
        
        // Request metadata
        requestType: AIRequestType;
        priority: Priority;
        timeoutMs: Nat;
        retryCount: Nat;
        
        // Data payload (PII-safe only)
        payload: AIPayload;
        
        // Triad integration
        triadContext: ?TriadContext;
    };
    
    public type AIResponse = {
        // Correlation
        correlationId: Text;
        requestId: Text;
        timestamp: Time.Time;
        
        // Response metadata
        status: AIStatus;
        confidence: Float; // 0.0 - 1.0
        processingTimeMs: Nat;
        modelVersion: Text;
        
        // Response data
        result: AIResult;
        reasoning: ?Text;
        
        // Compliance
        auditTrail: [AuditEntry];
        requiresHumanReview: Bool;
    };
    
    public type AIRequestType = {
        #PaymentRisk;
        #EscrowAdvisory;
        #ComplianceCheck;
        #FraudDetection;
        #PatternAnalysis;
        #GovernanceReview;
    };
    
    public type Priority = {
        #Critical;   // < 50ms
        #High;       // < 150ms
        #Normal;     // < 400ms
        #Background; // < 2000ms
    };
    
    // PII-safe payload enforcing Q1 policy
    public type AIPayload = {
        userId: Text;              // Hashed identifier
        transactionId: ?Text;      // Reference ID
        amountTier: Nat;          // 1-5 range, not exact amount
        riskFactors: [Text];      // Categorized indicators
        patternHash: Text;        // Behavioral fingerprint
        contextBlob: Blob;        // Encrypted feature vector
        metadata: [(Text, Text)]; // Additional safe context
    };
    
    public type AIStatus = {
        #Success;
        #Pending;
        #Failed: {
            code: Text;
            message: Text;
            retryable: Bool;
        };
        #Timeout;
        #Throttled;
        #ValidationError: Text;
    };
    
    public type AIResult = {
        #RiskAssessment: RiskResult;
        #Advisory: AdvisoryResult;
        #ComplianceCheck: ComplianceResult;
        #PatternAnalysis: PatternResult;
        #GovernanceReview: GovernanceResult;
    };
    
    public type RiskResult = {
        riskScore: Float;        // 0.0 - 1.0
        riskLevel: RiskLevel;
        factors: [RiskFactor];
        recommendation: RiskAction;
    };
    
    public type AdvisoryResult = {
        recommendation: AdvisoryAction;
        confidence: Float;
        reasoning: [Text];
        alternatives: [AdvisoryAction];
    };
    
    public type ComplianceResult = {
        compliant: Bool;
        violations: [ComplianceViolation];
        remediation: [Text];
        severity: ComplianceSeverity;
    };
    
    public type PatternResult = {
        anomalyScore: Float;
        patterns: [PatternMatch];
        trends: [TrendIndicator];
        alerts: [PatternAlert];
    };
    
    public type GovernanceResult = {
        approved: Bool;
        conditions: [GovernanceCondition];
        reviewRequired: Bool;
        escalationLevel: EscalationLevel;
    };
    
    public type RiskLevel = {
        #Low;      // 0.0 - 0.3
        #Medium;   // 0.3 - 0.7
        #High;     // 0.7 - 0.9
        #Critical; // 0.9 - 1.0
    };
    
    public type RiskAction = {
        #Proceed;
        #RequireMFA;
        #HoldForReview;
        #Block;
        #Escalate;
    };
    
    public type AdvisoryAction = {
        #Approve;
        #Review;
        #Deny;
        #ModifyTerms;
        #RequestAdditionalInfo;
    };
    
    public type ComplianceSeverity = {
        #Info;
        #Warning;
        #Critical;
        #Blocking;
    };
    
    public type EscalationLevel = {
        #None;
        #Supervisor;
        #Management;
        #Executive;
        #Legal;
    };
    
    // Triad integration context
    public type TriadContext = {
        triadId: Text;
        moduleType: TriadModule;
        operationType: Text;
        correlationChain: [Text];
        errorContext: ?TriadErrorContext;
    };
    
    public type TriadModule = {
        #Escrow;
        #Payment;
        #Treasury;
        #Payout;
        #SplitPayment;
        #Subscriptions;
        #Governance;
        #Identity;
        #AssetRegistry;
    };
    
    public type TriadErrorContext = {
        errorType: Text;
        errorMessage: Text;
        recoveryActions: [Text];
        humanInterventionRequired: Bool;
    };
    
    // Audit and compliance
    public type AuditEntry = {
        timestamp: Time.Time;
        action: Text;
        actionBy: Text; // Changed from 'actor' which is reserved
        context: Text;
        result: Text;
    };
    
    public type RiskFactor = {
        factor: Text;
        weight: Float;
        contribution: Float;
        source: Text;
    };
    
    public type ComplianceViolation = {
        rule: Text;
        severity: ComplianceSeverity;
        description: Text;
        remediation: Text;
    };
    
    public type PatternMatch = {
        pattern: Text;
        confidence: Float;
        frequency: Nat;
        lastSeen: Time.Time;
    };
    
    public type TrendIndicator = {
        metric: Text;
        direction: TrendDirection;
        magnitude: Float;
        timeframe: Text;
    };
    
    public type TrendDirection = {
        #Increasing;
        #Decreasing;
        #Stable;
        #Volatile;
    };
    
    public type PatternAlert = {
        alertType: Text;
        severity: AlertSeverity;
        description: Text;
        actionRequired: Bool;
    };
    
    public type AlertSeverity = {
        #Info;
        #Low;
        #Medium;
        #High;
        #Critical;
    };
    
    public type GovernanceCondition = {
        condition: Text;
        required: Bool;
        timeframe: ?Nat; // milliseconds
        approver: ?Text;
    };
    
    // Validation functions
    public func validatePayload(payload: AIPayload) : Bool {
        // Enforce Q1 policy - no PII allowed
        payload.userId != "" and 
        payload.amountTier >= 1 and payload.amountTier <= 5 and
        payload.riskFactors.size() > 0 and
        payload.patternHash != ""
    };
    
    public func createAuditEntry(action: Text, actionBy: Text, context: Text, result: Text) : AuditEntry {
        {
            timestamp = Time.now();
            action = action;
            actionBy = actionBy;
            context = context;
            result = result;
        }
    };
    
    public func isHighPriorityRequest(requestType: AIRequestType) : Bool {
        switch (requestType) {
            case (#FraudDetection or #ComplianceCheck) true;
            case (_) false;
        }
    };
    
    public func requiresEscalation(result: AIResult) : Bool {
        switch (result) {
            case (#RiskAssessment(risk)) {
                switch (risk.riskLevel) {
                    case (#High or #Critical) true;
                    case (_) false;
                }
            };
            case (#ComplianceCheck(compliance)) {
                switch (compliance.severity) {
                    case (#Critical or #Blocking) true;
                    case (_) false;
                }
            };
            case (#GovernanceReview(governance)) {
                governance.reviewRequired
            };
            case (_) false;
        }
    };
}
