import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Float "mo:base/Float";

import AIEnvelope "../types/ai_envelope";
import PolicyEngine "../policy/policy_engine";

// Week 9 Auto-Action Integration Module
// Bridges AI Router and Policy Engine for safe auto-actions
module AutoActionIntegration {
    
    type AIRequest = AIEnvelope.AIRequest;
    type AIResponse = AIEnvelope.AIResponse;
    type PolicyDecision = PolicyEngine.PolicyDecision;
    type AutoActionConfig = PolicyEngine.AutoActionConfig;
    type ModuleAutoActions = PolicyEngine.ModuleAutoActions;
    
    // Week 9 Auto-action result with audit trail
    public type AutoActionResult = {
        decision : PolicyDecision;
        confidence : Float;
        reason : Text;
        moduleName : Text;
        corrId : Text;
        timestamp : Int;
        featureFlagEnabled : Bool;
        withinScope : Bool;
    };
    
    // Week 9 Feature flag controller
    public type FeatureFlags = {
        paymentsAutoActionsEnabled : Bool;
        escrowAutoActionsEnabled : Bool;
        governanceAutoActionsEnabled : Bool;
        globalKillSwitch : Bool; // Emergency disable all auto-actions
    };
    
    // Default feature flags (all off for Week 9 start)
    public let defaultFeatureFlags : FeatureFlags = {
        paymentsAutoActionsEnabled = false;
        escrowAutoActionsEnabled = false;
        governanceAutoActionsEnabled = false;
        globalKillSwitch = false;
    };
    
