// Model Governance Main Module - Phase 2 Week 7
// Orchestrates model version management, canary deployments, and rollback triggers

import Time "mo:base/Time";
import Result "mo:base/Result";
import _HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import _Option "mo:base/Option";
import Int "mo:base/Int";

import ModelGovernance "./model_governance";
import CanaryController "./canary_controller";
import RollbackTriggers "./rollback_triggers";

persistent actor ModelGovernanceService {
    // Core service instances
    private transient let governanceManager = ModelGovernance.ModelGovernanceManager();
    private transient let canaryController = CanaryController.CanaryTrafficSplitter();
    private transient let rollbackManager = RollbackTriggers.RollbackTriggerManager();
    
    // Service state
    private transient var initialized = false;
    private transient var serviceConfig = {
        enableCanaryDeployments = true;
        enableAutomaticRollbacks = true;
        maxConcurrentCanaries = 3;
        defaultCanaryPercentage = 5.0;
        rollbackCooldownMs = 300000; // 5 minutes
    };

    // Initialization
    public func initialize() : async Result.Result<Text, Text> {
        Debug.print("Model Governance Service: Initializing...");
        
        if (initialized) {
            return #err("Service already initialized");
        };
        
        // Set up default confidence thresholds
        let defaultThresholds = [
            {
                pathName = "escrow";
                modelVersion = "stable-v1.0";
                minConfidence = 0.85;
                escalationThreshold = 0.70;
                fallbackStrategy = #DeterministicRules;
                owner = #Joint({ productLead = "escrow-lead"; sreOncall = "sre-oncall" });
                lastReviewed = Time.now();
            },
            {
                pathName = "compliance";
                modelVersion = "stable-v1.0";
                minConfidence = 0.90;
                escalationThreshold = 0.80;
                fallbackStrategy = #HumanApproval;
                owner = #Joint({ productLead = "compliance-lead"; sreOncall = "sre-oncall" });
                lastReviewed = Time.now();
            },
            {
                pathName = "payment";
                modelVersion = "stable-v1.0";
                minConfidence = 0.95;
                escalationThreshold = 0.85;
                fallbackStrategy = #BlockTransaction;
                owner = #SRE({ team = "payments-sre"; oncall = "payments-oncall" });
                lastReviewed = Time.now();
            }
        ];
        
        // Install confidence thresholds
        for (threshold in defaultThresholds.vals()) {
            let _ = governanceManager.setConfidenceThreshold(threshold);
        };
        
        // Set up default rollback triggers
        let defaultTriggers = [
            {
                triggerId = "latency_drift_p95";
                modelVersion = "stable-v1.0";
                triggerType = #LatencyDrift({ baselineP95 = 100.0; baselineP99 = 200.0 });
                threshold = 0.20; // 20% increase
                windowSizeMs = 300000; // 5 minutes
                minSamples = 100;
                consecutiveViolations = 3;
                enabled = true;
                severity = #High;
                owner = "sre-team";
                lastUpdated = Time.now();
            },
            {
                triggerId = "accuracy_drop_critical";
                modelVersion = "stable-v1.0";
                triggerType = #AccuracyDrop({ baselineAccuracy = 0.95 });
                threshold = 0.05; // 5% drop
                windowSizeMs = 180000; // 3 minutes
                minSamples = 50;
                consecutiveViolations = 2;
                enabled = true;
                severity = #Critical;
                owner = "ml-team";
                lastUpdated = Time.now();
            },
            {
                triggerId = "error_rate_spike";
                modelVersion = "stable-v1.0";
                triggerType = #ErrorRateSpike({ baselineErrorRate = 0.01 });
                threshold = 2.0; // 200% increase (triple the error rate)
                windowSizeMs = 120000; // 2 minutes
                minSamples = 30;
                consecutiveViolations = 1;
                enabled = true;
                severity = #Critical;
                owner = "sre-team";
                lastUpdated = Time.now();
            }
        ];
        
        // Install rollback triggers
        for (trigger in defaultTriggers.vals()) {
            let _ = rollbackManager.addRollbackTrigger(trigger);
        };
        
        initialized := true;
        Debug.print("Model Governance Service initialized successfully");
        #ok("Model Governance Service initialized")
    };

    // Model Version Management
    public func registerModel(version: ModelGovernance.ModelVersion) : async Result.Result<Text, Text> {
        if (not initialized) {
            return #err("Service not initialized");
        };
        
        Debug.print("Registering model version: " # version.version);
        governanceManager.registerModelVersion(version)
    };

    public shared(_msg) func deployCanary(
        version: Text,
        targetPercentage: Float,
        _paths: [Text]
    ) : async Result.Result<Text, Text> {
        if (not initialized) {
            return #err("Service not initialized");
        };
        
        if (not serviceConfig.enableCanaryDeployments) {
            return #err("Canary deployments are disabled");
        };
        
        Debug.print("Deploying canary for version: " # version);
        
        // Create rollout steps for canary controller
        let canaryRolloutSteps = [
            {
                stepNumber = 0;
                targetPercentage = targetPercentage;
                durationMs = 900000; // 15 minutes
                evaluationCriteria = [
                    #LatencyP95({ target = 150.0; actual = 0.0; passing = false }),
                    #ErrorRate({ maxThreshold = 0.02; actual = 0.0; passing = false }),
                    #Confidence({ minThreshold = 0.85; actual = 0.0; passing = false })
                ];
                completedAt = null;
                successful = null;
            }
        ];
        
        // Create rollout steps for governance manager  
        let governanceRolloutSteps = [
            {
                percentage = targetPercentage;
                durationMs = 900000; // 15 minutes
                evaluationCriteria = [
                    #LatencyImprovement({ minImprovement = 0.1 }),
                    #ErrorRateLimit({ maxErrorRate = 0.02 }),
                    #ConfidenceMaintenance({ minConfidence = 0.85 })
                ];
            }
        ];
        
        let canaryConfig = {
            version = version;
            targetPercentage = targetPercentage;
            incrementStep = 5.0;
            evaluationWindowMs = 300000; // 5 minutes
            rolloutSchedule = governanceRolloutSteps;
            abTestConfig = {
                enabled = false;
                controlVersion = "stable-v1.0";
                testVersion = version;
                trafficSplit = 50.0;
                significanceLevel = 0.05;
                minSampleSize = 1000;
            };
        };
        
        // Start canary rollout
        let rolloutId = "canary_" # version # "_" # Int.toText(Time.now());
        let createResult = canaryController.createCanaryRollout(rolloutId, version, canaryRolloutSteps);
        
        switch (createResult) {
            case (#ok(_)) {
                let startResult = canaryController.startRollout(rolloutId);
                switch (startResult) {
                    case (#ok(_message)) {
                        let _ = governanceManager.deployCanary(version, canaryConfig);
                        #ok("Canary deployment started: " # rolloutId);
                    };
                    case (#err(error)) #err("Failed to start rollout: " # error);
                };
            };
            case (#err(error)) #err("Failed to create rollout: " # error);
        }
    };

    public func promoteToStable(version: Text) : async Result.Result<Text, Text> {
        if (not initialized) {
            return #err("Service not initialized");
        };
        
        Debug.print("Promoting version to stable: " # version);
        governanceManager.promoteToStable(version)
    };

    // Traffic Routing
    public func getRoutingDecision(pathName: Text, requestId: Text) : async RoutingDecision {
        if (not initialized) {
            return {
                targetVersion = "stable-v1.0";
                routingReason = "Service not initialized";
                canaryPercentage = 0.0;
                confidenceThreshold = 0.85;
                fallbackStrategy = #DeterministicRules;
            };
        };
        
        // Get traffic split decision from canary controller
        let canaryDecision = canaryController.shouldRouteToCanary(pathName, requestId);
        
        // Get confidence threshold for this path
        let threshold = switch (governanceManager.getConfidenceThreshold(pathName, canaryDecision.canaryVersion)) {
            case (?t) t;
            case (null) {
                let defaultThreshold = {
                    pathName = pathName;
                    modelVersion = "stable-v1.0";
                    minConfidence = 0.85;
                    escalationThreshold = 0.70;
                    fallbackStrategy = #DeterministicRules;
                    owner = #Joint({ productLead = "default"; sreOncall = "default" });
                    lastReviewed = Time.now();
                };
                defaultThreshold
            };
        };
        
        let targetVersion = if (canaryDecision.useCanary) {
            canaryDecision.canaryVersion
        } else {
            "stable-v1.0"
        };
        
        {
            targetVersion = targetVersion;
            routingReason = canaryDecision.routingReason;
            canaryPercentage = canaryDecision.percentage;
            confidenceThreshold = threshold.minConfidence;
            fallbackStrategy = threshold.fallbackStrategy;
        }
    };

    // Monitoring and Health Checks
    public func updateModelMetrics(
        modelVersion: Text,
        metrics: RollbackTriggers.ModelMetrics
    ) : async Result.Result<Text, Text> {
        if (not initialized) {
            return #err("Service not initialized");
        };
        
        // Update metrics in rollback manager
        let updateResult = rollbackManager.updateMetrics(modelVersion, metrics);
        
        // Evaluate rollback triggers
        let rollbackDecision = rollbackManager.evaluateTriggersForModel(modelVersion, metrics);
        
        if (rollbackDecision.shouldRollback and serviceConfig.enableAutomaticRollbacks) {
            Debug.print("AUTOMATIC ROLLBACK TRIGGERED for " # modelVersion);
            let _ = executeAutomaticRollback(modelVersion, rollbackDecision);
        };
        
        updateResult
    };

    public func getGovernanceStatus() : async GovernanceStatus {
        let governanceMetrics = governanceManager.getGovernanceMetrics();
        let triggerStatus = rollbackManager.getTriggerStatus();
        let activeCanaries = canaryController.getAllActiveCanaries();
        
        {
            initialized = initialized;
            modelVersions = governanceMetrics.totalVersions;
            activeCanaries = Array.size(activeCanaries);
            rollbackTriggers = Array.size(triggerStatus);
            lastHealthCheck = Time.now();
            serviceConfig = serviceConfig;
        }
    };

    // Configuration Management
    public func updateConfidenceThreshold(
        pathName: Text,
        modelVersion: Text,
        newThreshold: Float,
        owner: ModelGovernance.ThresholdOwner
    ) : async Result.Result<Text, Text> {
        if (not initialized) {
            return #err("Service not initialized");
        };
        
        let threshold = {
            pathName = pathName;
            modelVersion = modelVersion;
            minConfidence = newThreshold;
            escalationThreshold = newThreshold - 0.15;
            fallbackStrategy = #HumanApproval;
            owner = owner;
            lastReviewed = Time.now();
        };
        
        governanceManager.setConfidenceThreshold(threshold)
    };

    public func updateServiceConfig(newConfig: ServiceConfig) : async Result.Result<Text, Text> {
        if (not initialized) {
            return #err("Service not initialized");
        };
        
        serviceConfig := newConfig;
        Debug.print("Service configuration updated");
        #ok("Configuration updated")
    };

    // Rollback Management
    private func executeAutomaticRollback(
        modelVersion: Text,
        decision: RollbackTriggers.RollbackDecision
    ) : Result.Result<Text, Text> {
        Debug.print("Executing automatic rollback for: " # modelVersion);
        
        switch (decision.targetVersion) {
            case (?targetVersion) {
                // Create rollback plan
                let plan = rollbackManager.createRollbackPlan(modelVersion, targetVersion, decision);
                
                // Execute rollback
                switch (rollbackManager.executeRollbackPlan(plan)) {
                    case (#ok(_execution)) {
                        Debug.print("Automatic rollback initiated: " # plan.planId);
                        #ok("Rollback executed: " # plan.planId);
                    };
                    case (#err(error)) {
                        Debug.print("Rollback execution failed: " # error);
                        #err("Rollback failed: " # error);
                    };
                };
            };
            case (null) {
                #err("No target version available for rollback");
            };
        }
    };

    public func manualRollback(fromVersion: Text, toVersion: Text, reason: Text) : async Result.Result<Text, Text> {
        if (not initialized) {
            return #err("Service not initialized");
        };
        
        Debug.print("Manual rollback requested: " # fromVersion # " -> " # toVersion);
        
        let decision = {
            shouldRollback = true;
            triggeredBy = ["manual"];
            severity = #High;
            reason = "Manual rollback: " # reason;
            targetVersion = ?toVersion;
            estimatedImpact = {
                affectedPaths = ["escrow", "compliance", "payment"];
                estimatedUsers = 10000;
                riskLevel = #Medium;
                rollbackDurationMinutes = 10;
                dataLossRisk = false;
            };
            recommendedActions = ["Monitor system health", "Verify rollback success"];
        };
        
        executeAutomaticRollback(fromVersion, decision)
    };

    // A/B Testing Support
    public func setupABTest(
        testId: Text,
        controlVersion: Text,
        treatmentVersion: Text,
        paths: [Text]
    ) : async Result.Result<Text, Text> {
        if (not initialized) {
            return #err("Service not initialized");
        };
        
        let testSetup = {
            testId = testId;
            controlVersion = controlVersion;
            treatmentVersion = treatmentVersion;
            trafficAllocation = 50.0;
            paths = paths;
            hypotheses = [
                {
                    metric = "latency";
                    expectedChange = -0.10; // 10% improvement
                    direction = #Decrease;
                    significance = 0.05;
                }
            ];
            statisticalConfig = {
                confidenceLevel = 0.95;
                minimumSampleSize = 1000;
                minimumDetectableEffect = 0.05;
                powerLevel = 0.80;
            };
            startedAt = Time.now();
            status = #Designing;
        };
        
        canaryController.setupABTest(testSetup)
    };

    // Supporting Types
    public type RoutingDecision = {
        targetVersion: Text;
        routingReason: Text;
        canaryPercentage: Float;
        confidenceThreshold: Float;
        fallbackStrategy: ModelGovernance.FallbackStrategy;
    };

    public type GovernanceStatus = {
        initialized: Bool;
        modelVersions: Nat;
        activeCanaries: Nat;
        rollbackTriggers: Nat;
        lastHealthCheck: Time.Time;
        serviceConfig: ServiceConfig;
    };

    public type ServiceConfig = {
        enableCanaryDeployments: Bool;
        enableAutomaticRollbacks: Bool;
        maxConcurrentCanaries: Nat;
        defaultCanaryPercentage: Float;
        rollbackCooldownMs: Nat;
    };
}
