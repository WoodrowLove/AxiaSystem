import Debug "mo:base/Debug";
import Time "mo:base/Time";
import _Result "mo:base/Result";
import _Array "mo:base/Array";
import Text "mo:base/Text";
import _HashMap "mo:base/HashMap";
import _Iter "mo:base/Iter";
import Int "mo:base/Int";
import _Buffer "mo:base/Buffer";
import Float "mo:base/Float";

// AI Communication Bridge Module
// Handles secure communication between AxiaSystem and sophos_ai
module AICommunicationBridge {
    
    public type MessageId = Text;
    public type CorrelationId = Text;
    public type SessionId = Text;
    
    public type AIMessage = {
        id : MessageId;
        correlationId : ?CorrelationId;
        timestamp : Int;
        messageType : MessageType;
        payload : MessagePayload;
        securityContext : SecurityContext;
        priority : Priority;
        source : Text;
        destination : Text;
    };
    
    public type MessageType = {
        #TriadErrorAnalysis;
        #FinancialOperationReview;
        #SystemHealthCheck;
        #ComplianceRequest;
        #ThreatAssessment;
        #OptimizationRequest;
        #PolicyValidation;
        #AuditTrailRequest;
        #RiskAssessment;
        #DecisionSupport;
    };
    
    public type MessagePayload = {
        #TriadError : TriadErrorData;
        #FinancialOp : FinancialOperationData;
        #SystemMetrics : SystemMetricsData;
        #ComplianceData : ComplianceRequestData;
        #ThreatData : ThreatAssessmentData;
        #OptimizationData : OptimizationRequestData;
        #PolicyData : PolicyValidationData;
        #AuditData : AuditTrailData;
        #RiskData : RiskAssessmentData;
        #DecisionData : DecisionSupportData;
    };
    
    public type Priority = {
        #Critical;  // < 1 second response required
        #High;      // < 5 seconds response required
        #Medium;    // < 30 seconds response required
        #Low;       // < 5 minutes response required
        #Batch;     // Process when convenient
    };
    
    public type SecurityContext = {
        authentication : AuthenticationData;
        authorization : AuthorizationLevel;
        encryption : EncryptionMetadata;
        auditTrail : AuditTrailMetadata;
        sessionInfo : SessionInfo;
    };
    
    public type AuthenticationData = {
        principalId : Text;
        serviceType : Text; // "ai.service"
        credentials : Text;
        signature : Text;
        timestamp : Int;
    };
    
    public type AuthorizationLevel = {
        #ReadOnly;
        #Submit;
        #Deliver;
        #Admin;
        #Emergency;
    };
    
    public type EncryptionMetadata = {
        algorithm : Text; // "AES-256-GCM"
        keyId : Text;
        nonce : Text;
        encrypted : Bool;
    };
    
    public type AuditTrailMetadata = {
        eventId : Text;
        sourceSystem : Text;
        eventType : Text;
        compliance : Bool;
        retentionClass : Text;
    };
    
    public type SessionInfo = {
        sessionId : SessionId;
        createdAt : Int;
        expiresAt : Int;
        rotationRequired : Bool;
        maxDuration : Int; // 4 hours = 14400 seconds
    };
    
    public type AIResponse = {
        messageId : MessageId;
        correlationId : CorrelationId;
        timestamp : Int;
        responseType : ResponseType;
        payload : ResponsePayload;
        confidence : Float; // 0.0 - 1.0
        recommendations : [Text];
        metadata : ResponseMetadata;
    };
    
    public type ResponseType = {
        #AnalysisComplete;
        #RiskAssessment;
        #ThreatDetected;
        #RecommendationGenerated;
        #ComplianceValidated;
        #DecisionSupport;
        #OptimizationSuggested;
        #Error;
    };
    
    public type ResponsePayload = {
        #TriadAnalysis : TriadAnalysisResult;
        #RiskScore : RiskScoreResult;
        #ThreatAlert : ThreatAlertResult;
        #Recommendation : RecommendationResult;
        #ComplianceReport : ComplianceReportResult;
        #Decision : DecisionResult;
        #Optimization : OptimizationResult;
        #ErrorReport : ErrorResult;
    };
    
    public type ResponseMetadata = {
        processingTime : Int; // milliseconds
        aiModel : Text;
        version : Text;
        confidence : Float;
        dataQuality : Float;
        recommendedAction : ?Text;
    };
    
