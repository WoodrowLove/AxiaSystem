// Model Governance Service - Phase 2 Week 7
// Sophisticated model version management with canary deployments and rollback triggers

import Time "mo:base/Time";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import _Option "mo:base/Option";
import Iter "mo:base/Iter";

module {
    // Core Model Version Management Types
    public type ModelVersion = {
        version: Text;
        deployedAt: Time.Time;
        canaryPercentage: Float;
        paths: [Text];
        performance: ModelPerformance;
        rollbackTriggers: [RollbackTrigger];
        status: ModelStatus;
        metadata: ModelMetadata;
    };

    public type ModelPerformance = {
        latencyP95Ms: Float;
        latencyP99Ms: Float;
        accuracyScore: Float;
        errorRate: Float;
        confidenceScore: Float;
        throughput: Float;
        lastUpdated: Time.Time;
    };

    public type RollbackTrigger = {
        #LatencyDrift: { threshold: Float; windowMs: Nat };
        #AccuracyDrop: { threshold: Float; minSamples: Nat };
        #ErrorRateSpike: { threshold: Float; windowMs: Nat };
        #ConfidenceDrop: { threshold: Float; minSamples: Nat };
        #ThroughputDrop: { threshold: Float; windowMs: Nat };
    };

    public type ModelStatus = {
        #Stable;
        #Canary: { percentage: Float };
        #Rollback: { reason: Text; triggeredAt: Time.Time };
        #Maintenance: { reason: Text };
        #Deprecated: { replacedBy: Text };
    };

    public type ModelMetadata = {
        description: Text;
        trainingDataHash: Text;
        configHash: Text;
        owner: Text;
        reviewers: [Text];
        approvedBy: Text;
        approvedAt: Time.Time;
    };

    // Canary Deployment Configuration
    public type CanaryConfig = {
        version: Text;
        targetPercentage: Float;
        incrementStep: Float;
        evaluationWindowMs: Nat;
        rolloutSchedule: [RolloutStep];
        abTestConfig: ABTestConfig;
    };

    public type RolloutStep = {
        percentage: Float;
        durationMs: Nat;
        evaluationCriteria: [EvaluationCriterion];
    };

    public type ABTestConfig = {
        enabled: Bool;
        controlVersion: Text;
        testVersion: Text;
        trafficSplit: Float;
        significanceLevel: Float;
        minSampleSize: Nat;
    };

    public type EvaluationCriterion = {
        #LatencyImprovement: { minImprovement: Float };
        #AccuracyMaintenance: { minAccuracy: Float };
        #ErrorRateLimit: { maxErrorRate: Float };
        #ConfidenceMaintenance: { minConfidence: Float };
        #ThroughputMaintenance: { minThroughput: Float };
    };

    // Confidence Threshold Management
    public type ConfidenceThreshold = {
        pathName: Text;
        modelVersion: Text;
        minConfidence: Float;
        escalationThreshold: Float;
        fallbackStrategy: FallbackStrategy;
        owner: ThresholdOwner;
        lastReviewed: Time.Time;
    };

    public type FallbackStrategy = {
        #DeterministicRules;
        #PreviousModel: { version: Text };
        #HumanApproval;
        #BlockTransaction;
    };

    public type ThresholdOwner = {
        #Product: { team: Text; lead: Text };
        #SRE: { team: Text; oncall: Text };
        #Joint: { productLead: Text; sreOncall: Text };
    };

    // Model Governance Manager Class
    public class ModelGovernanceManager() {
        private var modelVersions = HashMap.HashMap<Text, ModelVersion>(10, Text.equal, Text.hash);
        private var canaryConfigs = HashMap.HashMap<Text, CanaryConfig>(10, Text.equal, Text.hash);
        private var confidenceThresholds = HashMap.HashMap<Text, ConfidenceThreshold>(10, Text.equal, Text.hash);
        private var rollbackHistory = HashMap.HashMap<Text, [RollbackEvent]>(10, Text.equal, Text.hash);
        private var currentStableVersion: ?Text = null;

        // Model Version Management
        public func registerModelVersion(version: ModelVersion) : Result.Result<Text, Text> {
            Debug.print("Model Governance: Registering model version " # version.version);
            
            // Validate model version
            if (version.canaryPercentage < 0.0 or version.canaryPercentage > 100.0) {
                return #err("Invalid canary percentage: must be between 0 and 100");
            };
            
            if (Array.size(version.paths) == 0) {
                return #err("Model version must specify at least one path");
            };
            
            modelVersions.put(version.version, version);
            
            // Initialize rollback history for new version
            rollbackHistory.put(version.version, []);
            
            Debug.print("Model version " # version.version # " registered successfully");
            #ok("Model version registered: " # version.version)
        };

        public func deployCanary(version: Text, config: CanaryConfig) : Result.Result<Text, Text> {
            switch (modelVersions.get(version)) {
                case (null) { 
                    return #err("Model version not found: " # version) 
                };
                case (?modelVersion) {
                    Debug.print("Model Governance: Deploying canary for version " # version);
                    
                    // Update model status to canary
                    let updatedVersion = {
                        modelVersion with
                        status = #Canary({ percentage = config.targetPercentage });
                        canaryPercentage = config.targetPercentage;
                    };
                    
                    modelVersions.put(version, updatedVersion);
                    canaryConfigs.put(version, config);
                    
                    // Log canary deployment
                    let _canaryEvent = {
                        eventType = #CanaryDeployed;
                        version = version;
                        timestamp = Time.now();
                        metadata = "Canary deployed at " # Float.toText(config.targetPercentage) # "%";
                    };
                    
                    Debug.print("Canary deployment initiated for " # version);
                    #ok("Canary deployed: " # version # " at " # Float.toText(config.targetPercentage) # "%")
                };
            }
        };

        public func promoteToStable(version: Text) : Result.Result<Text, Text> {
            switch (modelVersions.get(version)) {
                case (null) { 
                    return #err("Model version not found: " # version) 
                };
                case (?modelVersion) {
                    Debug.print("Model Governance: Promoting version " # version # " to stable");
                    
                    // Update current stable version
                    currentStableVersion := ?version;
                    
                    // Update model status
                    let promotedVersion = {
                        modelVersion with
                        status = #Stable;
                        canaryPercentage = 100.0;
                    };
                    
                    modelVersions.put(version, promotedVersion);
                    
                    Debug.print("Model version " # version # " promoted to stable");
                    #ok("Model promoted to stable: " # version)
                };
            }
        };

        // Rollback System
        public func evaluateRollbackTriggers(version: Text, currentMetrics: ModelPerformance) : Result.Result<Bool, Text> {
            switch (modelVersions.get(version)) {
                case (null) { 
                    return #err("Model version not found: " # version) 
                };
                case (?modelVersion) {
                    let triggers = modelVersion.rollbackTriggers;
                    
                    for (trigger in triggers.vals()) {
                        let shouldRollback = switch (trigger) {
                            case (#LatencyDrift({ threshold; windowMs = _ })) {
                                currentMetrics.latencyP95Ms > (modelVersion.performance.latencyP95Ms * (1.0 + threshold))
                            };
                            case (#AccuracyDrop({ threshold; minSamples = _ })) {
                                currentMetrics.accuracyScore < (modelVersion.performance.accuracyScore - threshold)
                            };
                            case (#ErrorRateSpike({ threshold; windowMs = _ })) {
                                currentMetrics.errorRate > (modelVersion.performance.errorRate + threshold)
                            };
                            case (#ConfidenceDrop({ threshold; minSamples = _ })) {
                                currentMetrics.confidenceScore < (modelVersion.performance.confidenceScore - threshold)
                            };
                            case (#ThroughputDrop({ threshold; windowMs = _ })) {
                                currentMetrics.throughput < (modelVersion.performance.throughput * (1.0 - threshold))
                            };
                        };
                        
                        if (shouldRollback) {
                            Debug.print("Rollback trigger activated for version " # version);
                            let _ = executeRollback(version, trigger);
                            return #ok(true);
                        };
                    };
                    
                    #ok(false)
                };
            }
        };

        public func executeRollback(version: Text, trigger: RollbackTrigger) : Result.Result<Text, Text> {
            Debug.print("Model Governance: Executing rollback for version " # version);
            
            switch (currentStableVersion) {
                case (null) {
                    return #err("No stable version available for rollback");
                };
                case (?stableVersion) {
                    if (stableVersion == version) {
                        return #err("Cannot rollback stable version without alternative");
                    };
                    
                    // Record rollback event
                    let rollbackEvent = {
                        eventType = #RollbackExecuted;
                        version = version;
                        timestamp = Time.now();
                        reason = switch (trigger) {
                            case (#LatencyDrift(_)) { "Latency drift exceeded threshold" };
                            case (#AccuracyDrop(_)) { "Accuracy drop exceeded threshold" };
                            case (#ErrorRateSpike(_)) { "Error rate spike exceeded threshold" };
                            case (#ConfidenceDrop(_)) { "Confidence drop exceeded threshold" };
                            case (#ThroughputDrop(_)) { "Throughput drop exceeded threshold" };
                        };
                        targetVersion = stableVersion;
                    };
                    
                    // Update model status
                    switch (modelVersions.get(version)) {
                        case (?modelVersion) {
                            let rolledBackVersion = {
                                modelVersion with
                                status = #Rollback({ 
                                    reason = rollbackEvent.reason; 
                                    triggeredAt = Time.now() 
                                });
                                canaryPercentage = 0.0;
                            };
                            modelVersions.put(version, rolledBackVersion);
                            
                            // Add to rollback history
                            switch (rollbackHistory.get(version)) {
                                case (?history) {
                                    rollbackHistory.put(version, Array.append(history, [rollbackEvent]));
                                };
                                case (null) {
                                    rollbackHistory.put(version, [rollbackEvent]);
                                };
                            };
                        };
                        case (null) { /* version not found, continue */ };
                    };
                    
                    Debug.print("Rollback executed: " # version # " -> " # stableVersion);
                    #ok("Rollback executed: " # version # " reverted to " # stableVersion)
                };
            }
        };

        // Confidence Threshold Management
        public func setConfidenceThreshold(threshold: ConfidenceThreshold) : Result.Result<Text, Text> {
            let key = threshold.pathName # ":" # threshold.modelVersion;
            confidenceThresholds.put(key, threshold);
            
            Debug.print("Confidence threshold set for " # threshold.pathName # " on model " # threshold.modelVersion);
            #ok("Confidence threshold configured for " # threshold.pathName)
        };

        public func getConfidenceThreshold(pathName: Text, modelVersion: Text) : ?ConfidenceThreshold {
            let key = pathName # ":" # modelVersion;
            confidenceThresholds.get(key)
        };

        public func updateThresholdOwnership(pathName: Text, modelVersion: Text, newOwner: ThresholdOwner) : Result.Result<Text, Text> {
            let key = pathName # ":" # modelVersion;
            switch (confidenceThresholds.get(key)) {
                case (?threshold) {
                    let updatedThreshold = {
                        threshold with
                        owner = newOwner;
                        lastReviewed = Time.now();
                    };
                    confidenceThresholds.put(key, updatedThreshold);
                    #ok("Threshold ownership updated for " # pathName);
                };
                case (null) {
                    #err("Confidence threshold not found for " # pathName # ":" # modelVersion);
                };
            }
        };

        // Traffic Splitting for Canary
        public func getTrafficSplit(pathName: Text) : TrafficSplitResult {
            // Find active canary for this path
            for ((version, modelVersion) in modelVersions.entries()) {
                if (Array.find(modelVersion.paths, func(p: Text) : Bool { p == pathName }) != null) {
                    switch (modelVersion.status) {
                        case (#Canary({ percentage })) {
                            return {
                                canaryVersion = ?version;
                                canaryPercentage = percentage;
                                stableVersion = currentStableVersion;
                                splitDecision = #CanaryActive;
                            };
                        };
                        case (_) { /* continue checking other versions */ };
                    };
                };
            };
            
            // No active canary, use stable version
            {
                canaryVersion = null;
                canaryPercentage = 0.0;
                stableVersion = currentStableVersion;
                splitDecision = #StableOnly;
            }
        };

        // Monitoring and Observability
        public func getGovernanceMetrics() : GovernanceMetrics {
            var totalVersions = 0;
            var canaryVersions = 0;
            var stableVersions = 0;
            var rollbackCount = 0;
            
            for ((_, version) in modelVersions.entries()) {
                totalVersions += 1;
                switch (version.status) {
                    case (#Canary(_)) { canaryVersions += 1; };
                    case (#Stable) { stableVersions += 1; };
                    case (#Rollback(_)) { rollbackCount += 1; };
                    case (_) { /* other statuses */ };
                };
            };
            
            {
                totalVersions = totalVersions;
                canaryVersions = canaryVersions;
                stableVersions = stableVersions;
                rollbackCount = rollbackCount;
                thresholdCount = confidenceThresholds.size();
                lastUpdate = Time.now();
            }
        };

        public func getVersionHistory(version: Text) : ?[RollbackEvent] {
            rollbackHistory.get(version)
        };

        public func getAllVersions() : [(Text, ModelVersion)] {
            Iter.toArray(modelVersions.entries())
        };

        public func getCurrentStable() : ?Text {
            currentStableVersion
        };
    };

    // Supporting types for traffic splitting
    public type TrafficSplitResult = {
        canaryVersion: ?Text;
        canaryPercentage: Float;
        stableVersion: ?Text;
        splitDecision: SplitDecision;
    };

    public type SplitDecision = {
        #StableOnly;
        #CanaryActive;
        #RollbackInProgress;
    };

    // Governance metrics for monitoring
    public type GovernanceMetrics = {
        totalVersions: Nat;
        canaryVersions: Nat;
        stableVersions: Nat;
        rollbackCount: Nat;
        thresholdCount: Nat;
        lastUpdate: Time.Time;
    };

    // Rollback event tracking
    public type RollbackEvent = {
        eventType: EventType;
        version: Text;
        timestamp: Time.Time;
        reason: Text;
        targetVersion: Text;
    };

    public type EventType = {
        #CanaryDeployed;
        #CanaryPromoted;
        #RollbackExecuted;
        #ThresholdUpdated;
        #OwnershipChanged;
    };
}
