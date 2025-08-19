import _Debug "mo:base/Debug";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Result "mo:base/Result";
import _HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";

import AIEnvelope "../types/ai_envelope";

module PolicyEngine {
    
    type AIRequest = AIEnvelope.AIRequest;
    type AIPayload = AIEnvelope.AIPayload;
    type RiskLevel = AIEnvelope.RiskLevel;
    type RiskAction = AIEnvelope.RiskAction;
    type ComplianceSeverity = AIEnvelope.ComplianceSeverity;
    type EscalationLevel = AIEnvelope.EscalationLevel;
    
    // Q2 Policy: Ownership split between Product and SRE
    public type PolicyDomain = {
        #Product;  // Business logic, UX, regulatory compliance
        #SRE;      // Performance, security controls, operational policies
        #Shared;   // AI decision thresholds, integration security
    };
    
    public type PolicyDecision = {
        #RequireMFA;
        #Hold;
        #Proceed;
        #Block;
        #Escalate: EscalationLevel;
    };
    
    public type PolicyRule = {
        id: Text;
        domain: PolicyDomain;
        condition: PolicyCondition;
        action: PolicyDecision;
        priority: Nat; // Higher number = higher priority
        active: Bool;
        lastModified: Time.Time;
        modifiedBy: Text;
    };
    
    public type PolicyCondition = {
        // Amount-based conditions (Q1 compliant - tiers only)
        amountTier: ?AmountTierCondition;
        
        // Risk-based conditions
        riskFactors: ?[Text]; // Must contain any of these factors
        
        // Request type conditions
        requestTypes: ?[AIEnvelope.AIRequestType];
        
        // Time-based conditions
        timeWindow: ?TimeWindow;
        
        // Frequency conditions
        frequency: ?FrequencyCondition;
        
        // Compliance conditions
        complianceFlags: ?[Text];
    };
    
    public type AmountTierCondition = {
        minTier: Nat; // 1-5
        maxTier: Nat; // 1-5
    };
    
    public type TimeWindow = {
        startHour: Nat; // 0-23
        endHour: Nat;   // 0-23
        timezone: Text;
    };
    
    public type FrequencyCondition = {
        maxRequests: Nat;
        windowMinutes: Nat;
        identifier: FrequencyIdentifier;
    };
    
    public type FrequencyIdentifier = {
        #UserId;
        #SessionId;
        #IPPattern; // Would use hashed IP as per Q1 policy
    };
    
    public type PolicyEvaluation = {
        decision: PolicyDecision;
        confidence: Float; // 0.0 - 1.0
        appliedRules: [Text]; // Rule IDs that triggered
        reasoning: [Text];
        escalationRequired: Bool;
        fallbackUsed: Bool;
    };
    
