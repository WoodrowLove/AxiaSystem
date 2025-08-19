// Compliance Advisory Module for Phase 2 Week 5
// Provides AI-powered compliance checks with tie-breaker logic

import Text "mo:base/Text";
import Float "mo:base/Float";

module ComplianceAdvisor {
    
    // Compliance recommendation types
    public type ComplianceRecommendation = {
        #Approve: { confidence: Float; checks: [Text] };
        #Reject: { confidence: Float; violations: [Text] };
        #RequireReview: { confidence: Float; concerns: [Text] };
        #RequestDocumentation: { confidence: Float; requirements: [Text] };
    };
    
    public type ComplianceRequest = {
        transactionId: Text;
        transactionType: TransactionType;
        amountTier: Nat; // 1-5 (Q1 compliant)
        participantInfo: ParticipantInfo;
        riskFactors: [Text];
        complianceFlags: [Text];
        jurisdictions: [Text];
    };
    
    public type TransactionType = {
        #Payment;
        #Escrow;
        #Refund;
        #Withdrawal;
        #Deposit;
    };
    
    public type ParticipantInfo = {
        verificationLevel: VerificationLevel;
        riskProfile: RiskProfile;
        jurisdictionFlags: [Text];
        sanctionsCheck: SanctionsStatus;
    };
    
    public type VerificationLevel = {
        #Unverified;
        #BasicVerified;
        #FullyVerified;
        #EnhancedVerified;
    };
    
    public type RiskProfile = {
        #Low;
        #Medium;
        #High;
        #Critical;
    };
    
    public type SanctionsStatus = {
        #Clear;
        #Flagged;
        #Under_Review;
        #Blocked;
    };
    
    public type ComplianceResponse = {
        recommendation: ComplianceRecommendation;
        rulesRecommendation: ComplianceRecommendation;
        finalDecision: ComplianceRecommendation;
        tieBreaker: ?TieBreakerResult;
        confidence: Float;
        aiFactors: [Text];
        auditTrail: [Text];
    };
    
    public type TieBreakerResult = {
        conflictReason: Text;
        resolution: Text;
        decidingFactor: Text;
        confidence: Float;
    };
    
    // Compliance advisor with tie-breaker logic
    public class ComplianceAdvisor() {
        
        public func checkCompliance(request: ComplianceRequest) : ComplianceResponse {
            // Get AI recommendation using advanced analysis (aiComplianceCheck) vs rules-based recommendation (rulesComplianceCheck)
            let aiRecommendation = aiComplianceCheck(request);
            
            // Get rules-based recommendation using deterministic rules
            let rulesRecommendation = rulesComplianceCheck(request);
            
            // Apply tie-breaker if needed
            let (finalDecision, tieBreaker) = resolveTieBreaker(aiRecommendation, rulesRecommendation, request);
            
            {
                recommendation = aiRecommendation;
                rulesRecommendation = rulesRecommendation;
                finalDecision = finalDecision;
                tieBreaker = tieBreaker;
                confidence = calculateOverallConfidence(aiRecommendation, rulesRecommendation);
                aiFactors = ["compliance_analysis", "risk_assessment"];
                auditTrail = generateComplianceAudit(request, aiRecommendation, rulesRecommendation);
            }
        };
        
        public func checkComplianceFallback(request: ComplianceRequest) : ComplianceResponse {
            let rulesOnly = rulesComplianceCheck(request);
            
            {
                recommendation = rulesOnly;
                rulesRecommendation = rulesOnly;
                finalDecision = rulesOnly;
                tieBreaker = null;
                confidence = 1.0;
                aiFactors = ["deterministic_rules_only"];
                auditTrail = ["Fallback compliance check using rules only"];
            }
        };
        
