import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Bool "mo:base/Bool";

// Auto-Action Policy Actor for Week 9 - Phase 3 Implementation
// Feature-flagged safe auto-actions with strict constraints
persistent actor AutoActionPolicy {
    
    // Action types allowed in Week 9
    public type Action = { 
        #Proceed; 
        #RequireMFA; 
        #HoldForReview; 
        #Block; 
        #SuggestHold;
        #Flag 
    };
    
    public type TriadCtx = { 
        identityId : Principal; 
        userId : ?Principal; 
        walletId : ?Principal 
    };
    
    public type RiskAdvisory = { 
        score : Nat8; 
        factors : [Text]; 
        confidence : Float 
    };
    
    public type AutoActionConfig = {
        enabled : Bool;
        minConfidence : Float;
        maxAmount : Nat;
        allowedRiskScore : Nat8;
    };
    
    public type ModuleConfig = {
        payments : AutoActionConfig;
        escrow : AutoActionConfig;
        governance : AutoActionConfig;
    };
    
    // Default configuration - feature-flagged off by default for Week 9
    private transient let defaultConfig : ModuleConfig = {
        payments = {
            enabled = false; // Feature flag - off by default
            minConfidence = 0.85; // 85% confidence minimum
            maxAmount = 50000; // $50k threshold for auto-actions
            allowedRiskScore = 75; // High risk threshold
        };
        escrow = {
            enabled = false; // Feature flag - off by default
            minConfidence = 0.90; // 90% confidence for escrow
            maxAmount = 10000; // Lower threshold for escrow
            allowedRiskScore = 70;
        };
        governance = {
            enabled = false; // Feature flag - off by default
            minConfidence = 0.95; // Very high confidence for governance
            maxAmount = 0; // No amount threshold - flags only
            allowedRiskScore = 50; // Lower threshold for flagging
        };
    };
    
    // Current configuration (stable for persistence)
    private var currentConfig : ModuleConfig = defaultConfig;
    
    // Update configuration (SRE/Product controlled)
    public func updateConfig(newConfig : ModuleConfig) : async Result.Result<(), Text> {
        // Validation: ensure confidence thresholds are reasonable
        if (newConfig.payments.minConfidence < 0.7 or newConfig.payments.minConfidence > 1.0) {
            return #err("Invalid payments confidence threshold");
        };
        if (newConfig.escrow.minConfidence < 0.8 or newConfig.escrow.minConfidence > 1.0) {
            return #err("Invalid escrow confidence threshold");
        };
        if (newConfig.governance.minConfidence < 0.9 or newConfig.governance.minConfidence > 1.0) {
            return #err("Invalid governance confidence threshold");
        };
        
        currentConfig := newConfig;
        Debug.print("Auto-action config updated at " # debug_show(Time.now()));
        #ok(())
    };
    
    // Get current configuration
    public query func getConfig() : async ModuleConfig {
        currentConfig
    };
    
    // Enable feature flag for specific module (controlled rollout)
    public func enableModule(moduleName : Text) : async Result.Result<(), Text> {
        switch (moduleName) {
            case ("payments") {
                currentConfig := {
                    currentConfig with
                    payments = { currentConfig.payments with enabled = true }
                };
                Debug.print("Payments auto-actions ENABLED");
                #ok(())
            };
            case ("escrow") {
                currentConfig := {
                    currentConfig with
                    escrow = { currentConfig.escrow with enabled = true }
                };
                Debug.print("Escrow auto-actions ENABLED");
                #ok(())
            };
            case ("governance") {
                currentConfig := {
                    currentConfig with
                    governance = { currentConfig.governance with enabled = true }
                };
                Debug.print("Governance auto-actions ENABLED");
                #ok(())
            };
            case (_) #err("Unknown module: " # moduleName);
        };
    };
    
    // Disable feature flag for specific module (emergency shutoff)
    public func disableModule(moduleName : Text) : async Result.Result<(), Text> {
        switch (moduleName) {
            case ("payments") {
                currentConfig := {
                    currentConfig with
                    payments = { currentConfig.payments with enabled = false }
                };
                Debug.print("Payments auto-actions DISABLED");
                #ok(())
            };
            case ("escrow") {
                currentConfig := {
                    currentConfig with
                    escrow = { currentConfig.escrow with enabled = false }
                };
                Debug.print("Escrow auto-actions DISABLED");
                #ok(())
            };
            case ("governance") {
                currentConfig := {
                    currentConfig with
                    governance = { currentConfig.governance with enabled = false }
                };
                Debug.print("Governance auto-actions DISABLED");
                #ok(())
            };
            case (_) #err("Unknown module: " # moduleName);
        };
    };
    
    // Determine auto-action for payments (Week 9 scope)
    public func decidePaymentAction(
        ctx : TriadCtx,
        amountTier : Nat8,
        actualAmount : ?Nat,
        advisory : RiskAdvisory,
        corrId : Text
    ) : async Action {
        let config = currentConfig.payments;
        
        // Feature flag check - if disabled, no auto-actions
        if (not config.enabled) {
            auditAutoAction("payments", ctx, #Proceed, advisory, corrId, "feature_disabled");
            return #Proceed;
        };
        
        // Confidence check
        if (advisory.confidence < config.minConfidence) {
            auditAutoAction("payments", ctx, #Proceed, advisory, corrId, "low_confidence");
            return #Proceed; // Fall back to normal flow
        };
        
        // Amount check (if provided)
        switch (actualAmount) {
            case (?amount) {
                if (amount > config.maxAmount) {
                    auditAutoAction("payments", ctx, #Proceed, advisory, corrId, "amount_exceeds_threshold");
                    return #Proceed; // Too high - require human oversight
                };
            };
            case null {
                // Use tier-based check as fallback
                if (amountTier > 4) { // Tier 5 = highest amounts
                    auditAutoAction("payments", ctx, #Proceed, advisory, corrId, "high_amount_tier");
                    return #Proceed;
                };
            };
        };
        
        // Risk-based auto-actions (Week 9 limited scope)
        if (advisory.score >= config.allowedRiskScore) {
            if (advisory.score >= 90) {
                let action = #HoldForReview;
                auditAutoAction("payments", ctx, action, advisory, corrId, "very_high_risk");
                return action;
            } else {
                let action = #RequireMFA;
                auditAutoAction("payments", ctx, action, advisory, corrId, "high_risk");
                return action;
            };
        };
        
        auditAutoAction("payments", ctx, #Proceed, advisory, corrId, "normal_risk");
        #Proceed
    };
    
    // Determine auto-action for escrow (Week 9 scope)
    public func decideEscrowAction(
        ctx : TriadCtx,
        escrowAmount : ?Nat,
        advisory : RiskAdvisory,
        corrId : Text
    ) : async Action {
        let config = currentConfig.escrow;
        
        // Feature flag check
        if (not config.enabled) {
            auditAutoAction("escrow", ctx, #Proceed, advisory, corrId, "feature_disabled");
            return #Proceed;
        };
        
        // Confidence check
        if (advisory.confidence < config.minConfidence) {
            auditAutoAction("escrow", ctx, #Proceed, advisory, corrId, "low_confidence");
            return #Proceed;
        };
        
        // Amount check
        switch (escrowAmount) {
            case (?amount) {
                if (amount > config.maxAmount) {
                    auditAutoAction("escrow", ctx, #Proceed, advisory, corrId, "amount_exceeds_threshold");
                    return #Proceed; // Require human oversight for large amounts
                };
            };
            case null { /* No amount restriction */ };
        };
        
        // For escrow, we only suggest holds - never block or auto-release (Week 9 constraint)
        if (advisory.score >= config.allowedRiskScore) {
            let action = #SuggestHold;
            auditAutoAction("escrow", ctx, action, advisory, corrId, "high_risk_suggest_hold");
            return action;
        };
        
        auditAutoAction("escrow", ctx, #Proceed, advisory, corrId, "normal_risk");
        #Proceed
    };
    
    // Determine auto-action for governance (Week 9 scope)
    public func decideGovernanceAction(
        ctx : TriadCtx,
        _proposalType : Text,
        advisory : RiskAdvisory,
        corrId : Text
    ) : async Action {
        let config = currentConfig.governance;
        
        // Feature flag check
        if (not config.enabled) {
            auditAutoAction("governance", ctx, #Proceed, advisory, corrId, "feature_disabled");
            return #Proceed;
        };
        
        // Confidence check
        if (advisory.confidence < config.minConfidence) {
            auditAutoAction("governance", ctx, #Proceed, advisory, corrId, "low_confidence");
            return #Proceed;
        };
        
        // For governance, we only flag - never auto-approve or block (Week 9 constraint)
        if (advisory.score >= config.allowedRiskScore) {
            let action = #Flag;
            auditAutoAction("governance", ctx, action, advisory, corrId, "flagged_for_review");
            return action;
        };
        
        auditAutoAction("governance", ctx, #Proceed, advisory, corrId, "normal_risk");
        #Proceed
    };
    
    // Audit function - track auto-action decisions
    private func auditAutoAction(
        moduleName : Text,
        _ctx : TriadCtx,
        action : Action,
        advisory : RiskAdvisory,
        corrId : Text,
        reason : Text
    ) {
        Debug.print("AUTO_ACTION_AUDIT: " # 
            "module=" # moduleName # 
            ", action=" # debug_show(action) # 
            ", confidence=" # Float.toText(advisory.confidence) # 
            ", riskScore=" # debug_show(advisory.score) # 
            ", corrId=" # corrId #
            ", reason=" # reason #
            ", timestamp=" # debug_show(Time.now())
        );
    };
    
    // Safety check - validate that action is within allowed scope (Week 9)
    public func validateActionScope(moduleName : Text, action : Action) : async Bool {
        switch (moduleName, action) {
            case ("payments", #RequireMFA) true;
            case ("payments", #HoldForReview) true;
            case ("payments", #Proceed) true;
            case ("escrow", #SuggestHold) true;
            case ("escrow", #Proceed) true;
            case ("governance", #Flag) true;
            case ("governance", #Proceed) true;
            case (_, _) false; // All other combinations are forbidden in Week 9
        };
    };
    
    // Override tracking for monitoring (Week 9 SLO requirement)
    public type Override = {
        corrId : Text;
        moduleName : Text;
        originalAction : Action;
        humanAction : Action;
        reason : Text;
        timestamp : Int;
    };
    
    private var overrides : [Override] = [];
    
    // Record when humans override auto-actions
    public func recordOverride(
        corrId : Text,
        moduleName : Text,
        originalAction : Action,
        humanAction : Action,
        reason : Text
    ) : async () {
        let override : Override = {
            corrId = corrId;
            moduleName = moduleName;
            originalAction = originalAction;
            humanAction = humanAction;
            reason = reason;
            timestamp = Time.now();
        };
        
        // Store the override (in production, would use proper data structure)
        overrides := [override]; // Simplified - would append properly
        Debug.print("OVERRIDE_RECORDED: " # debug_show(override));
    };
    
    // Calculate override rate (for SLO monitoring: < 3% target)
    public query func getOverrideRate(windowMs : Int) : async Float {
        let now = Time.now();
        let _windowStart = now - windowMs * 1_000_000; // Convert to nanoseconds
        
        // In production, would filter overrides by timestamp window
        let recentOverrides = overrides.size(); 
        let totalActions = 100; // In production, would track actual auto-actions
        
        if (totalActions == 0) {
            return 0.0;
        };
        
        Float.fromInt(recentOverrides) / Float.fromInt(totalActions)
    };
    
    // Get override statistics for monitoring
    public query func getOverrideStats() : async {
        totalOverrides : Nat;
        recentOverrides : Nat;
        overrideRate : Float;
    } {
        let total = overrides.size();
        let recent = total; // Simplified - would filter by time window
        let rate = if (total > 0) { Float.fromInt(recent) / Float.fromInt(total) } else { 0.0 };
        
        {
            totalOverrides = total;
            recentOverrides = recent;
            overrideRate = rate;
        }
    };
    
    // Emergency kill switch - disable all auto-actions
    public func emergencyDisable() : async () {
        currentConfig := {
            payments = { currentConfig.payments with enabled = false };
            escrow = { currentConfig.escrow with enabled = false };
            governance = { currentConfig.governance with enabled = false };
        };
        Debug.print("EMERGENCY_DISABLE: All auto-actions disabled at " # debug_show(Time.now()));
    };
    
    // Health check for monitoring
    public query func healthCheck() : async {
        status : Text;
        paymentsEnabled : Bool;
        escrowEnabled : Bool;
        governanceEnabled : Bool;
        timestamp : Int;
    } {
        {
            status = "healthy";
            paymentsEnabled = currentConfig.payments.enabled;
            escrowEnabled = currentConfig.escrow.enabled;
            governanceEnabled = currentConfig.governance.enabled;
            timestamp = Time.now();
        }
    };
}