    // Data type definitions for various message payloads
    public type TriadErrorData = {
        errorId : Text;
        errorType : Text;
        severity : Text;
        context : Text;
        stackTrace : ?Text;
        affectedComponents : [Text];
        timestamp : Int;
    };
    
    public type FinancialOperationData = {
        operationId : Text;
        operationType : Text;
        amount : ?Int;
        currency : ?Text;
        participants : [Text];
        riskFactors : [Text];
        timestamp : Int;
    };
    
    public type SystemMetricsData = {
        cpu : Float;
        memory : Float;
        storage : Float;
        network : Float;
        errorRate : Float;
        responseTime : Float;
        timestamp : Int;
    };
    
    public type ComplianceRequestData = {
        requestId : Text;
        complianceType : Text;
        requiredFrameworks : [Text];
        dataScope : Text;
        urgency : Text;
        timestamp : Int;
    };
    
    public type ThreatAssessmentData = {
        threatId : Text;
        threatType : Text;
        severity : Text;
        indicators : [Text];
        affectedSystems : [Text];
        timestamp : Int;
    };
    
    public type OptimizationRequestData = {
        requestId : Text;
        optimizationType : Text;
        currentMetrics : [Float];
        targetMetrics : [Float];
        constraints : [Text];
        timestamp : Int;
    };
    
    public type PolicyValidationData = {
        policyId : Text;
        policyType : Text;
        rules : [Text];
        context : Text;
        validationScope : Text;
        timestamp : Int;
    };
    
    public type AuditTrailData = {
        trailId : Text;
        eventType : Text;
        timeRange : (Int, Int);
        scope : Text;
        complianceFramework : Text;
        timestamp : Int;
    };
    
    public type RiskAssessmentData = {
        assessmentId : Text;
        riskType : Text;
        context : Text;
        factors : [Text];
        historicalData : ?Text;
        timestamp : Int;
    };
    
    public type DecisionSupportData = {
        decisionId : Text;
        decisionType : Text;
        options : [Text];
        criteria : [Text];
        context : Text;
        timestamp : Int;
    };
    
    // Response result types
    public type TriadAnalysisResult = {
        analysisId : Text;
        rootCause : Text;
        impactAssessment : Text;
        recommendations : [Text];
        preventionStrategy : Text;
        confidence : Float;
    };
    
    public type RiskScoreResult = {
        riskScore : Float; // 0.0 - 1.0
        riskLevel : Text; // Low/Medium/High/Critical
        factors : [Text];
        mitigation : [Text];
        monitoring : [Text];
    };
    
    public type ThreatAlertResult = {
        alertLevel : Text;
        threatType : Text;
        immediateActions : [Text];
        longTermActions : [Text];
        affectedSystems : [Text];
    };
    
    public type RecommendationResult = {
        recommendations : [Text];
        priority : [Text];
        implementation : [Text];
        expectedBenefit : [Text];
        riskAssessment : [Text];
    };
    
    public type ComplianceReportResult = {
        complianceScore : Float;
        frameworks : [Text];
        violations : [Text];
        remediation : [Text];
        timeline : Text;
    };
    
    public type DecisionResult = {
        recommendedDecision : Text;
        alternatives : [Text];
        reasoning : [Text];
        risks : [Text];
        benefits : [Text];
    };
    
    public type OptimizationResult = {
        optimizations : [Text];
        expectedImpact : [Float];
        implementation : [Text];
        timeline : [Text];
        dependencies : [Text];
    };
    
    public type ErrorResult = {
        errorCode : Text;
        errorMessage : Text;
        details : Text;
        resolution : ?Text;
        contactInfo : ?Text;
    };
    
    // Communication protocols
    public type CommunicationProtocol = {
        #Push;
        #Pull;
        #Hybrid;
    };
    
    public type PushConfig = {
        endpoint : Text;
        authentication : Text;
        rateLimiting : RateLimitConfig;
        retryPolicy : RetryPolicy;
        timeout : Int;
    };
    
    public type PullConfig = {
        pollingInterval : Int;
        batchSize : Int;
        maxWaitTime : Int;
        priorityFiltering : Bool;
        caching : CacheConfig;
    };
    
