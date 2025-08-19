// Human-in-the-Loop Service Module for Phase 2 Week 6
// Production-grade approval workflows with SLA tracking

import Text "mo:base/Text";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Debug "mo:base/Debug";

module HILService {
    
    public type ApprovalRequest = {
        correlationId: Text;
        requestType: HILRequestType;
        priority: Priority;
        submittedAt: Time.Time;
        slaExpiresAt: Time.Time;
        auditBundle: AuditBundle;
        status: ApprovalStatus;
        assignedTo: ?Text;
        escalationLevel: Nat;
        metadata: [(Text, Text)];
    };
    
    public type HILRequestType = {
        #EscrowRelease: { transactionId: Text; amount: Float };
        #ComplianceOverride: { violationType: Text; riskLevel: Text };
        #HighValueTransaction: { amount: Float; threshold: Float };
        #SanctionsFlag: { entityId: Text; flagType: Text };
        #EmergencyEscalation: { reason: Text; urgency: Text };
    };
    
    public type Priority = {
        #Critical: { slaMinutes: Nat }; // 15 minutes
        #High: { slaMinutes: Nat };     // 60 minutes
        #Medium: { slaMinutes: Nat };   // 240 minutes (4 hours)
        #Low: { slaMinutes: Nat };      // 1440 minutes (24 hours)
    };
    
    public type ApprovalStatus = {
        #Pending;
        #Acknowledged: { by: Text; at: Time.Time };
        #UnderReview: { by: Text; startedAt: Time.Time };
        #Approved: { by: Text; at: Time.Time; reasoning: Text };
        #Denied: { by: Text; at: Time.Time; reasoning: Text };
        #Escalated: { to: Text; at: Time.Time; reason: Text };
        #Expired: { at: Time.Time };
        #AutoClosed: { at: Time.Time; reason: Text };
    };
    
    public type AuditBundle = {
        featuresHash: Text;
        aiFactors: [Text];
        confidence: Float;
        recommendation: Text;
        fallbackReason: ?Text;
        originalRequest: Text;
        decisionPath: [Text];
        riskAssessment: RiskAssessment;
        complianceFlags: [Text];
    };
    
    public type RiskAssessment = {
        riskScore: Float;
        riskFactors: [Text];
        mitigationSuggestions: [Text];
        escalationTriggers: [Text];
    };
    
    public type ApprovalResponse = {
        correlationId: Text;
        action: ApprovalAction;
        approver: Text;
        timestamp: Time.Time;
        reasoning: Text;
        nextSteps: [Text];
    };
    
    public type ApprovalAction = {
        #Acknowledge;
        #Approve;
        #Deny;
        #Escalate: { to: Text; reason: Text };
        #RequestMoreInfo: { questions: [Text] };
    };
    
    public type SLAMetrics = {
        requestsTotal: Nat;
        requestsWithinSLA: Nat;
        averageResponseTime: Float;
        escalationRate: Float;
        autoClosureRate: Float;
        currentSLACompliance: Float;
    };
    
    public type WebhookPayload = {
        correlationId: Text;
        requestType: Text;
        priority: Text;
        slaExpiresAt: Int;
        summary: Text;
        actionRequired: Text;
        dashboardUrl: Text;
    };
    
    public class HILServiceManager() {
        private var approvalRequests = HashMap.HashMap<Text, ApprovalRequest>(10, Text.equal, Text.hash);
        private var slaMetrics = {
            var requestsTotal: Nat = 0;
            var requestsWithinSLA: Nat = 0;
            var totalResponseTime: Float = 0.0;
            var escalationCount: Nat = 0;
            var autoClosureCount: Nat = 0;
        };
        