        private func aiComplianceCheck(request: ComplianceRequest) : ComplianceRecommendation {
            // Sanctions check (highest priority)
            switch (request.participantInfo.sanctionsCheck) {
                case (#Blocked) {
                    return #Reject({
                        confidence = 0.99;
                        violations = ["sanctions_violation", "blocked_entity"];
                    });
                };
                case (#Flagged) {
                    return #RequireReview({
                        confidence = 0.95;
                        concerns = ["sanctions_flag", "requires_investigation"];
                    });
                };
                case (#Under_Review) {
                    return #RequireReview({
                        confidence = 0.90;
                        concerns = ["ongoing_sanctions_review"];
                    });
                };
                case (#Clear) {};
            };
            
            // Risk profile assessment
            switch (request.participantInfo.riskProfile) {
                case (#Critical) {
                    return #Reject({
                        confidence = 0.90;
                        violations = ["critical_risk_profile"];
                    });
                };
                case (#High) {
                    return #RequireReview({
                        confidence = 0.85;
                        concerns = ["high_risk_profile", "enhanced_due_diligence"];
                    });
                };
                case (#Medium) {
                    // Continue with additional checks
                };
                case (#Low) {
                    // Low risk, likely to approve
                };
            };
            
            // Verification level checks
            if (request.amountTier >= 4) {
                switch (request.participantInfo.verificationLevel) {
                    case (#Unverified or #BasicVerified) {
                        return #RequestDocumentation({
                            confidence = 0.80;
                            requirements = ["enhanced_verification", "proof_of_identity"];
                        });
                    };
                    case (_) {};
                };
            };
            
            // Compliance flags analysis
            if (request.complianceFlags.size() > 0) {
                return #RequireReview({
                    confidence = 0.75;
                    concerns = request.complianceFlags;
                });
            };
            
            // Multiple jurisdiction complexity
            if (request.jurisdictions.size() > 2) {
                return #RequireReview({
                    confidence = 0.70;
                    concerns = ["multi_jurisdiction_complexity"];
                });
            };
            
            // Default: approve with standard checks
            #Approve({
                confidence = 0.85;
                checks = ["sanctions_clear", "risk_acceptable", "verification_sufficient"];
            })
        };
        
        private func rulesComplianceCheck(request: ComplianceRequest) : ComplianceRecommendation {
            // Hard rules that always apply
            
            // Rule 1: Blocked entities are always rejected
            if (request.participantInfo.sanctionsCheck == #Blocked) {
                return #Reject({
                    confidence = 1.0;
                    violations = ["sanctions_blocked"];
                });
            };
            
            // Rule 2: Critical risk profiles are rejected
            if (request.participantInfo.riskProfile == #Critical) {
                return #Reject({
                    confidence = 1.0;
                    violations = ["critical_risk"];
                });
            };
            
            // Rule 3: High-value transactions require full verification
            if (request.amountTier >= 5) {
                switch (request.participantInfo.verificationLevel) {
                    case (#EnhancedVerified) {
                        // Can proceed
                    };
                    case (_) {
                        return #RequestDocumentation({
                            confidence = 1.0;
                            requirements = ["enhanced_verification_required"];
                        });
                    };
                };
            };
            
            // Rule 4: Flagged sanctions require review
            if (request.participantInfo.sanctionsCheck == #Flagged) {
                return #RequireReview({
                    confidence = 1.0;
                    concerns = ["sanctions_flagged"];
                });
            };
            
            // Rule 5: Unverified users have limits
            if (request.participantInfo.verificationLevel == #Unverified and request.amountTier >= 3) {
                return #RequestDocumentation({
                    confidence = 1.0;
                    requirements = ["basic_verification_required"];
                });
            };
            
            // Default: approve
            #Approve({
                confidence = 1.0;
                checks = ["all_rules_passed"];
            })
        };
        
        private func resolveTieBreaker(
            ai: ComplianceRecommendation,
            rules: ComplianceRecommendation,
            request: ComplianceRequest
        ) : (ComplianceRecommendation, ?TieBreakerResult) {
            
            // Check if there's a conflict
            let aiDecision = getDecisionType(ai);
            let rulesDecision = getDecisionType(rules);
            
            if (aiDecision == rulesDecision) {
                // No conflict, use AI recommendation (more nuanced)
                return (ai, null);
            };
            
            // There's a conflict - apply tie-breaker logic
            let tieBreaker = determineTieBreaker(ai, rules, request);
            let finalDecision = tieBreaker.resolution;
            
            let resolvedRecommendation = switch (finalDecision) {
                case ("approve") { ai }; // Use AI's approve reasoning
                case ("reject") { 
                    // Use whichever recommended rejection
                    switch (ai) {
                        case (#Reject(_)) { ai };
                        case (_) { rules };
                    };
                };
                case ("review") {
                    #RequireReview({
                        confidence = 0.8;
                        concerns = ["ai_rules_conflict", "requires_human_review"];
                    });
                };
                case (_) { rules }; // Default to rules
            };
            
            (resolvedRecommendation, ?tieBreaker)
        };
        
        private func getDecisionType(recommendation: ComplianceRecommendation) : Text {
            switch (recommendation) {
                case (#Approve(_)) { "approve" };
                case (#Reject(_)) { "reject" };
                case (#RequireReview(_)) { "review" };
                case (#RequestDocumentation(_)) { "request_docs" };
            }
        };
        
        private func determineTieBreaker(
            ai: ComplianceRecommendation,
            rules: ComplianceRecommendation,
            request: ComplianceRequest
        ) : TieBreakerResult {
            let aiType = getDecisionType(ai);
            let rulesType = getDecisionType(rules);
            
            // Tie-breaker hierarchy: Safety first
            if (aiType == "reject" or rulesType == "reject") {
                {
                    conflictReason = "AI: " # aiType # ", Rules: " # rulesType;
                    resolution = "reject";
                    decidingFactor = "safety_first_principle";
                    confidence = 0.95;
                }
            } else if (aiType == "review" or rulesType == "review") {
                {
                    conflictReason = "AI: " # aiType # ", Rules: " # rulesType;
                    resolution = "review";
                    decidingFactor = "caution_principle";
                    confidence = 0.85;
                }
            } else if (request.amountTier >= 4) {
                // High-value transactions: prefer conservative approach
                {
                    conflictReason = "AI: " # aiType # ", Rules: " # rulesType;
                    resolution = "review";
                    decidingFactor = "high_value_conservatism";
                    confidence = 0.80;
                }
            } else {
                // Low-value transactions: can be more permissive
                {
                    conflictReason = "AI: " # aiType # ", Rules: " # rulesType;
                    resolution = "approve";
                    decidingFactor = "low_value_permissive";
                    confidence = 0.75;
                }
            }
        };
        
        private func calculateOverallConfidence(ai: ComplianceRecommendation, rules: ComplianceRecommendation) : Float {
            let aiConf = getRecommendationConfidence(ai);
            let rulesConf = getRecommendationConfidence(rules);
            
            // Average confidence, but weight rules slightly higher for compliance
            (aiConf * 0.4) + (rulesConf * 0.6)
        };
        
        private func getRecommendationConfidence(rec: ComplianceRecommendation) : Float {
            switch (rec) {
                case (#Approve(details)) { details.confidence };
                case (#Reject(details)) { details.confidence };
                case (#RequireReview(details)) { details.confidence };
                case (#RequestDocumentation(details)) { details.confidence };
            }
        };
        
        private func generateComplianceAudit(
            request: ComplianceRequest,
            ai: ComplianceRecommendation,
            rules: ComplianceRecommendation
        ) : [Text] {
            [
                "Compliance check for transaction: " # request.transactionId,
                "AI recommendation: " # getDecisionType(ai),
                "Rules recommendation: " # getDecisionType(rules),
                "Amount tier: " # debug_show(request.amountTier),
                "Risk profile: " # debug_show(request.participantInfo.riskProfile),
                "Verification level: " # debug_show(request.participantInfo.verificationLevel),
                "Sanctions status: " # debug_show(request.participantInfo.sanctionsCheck)
            ]
        };
    };
}
