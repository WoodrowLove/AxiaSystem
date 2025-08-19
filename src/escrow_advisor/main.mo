import _Debug "mo:base/Debug";
import Time "mo:base/Time";
import _Result "mo:base/Result";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";

import _AI "../types/ai_envelope";

module EscrowAdvisor {
    
    // Escrow recommendation types
    public type EscrowRecommendation = {
        #Release: { confidence: Float; reasoning: [Text]; riskScore: Float };
        #Hold: { confidence: Float; reasoning: [Text]; riskScore: Float };
        #RequestAdditionalInfo: { confidence: Float; reasoning: [Text]; requirements: [Text] };
        #Escalate: { level: EscalationLevel; reasoning: [Text]; urgency: Urgency };
    };
    
    public type EscalationLevel = {
        #Supervisor;
        #Management; 
        #Legal;
        #Compliance;
    };
    
    public type Urgency = {
        #Low;     // Standard escalation - 24 hours
        #Medium;  // Priority escalation - 4 hours
        #High;    // Urgent escalation - 1 hour
        #Critical; // Immediate escalation - 15 minutes
    };
    
    public type EscrowAdvisoryRequest = {
        correlationId: Text;
        escrowId: Text;
        sessionId: Text;
        escrowDetails: EscrowDetails;
        requestedAction: EscrowAction;
        timeoutMs: Nat;
        retryCount: Nat;
    };
    
    public type EscrowDetails = {
        escrowAmount: Float;
        amountTier: Nat; // 1-5 based on amount ranges (Q1 compliant)
        projectId: Text;
        milestoneId: ?Text;
        participantCount: Nat;
        escrowAge: Int; // Days since creation
        disputeHistory: [DisputeRecord];
        complianceFlags: [Text];
        riskFactors: [Text];
    };
    
    public type DisputeRecord = {
        disputeId: Text;
        raisedAt: Time.Time;
        resolvedAt: ?Time.Time;
        outcome: ?DisputeOutcome;
        severity: DisputeSeverity;
    };
    
    public type DisputeOutcome = {
        #FavorBuyer;
        #FavorSeller;
        #PartialRefund: Float;
        #Mediation;
    };
    
    public type DisputeSeverity = {
        #Minor;   // < $1,000 impact
        #Moderate; // $1,000 - $10,000 impact
        #Major;   // $10,000 - $50,000 impact
        #Critical; // > $50,000 impact
    };
    
    public type EscrowAction = {
        #Release;
        #Hold;
        #PartialRelease: Float;
        #RefundBuyer;
        #ExtendDeadline: Int; // Days to extend
    };
    
    public type EscrowAdvisoryResponse = {
        correlationId: Text;
        recommendation: EscrowRecommendation;
        alternativeOptions: [EscrowRecommendation];
        confidence: Float;
        processingTimeMs: Nat;
        aiFactors: [Text];
        fallbackUsed: Bool;
        auditTrail: [Text];
    };
    
    // Risk assessment factors
    public type RiskAssessment = {
        overallRisk: Float; // 0.0 - 1.0
        riskFactors: [(Text, Float)]; // Factor name and weight
        mitigatingFactors: [(Text, Float)];
        riskCategory: RiskCategory;
        recommendedAction: EscrowRecommendation;
    };
    
    public type RiskCategory = {
        #LowRisk;    // 0.0 - 0.3
        #MediumRisk; // 0.3 - 0.7
        #HighRisk;   // 0.7 - 0.9
        #CriticalRisk; // 0.9 - 1.0
    };
    
    // Escrow advisor engine
    public class EscrowAdvisorEngine() {
        
        // Main advisory function - determines escrow action recommendation
        public func recommend(request: EscrowAdvisoryRequest) : EscrowAdvisoryResponse {
            let startTime = Time.now();
            
            // 1. Perform risk assessment
            let riskAssessment = assessRisk(request.escrowDetails);
            
            // 2. Analyze historical patterns
            let historicalFactors = analyzeHistoricalPatterns(request.escrowDetails);
            
            // 3. Apply business rules
            let businessRuleResult = applyBusinessRules(request);
            
            // 4. Generate final recommendation
            let recommendation = synthesizeRecommendation(
                riskAssessment,
                historicalFactors,
                businessRuleResult,
                request.requestedAction
            );
            
            // 5. Calculate confidence and alternatives
            let confidence = calculateConfidence(riskAssessment, historicalFactors);
            let alternatives = generateAlternatives(recommendation, riskAssessment);
            
            let processingTime = Int.abs(Time.now() - startTime) / 1_000_000;
            
            {
                correlationId = request.correlationId;
                recommendation = recommendation;
                alternativeOptions = alternatives;
                confidence = confidence;
                processingTimeMs = Int.abs(processingTime);
                aiFactors = extractAIFactors(riskAssessment, historicalFactors);
                fallbackUsed = false; // This is AI-powered recommendation
                auditTrail = generateAuditTrail(request, riskAssessment, recommendation);
            }
        };
        
