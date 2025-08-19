// Integration Layer for Escrow and Compliance Advisors
// Phase 2 Week 5 - Intelligence Integration

import Text "mo:base/Text";
import Float "mo:base/Float";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import EscrowAdvisor "../escrow_advisor/escrow_advisor";
import ComplianceAdvisor "../compliance_advisor/compliance_advisor";

module IntelligenceIntegration {
    
    public type AdvisoryRequest = {
        transactionId: Text;
        requestType: RequestType;
        escrowData: ?EscrowAdvisor.EscrowRequest;
        complianceData: ?ComplianceAdvisor.ComplianceRequest;
        priority: Priority;
        timestamp: Int;
    };
    
    public type RequestType = {
        #EscrowOnly;
        #ComplianceOnly;
        #Both;
        #Emergency;
    };
    
    public type Priority = {
        #Low;
        #Medium;
        #High;
        #Critical;
    };
    
    public type AdvisoryResponse = {
        transactionId: Text;
        escrowResponse: ?EscrowAdvisor.EscrowResponse;
        complianceResponse: ?ComplianceAdvisor.ComplianceResponse;
        combinedRecommendation: CombinedRecommendation;
        confidence: Float;
        processingTime: Int;
        flags: [Text];
    };
    
    public type CombinedRecommendation = {
        #Proceed: { confidence: Float; conditions: [Text] };
        #Block: { confidence: Float; reasons: [Text] };
        #Review: { confidence: Float; concerns: [Text] };
        #Escalate: { confidence: Float; urgency: Text };
    };
    
    public class IntelligenceService() {
        private let escrowAdvisor = EscrowAdvisor.EscrowAdvisor();
        private let complianceAdvisor = ComplianceAdvisor.ComplianceAdvisor();
        
        public func processRequest(request: AdvisoryRequest) : AdvisoryResponse {
            let _startTime = Debug.print("Processing advisory request: " # request.transactionId);
            
            var escrowResponse: ?EscrowAdvisor.EscrowResponse = null;
            var complianceResponse: ?ComplianceAdvisor.ComplianceResponse = null;
            var flags: [Text] = [];
            
            // Process escrow advisory if requested
            switch (request.requestType) {
                case (#EscrowOnly or #Both or #Emergency) {
                    switch (request.escrowData) {
                        case (?escrowData) {
                            escrowResponse := ?escrowAdvisor.recommend(escrowData);
                        };
                        case (null) {
                            flags := Array.append(["missing_escrow_data"], flags);
                        };
                    };
                };
                case (_) {};
            };
            
            // Process compliance advisory if requested
            switch (request.requestType) {
                case (#ComplianceOnly or #Both or #Emergency) {
                    switch (request.complianceData) {
                        case (?complianceData) {
                            complianceResponse := ?complianceAdvisor.checkCompliance(complianceData);
                        };
                        case (null) {
                            flags := Array.append(["missing_compliance_data"], flags);
                        };
                    };
                };
                case (_) {};
            };
            
            // Combine recommendations
            let combinedRecommendation = combineRecommendations(escrowResponse, complianceResponse, request.priority);
            let overallConfidence = calculateCombinedConfidence(escrowResponse, complianceResponse);
            
            {
                transactionId = request.transactionId;
                escrowResponse = escrowResponse;
                complianceResponse = complianceResponse;
                combinedRecommendation = combinedRecommendation;
                confidence = overallConfidence;
                processingTime = 0; // Would calculate actual time in production
                flags = flags;
            }
        };
        
        public func processEmergencyRequest(request: AdvisoryRequest) : AdvisoryResponse {
            // Emergency processing with accelerated decision making
            Debug.print("EMERGENCY: Processing critical advisory request: " # request.transactionId);
            
            let response = processRequest(request);
            
            // Apply emergency overrides if needed
            let emergencyRecommendation = switch (response.combinedRecommendation) {
                case (#Block(details)) {
                    // Emergency blocks are immediate
                    #Block({
                        confidence = Float.max(details.confidence, 0.95);
                        reasons = Array.append(["EMERGENCY_BLOCK"], details.reasons);
                    });
                };
                case (#Review(details)) {
                    // Emergency reviews escalate immediately
                    #Escalate({
                        confidence = details.confidence;
                        urgency = "IMMEDIATE";
                    });
                };
                case (other) { other };
            };
            
