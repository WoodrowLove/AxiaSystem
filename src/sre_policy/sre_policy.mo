// SRE Policy Enhancement Module for Phase 2 Week 6
// Advanced SRE policies for latency budgets and dynamic throttling

import Text "mo:base/Text";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";

module SREPolicyEngine {
    
    public type LatencyBudget = {
        pathName: Text;
        targetP95Ms: Nat;
        targetP99Ms: Nat;
        budgetRemaining: Float;
        violationCount: Nat;
        windowStartTime: Time.Time;
        windowDurationMs: Nat;
        totalRequests: Nat;
        violatingRequests: Nat;
    };
    
    public type PathMetrics = {
        pathName: Text;
        currentP95Ms: Nat;
        currentP99Ms: Nat;
        requestCount: Nat;
        errorRate: Float;
        throughputRPS: Float;
        lastUpdated: Time.Time;
        healthStatus: PathHealthStatus;
    };
    
    public type PathHealthStatus = {
        #Healthy;
        #Degraded: { reason: Text; severity: Nat };
        #Critical: { reason: Text; actionRequired: Text };
        #Throttled: { level: Nat; reason: Text };
    };
    
    public type ThrottlePolicy = {
        pathName: Text;
        currentLevel: Nat; // 0-10 (0 = no throttle, 10 = maximum throttle)
        maxLevel: Nat;
        stepSize: Nat;
        cooldownPeriodMs: Nat;
        lastAdjustment: Time.Time;
        triggerConditions: [ThrottleTrigger];
        recoveryConditions: [RecoveryCondition];
    };
    
    public type ThrottleTrigger = {
        #LatencyBudgetViolation: { consecutiveViolations: Nat };
        #ErrorRateSpike: { threshold: Float };
        #CircuitBreakerOpen: { pathName: Text };
        #ResourceExhaustion: { metric: Text; threshold: Float };
    };
    
    public type RecoveryCondition = {
        #LatencyImprovement: { targetReduction: Float };
        #ErrorRateNormalization: { maxRate: Float };
        #StablePerformance: { durationMs: Nat };
        #ManualOverride: { operator: Text };
    };
    
    public type SLITracker = {
        pathName: Text;
        sliType: SLIType;
        target: Float;
        current: Float;
        trend: TrendDirection;
        alertThreshold: Float;
        lastAlert: ?Time.Time;
        measurements: [SLIMeasurement];
    };
    
    public type SLIType = {
        #Availability: { windowMs: Nat };
        #Latency: { percentile: Nat };
        #Throughput: { windowMs: Nat };
        #ErrorRate: { windowMs: Nat };
    };
    
    public type TrendDirection = {
        #Improving;
        #Stable;
        #Degrading;
        #Critical;
    };
    
    public type SLIMeasurement = {
        timestamp: Time.Time;
        value: Float;
        context: [(Text, Text)];
    };
    
    public type PolicyAction = {
        #ThrottleIncrease: { pathName: Text; newLevel: Nat };
        #ThrottleDecrease: { pathName: Text; newLevel: Nat };
        #CircuitBreakerTrigger: { pathName: Text; reason: Text };
        #AlertTrigger: { pathName: Text; severity: Text; message: Text };
        #RollbackTrigger: { pathName: Text; reason: Text };
    };
    
    public type PolicyDecision = {
        timestamp: Time.Time;
        trigger: Text;
        decision: PolicyAction;
        reasoning: [Text];
        confidence: Float;
        expectedImpact: Text;
    };
    
    public class SREPolicyManager() {
        private var latencyBudgets = HashMap.HashMap<Text, LatencyBudget>(10, Text.equal, Text.hash);
        private var pathMetrics = HashMap.HashMap<Text, PathMetrics>(10, Text.equal, Text.hash);
        private var throttlePolicies = HashMap.HashMap<Text, ThrottlePolicy>(10, Text.equal, Text.hash);
        private var sliTrackers = HashMap.HashMap<Text, SLITracker>(10, Text.equal, Text.hash);
        private var policyDecisions: [PolicyDecision] = [];
        