        // Deterministic fallback when AI is unavailable
        public func recommendFallback(request: EscrowAdvisoryRequest) : EscrowAdvisoryResponse {
            let startTime = Time.now();
            
            // Use deterministic rules based on amount tiers and basic risk factors
            let recommendation = determineFallbackRecommendation(request);
            let processingTime = Int.abs(Time.now() - startTime) / 1_000_000;
            
            {
                correlationId = request.correlationId;
                recommendation = recommendation;
                alternativeOptions = [];
                confidence = 1.0; // Deterministic rules are 100% confident
                processingTimeMs = Int.abs(processingTime);
                aiFactors = ["deterministic_fallback"];
                fallbackUsed = true;
                auditTrail = ["Fallback recommendation based on deterministic rules"];
            }
        };
        
        // Risk assessment engine
        private func assessRisk(details: EscrowDetails) : RiskAssessment {
            var riskScore: Float = 0.0;
            var factors: [(Text, Float)] = [];
            var mitigating: [(Text, Float)] = [];
            
            // Amount-based risk (higher amounts = higher risk)
            let amountRisk = switch (details.amountTier) {
                case (1) { 0.1 }; // Low amounts
                case (2) { 0.2 };
                case (3) { 0.4 };
                case (4) { 0.7 }; // High amounts
                case (5) { 0.9 }; // Very high amounts
                case (_) { 0.5 }; // Default medium risk
            };
            riskScore += amountRisk * 0.3;
            factors := Array.append(factors, [("amount_tier_risk", amountRisk)]);
            
            // Dispute history risk
            let disputeCount = details.disputeHistory.size();
            let disputeRisk = Float.min(Float.fromInt(disputeCount) * 0.2, 1.0);
            riskScore += disputeRisk * 0.3;
            factors := Array.append(factors, [("dispute_history_risk", disputeRisk)]);
            
            // Age-based risk (very new or very old escrows are riskier)
            let ageRisk = if (details.escrowAge < 1) {
                0.6 // New escrows are risky
            } else if (details.escrowAge > 90) {
                0.8 // Very old escrows are risky
            } else if (details.escrowAge > 30) {
                0.3 // Moderately aged escrows
            } else {
                0.1 // Normal age range
            };
            riskScore += ageRisk * 0.2;
            factors := Array.append(factors, [("escrow_age_risk", ageRisk)]);
            
            // Compliance flags risk
            let complianceRisk = Float.min(Float.fromInt(details.complianceFlags.size()) * 0.3, 1.0);
            riskScore += complianceRisk * 0.2;
            factors := Array.append(factors, [("compliance_flags_risk", complianceRisk)]);
            
            // Participant count (more participants = more complexity)
            let participantRisk = if (details.participantCount > 5) {
                0.5
            } else if (details.participantCount > 2) {
                0.2
            } else {
                0.1
            };
            factors := Array.append(factors, [("participant_complexity_risk", participantRisk)]);
            
            // Mitigating factors
            if (details.milestoneId != null) {
                mitigating := Array.append(mitigating, [("milestone_based", 0.1)]);
                riskScore -= 0.05; // Milestone-based escrows are less risky
            };
            
            // Normalize risk score
            riskScore := Float.max(0.0, Float.min(1.0, riskScore));
            
            let category = if (riskScore <= 0.3) {
                #LowRisk
            } else if (riskScore <= 0.7) {
                #MediumRisk
            } else if (riskScore <= 0.9) {
                #HighRisk
            } else {
                #CriticalRisk
            };
            
            let recommendedAction = generateRiskBasedRecommendation(riskScore, details);
            
            {
                overallRisk = riskScore;
                riskFactors = factors;
                mitigatingFactors = mitigating;
                riskCategory = category;
                recommendedAction = recommendedAction;
            }
        };
        