            {
                response with
                combinedRecommendation = emergencyRecommendation;
                flags = Array.append(["EMERGENCY_PROCESSING"], response.flags);
            }
        };
        
        private func combineRecommendations(
            escrowResponse: ?EscrowAdvisor.EscrowResponse,
            complianceResponse: ?ComplianceAdvisor.ComplianceResponse,
            priority: Priority
        ) : CombinedRecommendation {
            
            switch (escrowResponse, complianceResponse) {
                case (?escrow, ?compliance) {
                    // Both advisors provided input
                    combineBothRecommendations(escrow, compliance, priority);
                };
                case (?escrow, null) {
                    // Only escrow advisor
                    convertEscrowToCombined(escrow.recommendation);
                };
                case (null, ?compliance) {
                    // Only compliance advisor
                    convertComplianceToCombined(compliance.finalDecision);
                };
                case (null, null) {
                    // No advisors available - conservative approach
                    #Review({
                        confidence = 0.5;
                        concerns = ["no_advisory_data"];
                    });
                };
            }
        };
        
        private func combineBothRecommendations(
            escrow: EscrowAdvisor.EscrowResponse,
            compliance: ComplianceAdvisor.ComplianceResponse,
            priority: Priority
        ) : CombinedRecommendation {
            
            let escrowDecision = getEscrowDecisionType(escrow.recommendation);
            let complianceDecision = getComplianceDecisionType(compliance.finalDecision);
            
            // Safety-first combination logic
            if (escrowDecision == "hold" or complianceDecision == "reject") {
                return #Block({
                    confidence = Float.min(escrow.confidence, compliance.confidence);
                    reasons = ["escrow_hold_or_compliance_reject"];
                });
            };
            
            if (escrowDecision == "escalate" or complianceDecision == "review") {
                return #Review({
                    confidence = (escrow.confidence + compliance.confidence) / 2.0;
                    concerns = ["advisory_escalation_required"];
                });
            };
            
            if (escrowDecision == "request_info" or complianceDecision == "request_docs") {
                return #Review({
                    confidence = (escrow.confidence + compliance.confidence) / 2.0;
                    concerns = ["additional_information_required"];
                });
            };
            
            // Both approve - proceed with conditions
            if (escrowDecision == "release" and complianceDecision == "approve") {
                let combinedConfidence = (escrow.confidence + compliance.confidence) / 2.0;
                
                // Apply priority-based confidence adjustment
                let adjustedConfidence = switch (priority) {
                    case (#Critical) { Float.min(combinedConfidence, 0.85) }; // Be more cautious
                    case (#High) { combinedConfidence };
                    case (#Medium) { combinedConfidence };
                    case (#Low) { Float.max(combinedConfidence, 0.75) }; // Can be more permissive
                };
                
                return #Proceed({
                    confidence = adjustedConfidence;
                    conditions = ["escrow_release_approved", "compliance_cleared"];
                });
            };
            
            // Default: require review
            #Review({
                confidence = 0.7;
                concerns = ["complex_advisory_decision"];
            })
        };
        
        private func convertEscrowToCombined(recommendation: EscrowAdvisor.EscrowRecommendation) : CombinedRecommendation {
            switch (recommendation) {
                case (#Release(details)) {
                    #Proceed({
                        confidence = details.confidence;
                        conditions = ["escrow_release_recommended"];
                    });
                };
                case (#Hold(details)) {
                    #Block({
                        confidence = details.confidence;
                        reasons = details.reasoning;
                    });
                };
                case (#RequestInfo(details)) {
                    #Review({
                        confidence = details.confidence;
                        concerns = details.requirements;
                    });
                };
                case (#Escalate(details)) {
                    #Escalate({
                        confidence = 0.9; // Default confidence for escalations
                        urgency = details.urgency;
                    });
                };
            }
        };
        
        private func convertComplianceToCombined(recommendation: ComplianceAdvisor.ComplianceRecommendation) : CombinedRecommendation {
            switch (recommendation) {
                case (#Approve(details)) {
                    #Proceed({
                        confidence = details.confidence;
                        conditions = details.checks;
                    });
                };
                case (#Reject(details)) {
                    #Block({
                        confidence = details.confidence;
                        reasons = details.violations;
                    });
                };
                case (#RequireReview(details)) {
                    #Review({
                        confidence = details.confidence;
                        concerns = details.concerns;
                    });
                };
                case (#RequestDocumentation(details)) {
                    #Review({
                        confidence = details.confidence;
                        concerns = details.requirements;
                    });
                };
            }
        };
        
        private func getEscrowDecisionType(recommendation: EscrowAdvisor.EscrowRecommendation) : Text {
            switch (recommendation) {
                case (#Release(_)) { "release" };
                case (#Hold(_)) { "hold" };
                case (#RequestInfo(_)) { "request_info" };
                case (#Escalate(_)) { "escalate" };
            }
        };
        
        private func getComplianceDecisionType(recommendation: ComplianceAdvisor.ComplianceRecommendation) : Text {
            switch (recommendation) {
                case (#Approve(_)) { "approve" };
                case (#Reject(_)) { "reject" };
                case (#RequireReview(_)) { "review" };
                case (#RequestDocumentation(_)) { "request_docs" };
            }
        };
        
        private func calculateCombinedConfidence(
            escrowResponse: ?EscrowAdvisor.EscrowResponse,
            complianceResponse: ?ComplianceAdvisor.ComplianceResponse
        ) : Float {
            switch (escrowResponse, complianceResponse) {
                case (?escrow, ?compliance) {
                    // Weight both equally
                    (escrow.confidence + compliance.confidence) / 2.0;
                };
                case (?escrow, null) {
                    // Only escrow available - reduce confidence slightly
                    escrow.confidence * 0.9;
                };
                case (null, ?compliance) {
                    // Only compliance available - reduce confidence slightly
                    compliance.confidence * 0.9;
                };
                case (null, null) {
                    // No advisors - very low confidence
                    0.3;
                };
            }
        };
    };
}