        public func submitApprovalRequest(request: ApprovalRequest) : Result.Result<Text, Text> {
            Debug.print("HIL: Submitting approval request " # request.correlationId);
            
            // Validate request
            switch (validateApprovalRequest(request)) {
                case (#err(error)) { return #err(error) };
                case (#ok(_)) {};
            };
            
            // Store request
            approvalRequests.put(request.correlationId, request);
            slaMetrics.requestsTotal += 1;
            
            // Send webhook notification
            let _ = sendWebhookNotification(request);
            
            // Start SLA timer
            startSLATimer(request.correlationId, request.slaExpiresAt);
            
            #ok("Approval request submitted successfully: " # request.correlationId)
        };
        
        public func acknowledgeRequest(correlationId: Text, approver: Text) : Result.Result<ApprovalResponse, Text> {
            switch (approvalRequests.get(correlationId)) {
                case (null) { return #err("Request not found: " # correlationId) };
                case (?request) {
                    let updatedRequest = {
                        request with
                        status = #Acknowledged({ by = approver; at = Time.now() });
                        assignedTo = ?approver;
                    };
                    
                    approvalRequests.put(correlationId, updatedRequest);
                    
                    let response = {
                        correlationId = correlationId;
                        action = #Acknowledge;
                        approver = approver;
                        timestamp = Time.now();
                        reasoning = "Request acknowledged and assigned";
                        nextSteps = ["Review audit bundle", "Make approval decision within SLA"];
                    };
                    
                    #ok(response)
                };
            }
        };
        
        public func approveRequest(correlationId: Text, approver: Text, reasoning: Text) : Result.Result<ApprovalResponse, Text> {
            switch (approvalRequests.get(correlationId)) {
                case (null) { return #err("Request not found: " # correlationId) };
                case (?request) {
                    let currentTime = Time.now();
                    
                    // Check if within SLA
                    let withinSLA = currentTime <= request.slaExpiresAt;
                    if (withinSLA) {
                        slaMetrics.requestsWithinSLA += 1;
                    };
                    
                    let responseTime = Float.fromInt(currentTime - request.submittedAt) / 1_000_000_000.0; // Convert to seconds
                    slaMetrics.totalResponseTime += responseTime;
                    
                    let updatedRequest = {
                        request with
                        status = #Approved({ by = approver; at = currentTime; reasoning = reasoning });
                    };
                    
                    approvalRequests.put(correlationId, updatedRequest);
                    
                    let response = {
                        correlationId = correlationId;
                        action = #Approve;
                        approver = approver;
                        timestamp = currentTime;
                        reasoning = reasoning;
                        nextSteps = ["Execute approved action", "Log audit trail"];
                    };
                    
                    #ok(response)
                };
            }
        };
        
        public func denyRequest(correlationId: Text, approver: Text, reasoning: Text) : Result.Result<ApprovalResponse, Text> {
            switch (approvalRequests.get(correlationId)) {
                case (null) { return #err("Request not found: " # correlationId) };
                case (?request) {
                    let currentTime = Time.now();
                    
                    // Check if within SLA
                    let withinSLA = currentTime <= request.slaExpiresAt;
                    if (withinSLA) {
                        slaMetrics.requestsWithinSLA += 1;
                    };
                    
                    let responseTime = Float.fromInt(currentTime - request.submittedAt) / 1_000_000_000.0;
                    slaMetrics.totalResponseTime += responseTime;
                    
                    let updatedRequest = {
                        request with
                        status = #Denied({ by = approver; at = currentTime; reasoning = reasoning });
                    };
                    
                    approvalRequests.put(correlationId, updatedRequest);
                    
                    let response = {
                        correlationId = correlationId;
                        action = #Deny;
                        approver = approver;
                        timestamp = currentTime;
                        reasoning = reasoning;
                        nextSteps = ["Block/hold action enforced", "Audit trail logged"];
                    };
                    
                    #ok(response)
                };
            }
        };
        
        public func escalateRequest(correlationId: Text, escalator: Text, escalateTo: Text, reason: Text) : Result.Result<ApprovalResponse, Text> {
            switch (approvalRequests.get(correlationId)) {
                case (null) { return #err("Request not found: " # correlationId) };
                case (?request) {
                    let currentTime = Time.now();
                    slaMetrics.escalationCount += 1;
                    
                    let updatedRequest = {
                        request with
                        status = #Escalated({ to = escalateTo; at = currentTime; reason = reason });
                        escalationLevel = request.escalationLevel + 1;
                        assignedTo = ?escalateTo;
                    };
                    
                    approvalRequests.put(correlationId, updatedRequest);
                    
                    // Send escalation webhook
                    let _ = createEscalationWebhook(updatedRequest, escalateTo);
                    
                    let response = {
                        correlationId = correlationId;
                        action = #Escalate({ to = escalateTo; reason = reason });
                        approver = escalator;
                        timestamp = currentTime;
                        reasoning = "Escalated due to: " # reason;
                        nextSteps = ["Notify escalation target", "Reset SLA timer"];
                    };
                    
                    #ok(response)
                };
            }
        };
        
        public func checkSLAExpiration() : [Text] {
            let currentTime = Time.now();
            var expiredRequests: [Text] = [];
            
            for ((correlationId, request) in approvalRequests.entries()) {
                switch (request.status) {
                    case (#Pending or #Acknowledged(_) or #UnderReview(_)) {
                        if (currentTime > request.slaExpiresAt) {
                            let expiredRequest = {
                                request with
                                status = #Expired({ at = currentTime });
                            };
                            
                            approvalRequests.put(correlationId, expiredRequest);
                            expiredRequests := Array.append(expiredRequests, [correlationId]);
                            slaMetrics.autoClosureCount += 1;
                            
                            // Trigger auto-escalation for expired critical requests
                            switch (request.priority) {
                                case (#Critical(_)) {
                                    let _ = autoEscalateExpiredCritical(correlationId, request);
                                };
                                case (_) {};
                            };
                        };
                    };
                    case (_) {};
                }
            };
            
            expiredRequests
        };
        
        public func getApprovalRequest(correlationId: Text) : ?ApprovalRequest {
            approvalRequests.get(correlationId)
        };
        
        public func getSLAMetrics() : SLAMetrics {
            let avgResponseTime = if (slaMetrics.requestsTotal > 0) {
                slaMetrics.totalResponseTime / Float.fromInt(slaMetrics.requestsTotal)
            } else { 0.0 };
            
            let escalationRate = if (slaMetrics.requestsTotal > 0) {
                Float.fromInt(slaMetrics.escalationCount) / Float.fromInt(slaMetrics.requestsTotal)
            } else { 0.0 };
            
            let autoClosureRate = if (slaMetrics.requestsTotal > 0) {
                Float.fromInt(slaMetrics.autoClosureCount) / Float.fromInt(slaMetrics.requestsTotal)
            } else { 0.0 };
            
            let slaCompliance = if (slaMetrics.requestsTotal > 0) {
                Float.fromInt(slaMetrics.requestsWithinSLA) / Float.fromInt(slaMetrics.requestsTotal)
            } else { 1.0 };
            
            {
                requestsTotal = slaMetrics.requestsTotal;
                requestsWithinSLA = slaMetrics.requestsWithinSLA;
                averageResponseTime = avgResponseTime;
                escalationRate = escalationRate;
                autoClosureRate = autoClosureRate;
                currentSLACompliance = slaCompliance;
            }
        };
        
        public func generateAuditBundle(
            aiFactors: [Text],
            confidence: Float,
            recommendation: Text,
            originalRequest: Text,
            fallbackReason: ?Text
        ) : AuditBundle {
            let featuresHash = generateFeaturesHash(aiFactors, confidence, recommendation);
            let decisionPath = generateDecisionPath(aiFactors, recommendation, fallbackReason);
            let riskAssessment = generateRiskAssessment(confidence, aiFactors);
            
            {
                featuresHash = featuresHash;
                aiFactors = aiFactors;
                confidence = confidence;
                recommendation = recommendation;
                fallbackReason = fallbackReason;
                originalRequest = originalRequest;
                decisionPath = decisionPath;
                riskAssessment = riskAssessment;
                complianceFlags = extractComplianceFlags(aiFactors);
            }
        };
        
        private func validateApprovalRequest(request: ApprovalRequest) : Result.Result<(), Text> {
            // Validate correlation ID
            if (request.correlationId == "") {
                return #err("Correlation ID cannot be empty");
            };
            
            // Check for duplicate correlation ID
            switch (approvalRequests.get(request.correlationId)) {
                case (?_) { return #err("Duplicate correlation ID: " # request.correlationId) };
                case (null) {};
            };
            
            // Validate SLA expiration
            if (request.slaExpiresAt <= request.submittedAt) {
                return #err("SLA expiration must be after submission time");
            };
            
            // Validate confidence score
            if (request.auditBundle.confidence < 0.0 or request.auditBundle.confidence > 1.0) {
                return #err("Confidence must be between 0.0 and 1.0");
            };
            
            #ok(())
        };
        
        private func sendWebhookNotification(request: ApprovalRequest) : Bool {
            let _ = createWebhookPayload(request);
            Debug.print("WEBHOOK: Sending notification for " # request.correlationId);
            Debug.print("Priority: " # getPriorityText(request.priority));
            Debug.print("SLA Expires: " # debug_show(request.slaExpiresAt));
            
            // In production, this would send HTTP POST to webhook URL
            true
        };
        
        private func createWebhookPayload(request: ApprovalRequest) : WebhookPayload {
            let priorityText = getPriorityText(request.priority);
            let requestTypeText = getRequestTypeText(request.requestType);
            
            {
                correlationId = request.correlationId;
                requestType = requestTypeText;
                priority = priorityText;
                slaExpiresAt = request.slaExpiresAt;
                summary = "HIL Approval Required: " # requestTypeText # " (" # priorityText # ")";
                actionRequired = "APPROVE/DENY Required";
                dashboardUrl = "https://hil.axiasystem.com/approval/" # request.correlationId;
            }
        };
        
        private func createEscalationWebhook(request: ApprovalRequest, _escalateTo: Text) : WebhookPayload {
            let priorityText = getPriorityText(request.priority);
            let requestTypeText = getRequestTypeText(request.requestType);
            
            {
                correlationId = request.correlationId;
                requestType = requestTypeText;
                priority = "ESCALATED-" # priorityText;
                slaExpiresAt = request.slaExpiresAt;
                summary = "ESCALATED: " # requestTypeText # " - Level " # debug_show(request.escalationLevel);
                actionRequired = "URGENT APPROVAL REQUIRED";
                dashboardUrl = "https://hil.axiasystem.com/escalation/" # request.correlationId;
            }
        };
        
        private func startSLATimer(correlationId: Text, expiresAt: Time.Time) {
            Debug.print("SLA Timer started for " # correlationId # " expires at " # debug_show(expiresAt));
            // In production, this would schedule a background job to check expiration
        };
        
        private func autoEscalateExpiredCritical(correlationId: Text, request: ApprovalRequest) : Bool {
            Debug.print("AUTO-ESCALATING expired critical request: " # correlationId);
            
            let escalationTarget = "senior-oncall@axiasystem.com";
            let reason = "Critical request expired without response";
            
            switch (escalateRequest(correlationId, "system", escalationTarget, reason)) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            }
        };
        
        private func generateFeaturesHash(aiFactors: [Text], confidence: Float, recommendation: Text) : Text {
            let combined = Text.join(",", aiFactors.vals()) # ":" # Float.toText(confidence) # ":" # recommendation;
            "hash_" # combined # "_" # debug_show(Time.now()) // Simplified hash
        };
        
        private func generateDecisionPath(_aiFactors: [Text], recommendation: Text, fallbackReason: ?Text) : [Text] {
            var path = ["Request received", "AI factors analyzed"];
            
            switch (fallbackReason) {
                case (?reason) {
                    path := Array.append(path, ["AI unavailable: " # reason, "Fallback rules applied"]);
                };
                case (null) {
                    path := Array.append(path, ["AI analysis completed"]);
                };
            };
            
            path := Array.append(path, ["Recommendation: " # recommendation, "HIL approval required"]);
            path
        };
        
        private func generateRiskAssessment(confidence: Float, _aiFactors: [Text]) : RiskAssessment {
            let riskScore = 1.0 - confidence; // Higher risk when confidence is low
            
            var riskFactors: [Text] = [];
            var mitigationSuggestions: [Text] = [];
            var escalationTriggers: [Text] = [];
            
            if (confidence < 0.7) {
                riskFactors := Array.append(riskFactors, ["Low confidence score"]);
                mitigationSuggestions := Array.append(mitigationSuggestions, ["Require additional verification"]);
            };
            
            if (confidence < 0.5) {
                escalationTriggers := Array.append(escalationTriggers, ["Critical confidence threshold"]);
            };
            
            {
                riskScore = riskScore;
                riskFactors = riskFactors;
                mitigationSuggestions = mitigationSuggestions;
                escalationTriggers = escalationTriggers;
            }
        };
        
        private func extractComplianceFlags(aiFactors: [Text]) : [Text] {
            var flags: [Text] = [];
            
            for (factor in aiFactors.vals()) {
                if (Text.contains(factor, #text("sanctions"))) {
                    flags := Array.append(flags, ["SANCTIONS_FLAG"]);
                };
                if (Text.contains(factor, #text("high_risk"))) {
                    flags := Array.append(flags, ["HIGH_RISK_FLAG"]);
                };
                if (Text.contains(factor, #text("compliance"))) {
                    flags := Array.append(flags, ["COMPLIANCE_FLAG"]);
                };
            };
            
            flags
        };
        
        private func getPriorityText(priority: Priority) : Text {
            switch (priority) {
                case (#Critical(_)) { "CRITICAL" };
                case (#High(_)) { "HIGH" };
                case (#Medium(_)) { "MEDIUM" };
                case (#Low(_)) { "LOW" };
            }
        };
        
        private func getRequestTypeText(requestType: HILRequestType) : Text {
            switch (requestType) {
                case (#EscrowRelease(_)) { "ESCROW_RELEASE" };
                case (#ComplianceOverride(_)) { "COMPLIANCE_OVERRIDE" };
                case (#HighValueTransaction(_)) { "HIGH_VALUE_TRANSACTION" };
                case (#SanctionsFlag(_)) { "SANCTIONS_FLAG" };
                case (#EmergencyEscalation(_)) { "EMERGENCY_ESCALATION" };
            }
        };
    };
}