    public type RateLimitConfig = {
        requestsPerSecond : Int;
        burstSize : Int;
        windowSize : Int;
        penaltyDuration : Int;
    };
    
    public type RetryPolicy = {
        maxRetries : Int;
        backoffStrategy : Text; // "exponential", "linear", "fixed"
        initialDelay : Int;
        maxDelay : Int;
        jitter : Bool;
    };
    
    public type CacheConfig = {
        enabled : Bool;
        ttl : Int; // Time to live in seconds
        maxSize : Int;
        evictionPolicy : Text; // "LRU", "FIFO", "LFU"
    };
    
    // Functions for message creation and handling
    
    public func createAIMessage(
        messageType : MessageType,
        payload : MessagePayload,
        priority : Priority,
        destination : Text
    ) : AIMessage {
        let messageId = "msg_" # Int.toText(Time.now());
        let timestamp = Time.now();
        
        {
            id = messageId;
            correlationId = null;
            timestamp = timestamp;
            messageType = messageType;
            payload = payload;
            securityContext = createSecurityContext();
            priority = priority;
            source = "axia_system";
            destination = destination;
        }
    };
    
    public func createSecurityContext() : SecurityContext {
        let timestamp = Time.now();
        
        {
            authentication = {
                principalId = "axia_system_principal";
                serviceType = "ai.service";
                credentials = "encrypted_credentials";
                signature = "message_signature";
                timestamp = timestamp;
            };
            authorization = #Submit;
            encryption = {
                algorithm = "AES-256-GCM";
                keyId = "key_" # Int.toText(timestamp);
                nonce = "nonce_" # Int.toText(timestamp);
                encrypted = true;
            };
            auditTrail = {
                eventId = "event_" # Int.toText(timestamp);
                sourceSystem = "axia_system";
                eventType = "ai_message";
                compliance = true;
                retentionClass = "operational_90d";
            };
            sessionInfo = {
                sessionId = "session_" # Int.toText(timestamp);
                createdAt = timestamp;
                expiresAt = timestamp + 14400_000_000_000; // 4 hours in nanoseconds
                rotationRequired = false;
                maxDuration = 14400; // 4 hours in seconds
            };
        }
    };
    
    public func validateMessage(message : AIMessage) : Bool {
        // Validate message structure and security context
        if (message.id == "" or message.timestamp <= 0) {
            return false;
        };
        
        // Validate security context
        let currentTime = Time.now();
        if (message.securityContext.sessionInfo.expiresAt < currentTime) {
            return false;
        };
        
        // Validate authentication
        if (message.securityContext.authentication.principalId == "") {
            return false;
        };
        
        true
    };
    
    public func processResponse(response : AIResponse) : Bool {
        // Process AI response and integrate with system
        Debug.print("Processing AI response: " # response.messageId);
        
        switch (response.responseType) {
            case (#AnalysisComplete) {
                Debug.print("Analysis completed with confidence: " # Float.toText(response.confidence));
            };
            case (#RiskAssessment) {
                Debug.print("Risk assessment completed");
            };
            case (#ThreatDetected) {
                Debug.print("THREAT DETECTED - Immediate action required");
            };
            case (#RecommendationGenerated) {
                Debug.print("Recommendations generated: " # debug_show(response.recommendations.size()));
            };
            case (#ComplianceValidated) {
                Debug.print("Compliance validation completed");
            };
            case (#DecisionSupport) {
                Debug.print("Decision support provided");
            };
            case (#OptimizationSuggested) {
                Debug.print("Optimization suggestions generated");
            };
            case (#Error) {
                Debug.print("AI processing error occurred");
                return false;
            };
        };
        
        true
    };
    
    public func createCorrelationId() : CorrelationId {
        "corr_" # Int.toText(Time.now())
    };
    
    public func prioritizeMessage(messageType : MessageType) : Priority {
        switch (messageType) {
            case (#ThreatAssessment) { #Critical };
            case (#TriadErrorAnalysis) { #High };
            case (#ComplianceRequest) { #High };
            case (#FinancialOperationReview) { #Medium };
            case (#SystemHealthCheck) { #Medium };
            case (#PolicyValidation) { #Medium };
            case (#RiskAssessment) { #Medium };
            case (#DecisionSupport) { #Low };
            case (#OptimizationRequest) { #Low };
            case (#AuditTrailRequest) { #Batch };
        }
    };
}