        public func initializeLatencyBudget(
            pathName: Text,
            targetP95Ms: Nat,
            targetP99Ms: Nat,
            windowDurationMs: Nat
        ) : Result.Result<LatencyBudget, Text> {
            let budget = {
                pathName = pathName;
                targetP95Ms = targetP95Ms;
                targetP99Ms = targetP99Ms;
                budgetRemaining = 1.0; // 100% budget remaining
                violationCount = 0;
                windowStartTime = Time.now();
                windowDurationMs = windowDurationMs;
                totalRequests = 0;
                violatingRequests = 0;
            };
            
            latencyBudgets.put(pathName, budget);
            Debug.print("Initialized latency budget for path: " # pathName);
            
            #ok(budget)
        };
        
        public func initializeThrottlePolicy(
            pathName: Text,
            maxLevel: Nat,
            stepSize: Nat,
            cooldownPeriodMs: Nat
        ) : Result.Result<ThrottlePolicy, Text> {
            let policy = {
                pathName = pathName;
                currentLevel = 0;
                maxLevel = maxLevel;
                stepSize = stepSize;
                cooldownPeriodMs = cooldownPeriodMs;
                lastAdjustment = Time.now();
                triggerConditions = [
                    #LatencyBudgetViolation({ consecutiveViolations = 3 }),
                    #ErrorRateSpike({ threshold = 0.05 }) // 5% error rate
                ];
                recoveryConditions = [
                    #LatencyImprovement({ targetReduction = 0.2 }),
                    #StablePerformance({ durationMs = 300000 }) // 5 minutes
                ];
            };
            
            throttlePolicies.put(pathName, policy);
            Debug.print("Initialized throttle policy for path: " # pathName);
            
            #ok(policy)
        };
        
        public func initializeSLITracker(
            pathName: Text,
            sliType: SLIType,
            target: Float,
            alertThreshold: Float
        ) : Result.Result<SLITracker, Text> {
            let tracker = {
                pathName = pathName;
                sliType = sliType;
                target = target;
                current = 0.0;
                trend = #Stable;
                alertThreshold = alertThreshold;
                lastAlert = null;
                measurements = [];
            };
            
            sliTrackers.put(pathName, tracker);
            Debug.print("Initialized SLI tracker for path: " # pathName);
            
            #ok(tracker)
        };
        
        public func updatePathMetrics(
            pathName: Text,
            p95Ms: Nat,
            p99Ms: Nat,
            requestCount: Nat,
            errorRate: Float,
            throughputRPS: Float
        ) : Result.Result<[PolicyDecision], Text> {
            let currentTime = Time.now();
            let healthStatus = determinePathHealth(pathName, p95Ms, p99Ms, errorRate);
            
            let metrics = {
                pathName = pathName;
                currentP95Ms = p95Ms;
                currentP99Ms = p99Ms;
                requestCount = requestCount;
                errorRate = errorRate;
                throughputRPS = throughputRPS;
                lastUpdated = currentTime;
                healthStatus = healthStatus;
            };
            
            pathMetrics.put(pathName, metrics);
            
            // Update latency budget
            let _ = updateLatencyBudget(pathName, p95Ms, p99Ms, requestCount);
            
            // Update SLI trackers
            let _ = updateSLITrackers(pathName, metrics);
            
            // Evaluate policy decisions
            let decisions = evaluatePolicyDecisions(pathName, metrics);
            
            #ok(decisions)
        };
        
        public func evaluateThrottling(pathName: Text) : Result.Result<PolicyDecision, Text> {
            switch (pathMetrics.get(pathName), throttlePolicies.get(pathName), latencyBudgets.get(pathName)) {
                case (?metrics, ?policy, ?budget) {
                    let currentTime = Time.now();
                    
                    // Check if cooldown period has passed
                    if (currentTime - policy.lastAdjustment < Int.abs(policy.cooldownPeriodMs * 1_000_000)) {
                        return #err("Throttle adjustment in cooldown period");
                    };
                    
                    // Evaluate throttle triggers
                    let shouldIncrease = shouldIncreaseThrottle(metrics, policy, budget);
                    let shouldDecrease = shouldDecreaseThrottle(metrics, policy, budget);
                    
                    if (shouldIncrease and policy.currentLevel < policy.maxLevel) {
                        let newLevel = Nat.min(policy.currentLevel + policy.stepSize, policy.maxLevel);
                        let updatedPolicy = {
                            policy with
                            currentLevel = newLevel;
                            lastAdjustment = currentTime;
                        };
                        
                        throttlePolicies.put(pathName, updatedPolicy);
                        
                        let decision = {
                            timestamp = currentTime;
                            trigger = "latency_budget_violation";
                            decision = #ThrottleIncrease({ pathName = pathName; newLevel = newLevel });
                            reasoning = ["Latency budget exceeded", "Error rate elevated"];
                            confidence = 0.9;
                            expectedImpact = "Reduce load by " # debug_show(newLevel * 10) # "%";
                        };
                        
                        policyDecisions := Array.append(policyDecisions, [decision]);
                        
                        #ok(decision)
                    } else if (shouldDecrease and policy.currentLevel > 0) {
                        let newLevel = if (policy.currentLevel >= policy.stepSize) {
                            Int.abs(policy.currentLevel - policy.stepSize)
                        } else { 0 };
                        
                        let updatedPolicy = {
                            policy with
                            currentLevel = newLevel;
                            lastAdjustment = currentTime;
                        };
                        
                        throttlePolicies.put(pathName, updatedPolicy);
                        
                        let decision = {
                            timestamp = currentTime;
                            trigger = "performance_improvement";
                            decision = #ThrottleDecrease({ pathName = pathName; newLevel = newLevel });
                            reasoning = ["Latency improved", "Stable performance observed"];
                            confidence = 0.8;
                            expectedImpact = "Increase capacity by " # debug_show(policy.stepSize * 10) # "%";
                        };
                        
                        policyDecisions := Array.append(policyDecisions, [decision]);
                        
                        #ok(decision)
                    } else {
                        #err("No throttle adjustment needed")
                    }
                };
                case (_, _, _) {
                    #err("Path not found or not fully initialized: " # pathName)
                };
            }
        };
        
        public func getLatencyBudget(pathName: Text) : ?LatencyBudget {
            latencyBudgets.get(pathName)
        };
        
        public func getPathMetrics(pathName: Text) : ?PathMetrics {
            pathMetrics.get(pathName)
        };
        
        public func getThrottlePolicy(pathName: Text) : ?ThrottlePolicy {
            throttlePolicies.get(pathName)
        };
        
        public func getSLITracker(pathName: Text) : ?SLITracker {
            sliTrackers.get(pathName)
        };
        
        public func getAllPolicyDecisions() : [PolicyDecision] {
            policyDecisions
        };
        
        public func getRecentPolicyDecisions(withinMs: Nat) : [PolicyDecision] {
            let currentTime = Time.now();
            let cutoffTime = currentTime - Int.abs(withinMs * 1_000_000);
            
            Array.filter<PolicyDecision>(policyDecisions, func(decision) {
                decision.timestamp >= cutoffTime
            })
        };
        
        private func updateLatencyBudget(pathName: Text, p95Ms: Nat, p99Ms: Nat, requestCount: Nat) : Bool {
            switch (latencyBudgets.get(pathName)) {
                case (null) { false };
                case (?budget) {
                    let currentTime = Time.now();
                    let windowElapsed = currentTime - budget.windowStartTime;
                    
                    // Check if we need to reset the window
                    if (windowElapsed >= Int.abs(budget.windowDurationMs * 1_000_000)) {
                        let newBudget = {
                            budget with
                            windowStartTime = currentTime;
                            totalRequests = requestCount;
                            violatingRequests = if (p95Ms > budget.targetP95Ms or p99Ms > budget.targetP99Ms) { 1 } else { 0 };
                            budgetRemaining = 1.0;
                            violationCount = 0;
                        };
                        
                        latencyBudgets.put(pathName, newBudget);
                        true
                    } else {
                        let newTotalRequests = budget.totalRequests + requestCount;
                        let newViolatingRequests = budget.violatingRequests + (
                            if (p95Ms > budget.targetP95Ms or p99Ms > budget.targetP99Ms) { requestCount } else { 0 }
                        );
                        
                        let budgetRemaining = if (newTotalRequests > 0) {
                            1.0 - (Float.fromInt(newViolatingRequests) / Float.fromInt(newTotalRequests))
                        } else { 1.0 };
                        
                        let newViolationCount = budget.violationCount + (
                            if (p95Ms > budget.targetP95Ms or p99Ms > budget.targetP99Ms) { 1 } else { 0 }
                        );
                        
                        let updatedBudget = {
                            budget with
                            totalRequests = newTotalRequests;
                            violatingRequests = newViolatingRequests;
                            budgetRemaining = budgetRemaining;
                            violationCount = newViolationCount;
                        };
                        
                        latencyBudgets.put(pathName, updatedBudget);
                        true
                    }
                };
            }
        };
        
        private func updateSLITrackers(pathName: Text, metrics: PathMetrics) : Bool {
            switch (sliTrackers.get(pathName)) {
                case (null) { false };
                case (?tracker) {
                    let currentValue = switch (tracker.sliType) {
                        case (#Availability(_)) { 1.0 - metrics.errorRate };
                        case (#Latency({ percentile = 95 })) { Float.fromInt(metrics.currentP95Ms) };
                        case (#Latency({ percentile = 99 })) { Float.fromInt(metrics.currentP99Ms) };
                        case (#Throughput(_)) { metrics.throughputRPS };
                        case (#ErrorRate(_)) { metrics.errorRate };
                        case (_) { 0.0 };
                    };
                    
                    let newMeasurement = {
                        timestamp = metrics.lastUpdated;
                        value = currentValue;
                        context = [("pathName", pathName), ("requestCount", debug_show(metrics.requestCount))];
                    };
                    
                    let updatedMeasurements = Array.append(tracker.measurements, [newMeasurement]);
                    let trend = calculateTrend(updatedMeasurements);
                    
                    let updatedTracker = {
                        tracker with
                        current = currentValue;
                        trend = trend;
                        measurements = if (updatedMeasurements.size() > 100) {
                            Array.tabulate<SLIMeasurement>(100, func(i) = updatedMeasurements[i + updatedMeasurements.size() - 100])
                        } else { updatedMeasurements };
                    };
                    
                    sliTrackers.put(pathName, updatedTracker);
                    true
                };
            }
        };
        
        private func determinePathHealth(_pathName: Text, p95Ms: Nat, p99Ms: Nat, errorRate: Float) : PathHealthStatus {
            if (errorRate > 0.1) { // 10% error rate
                return #Critical({ reason = "High error rate"; actionRequired = "Immediate investigation required" });
            };
            
            if (p95Ms > 5000 or p99Ms > 10000) { // 5s P95, 10s P99
                return #Critical({ reason = "Extreme latency"; actionRequired = "Circuit breaker activation recommended" });
            };
            
            if (errorRate > 0.05 or p95Ms > 2000) { // 5% error rate, 2s P95
                return #Degraded({ reason = "Performance degradation"; severity = 2 });
            };
            
            if (errorRate > 0.02 or p95Ms > 1000) { // 2% error rate, 1s P95
                return #Degraded({ reason = "Minor performance impact"; severity = 1 });
            };
            
            #Healthy
        };
        
        private func evaluatePolicyDecisions(pathName: Text, metrics: PathMetrics) : [PolicyDecision] {
            var decisions: [PolicyDecision] = [];
            
            // Check for circuit breaker trigger
            switch (metrics.healthStatus) {
                case (#Critical({ reason; actionRequired })) {
                    let decision = {
                        timestamp = metrics.lastUpdated;
                        trigger = "critical_health_status";
                        decision = #CircuitBreakerTrigger({ pathName = pathName; reason = reason });
                        reasoning = [reason, actionRequired];
                        confidence = 0.95;
                        expectedImpact = "Prevent cascade failure";
                    };
                    decisions := Array.append(decisions, [decision]);
                };
                case (_) {};
            };
            
            // Check for alert triggers
            if (metrics.errorRate > 0.05) {
                let decision = {
                    timestamp = metrics.lastUpdated;
                    trigger = "error_rate_threshold";
                    decision = #AlertTrigger({ pathName = pathName; severity = "HIGH"; message = "Error rate exceeded 5%" });
                    reasoning = ["Error rate: " # Float.toText(metrics.errorRate)];
                    confidence = 0.9;
                    expectedImpact = "Alert on-call team";
                };
                decisions := Array.append(decisions, [decision]);
            };
            
            decisions
        };
        
        private func shouldIncreaseThrottle(metrics: PathMetrics, _policy: ThrottlePolicy, budget: LatencyBudget) : Bool {
            // Increase throttle if latency budget is being violated
            if (budget.budgetRemaining < 0.8 and budget.violationCount >= 3) {
                return true;
            };
            
            // Increase throttle if error rate is high
            if (metrics.errorRate > 0.05) {
                return true;
            };
            
            // Increase throttle if health status is critical
            switch (metrics.healthStatus) {
                case (#Critical(_) or #Degraded({ severity = 2 })) { true };
                case (_) { false };
            }
        };
        
        private func shouldDecreaseThrottle(metrics: PathMetrics, policy: ThrottlePolicy, budget: LatencyBudget) : Bool {
            // Only decrease if currently throttled
            if (policy.currentLevel == 0) {
                return false;
            };
            
            // Decrease throttle if performance is good and budget is healthy
            if (budget.budgetRemaining > 0.9 and metrics.errorRate < 0.01) {
                switch (metrics.healthStatus) {
                    case (#Healthy) { true };
                    case (_) { false };
                }
            } else { false }
        };
        
        private func calculateTrend(measurements: [SLIMeasurement]) : TrendDirection {
            if (measurements.size() < 3) {
                return #Stable;
            };
            
            let recent = measurements[measurements.size() - 1].value;
            let previous = measurements[measurements.size() - 2].value;
            let older = measurements[measurements.size() - 3].value;
            
            let recentChange = recent - previous;
            let previousChange = previous - older;
            
            if (recentChange > 0.1 and previousChange > 0.1) {
                #Degrading
            } else if (recentChange < -0.1 and previousChange < -0.1) {
                #Improving
            } else if (Float.abs(recentChange) > 0.5 or Float.abs(previousChange) > 0.5) {
                #Critical
            } else {
                #Stable
            }
        };
    };
}
