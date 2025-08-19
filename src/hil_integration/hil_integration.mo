// HIL Integration Module for Phase 2 Week 6
// Connects Human-in-the-Loop with Intelligence Advisory system

import Text "mo:base/Text";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import HILService "../hil_service/hil_service";
import IntelligenceIntegration "../intelligence_integration/intelligence_integration";
import SREPolicyEngine "../sre_policy/sre_policy";
import EscrowAdvisor "../escrow_advisor/escrow_advisor";
import ComplianceAdvisor "../compliance_advisor/compliance_advisor";

module HILIntegration {
    
    public type HILTriggerCondition = {
        #LowConfidence: { threshold: Float };
        #ConflictingRecommendations: { aiVsRules: Bool };
        #HighValueTransaction: { amountThreshold: Float };
        #ComplianceEscalation: { riskLevel: Text };
        #ManualReview: { requestedBy: Text };
    };
    
    public type HILDecisionRequest = {
        intelligenceRequest: IntelligenceIntegration.AdvisoryRequest;
        intelligenceResponse: IntelligenceIntegration.AdvisoryResponse;
        triggerCondition: HILTriggerCondition;
        businessContext: BusinessContext;
        urgencyLevel: HILService.Priority;
    };
    
    public type BusinessContext = {
        transactionId: Text;
        customerTier: CustomerTier;
        businessImpact: BusinessImpact;
        regulatoryRequirements: [Text];
        stakeholders: [Text];
    };
    
    public type CustomerTier = {
        #Enterprise;
        #Premium;
        #Standard;
        #Basic;
    };
    
    public type BusinessImpact = {
        #Critical: { revenue: Float; reputation: Text };
        #High: { revenue: Float };
        #Medium: { operational: Text };
        #Low: { routine: Bool };
    };
    
    public type HILOutcome = {
        correlationId: Text;
        originalIntelligenceResponse: IntelligenceIntegration.AdvisoryResponse;
        hilDecision: HILService.ApprovalResponse;
        finalRecommendation: FinalRecommendation;
        executionInstructions: [Text];
        auditSummary: Text;
        slaCompliant: Bool;
    };
    
    public type FinalRecommendation = {
        #ExecuteOriginal: { confirmation: Text };
        #ExecuteModified: { modifications: [Text]; reasoning: Text };
        #Block: { reason: Text; duration: ?Nat };
        #Escalate: { to: Text; reason: Text };
        #RequestAdditionalInfo: { requirements: [Text] };
    };
    
    public class HILIntegrationService() {
        private let hilService = HILService.HILServiceManager();
        private let _srePolicy = SREPolicyEngine.SREPolicyManager();
        
        public func evaluateForHIL(
            intelligenceRequest: IntelligenceIntegration.AdvisoryRequest,
            intelligenceResponse: IntelligenceIntegration.AdvisoryResponse
        ) : Result.Result<?HILDecisionRequest, Text> {
            
            // Evaluate if HIL is needed
            switch (shouldTriggerHIL(intelligenceResponse)) {
                case (?trigger) {
                    let urgency = determineUrgency(intelligenceRequest, intelligenceResponse, trigger);
                    let businessContext = extractBusinessContext(intelligenceRequest);
                    
                    let hilRequest = {
                        intelligenceRequest = intelligenceRequest;
                        intelligenceResponse = intelligenceResponse;
                        triggerCondition = trigger;
                        businessContext = businessContext;
                        urgencyLevel = urgency;
                    };
                    
                    #ok(?hilRequest)
                };
                case (null) {
                    #ok(null) // No HIL needed
                };
            }
        };
        