    // Week 9: Process auto-action for payments
    public func processPaymentAutoAction(
        request : AIRequest,
        aiResponse : ?AIResponse,
        config : AutoActionConfig,
        featureFlags : FeatureFlags,
        corrId : Text
    ) : AutoActionResult {
        let moduleName = "payments";
        let timestamp = Time.now();
        
        // Global kill switch check
        if (featureFlags.globalKillSwitch) {
            return {
                decision = #Proceed;
                confidence = 1.0;
                reason = "global_kill_switch_active";
                moduleName = moduleName;
                corrId = corrId;
                timestamp = timestamp;
                featureFlagEnabled = false;
                withinScope = true;
            };
        };
        
        // Module-specific feature flag check
        if (not featureFlags.paymentsAutoActionsEnabled) {
            return {
                decision = #Proceed;
                confidence = 1.0;
                reason = "feature_flag_disabled";
                moduleName = moduleName;
                corrId = corrId;
                timestamp = timestamp;
                featureFlagEnabled = false;
                withinScope = true;
            };
        };
        
        // Extract AI confidence and risk score
        let (aiConfidence, aiRiskScore) = switch (aiResponse) {
            case (?response) {
                // Extract from AI response
                let confidence = extractConfidence(response);
                let riskScore = extractRiskScore(response);
                (confidence, riskScore)
            };
            case null {
                (null, null)
            };
        };
        
        // Get auto-action decision
        let decision = PolicyEngine.decidePaymentAutoAction(
            request,
            config,
            aiConfidence,
            aiRiskScore
        );
        
        // Validate scope (Week 9 constraints)
        let withinScope = PolicyEngine.validateWeek9ActionScope(moduleName, decision);
        
        // Final decision with scope validation
        let finalDecision = if (withinScope) { decision } else { #Proceed };
        
        let result : AutoActionResult = {
            decision = finalDecision;
            confidence = switch (aiConfidence) { case (?c) c; case null 1.0 };
            reason = if (withinScope) { "auto_action_applied" } else { "scope_violation_fallback" };
            moduleName = moduleName;
            corrId = corrId;
            timestamp = timestamp;
            featureFlagEnabled = true;
            withinScope = withinScope;
        };
        
        // Audit the decision
        auditAutoAction(result);
        
        result
    };
    
    // Week 9: Process auto-action for escrow
    public func processEscrowAutoAction(
        request : AIRequest,
        aiResponse : ?AIResponse,
        config : AutoActionConfig,
        featureFlags : FeatureFlags,
        corrId : Text
    ) : AutoActionResult {
        let moduleName = "escrow";
        let timestamp = Time.now();
        
        // Global kill switch check
        if (featureFlags.globalKillSwitch) {
            return createFallbackResult(moduleName, corrId, timestamp, "global_kill_switch_active");
        };
        
        // Module-specific feature flag check
        if (not featureFlags.escrowAutoActionsEnabled) {
            return createFallbackResult(moduleName, corrId, timestamp, "feature_flag_disabled");
        };
        
        // Extract AI data
        let (aiConfidence, aiRiskScore) = extractAIData(aiResponse);
        
        // Get auto-action decision
        let decision = PolicyEngine.decideEscrowAutoAction(
            request,
            config,
            aiConfidence,
            aiRiskScore
        );
        
        // Validate scope (Week 9 constraints)
        let withinScope = PolicyEngine.validateWeek9ActionScope(moduleName, decision);
        let finalDecision = if (withinScope) { decision } else { #Proceed };
        
        let result : AutoActionResult = {
            decision = finalDecision;
            confidence = switch (aiConfidence) { case (?c) c; case null 1.0 };
            reason = if (withinScope) { "auto_action_applied" } else { "scope_violation_fallback" };
            moduleName = moduleName;
            corrId = corrId;
            timestamp = timestamp;
            featureFlagEnabled = true;
            withinScope = withinScope;
        };
        
        auditAutoAction(result);
        result
    };
    
    // Week 9: Process auto-action for governance
    public func processGovernanceAutoAction(
        request : AIRequest,
        aiResponse : ?AIResponse,
        config : AutoActionConfig,
        featureFlags : FeatureFlags,
        corrId : Text
    ) : AutoActionResult {
        let moduleName = "governance";
        let timestamp = Time.now();
        
        // Global kill switch check
        if (featureFlags.globalKillSwitch) {
            return createFallbackResult(moduleName, corrId, timestamp, "global_kill_switch_active");
        };
        
        // Module-specific feature flag check
        if (not featureFlags.governanceAutoActionsEnabled) {
            return createFallbackResult(moduleName, corrId, timestamp, "feature_flag_disabled");
        };
        
        // Extract AI data
        let (aiConfidence, aiRiskScore) = extractAIData(aiResponse);
        
        // Get auto-action decision
        let decision = PolicyEngine.decideGovernanceAutoAction(
            request,
            config,
            aiConfidence,
            aiRiskScore
        );
        
        // Validate scope (Week 9 constraints)
        let withinScope = PolicyEngine.validateWeek9ActionScope(moduleName, decision);
        let finalDecision = if (withinScope) { decision } else { #Proceed };
        
        let result : AutoActionResult = {
            decision = finalDecision;
            confidence = switch (aiConfidence) { case (?c) c; case null 1.0 };
            reason = if (withinScope) { "auto_action_applied" } else { "scope_violation_fallback" };
            moduleName = moduleName;
            corrId = corrId;
            timestamp = timestamp;
            featureFlagEnabled = true;
            withinScope = withinScope;
        };
        
        auditAutoAction(result);
        result
    };
    
    // Helper function to create fallback results
    private func createFallbackResult(
        moduleName : Text,
        corrId : Text,
        timestamp : Int,
        reason : Text
    ) : AutoActionResult {
        {
            decision = #Proceed;
            confidence = 1.0;
            reason = reason;
            moduleName = moduleName;
            corrId = corrId;
            timestamp = timestamp;
            featureFlagEnabled = false;
            withinScope = true;
        }
    };
    
    // Extract AI confidence from response
    private func extractConfidence(_response : AIResponse) : ?Float {
        // Simplified extraction - would implement based on AIResponse structure
        ?0.85 // Placeholder
    };
    
    // Extract AI risk score from response
    private func extractRiskScore(_response : AIResponse) : ?Nat8 {
        // Simplified extraction - would implement based on AIResponse structure
        ?75 // Placeholder
    };
    
    // Extract both confidence and risk score
    private func extractAIData(aiResponse : ?AIResponse) : (?Float, ?Nat8) {
        switch (aiResponse) {
            case (?response) {
                (extractConfidence(response), extractRiskScore(response))
            };
            case null {
                (null, null)
            };
        }
    };
    
    // Audit auto-action decision
    private func auditAutoAction(result : AutoActionResult) {
        Debug.print("WEEK9_AUTO_ACTION: " #
            "module=" # result.moduleName # 
            ", decision=" # debug_show(result.decision) #
            ", confidence=" # Float.toText(result.confidence) #
            ", reason=" # result.reason #
            ", corrId=" # result.corrId #
            ", featureEnabled=" # debug_show(result.featureFlagEnabled) #
            ", withinScope=" # debug_show(result.withinScope) #
            ", timestamp=" # debug_show(result.timestamp)
        );
    };
    
    // Week 9: Validate override rate (SLO requirement < 3%)
    public func validateOverrideRate(
        overrides : [PolicyEngine.AutoActionOverride],
        totalActions : Nat,
        windowMs : Int
    ) : {
        currentRate : Float;
        withinSLO : Bool;
        sloThreshold : Float;
    } {
        let sloThreshold = 0.03; // 3% threshold
        let currentRate = PolicyEngine.calculateOverrideRate(overrides, totalActions, windowMs);
        
        {
            currentRate = currentRate;
            withinSLO = currentRate <= sloThreshold;
            sloThreshold = sloThreshold;
        }
    };
    
    // Week 9: Shadow mode tracking for safe rollout
    public type ShadowModeResult = {
        autoActionDecision : PolicyDecision;
        actualDecision : PolicyDecision;
        wouldHaveMatched : Bool;
        confidence : Float;
        timestamp : Int;
    };
    
    // Compare auto-action with actual human decision (shadow mode)
    public func trackShadowMode(
        autoResult : AutoActionResult,
        humanDecision : PolicyDecision
    ) : ShadowModeResult {
        {
            autoActionDecision = autoResult.decision;
            actualDecision = humanDecision;
            wouldHaveMatched = autoResult.decision == humanDecision;
            confidence = autoResult.confidence;
            timestamp = autoResult.timestamp;
        }
    };
    
    // Calculate shadow mode accuracy for rollout decision
    public func calculateShadowAccuracy(shadowResults : [ShadowModeResult]) : {
        totalSamples : Nat;
        matches : Nat;
        accuracy : Float;
        confidenceThreshold : Float;
    } {
        let total = shadowResults.size();
        var matches = 0;
        var highConfidenceMatches = 0;
        var highConfidenceTotal = 0;
        
        let confidenceThreshold = 0.85;
        
        for (result in shadowResults.vals()) {
            if (result.wouldHaveMatched) {
                matches += 1;
            };
            
            if (result.confidence >= confidenceThreshold) {
                highConfidenceTotal += 1;
                if (result.wouldHaveMatched) {
                    highConfidenceMatches += 1;
                };
            };
        };
        
        let accuracy = if (total > 0) {
            Float.fromInt(matches) / Float.fromInt(total)
        } else { 0.0 };
        
        {
            totalSamples = total;
            matches = matches;
            accuracy = accuracy;
            confidenceThreshold = confidenceThreshold;
        }
    };
}