    // Default fallback policies (deterministic, no AI)
    public func getDefaultPolicies() : [PolicyRule] {
        [
            // Product domain policies
            {
                id = "PRODUCT_HIGH_VALUE_MFA";
                domain = #Product;
                condition = {
                    amountTier = ?{ minTier = 4; maxTier = 5 }; // Tier 4-5 (high value)
                    riskFactors = null;
                    requestTypes = ?[#PaymentRisk, #EscrowAdvisory];
                    timeWindow = null;
                    frequency = null;
                    complianceFlags = null;
                };
                action = #RequireMFA;
                priority = 100;
                active = true;
                lastModified = Time.now();
                modifiedBy = "SYSTEM_DEFAULT";
            },
            
            {
                id = "PRODUCT_FRAUD_BLOCK";
                domain = #Product;
                condition = {
                    amountTier = null;
                    riskFactors = ?["fraud_indicator", "suspicious_pattern", "blacklist_match"];
                    requestTypes = ?[#FraudDetection];
                    timeWindow = null;
                    frequency = null;
                    complianceFlags = null;
                };
                action = #Block;
                priority = 200;
                active = true;
                lastModified = Time.now();
                modifiedBy = "SYSTEM_DEFAULT";
            },
            
            // SRE domain policies
            {
                id = "SRE_RATE_LIMIT_BLOCK";
                domain = #SRE;
                condition = {
                    amountTier = null;
                    riskFactors = null;
                    requestTypes = null;
                    timeWindow = null;
                    frequency = ?{
                        maxRequests = 100;
                        windowMinutes = 1;
                        identifier = #UserId;
                    };
                    complianceFlags = null;
                };
                action = #Block;
                priority = 300;
                active = true;
                lastModified = Time.now();
                modifiedBy = "SYSTEM_DEFAULT";
            },
            
            {
                id = "SRE_OFF_HOURS_HOLD";
                domain = #SRE;
                condition = {
                    amountTier = ?{ minTier = 3; maxTier = 5 };
                    riskFactors = null;
                    requestTypes = null;
                    timeWindow = ?{
                        startHour = 22; // 10 PM
                        endHour = 6;    // 6 AM
                        timezone = "UTC";
                    };
                    frequency = null;
                    complianceFlags = null;
                };
                action = #Hold;
                priority = 150;
                active = true;
                lastModified = Time.now();
                modifiedBy = "SYSTEM_DEFAULT";
            },
            
            // Shared domain policies
            {
                id = "SHARED_COMPLIANCE_ESCALATE";
                domain = #Shared;
                condition = {
                    amountTier = null;
                    riskFactors = null;
                    requestTypes = ?[#ComplianceCheck];
                    timeWindow = null;
                    frequency = null;
                    complianceFlags = ?["aml_flag", "kyc_violation", "sanctions_check"];
                };
                action = #Escalate(#Legal);
                priority = 400;
                active = true;
                lastModified = Time.now();
                modifiedBy = "SYSTEM_DEFAULT";
            }
        ]
    };
    
    // Core policy evaluation function (deterministic)
    public func evaluateRequest(request: AIRequest, rules: [PolicyRule]) : PolicyEvaluation {
        let applicableRules = filterApplicableRules(request, rules);
        let sortedRules = Array.sort(applicableRules, func(a: PolicyRule, b: PolicyRule) : {#less; #equal; #greater} {
            if (a.priority > b.priority) #less
            else if (a.priority < b.priority) #greater
            else #equal
        });
        
        var appliedRuleIds: [Text] = [];
        var reasoning: [Text] = [];
        var policyDecision: PolicyDecision = #Proceed; // Default action
        var escalationRequired = false;
        
        // Apply highest priority rule that matches
        label ruleLoop for (rule in sortedRules.vals()) {
            if (evaluateCondition(rule.condition, request)) {
                policyDecision := rule.action;
                appliedRuleIds := Array.append(appliedRuleIds, [rule.id]);
                reasoning := Array.append(reasoning, ["Applied rule " # rule.id # " (" # debug_show(rule.domain) # ")"]);
                
                switch (rule.action) {
                    case (#Escalate(_)) { escalationRequired := true };
                    case (_) {};
                };
                
                // Take first matching rule (highest priority)
                break ruleLoop;
            };
        };
        
        {
            decision = policyDecision;
            confidence = 1.0; // Deterministic rules have 100% confidence
            appliedRules = appliedRuleIds;
            reasoning = reasoning;
            escalationRequired = escalationRequired;
            fallbackUsed = appliedRuleIds.size() == 0; // No rules matched
        }
    };
    
    // Advanced policy evaluation with AI advisory integration
    public func evaluateWithAIAdvisory(
        request: AIRequest, 
        rules: [PolicyRule],
        aiConfidence: ?Float,
        aiRecommendation: ?RiskAction
    ) : PolicyEvaluation {
        let baseEvaluation = evaluateRequest(request, rules);
        
        // If deterministic rules give clear decision, use that
        if (baseEvaluation.decision != #Proceed or not baseEvaluation.fallbackUsed) {
            return baseEvaluation;
        };
        
        // Use AI advisory for borderline cases
        switch (aiRecommendation, aiConfidence) {
            case (?recommendation, ?confidence) {
                if (confidence >= 0.8) { // High confidence threshold
                    let aiDecision = mapRiskActionToPolicyDecision(recommendation);
                    {
                        baseEvaluation with
                        decision = aiDecision;
                        confidence = confidence;
                        reasoning = Array.append(baseEvaluation.reasoning, ["AI advisory: " # debug_show(recommendation) # " (confidence: " # Float.toText(confidence) # ")"]);
                        fallbackUsed = false;
                    }
                } else {
                    // Low confidence - stick with fallback
                    {
                        baseEvaluation with
                        reasoning = Array.append(baseEvaluation.reasoning, ["AI confidence too low: " # Float.toText(confidence) # " < 0.8"]);
                    }
                }
            };
            case (_, _) {
                baseEvaluation // No AI recommendation available
            };
        }
    };
    
    // Human-in-the-loop escalation logic (Q3 policy)
    public func requiresHumanApproval(decision: PolicyDecision, amountTier: Nat) : Bool {
        switch (decision) {
            case (#Block) {
                // Require approval for blocking high-value transactions
                amountTier >= 4 // Tier 4-5 ($10K+ equivalent)
            };
            case (#Escalate(_)) {
                true // All escalations require human review
            };
            case (#Hold) {
                // Require approval for holds on very high value
                amountTier >= 5 // Tier 5 ($50K+ equivalent)
            };
            case (#RequireMFA or #Proceed) {
                false // Automated actions
            };
        }
    };
    
    // Policy rule management functions
    public func validatePolicyRule(rule: PolicyRule) : Result.Result<(), Text> {
        // Validate condition ranges
        switch (rule.condition.amountTier) {
            case (?tierCondition) {
                if (tierCondition.minTier < 1 or tierCondition.minTier > 5 or
                    tierCondition.maxTier < 1 or tierCondition.maxTier > 5 or
                    tierCondition.minTier > tierCondition.maxTier) {
                    return #err("Invalid amount tier condition: tiers must be 1-5 and min <= max");
                };
            };
            case null {};
        };
        
        // Validate time window
        switch (rule.condition.timeWindow) {
            case (?timeWindow) {
                if (timeWindow.startHour > 23 or timeWindow.endHour > 23) {
                    return #err("Invalid time window: hours must be 0-23");
                };
            };
            case null {};
        };
        
        // Validate frequency limits
        switch (rule.condition.frequency) {
            case (?frequency) {
                if (frequency.maxRequests == 0 or frequency.windowMinutes == 0) {
                    return #err("Invalid frequency condition: values must be > 0");
                };
            };
            case null {};
        };
        
        // Validate rule ID
        if (Text.size(rule.id) == 0) {
            return #err("Rule ID cannot be empty");
        };
        
        #ok()
    };
    
    // Policy change audit
    public func createPolicyChangeAudit(
        oldRule: ?PolicyRule, 
        newRule: PolicyRule, 
        changedBy: Text
    ) : {
        changeType: Text;
        ruleId: Text;
        domain: PolicyDomain;
        timestamp: Time.Time;
        changedBy: Text;
        changes: [Text];
    } {
        let changeType = switch (oldRule) {
            case (null) "CREATE";
            case (?_) "UPDATE";
        };
        
        var changes: [Text] = [];
        
        switch (oldRule) {
            case (?old) {
                if (old.active != newRule.active) {
                    changes := Array.append(changes, ["active: " # debug_show(old.active) # " -> " # debug_show(newRule.active)]);
                };
                if (old.priority != newRule.priority) {
                    changes := Array.append(changes, ["priority: " # debug_show(old.priority) # " -> " # debug_show(newRule.priority)]);
                };
                // Add more change detection as needed
            };
            case null {
                changes := ["New rule created"];
            };
        };
        
        {
            changeType = changeType;
            ruleId = newRule.id;
            domain = newRule.domain;
            timestamp = Time.now();
            changedBy = changedBy;
            changes = changes;
        }
    };
    
    // Private helper functions
    private func filterApplicableRules(request: AIRequest, rules: [PolicyRule]) : [PolicyRule] {
        Array.filter(rules, func(rule: PolicyRule) : Bool {
            rule.active and couldRuleApply(rule, request)
        })
    };
    
    private func couldRuleApply(rule: PolicyRule, request: AIRequest) : Bool {
        // Quick pre-filter before detailed evaluation
        switch (rule.condition.requestTypes) {
            case (?types) {
                Array.find<AIEnvelope.AIRequestType>(types, func(t: AIEnvelope.AIRequestType) : Bool = t == request.requestType) != null
            };
            case null { true };
        }
    };
    
    private func evaluateCondition(condition: PolicyCondition, request: AIRequest) : Bool {
        // Amount tier check
        switch (condition.amountTier) {
            case (?tierCondition) {
                let userTier = request.payload.amountTier;
                if (userTier < tierCondition.minTier or userTier > tierCondition.maxTier) {
                    return false;
                };
            };
            case null {};
        };
        
        // Risk factors check
        switch (condition.riskFactors) {
            case (?requiredFactors) {
                var hasMatchingFactor = false;
                label factorLoop for (required in requiredFactors.vals()) {
                    for (userFactor in request.payload.riskFactors.vals()) {
                        if (Text.contains(userFactor, #text required)) {
                            hasMatchingFactor := true;
                            break factorLoop;
                        };
                    };
                };
                if (not hasMatchingFactor) {
                    return false;
                };
            };
            case null {};
        };
        
        // Request type check
        switch (condition.requestTypes) {
            case (?types) {
                if (Array.find<AIEnvelope.AIRequestType>(types, func(t: AIEnvelope.AIRequestType) : Bool = t == request.requestType) == null) {
                    return false;
                };
            };
            case null {};
        };
        
        // Time window check (simplified - would need proper timezone handling)
        switch (condition.timeWindow) {
            case (?timeWindow) {
                let currentHour = getCurrentHour(); // Simplified implementation
                if (timeWindow.startHour <= timeWindow.endHour) {
                    // Same day window
                    if (currentHour < timeWindow.startHour or currentHour > timeWindow.endHour) {
                        return false;
                    };
                } else {
                    // Crosses midnight
                    if (currentHour < timeWindow.startHour and currentHour > timeWindow.endHour) {
                        return false;
                    };
                };
            };
            case null {};
        };
        
        // All conditions passed
        true
    };
    
    private func mapRiskActionToPolicyDecision(riskAction: RiskAction) : PolicyDecision {
        switch (riskAction) {
            case (#Proceed) #Proceed;
            case (#RequireMFA) #RequireMFA;
            case (#HoldForReview) #Hold;
            case (#Block) #Block;
            case (#Escalate) #Escalate(#Supervisor);
        }
    };
    
    private func getCurrentHour() : Nat {
        // Simplified - in production would use proper time zone conversion
        let now = Time.now();
        let secondsInDay = (now / 1000000000) % (24 * 60 * 60);
        Int.abs(secondsInDay) / 3600
    };
    
    // Policy metrics and reporting
    public func generatePolicyMetrics(evaluations: [PolicyEvaluation]) : {
        totalEvaluations: Nat;
        decisionBreakdown: [(PolicyDecision, Nat)];
        averageConfidence: Float;
        escalationRate: Float;
        fallbackRate: Float;
    } {
        var proceedCount = 0;
        var mfaCount = 0;
        var holdCount = 0;
        var blockCount = 0;
        var escalateCount = 0;
        var totalConfidence = 0.0;
        var escalations = 0;
        var fallbacks = 0;
        
        for (eval in evaluations.vals()) {
            switch (eval.decision) {
                case (#Proceed) { proceedCount += 1 };
                case (#RequireMFA) { mfaCount += 1 };
                case (#Hold) { holdCount += 1 };
                case (#Block) { blockCount += 1 };
                case (#Escalate(_)) { escalateCount += 1 };
            };
            
            totalConfidence += eval.confidence;
            
            if (eval.escalationRequired) {
                escalations += 1;
            };
            
            if (eval.fallbackUsed) {
                fallbacks += 1;
            };
        };
        
        let total = evaluations.size();
        let totalFloat = Float.fromInt(total);
        
        {
            totalEvaluations = total;
            decisionBreakdown = [
                (#Proceed, proceedCount),
                (#RequireMFA, mfaCount),
                (#Hold, holdCount),
                (#Block, blockCount),
                (#Escalate(#None), escalateCount)
            ];
            averageConfidence = if (total > 0) totalConfidence / totalFloat else 0.0;
            escalationRate = if (total > 0) Float.fromInt(escalations) / totalFloat else 0.0;
            fallbackRate = if (total > 0) Float.fromInt(fallbacks) / totalFloat else 0.0;
        }
    };
}