        public func submitToHIL(hilRequest: HILDecisionRequest) : Result.Result<Text, Text> {
            // Extract AI factors from intelligence response
            let aiFactors = switch (hilRequest.intelligenceResponse.escrowResponse) {
                case (?_escrow) { ["escrow_analysis"] };
                case (null) {
                    switch (hilRequest.intelligenceResponse.complianceResponse) {
                        case (?_compliance) { ["compliance_analysis"] };
                        case (null) { ["no_ai_factors"] };
                    };
                };
            };
            
            // Generate audit bundle from intelligence response
            let auditBundle = hilService.generateAuditBundle(
                aiFactors,
                hilRequest.intelligenceResponse.confidence,
                getRecommendationText(hilRequest.intelligenceResponse.combinedRecommendation),
                hilRequest.intelligenceRequest.transactionId,
                getFailureReason(hilRequest.intelligenceResponse)
            );
            
            // Determine SLA based on urgency and business impact
            let slaMinutes = calculateSLA(hilRequest.urgencyLevel, hilRequest.businessContext);
            let currentTime = Time.now();
            let slaExpiresAt = currentTime + (slaMinutes * 60 * 1_000_000_000); // Convert minutes to nanoseconds
            
            // Create approval request
            let approvalRequest: HILService.ApprovalRequest = {
                correlationId = hilRequest.intelligenceRequest.transactionId # "_hil_" # debug_show(currentTime);
                requestType = mapToHILRequestType(hilRequest);
                priority = hilRequest.urgencyLevel;
                submittedAt = currentTime;
                slaExpiresAt = slaExpiresAt;
                auditBundle = auditBundle;
                status = #Pending;
                assignedTo = null;
                escalationLevel = 0;
                metadata = [
                    ("original_confidence", Float.toText(hilRequest.intelligenceResponse.confidence)),
                    ("trigger_condition", getTriggerConditionText(hilRequest.triggerCondition)),
                    ("business_impact", getBusinessImpactText(hilRequest.businessContext.businessImpact))
                ];
            };
            
            // Submit to HIL service
            switch (hilService.submitApprovalRequest(approvalRequest)) {
                case (#ok(_result)) {
                    Debug.print("HIL request submitted: " # approvalRequest.correlationId);
                    #ok(approvalRequest.correlationId)
                };
                case (#err(error)) {
                    Debug.print("HIL submission failed: " # error);
                    #err(error)
                };
            }
        };
        
        public func processHILOutcome(
            correlationId: Text,
            hilDecision: HILService.ApprovalResponse
        ) : Result.Result<HILOutcome, Text> {
            switch (hilService.getApprovalRequest(correlationId)) {
                case (null) {
                    #err("HIL request not found: " # correlationId)
                };
                case (?approvalRequest) {
                    // Extract original intelligence response from metadata
                    let originalResponse = reconstructIntelligenceResponse(approvalRequest);
                    
                    // Generate final recommendation based on HIL decision
                    let finalRecommendation = generateFinalRecommendation(hilDecision, approvalRequest);
                    
                    // Generate execution instructions
                    let executionInstructions = generateExecutionInstructions(finalRecommendation, approvalRequest);
                    
                    // Check SLA compliance
                    let slaCompliant = hilDecision.timestamp <= approvalRequest.slaExpiresAt;
                    
                    // Generate audit summary
                    let auditSummary = generateAuditSummary(approvalRequest, hilDecision, slaCompliant);
                    
                    let outcome = {
                        correlationId = correlationId;
                        originalIntelligenceResponse = originalResponse;
                        hilDecision = hilDecision;
                        finalRecommendation = finalRecommendation;
                        executionInstructions = executionInstructions;
                        auditSummary = auditSummary;
                        slaCompliant = slaCompliant;
                    };
                    
                    #ok(outcome)
                };
            }
        };
        
        public func getHILMetrics() : HILService.SLAMetrics {
            hilService.getSLAMetrics()
        };
        
        public func checkExpiredRequests() : [Text] {
            hilService.checkSLAExpiration()
        };
        
        private func shouldTriggerHIL(response: IntelligenceIntegration.AdvisoryResponse) : ?HILTriggerCondition {
            // Low confidence trigger
            if (response.confidence < 0.6) {
                return ?#LowConfidence({ threshold = 0.6 });
            };
            
            // Conflicting recommendations trigger
            switch (response.escrowResponse, response.complianceResponse) {
                case (?escrow, ?compliance) {
                    let escrowDecision = convertEscrowRecommendationToText(escrow.recommendation);
                    let complianceDecision = convertComplianceRecommendationToText(compliance.finalDecision);
                    
                    if (isConflicting(escrowDecision, complianceDecision)) {
                        return ?#ConflictingRecommendations({ aiVsRules = true });
                    };
                };
                case (_, _) {};
            };
            
            // High value transaction trigger
            switch (response.escrowResponse) {
                case (?_escrow) {
                    // Extract amount from escrow data (simplified)
                    return ?#HighValueTransaction({ amountThreshold = 100000.0 });
                };
                case (null) {};
            };
            
            // Compliance escalation trigger
            switch (response.complianceResponse) {
                case (?compliance) {
                    if (compliance.confidence < 0.5) {
                        return ?#ComplianceEscalation({ riskLevel = "HIGH" });
                    };
                };
                case (null) {};
            };
            
            null // No HIL needed
        };
        
        private func determineUrgency(
            _request: IntelligenceIntegration.AdvisoryRequest,
            response: IntelligenceIntegration.AdvisoryResponse,
            trigger: HILTriggerCondition
        ) : HILService.Priority {
            switch (trigger) {
                case (#ComplianceEscalation(_) or #ConflictingRecommendations(_)) {
                    #Critical({ slaMinutes = 15 })
                };
                case (#HighValueTransaction(_)) {
                    #High({ slaMinutes = 60 })
                };
                case (#LowConfidence(_)) {
                    if (response.confidence < 0.3) {
                        #High({ slaMinutes = 60 })
                    } else {
                        #Medium({ slaMinutes = 240 })
                    }
                };
                case (#ManualReview(_)) {
                    #Medium({ slaMinutes = 240 })
                };
            }
        };
        
        private func extractBusinessContext(request: IntelligenceIntegration.AdvisoryRequest) : BusinessContext {
            // Simplified business context extraction
            {
                transactionId = request.transactionId;
                customerTier = #Standard; // Would be determined from request data
                businessImpact = #Medium({ operational = "Standard transaction processing" });
                regulatoryRequirements = ["AML", "KYC"];
                stakeholders = ["finance_team", "compliance_team"];
            }
        };
        
        private func mapToHILRequestType(hilRequest: HILDecisionRequest) : HILService.HILRequestType {
            switch (hilRequest.triggerCondition) {
                case (#HighValueTransaction({ amountThreshold })) {
                    #HighValueTransaction({ amount = amountThreshold; threshold = amountThreshold });
                };
                case (#ComplianceEscalation({ riskLevel })) {
                    #ComplianceOverride({ violationType = "ESCALATION"; riskLevel = riskLevel });
                };
                case (#ConflictingRecommendations(_)) {
                    #EmergencyEscalation({ reason = "Conflicting AI recommendations"; urgency = "HIGH" });
                };
                case (#LowConfidence(_)) {
                    #ComplianceOverride({ violationType = "LOW_CONFIDENCE"; riskLevel = "MEDIUM" });
                };
                case (#ManualReview({ requestedBy })) {
                    #EmergencyEscalation({ reason = "Manual review requested by " # requestedBy; urgency = "MEDIUM" });
                };
            }
        };
        
        private func calculateSLA(priority: HILService.Priority, businessContext: BusinessContext) : Nat {
            let baseSLA = switch (priority) {
                case (#Critical({ slaMinutes })) { slaMinutes };
                case (#High({ slaMinutes })) { slaMinutes };
                case (#Medium({ slaMinutes })) { slaMinutes };
                case (#Low({ slaMinutes })) { slaMinutes };
            };
            
            // Adjust based on business impact
            switch (businessContext.businessImpact) {
                case (#Critical(_)) { baseSLA / 2 }; // Halve SLA for critical impact
                case (#High(_)) { (baseSLA * 3) / 4 }; // 75% of normal SLA
                case (#Medium(_)) { baseSLA };
                case (#Low(_)) { baseSLA * 2 }; // Double SLA for low impact
            }
        };
        
        private func generateFinalRecommendation(
            hilDecision: HILService.ApprovalResponse,
            _approvalRequest: HILService.ApprovalRequest
        ) : FinalRecommendation {
            switch (hilDecision.action) {
                case (#Approve) {
                    #ExecuteOriginal({ confirmation = "Approved by " # hilDecision.approver });
                };
                case (#Deny) {
                    #Block({ reason = hilDecision.reasoning; duration = null });
                };
                case (#Escalate({ to; reason })) {
                    #Escalate({ to = to; reason = reason });
                };
                case (#RequestMoreInfo({ questions })) {
                    #RequestAdditionalInfo({ requirements = questions });
                };
                case (#Acknowledge) {
                    #ExecuteOriginal({ confirmation = "Acknowledged by " # hilDecision.approver });
                };
            }
        };
        
        private func generateExecutionInstructions(
            finalRecommendation: FinalRecommendation,
            _approvalRequest: HILService.ApprovalRequest
        ) : [Text] {
            switch (finalRecommendation) {
                case (#ExecuteOriginal({ confirmation })) {
                    ["Execute original AI recommendation", "Log approval: " # confirmation];
                };
                case (#Block({ reason; duration })) {
                    switch (duration) {
                        case (?d) { ["Block transaction", "Reason: " # reason, "Duration: " # debug_show(d) # " minutes"] };
                        case (null) { ["Block transaction permanently", "Reason: " # reason] };
                    };
                };
                case (#Escalate({ to; reason })) {
                    ["Escalate to " # to, "Reason: " # reason, "Maintain hold status"];
                };
                case (#RequestAdditionalInfo({ requirements })) {
                    Array.append(["Request additional information"], requirements);
                };
                case (#ExecuteModified({ modifications; reasoning })) {
                    ["Execute with modifications", "Modifications: " # Text.join(", ", modifications.vals()), "Reasoning: " # reasoning];
                };
            }
        };
        
        private func generateAuditSummary(
            approvalRequest: HILService.ApprovalRequest,
            hilDecision: HILService.ApprovalResponse,
            slaCompliant: Bool
        ) : Text {
            let slaStatus = if (slaCompliant) { "WITHIN_SLA" } else { "SLA_VIOLATED" };
            
            "HIL Decision Summary: " #
            "Request: " # approvalRequest.correlationId # ", " #
            "Decision: " # debug_show(hilDecision.action) # ", " #
            "Approver: " # hilDecision.approver # ", " #
            "SLA: " # slaStatus # ", " #
            "Reasoning: " # hilDecision.reasoning
        };
        
        private func reconstructIntelligenceResponse(approvalRequest: HILService.ApprovalRequest) : IntelligenceIntegration.AdvisoryResponse {
            // Simplified reconstruction - in production would store full response
            {
                transactionId = approvalRequest.correlationId;
                escrowResponse = null;
                complianceResponse = null;
                combinedRecommendation = #Review({ confidence = 0.5; concerns = ["HIL_REQUIRED"] });
                confidence = 0.5;
                processingTime = 0;
                flags = ["HIL_PROCESSED"];
            }
        };
        
        private func getRecommendationText(recommendation: IntelligenceIntegration.CombinedRecommendation) : Text {
            switch (recommendation) {
                case (#Proceed(_)) { "PROCEED" };
                case (#Block(_)) { "BLOCK" };
                case (#Review(_)) { "REVIEW" };
                case (#Escalate(_)) { "ESCALATE" };
            }
        };
        
        private func getFailureReason(response: IntelligenceIntegration.AdvisoryResponse) : ?Text {
            if (Array.find<Text>(response.flags, func(flag) = flag == "escrow_analysis_failed") != null) {
                ?("Escrow analysis failed")
            } else if (Array.find<Text>(response.flags, func(flag) = flag == "compliance_analysis_failed") != null) {
                ?("Compliance analysis failed")
            } else {
                null
            }
        };
        
        private func getTriggerConditionText(condition: HILTriggerCondition) : Text {
            switch (condition) {
                case (#LowConfidence(_)) { "LOW_CONFIDENCE" };
                case (#ConflictingRecommendations(_)) { "CONFLICTING_RECOMMENDATIONS" };
                case (#HighValueTransaction(_)) { "HIGH_VALUE_TRANSACTION" };
                case (#ComplianceEscalation(_)) { "COMPLIANCE_ESCALATION" };
                case (#ManualReview(_)) { "MANUAL_REVIEW" };
            }
        };
        
        private func getBusinessImpactText(impact: BusinessImpact) : Text {
            switch (impact) {
                case (#Critical(_)) { "CRITICAL" };
                case (#High(_)) { "HIGH" };
                case (#Medium(_)) { "MEDIUM" };
                case (#Low(_)) { "LOW" };
            }
        };
        
        private func convertEscrowRecommendationToText(recommendation: EscrowAdvisor.EscrowRecommendation) : Text {
            switch (recommendation) {
                case (#Release(_)) { "RELEASE" };
                case (#Hold(_)) { "HOLD" };
                case (#RequestInfo(_)) { "REQUEST_INFO" };
                case (#Escalate(_)) { "ESCALATE" };
            }
        };
        
        private func convertComplianceRecommendationToText(recommendation: ComplianceAdvisor.ComplianceRecommendation) : Text {
            switch (recommendation) {
                case (#Approve(_)) { "APPROVE" };
                case (#Reject(_)) { "REJECT" };
                case (#RequireReview(_)) { "REVIEW" };
                case (#RequestDocumentation(_)) { "REQUEST_DOCS" };
            }
        };
        
        private func _getEscrowDecisionType(recommendation: Text) : Text {
            recommendation
        };
        
        private func _getComplianceDecisionType(recommendation: Text) : Text {
            recommendation
        };
        
        private func isConflicting(escrowDecision: Text, complianceDecision: Text) : Bool {
            // Simplified conflict detection
            (escrowDecision == "APPROVE" and complianceDecision == "REJECT") or
            (escrowDecision == "REJECT" and complianceDecision == "APPROVE")
        };
    };
}
