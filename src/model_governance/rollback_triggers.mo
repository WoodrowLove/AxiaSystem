// Rollback Triggers - Phase 2 Week 7
// Advanced monitoring and automatic rollback system for model governance

import Time "mo:base/Time";
import Result "mo:base/Result";
import Float "mo:base/Float";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Nat "mo:base/Nat";

module {
    // Rollback Trigger Configuration
    public type RollbackTriggerConfig = {
        triggerId: Text;
        modelVersion: Text;
        triggerType: TriggerType;
        threshold: Float;
        windowSizeMs: Nat;
        minSamples: Nat;
        consecutiveViolations: Nat;
        enabled: Bool;
        severity: AlertSeverity;
        owner: Text;
        lastUpdated: Time.Time;
    };

    public type TriggerType = {
        #LatencyDrift: { baselineP95: Float; baselineP99: Float };
        #AccuracyDrop: { baselineAccuracy: Float };
        #ErrorRateSpike: { baselineErrorRate: Float };
        #ConfidenceDrop: { baselineConfidence: Float };
        #ThroughputDrop: { baselineThroughput: Float };
        #MemoryLeak: { maxMemoryMB: Float };
        #CPUSpike: { maxCPUPercent: Float };
        #DataDrift: { driftThreshold: Float };
    };

    public type AlertSeverity = {
        #Low;
        #Medium;
        #High;
        #Critical;
    };

    // Monitoring Data Points
    public type MetricDataPoint = {
        timestamp: Time.Time;
        value: Float;
        metadata: [(Text, Text)];
    };

    public type ModelMetrics = {
        modelVersion: Text;
        latencyP95: [MetricDataPoint];
        latencyP99: [MetricDataPoint];
        accuracy: [MetricDataPoint];
        errorRate: [MetricDataPoint];
        confidence: [MetricDataPoint];
        throughput: [MetricDataPoint];
        memoryUsage: [MetricDataPoint];
        cpuUsage: [MetricDataPoint];
        lastUpdated: Time.Time;
    };

    // Rollback Decision and Execution
    public type RollbackDecision = {
        shouldRollback: Bool;
        triggeredBy: [Text];
        severity: AlertSeverity;
        reason: Text;
        targetVersion: ?Text;
        estimatedImpact: ImpactAssessment;
        recommendedActions: [Text];
    };

    public type ImpactAssessment = {
        affectedPaths: [Text];
        estimatedUsers: Nat;
        riskLevel: RiskLevel;
        rollbackDurationMinutes: Nat;
        dataLossRisk: Bool;
    };

    public type RiskLevel = {
        #Low;
        #Medium;
        #High;
        #Critical;
    };

    // Rollback Execution Plan
    public type RollbackPlan = {
        planId: Text;
        fromVersion: Text;
        toVersion: Text;
        executionSteps: [RollbackStep];
        estimatedDurationMs: Nat;
        rollbackStrategy: RollbackStrategy;
        verificationChecks: [VerificationCheck];
        createdAt: Time.Time;
    };

    public type RollbackStep = {
        stepNumber: Nat;
        description: Text;
        action: RollbackAction;
        timeout: Nat;
        rollbackOnFailure: Bool;
    };

    public type RollbackAction = {
        #UpdateTrafficSplit: { percentage: Float };
        #SwitchModelVersion: { version: Text };
        #EnableCircuitBreaker: { paths: [Text] };
        #NotifyOperators: { message: Text; severity: AlertSeverity };
        #HealthCheck: { endpoints: [Text] };
        #ValidateMetrics: { requiredThresholds: [(Text, Float)] };
    };

    public type RollbackStrategy = {
        #Immediate: { switchPercentage: Float };
        #Gradual: { steps: [Float]; stepDurationMs: Nat };
        #Blue_Green: { warmupTimeMs: Nat };
        #Canary_Reverse: { reverseSteps: [Float] };
    };

    public type VerificationCheck = {
        checkName: Text;
        checkType: CheckType;
        threshold: Float;
        mandatory: Bool;
    };

    public type CheckType = {
        #LatencyCheck: { maxP95Ms: Float };
        #ErrorRateCheck: { maxErrorRate: Float };
        #ThroughputCheck: { minThroughput: Float };
        #HealthEndpoint: { endpoint: Text; expectedStatus: Nat };
    };

    // Rollback Trigger Manager
    public class RollbackTriggerManager() {
        private var triggers = HashMap.HashMap<Text, RollbackTriggerConfig>(10, Text.equal, Text.hash);
        private var metricsHistory = HashMap.HashMap<Text, ModelMetrics>(10, Text.equal, Text.hash);
        private var violationCounts = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
        private var rollbackHistory = Buffer.Buffer<RollbackExecution>(100);

        // Trigger Configuration
        public func addRollbackTrigger(config: RollbackTriggerConfig) : Result.Result<Text, Text> {
            Debug.print("Adding rollback trigger: " # config.triggerId # " for model " # config.modelVersion);
            
            if (config.threshold <= 0.0) {
                return #err("Threshold must be positive");
            };
            
            if (config.windowSizeMs == 0) {
                return #err("Window size must be greater than 0");
            };
            
            triggers.put(config.triggerId, config);
            violationCounts.put(config.triggerId, 0);
            
            Debug.print("Rollback trigger added: " # config.triggerId);
            #ok("Trigger configured: " # config.triggerId)
        };

        public func updateTrigger(triggerId: Text, newConfig: RollbackTriggerConfig) : Result.Result<Text, Text> {
            switch (triggers.get(triggerId)) {
                case (?_existing) {
                    let updated = { newConfig with lastUpdated = Time.now() };
                    triggers.put(triggerId, updated);
                    Debug.print("Trigger updated: " # triggerId);
                    #ok("Trigger updated: " # triggerId);
                };
                case (null) {
                    #err("Trigger not found: " # triggerId);
                };
            }
        };

        public func disableTrigger(triggerId: Text) : Result.Result<Text, Text> {
            switch (triggers.get(triggerId)) {
                case (?trigger) {
                    let disabled = { trigger with enabled = false; lastUpdated = Time.now() };
                    triggers.put(triggerId, disabled);
                    #ok("Trigger disabled: " # triggerId);
                };
                case (null) {
                    #err("Trigger not found: " # triggerId);
                };
            }
        };

        // Metrics Collection and Processing
        public func updateMetrics(modelVersion: Text, newMetrics: ModelMetrics) : Result.Result<Text, Text> {
            Debug.print("Updating metrics for model: " # modelVersion);
            
            metricsHistory.put(modelVersion, newMetrics);
            
            // Evaluate all triggers for this model version
            let _ = evaluateTriggersForModel(modelVersion, newMetrics);
            
            #ok("Metrics updated for: " # modelVersion)
        };

        public func evaluateTriggersForModel(modelVersion: Text, metrics: ModelMetrics) : RollbackDecision {
            var triggeredTriggers: [Text] = [];
            var maxSeverity: AlertSeverity = #Low;
            var shouldRollback = false;
            
            for ((triggerId, trigger) in triggers.entries()) {
                if (trigger.modelVersion == modelVersion and trigger.enabled) {
                    let violation = evaluateSingleTrigger(trigger, metrics);
                    
                    if (violation.violated) {
                        triggeredTriggers := Array.append(triggeredTriggers, [triggerId]);
                        shouldRollback := true;
                        
                        // Update violation count
                        let currentCount = Option.get(violationCounts.get(triggerId), 0);
                        violationCounts.put(triggerId, currentCount + 1);
                        
                        // Update max severity
                        if (severityLevel(trigger.severity) > severityLevel(maxSeverity)) {
                            maxSeverity := trigger.severity;
                        };
                        
                        Debug.print("Trigger violated: " # triggerId # " - " # violation.reason);
                    } else {
                        // Reset violation count on success
                        violationCounts.put(triggerId, 0);
                    };
                };
            };
            
            let decision = {
                shouldRollback = shouldRollback;
                triggeredBy = triggeredTriggers;
                severity = maxSeverity;
                reason = createRollbackReason(triggeredTriggers);
                targetVersion = findStableVersion(modelVersion);
                estimatedImpact = assessImpact(modelVersion, maxSeverity);
                recommendedActions = generateRecommendations(triggeredTriggers, maxSeverity);
            };
            
            if (shouldRollback) {
                Debug.print("ROLLBACK DECISION: " # modelVersion # " should be rolled back due to " # 
                          Int.toText(Array.size(triggeredTriggers)) # " trigger violations");
            };
            
            decision
        };

        // Rollback Execution
        public func createRollbackPlan(fromVersion: Text, toVersion: Text, decision: RollbackDecision) : RollbackPlan {
            let planId = "rollback_" # fromVersion # "_to_" # toVersion # "_" # Int.toText(Time.now());
            
            let strategy = selectRollbackStrategy(decision.severity);
            let steps = generateRollbackSteps(fromVersion, toVersion, strategy);
            let verificationChecks = generateVerificationChecks(decision.severity);
            
            {
                planId = planId;
                fromVersion = fromVersion;
                toVersion = toVersion;
                executionSteps = steps;
                estimatedDurationMs = calculateDuration(steps);
                rollbackStrategy = strategy;
                verificationChecks = verificationChecks;
                createdAt = Time.now();
            }
        };

        public func executeRollbackPlan(plan: RollbackPlan) : Result.Result<RollbackExecution, Text> {
            Debug.print("Executing rollback plan: " # plan.planId);
            
            let execution = {
                planId = plan.planId;
                fromVersion = plan.fromVersion;
                toVersion = plan.toVersion;
                startedAt = Time.now();
                completedAt = null;
                status = #InProgress;
                stepsCompleted = 0;
                totalSteps = Array.size(plan.executionSteps);
                errors = [];
                verificationResults = [];
            };
            
            rollbackHistory.add(execution);
            
            // In a real implementation, this would execute each step
            Debug.print("Rollback execution started: " # plan.planId);
            #ok(execution)
        };

        // Monitoring and Observability
        public func getTriggerStatus() : [(Text, TriggerStatus)] {
            var results: [(Text, TriggerStatus)] = [];
            
            for ((triggerId, trigger) in triggers.entries()) {
                let violationCount = Option.get(violationCounts.get(triggerId), 0);
                let status = {
                    triggerId = triggerId;
                    enabled = trigger.enabled;
                    violationCount = violationCount;
                    lastEvaluated = trigger.lastUpdated;
                    threshold = trigger.threshold;
                    severity = trigger.severity;
                };
                results := Array.append(results, [(triggerId, status)]);
            };
            
            results
        };

        public func getRollbackHistory() : [RollbackExecution] {
            Buffer.toArray(rollbackHistory)
        };

        public func getMetricsForModel(modelVersion: Text) : ?ModelMetrics {
            metricsHistory.get(modelVersion)
        };

        // Helper Functions
        private func evaluateSingleTrigger(trigger: RollbackTriggerConfig, metrics: ModelMetrics) : TriggerViolation {
            let violation = switch (trigger.triggerType) {
                case (#LatencyDrift({ baselineP95; baselineP99 = _ })) {
                    if (Array.size(metrics.latencyP95) > 0) {
                        let currentP95 = metrics.latencyP95[Array.size(metrics.latencyP95) - 1].value;
                        let driftPercent = (currentP95 - baselineP95) / baselineP95;
                        {
                            violated = driftPercent > trigger.threshold;
                            reason = "P95 latency drift: " # Float.toText(driftPercent * 100.0) # "%";
                            currentValue = currentP95;
                            threshold = trigger.threshold;
                        }
                    } else {
                        { violated = false; reason = "No latency data"; currentValue = 0.0; threshold = trigger.threshold }
                    };
                };
                
                case (#AccuracyDrop({ baselineAccuracy })) {
                    if (Array.size(metrics.accuracy) > 0) {
                        let currentAccuracy = metrics.accuracy[Array.size(metrics.accuracy) - 1].value;
                        let dropPercent = (baselineAccuracy - currentAccuracy) / baselineAccuracy;
                        {
                            violated = dropPercent > trigger.threshold;
                            reason = "Accuracy drop: " # Float.toText(dropPercent * 100.0) # "%";
                            currentValue = currentAccuracy;
                            threshold = trigger.threshold;
                        }
                    } else {
                        { violated = false; reason = "No accuracy data"; currentValue = 0.0; threshold = trigger.threshold }
                    };
                };
                
                case (#ErrorRateSpike({ baselineErrorRate })) {
                    if (Array.size(metrics.errorRate) > 0) {
                        let currentErrorRate = metrics.errorRate[Array.size(metrics.errorRate) - 1].value;
                        let spikePercent = (currentErrorRate - baselineErrorRate) / baselineErrorRate;
                        {
                            violated = spikePercent > trigger.threshold;
                            reason = "Error rate spike: " # Float.toText(spikePercent * 100.0) # "%";
                            currentValue = currentErrorRate;
                            threshold = trigger.threshold;
                        }
                    } else {
                        { violated = false; reason = "No error rate data"; currentValue = 0.0; threshold = trigger.threshold }
                    };
                };
                
                case (_) {
                    { violated = false; reason = "Trigger type not implemented"; currentValue = 0.0; threshold = trigger.threshold }
                };
            };
            
            // Check if we have enough consecutive violations
            let currentViolations = Option.get(violationCounts.get(trigger.triggerId), 0);
            if (violation.violated and currentViolations < trigger.consecutiveViolations) {
                { violation with violated = false; reason = violation.reason # " (need " # Nat.toText(trigger.consecutiveViolations) # " consecutive)" }
            } else {
                violation
            }
        };

        private func severityLevel(severity: AlertSeverity) : Nat {
            switch (severity) {
                case (#Low) 1;
                case (#Medium) 2;
                case (#High) 3;
                case (#Critical) 4;
            }
        };

        private func createRollbackReason(triggers: [Text]) : Text {
            if (Array.size(triggers) == 0) {
                "No triggers violated"
            } else if (Array.size(triggers) == 1) {
                "Trigger violated: " # triggers[0]
            } else {
                "Multiple triggers violated: " # Text.join(", ", triggers.vals())
            }
        };

        private func findStableVersion(_currentVersion: Text) : ?Text {
            // In a real implementation, this would query the model governance service
            ?"stable-v1.0"
        };

        private func assessImpact(_modelVersion: Text, severity: AlertSeverity) : ImpactAssessment {
            {
                affectedPaths = ["escrow", "compliance", "payment"];
                estimatedUsers = switch (severity) {
                    case (#Low) 100;
                    case (#Medium) 1000;
                    case (#High) 10000;
                    case (#Critical) 100000;
                };
                riskLevel = switch (severity) {
                    case (#Low) #Low;
                    case (#Medium) #Medium;
                    case (#High) #High;
                    case (#Critical) #Critical;
                };
                rollbackDurationMinutes = switch (severity) {
                    case (#Low) 30;
                    case (#Medium) 15;
                    case (#High) 5;
                    case (#Critical) 2;
                };
                dataLossRisk = false;
            }
        };

        private func generateRecommendations(triggers: [Text], severity: AlertSeverity) : [Text] {
            var recommendations: [Text] = [];
            
            recommendations := Array.append(recommendations, ["Initiate rollback to stable version"]);
            
            if (severityLevel(severity) >= 3) {
                recommendations := Array.append(recommendations, ["Enable circuit breaker for affected paths"]);
                recommendations := Array.append(recommendations, ["Notify on-call team immediately"]);
            };
            
            recommendations := Array.append(recommendations, ["Monitor metrics during rollback"]);
            recommendations := Array.append(recommendations, ["Verify system health post-rollback"]);
            
            recommendations
        };

        private func selectRollbackStrategy(severity: AlertSeverity) : RollbackStrategy {
            switch (severity) {
                case (#Critical) #Immediate({ switchPercentage = 100.0 });
                case (#High) #Gradual({ steps = [50.0, 100.0]; stepDurationMs = 30000 });
                case (#Medium) #Gradual({ steps = [25.0, 50.0, 100.0]; stepDurationMs = 60000 });
                case (#Low) #Canary_Reverse({ reverseSteps = [75.0, 50.0, 25.0, 0.0] });
            }
        };

        private func generateRollbackSteps(_fromVersion: Text, _toVersion: Text, strategy: RollbackStrategy) : [RollbackStep] {
            switch (strategy) {
                case (#Immediate({ switchPercentage })) {
                    [
                        {
                            stepNumber = 1;
                            description = "Switch traffic to stable version";
                            action = #UpdateTrafficSplit({ percentage = switchPercentage });
                            timeout = 30000;
                            rollbackOnFailure = false;
                        },
                        {
                            stepNumber = 2;
                            description = "Verify health checks";
                            action = #HealthCheck({ endpoints = ["/health", "/ready"] });
                            timeout = 10000;
                            rollbackOnFailure = true;
                        }
                    ]
                };
                case (_) {
                    // Simplified for other strategies
                    [
                        {
                            stepNumber = 1;
                            description = "Gradual rollback";
                            action = #UpdateTrafficSplit({ percentage = 100.0 });
                            timeout = 60000;
                            rollbackOnFailure = false;
                        }
                    ]
                };
            }
        };

        private func generateVerificationChecks(_severity: AlertSeverity) : [VerificationCheck] {
            [
                {
                    checkName = "Latency Check";
                    checkType = #LatencyCheck({ maxP95Ms = 100.0 });
                    threshold = 100.0;
                    mandatory = true;
                },
                {
                    checkName = "Error Rate Check";
                    checkType = #ErrorRateCheck({ maxErrorRate = 0.01 });
                    threshold = 0.01;
                    mandatory = true;
                }
            ]
        };

        private func calculateDuration(steps: [RollbackStep]) : Nat {
            var total = 0;
            for (step in steps.vals()) {
                total += step.timeout;
            };
            total
        };
    };

    // Supporting types
    public type TriggerViolation = {
        violated: Bool;
        reason: Text;
        currentValue: Float;
        threshold: Float;
    };

    public type TriggerStatus = {
        triggerId: Text;
        enabled: Bool;
        violationCount: Nat;
        lastEvaluated: Time.Time;
        threshold: Float;
        severity: AlertSeverity;
    };

    public type RollbackExecution = {
        planId: Text;
        fromVersion: Text;
        toVersion: Text;
        startedAt: Time.Time;
        completedAt: ?Time.Time;
        status: ExecutionStatus;
        stepsCompleted: Nat;
        totalSteps: Nat;
        errors: [Text];
        verificationResults: [VerificationResult];
    };

    public type ExecutionStatus = {
        #InProgress;
        #Completed;
        #Failed: { step: Nat; reason: Text };
        #PartiallyCompleted: { reason: Text };
    };

    public type VerificationResult = {
        checkName: Text;
        passed: Bool;
        actualValue: Float;
        threshold: Float;
        message: Text;
    };
}