        private func generateRiskBasedRecommendation(riskScore: Float, _details: EscrowDetails) : EscrowRecommendation {
            if (riskScore <= 0.3) {
                #Release({
                    confidence = 0.9;
                    reasoning = ["Low risk assessment", "Normal escrow parameters"];
                    riskScore = riskScore;
                })
            } else if (riskScore <= 0.5) {
                #RequestAdditionalInfo({
                    confidence = 0.8;
                    reasoning = ["Medium risk detected", "Additional verification recommended"];
                    requirements = ["project_status_update", "milestone_verification"];
                })
            } else if (riskScore <= 0.8) {
                #Hold({
                    confidence = 0.7;
                    reasoning = ["High risk factors identified", "Hold pending investigation"];
                    riskScore = riskScore;
                })
            } else {
                #Escalate({
                    level = #Management;
                    reasoning = ["Critical risk level", "Requires management approval"];
                    urgency = #High;
                })
            }
        };
        
        private func analyzeHistoricalPatterns(details: EscrowDetails) : [Text] {
            var patterns: [Text] = [];
            
            // Analyze dispute patterns
            let recentDisputes = Array.filter<DisputeRecord>(details.disputeHistory, func(dispute) {
                let daysSince = Int.abs(Time.now() - dispute.raisedAt) / (24 * 60 * 60 * 1_000_000_000);
                daysSince < 30 // Last 30 days
            });
            
            if (recentDisputes.size() > 0) {
                patterns := Array.append(patterns, ["recent_dispute_activity"]);
            };
            
            // Check for recurring dispute patterns
            let disputeTypes = Array.map<DisputeRecord, DisputeSeverity>(details.disputeHistory, func(d) = d.severity);
            if (disputeTypes.size() > 2) {
                patterns := Array.append(patterns, ["multiple_dispute_history"]);
            };
            
            patterns
        };
        
        private func applyBusinessRules(request: EscrowAdvisoryRequest) : EscrowRecommendation {
            let details = request.escrowDetails;
            
            // Business rule: High-value escrows require additional approval
            if (details.amountTier >= 4) {
                return #Escalate({
                    level = #Management;
                    reasoning = ["High-value escrow requires management approval"];
                    urgency = #Medium;
                });
            };
            
            // Business rule: Escrows with compliance flags need review
            if (details.complianceFlags.size() > 0) {
                return #Hold({
                    confidence = 0.8;
                    reasoning = ["Compliance flags detected", "Hold pending compliance review"];
                    riskScore = 0.6;
                });
            };
            
            // Business rule: Recent disputes require caution
            let recentDisputes = Array.filter<DisputeRecord>(details.disputeHistory, func(dispute) {
                let daysSince = Int.abs(Time.now() - dispute.raisedAt) / (24 * 60 * 60 * 1_000_000_000);
                daysSince < 7 // Last 7 days
            });
            
            if (recentDisputes.size() > 0) {
                return #RequestAdditionalInfo({
                    confidence = 0.7;
                    reasoning = ["Recent dispute activity detected"];
                    requirements = ["dispute_resolution_status", "participant_confirmation"];
                });
            };
            
            // Default: proceed with standard assessment
            #Release({
                confidence = 0.8;
                reasoning = ["Business rules assessment passed"];
                riskScore = 0.2;
            })
        };
        
        private func synthesizeRecommendation(
            riskAssessment: RiskAssessment,
            _historicalFactors: [Text],
            businessRuleResult: EscrowRecommendation,
            _requestedAction: EscrowAction
        ) : EscrowRecommendation {
            // Use the most restrictive recommendation from all assessments
            let assessments = [riskAssessment.recommendedAction, businessRuleResult];
            
            // Priority order: Escalate > Hold > RequestAdditionalInfo > Release
            for (assessment in assessments.vals()) {
                switch (assessment) {
                    case (#Escalate(_)) { return assessment };
                    case (_) {};
                };
            };
            
            for (assessment in assessments.vals()) {
                switch (assessment) {
                    case (#Hold(_)) { return assessment };
                    case (_) {};
                };
            };
            
            for (assessment in assessments.vals()) {
                switch (assessment) {
                    case (#RequestAdditionalInfo(_)) { return assessment };
                    case (_) {};
                };
            };
            
            // If all assessments suggest release, return release
            #Release({
                confidence = 0.85;
                reasoning = ["All assessments support release", "Risk within acceptable limits"];
                riskScore = riskAssessment.overallRisk;
            })
        };
        
        private func calculateConfidence(riskAssessment: RiskAssessment, historicalFactors: [Text]) : Float {
            var baseConfidence: Float = 0.8;
            
            // Adjust confidence based on risk level
            baseConfidence -= riskAssessment.overallRisk * 0.2;
            
            // Adjust for historical complexity
            if (historicalFactors.size() > 2) {
                baseConfidence -= 0.1;
            };
            
            Float.max(0.3, Float.min(0.95, baseConfidence))
        };
        
        private func generateAlternatives(primary: EscrowRecommendation, riskAssessment: RiskAssessment) : [EscrowRecommendation] {
            switch (primary) {
                case (#Release(_)) {
                    [
                        #RequestAdditionalInfo({
                            confidence = 0.6;
                            reasoning = ["Alternative: additional verification"];
                            requirements = ["milestone_confirmation"];
                        })
                    ]
                };
                case (#Hold(_)) {
                    [
                        #RequestAdditionalInfo({
                            confidence = 0.7;
                            reasoning = ["Alternative: request additional information before hold"];
                            requirements = ["project_status", "participant_verification"];
                        }),
                        #Escalate({
                            level = #Supervisor;
                            reasoning = ["Alternative: escalate for review"];
                            urgency = #Medium;
                        })
                    ]
                };
                case (#RequestAdditionalInfo(_)) {
                    [
                        #Hold({
                            confidence = 0.6;
                            reasoning = ["Alternative: hold if information not provided"];
                            riskScore = riskAssessment.overallRisk;
                        })
                    ]
                };
                case (#Escalate(_)) {
                    [
                        #Hold({
                            confidence = 0.8;
                            reasoning = ["Alternative: hold pending escalation"];
                            riskScore = riskAssessment.overallRisk;
                        })
                    ]
                };
            }
        };
        
        private func extractAIFactors(riskAssessment: RiskAssessment, historicalFactors: [Text]) : [Text] {
            var factors: [Text] = [];
            
            // Add risk factors
            for ((factor, weight) in riskAssessment.riskFactors.vals()) {
                if (weight > 0.3) {
                    factors := Array.append(factors, [factor]);
                };
            };
            
            // Add historical factors
            factors := Array.append(factors, historicalFactors);
            
            // Add risk category
            let categoryText = switch (riskAssessment.riskCategory) {
                case (#LowRisk) { "low_risk_category" };
                case (#MediumRisk) { "medium_risk_category" };
                case (#HighRisk) { "high_risk_category" };
                case (#CriticalRisk) { "critical_risk_category" };
            };
            factors := Array.append(factors, [categoryText]);
            
            factors
        };
        
        private func generateAuditTrail(request: EscrowAdvisoryRequest, riskAssessment: RiskAssessment, recommendation: EscrowRecommendation) : [Text] {
            [
                "Escrow advisory request processed for ID: " # request.escrowId,
                "Risk assessment completed with score: " # Float.toText(riskAssessment.overallRisk),
                "Recommendation generated: " # debug_show(recommendation),
                "Processing completed at: " # Int.toText(Time.now())
            ]
        };
        
        private func determineFallbackRecommendation(request: EscrowAdvisoryRequest) : EscrowRecommendation {
            let details = request.escrowDetails;
            
            // Simple deterministic rules for fallback
            if (details.amountTier >= 5) {
                #Escalate({
                    level = #Management;
                    reasoning = ["Fallback: Very high value requires management approval"];
                    urgency = #High;
                })
            } else if (details.complianceFlags.size() > 0) {
                #Hold({
                    confidence = 1.0;
                    reasoning = ["Fallback: Compliance flags require hold"];
                    riskScore = 0.8;
                })
            } else if (details.disputeHistory.size() > 2) {
                #RequestAdditionalInfo({
                    confidence = 1.0;
                    reasoning = ["Fallback: Multiple disputes require additional info"];
                    requirements = ["dispute_status", "project_verification"];
                })
            } else if (details.amountTier >= 3) {
                #RequestAdditionalInfo({
                    confidence = 1.0;
                    reasoning = ["Fallback: Medium-high value requires verification"];
                    requirements = ["milestone_confirmation"];
                })
            } else {
                #Release({
                    confidence = 1.0;
                    reasoning = ["Fallback: Low risk parameters, safe to release"];
                    riskScore = 0.2;
                })
            }
        };
    };
}
