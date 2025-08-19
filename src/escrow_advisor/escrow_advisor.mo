// Escrow Advisory Module for Phase 2 Week 5
// Provides AI-powered escrow outcome recommendations

import Text "mo:base/Text";
import Float "mo:base/Float";
import Int "mo:base/Int";

module EscrowAdvisor {
    
    // Core recommendation types
    public type EscrowRecommendation = {
        #Release: { confidence: Float; reasoning: [Text] };
        #Hold: { confidence: Float; reasoning: [Text] };
        #RequestInfo: { confidence: Float; requirements: [Text] };
        #Escalate: { level: Text; urgency: Text };
    };
    
    public type EscrowRequest = {
        escrowId: Text;
        amountTier: Nat; // 1-5 (Q1 compliant)
        projectId: Text;
        riskFactors: [Text];
        disputeCount: Nat;
        escrowAge: Int;
    };
    
    public type EscrowResponse = {
        recommendation: EscrowRecommendation;
        confidence: Float;
        aiFactors: [Text];
        fallbackUsed: Bool;
    };
    
    // Simple escrow advisor for Phase 2 foundation
    public class EscrowAdvisor() {
        
        public func recommend(request: EscrowRequest) : EscrowResponse {
            let recommendation = analyzeEscrow(request);
            let confidence = calculateConfidence(request);
            
            {
                recommendation = recommendation;
                confidence = confidence;
                aiFactors = ["amount_tier", "risk_assessment"];
                fallbackUsed = false;
            }
        };
        
        public func recommendFallback(request: EscrowRequest) : EscrowResponse {
            let recommendation = fallbackLogic(request);
            
            {
                recommendation = recommendation;
                confidence = 1.0;
                aiFactors = ["deterministic_fallback"];
                fallbackUsed = true;
            }
        };
        
        private func analyzeEscrow(request: EscrowRequest) : EscrowRecommendation {
            // High-value escrows need escalation
            if (request.amountTier >= 4) {
                return #Escalate({
                    level = "management";
                    urgency = "medium";
                });
            };
            
            // Recent disputes require caution
            if (request.disputeCount > 0) {
                return #RequestInfo({
                    confidence = 0.7;
                    requirements = ["dispute_status", "resolution_proof"];
                });
            };
            
            // High risk factors require hold
            if (request.riskFactors.size() > 2) {
                return #Hold({
                    confidence = 0.8;
                    reasoning = ["Multiple risk factors detected"];
                });
            };
            
            // Old escrows need review
            if (request.escrowAge > 90) {
                return #RequestInfo({
                    confidence = 0.6;
                    requirements = ["project_status", "milestone_update"];
                });
            };
            
            // Default: safe to release
            #Release({
                confidence = 0.9;
                reasoning = ["Low risk assessment", "Standard parameters"];
            })
        };
        
        private func calculateConfidence(request: EscrowRequest) : Float {
            var confidence: Float = 0.8;
            
            // Reduce confidence for high-risk scenarios
            if (request.amountTier >= 4) { confidence -= 0.1 };
            if (request.disputeCount > 0) { confidence -= 0.1 };
            if (request.riskFactors.size() > 2) { confidence -= 0.1 };
            
            Float.max(0.5, confidence)
        };
        
        private func fallbackLogic(request: EscrowRequest) : EscrowRecommendation {
            // Simple deterministic rules
            if (request.amountTier >= 5) {
                #Escalate({ level = "management"; urgency = "high" })
            } else if (request.disputeCount > 0) {
                #Hold({ confidence = 1.0; reasoning = ["Dispute detected"] })
            } else if (request.amountTier >= 3) {
                #RequestInfo({ confidence = 1.0; requirements = ["verification"] })
            } else {
                #Release({ confidence = 1.0; reasoning = ["Low risk"] })
            }
        };
    };
}
