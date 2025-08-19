// Canary Controller - Phase 2 Week 7
// Advanced canary deployment with A/B testing and gradual rollout

import Time "mo:base/Time";
import Result "mo:base/Result";
import Float "mo:base/Float";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import _Option "mo:base/Option";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";

module {
    public type CanaryController = {
        rolloutId: Text;
        modelVersion: Text;
        currentPercentage: Float;
        targetPercentage: Float;
        rolloutSteps: [RolloutStep];
        currentStep: Nat;
        startedAt: Time.Time;
        lastUpdated: Time.Time;
        status: RolloutStatus;
    };

    public type RolloutStep = {
        stepNumber: Nat;
        targetPercentage: Float;
        durationMs: Nat;
        evaluationCriteria: [EvaluationMetric];
        completedAt: ?Time.Time;
        successful: ?Bool;
    };

    public type RolloutStatus = {
        #Planning;
        #InProgress: { stepNumber: Nat };
        #Paused: { reason: Text; atStep: Nat };
        #Completed: { finalPercentage: Float };
        #Aborted: { reason: Text; atStep: Nat };
        #RolledBack: { reason: Text; fromStep: Nat };
    };

    public type EvaluationMetric = {
        #LatencyP95: { target: Float; actual: Float; passing: Bool };
        #LatencyP99: { target: Float; actual: Float; passing: Bool };
        #ErrorRate: { maxThreshold: Float; actual: Float; passing: Bool };
        #Throughput: { minThreshold: Float; actual: Float; passing: Bool };
        #Confidence: { minThreshold: Float; actual: Float; passing: Bool };
        #UserExperience: { scoreThreshold: Float; actual: Float; passing: Bool };
    };

    // A/B Testing Framework
    public type ABTestSetup = {
        testId: Text;
        controlVersion: Text;
        treatmentVersion: Text;
        trafficAllocation: Float;
        paths: [Text];
        hypotheses: [ABHypothesis];
        statisticalConfig: StatisticalConfig;
        startedAt: Time.Time;
        status: ABTestStatus;
    };

    public type ABHypothesis = {
        metric: Text;
        expectedChange: Float;
        direction: ImprovementDirection;
        significance: Float;
    };

    public type ImprovementDirection = {
        #Increase;
        #Decrease;
        #Maintain;
    };

    public type StatisticalConfig = {
        confidenceLevel: Float;
        minimumSampleSize: Nat;
        minimumDetectableEffect: Float;
        powerLevel: Float;
    };

    public type ABTestStatus = {
        #Designing;
        #Running: { samplesCollected: Nat };
        #Analyzing: { preliminaryResults: [ABResult] };
        #Concluded: { finalResults: [ABResult]; winner: ?Text };
        #Inconclusive: { reason: Text };
    };

    public type ABResult = {
        metric: Text;
        controlValue: Float;
        treatmentValue: Float;
        improvementPercent: Float;
        pValue: Float;
        significant: Bool;
        confidenceInterval: (Float, Float);
    };

    // Traffic Splitting Logic
    public class CanaryTrafficSplitter() {
        private var activeCanaries = HashMap.HashMap<Text, CanaryController>(10, Text.equal, Text.hash);
        private var abTests = HashMap.HashMap<Text, ABTestSetup>(10, Text.equal, Text.hash);
        // Path-specific canary configurations
        private var _pathMappings = HashMap.HashMap<Text, Text>(10, Text.equal, Text.hash);

        public func createCanaryRollout(
            rolloutId: Text,
            modelVersion: Text,
            rolloutSteps: [RolloutStep]
        ) : Result.Result<Text, Text> {
            Debug.print("Canary Controller: Creating rollout " # rolloutId # " for version " # modelVersion);
            
            if (Array.size(rolloutSteps) == 0) {
                return #err("Rollout must have at least one step");
            };
            
            let canary = {
                rolloutId = rolloutId;
                modelVersion = modelVersion;
                currentPercentage = 0.0;
                targetPercentage = rolloutSteps[Array.size(rolloutSteps) - 1].targetPercentage;
                rolloutSteps = rolloutSteps;
                currentStep = 0;
                startedAt = Time.now();
                lastUpdated = Time.now();
                status = #Planning;
            };
            
            activeCanaries.put(rolloutId, canary);
            Debug.print("Canary rollout created: " # rolloutId);
            #ok("Canary rollout created: " # rolloutId)
        };

        public func startRollout(rolloutId: Text) : Result.Result<Text, Text> {
            switch (activeCanaries.get(rolloutId)) {
                case (?canary) {
                    Debug.print("Starting canary rollout: " # rolloutId);
                    
                    let updatedCanary = {
                        canary with
                        status = #InProgress({ stepNumber = 0 });
                        lastUpdated = Time.now();
                    };
                    
                    activeCanaries.put(rolloutId, updatedCanary);
                    #ok("Rollout started: " # rolloutId);
                };
                case (null) {
                    #err("Canary rollout not found: " # rolloutId);
                };
            }
        };

        public func evaluateCurrentStep(rolloutId: Text, metrics: [EvaluationMetric]) : Result.Result<StepEvaluation, Text> {
            switch (activeCanaries.get(rolloutId)) {
                case (?canary) {
                    switch (canary.status) {
                        case (#InProgress({ stepNumber })) {
                            if (stepNumber >= Array.size(canary.rolloutSteps)) {
                                return #err("Invalid step number");
                            };
                            
                            let currentStep = canary.rolloutSteps[stepNumber];
                            let evaluation = evaluateStepCriteria(currentStep.evaluationCriteria, metrics);
                            
                            Debug.print("Step evaluation for " # rolloutId # " step " # debug_show(stepNumber) # ": " # 
                                      (if (evaluation.passed) "PASSED" else "FAILED"));
                            
                            #ok(evaluation);
                        };
                        case (_) {
                            #err("Rollout is not in progress");
                        };
                    };
                };
                case (null) {
                    #err("Canary rollout not found: " # rolloutId);
                };
            }
        };

        public func advanceToNextStep(rolloutId: Text) : Result.Result<Text, Text> {
            switch (activeCanaries.get(rolloutId)) {
                case (?canary) {
                    switch (canary.status) {
                        case (#InProgress({ stepNumber })) {
                            let nextStep = stepNumber + 1;
                            
                            if (nextStep >= Array.size(canary.rolloutSteps)) {
                                // Rollout completed
                                let completedCanary = {
                                    canary with
                                    status = #Completed({ finalPercentage = canary.targetPercentage });
                                    currentPercentage = canary.targetPercentage;
                                    lastUpdated = Time.now();
                                };
                                activeCanaries.put(rolloutId, completedCanary);
                                #ok("Rollout completed: " # rolloutId);
                            } else {
                                // Advance to next step
                                let nextStepConfig = canary.rolloutSteps[nextStep];
                                let advancedCanary = {
                                    canary with
                                    status = #InProgress({ stepNumber = nextStep });
                                    currentStep = nextStep;
                                    currentPercentage = nextStepConfig.targetPercentage;
                                    lastUpdated = Time.now();
                                };
                                activeCanaries.put(rolloutId, advancedCanary);
                                #ok("Advanced to step " # debug_show(nextStep) # ": " # Float.toText(nextStepConfig.targetPercentage) # "%");
                            };
                        };
                        case (_) {
                            #err("Rollout is not in progress");
                        };
                    };
                };
                case (null) {
                    #err("Canary rollout not found: " # rolloutId);
                };
            }
        };

        public func pauseRollout(rolloutId: Text, reason: Text) : Result.Result<Text, Text> {
            switch (activeCanaries.get(rolloutId)) {
                case (?canary) {
                    switch (canary.status) {
                        case (#InProgress({ stepNumber })) {
                            let pausedCanary = {
                                canary with
                                status = #Paused({ reason = reason; atStep = stepNumber });
                                lastUpdated = Time.now();
                            };
                            activeCanaries.put(rolloutId, pausedCanary);
                            Debug.print("Rollout paused: " # rolloutId # " - " # reason);
                            #ok("Rollout paused: " # reason);
                        };
                        case (_) {
                            #err("Rollout is not in progress");
                        };
                    };
                };
                case (null) {
                    #err("Canary rollout not found: " # rolloutId);
                };
            }
        };

        public func abortRollout(rolloutId: Text, reason: Text) : Result.Result<Text, Text> {
            switch (activeCanaries.get(rolloutId)) {
                case (?canary) {
                    let abortedCanary = {
                        canary with
                        status = #Aborted({ reason = reason; atStep = canary.currentStep });
                        currentPercentage = 0.0;
                        lastUpdated = Time.now();
                    };
                    activeCanaries.put(rolloutId, abortedCanary);
                    Debug.print("Rollout aborted: " # rolloutId # " - " # reason);
                    #ok("Rollout aborted: " # reason);
                };
                case (null) {
                    #err("Canary rollout not found: " # rolloutId);
                };
            }
        };

        // Traffic Routing Decision
        public func shouldRouteToCanary(_pathName: Text, requestId: Text) : CanaryRoutingDecision {
            // Find active canary for this path
            for ((rolloutId, canary) in activeCanaries.entries()) {
                switch (canary.status) {
                    case (#InProgress(_) or #Completed(_)) {
                        // Use deterministic routing based on request ID hash
                        let hashValue = Int.abs(Nat32.toNat(Text.hash(requestId) % 100));
                        let threshold = Float.toInt(canary.currentPercentage);
                        
                        if (hashValue < threshold) {
                            return {
                                useCanary = true;
                                canaryVersion = canary.modelVersion;
                                rolloutId = ?rolloutId;
                                routingReason = "Hash-based canary routing";
                                percentage = canary.currentPercentage;
                            };
                        };
                    };
                    case (_) { /* canary not active */ };
                };
            };
            
            // No active canary, route to stable
            {
                useCanary = false;
                canaryVersion = "";
                rolloutId = null;
                routingReason = "No active canary";
                percentage = 0.0;
            }
        };

        // A/B Test Management
        public func setupABTest(testSetup: ABTestSetup) : Result.Result<Text, Text> {
            Debug.print("Setting up A/B test: " # testSetup.testId);
            abTests.put(testSetup.testId, testSetup);
            #ok("A/B test setup complete: " # testSetup.testId)
        };

        public func getABTestAssignment(testId: Text, userId: Text) : ABAssignment {
            switch (abTests.get(testId)) {
                case (?test) {
                    let userHash = Int.abs(Nat32.toNat(Text.hash(userId) % 100));
                    let controlThreshold = Float.toInt(50.0); // 50/50 split
                    
                    if (userHash < controlThreshold) {
                        {
                            assignment = #Control;
                            version = test.controlVersion;
                            testId = testId;
                            cohort = "control";
                        }
                    } else {
                        {
                            assignment = #Treatment;
                            version = test.treatmentVersion;
                            testId = testId;
                            cohort = "treatment";
                        }
                    };
                };
                case (null) {
                    {
                        assignment = #NotInTest;
                        version = "";
                        testId = "";
                        cohort = "none";
                    };
                };
            }
        };

        // Monitoring and Status
        public func getCanaryStatus(rolloutId: Text) : ?CanaryController {
            activeCanaries.get(rolloutId)
        };

        public func getAllActiveCanaries() : [(Text, CanaryController)] {
            Iter.toArray(activeCanaries.entries())
        };

        // Helper functions
        private func evaluateStepCriteria(criteria: [EvaluationMetric], actual: [EvaluationMetric]) : StepEvaluation {
            var totalCriteria = Array.size(criteria);
            var passingCriteria = 0;
            var evaluations: [CriterionEvaluation] = [];
            
            for (criterion in criteria.vals()) {
                let evaluation = evaluateSingleCriterion(criterion, actual);
                evaluations := Array.append(evaluations, [evaluation]);
                if (evaluation.passed) {
                    passingCriteria += 1;
                };
            };
            
            {
                passed = passingCriteria == totalCriteria;
                totalCriteria = totalCriteria;
                passingCriteria = passingCriteria;
                evaluations = evaluations;
                evaluatedAt = Time.now();
            }
        };

        private func evaluateSingleCriterion(criterion: EvaluationMetric, actuals: [EvaluationMetric]) : CriterionEvaluation {
            // Find matching actual metric
            for (actual in actuals.vals()) {
                let matches = switch (criterion, actual) {
                    case (#LatencyP95(expected), #LatencyP95(actualData)) {
                        { metricName = "LatencyP95"; passed = actualData.actual <= expected.target; expected = expected.target; actual = actualData.actual }
                    };
                    case (#ErrorRate(expected), #ErrorRate(actualData)) {
                        { metricName = "ErrorRate"; passed = actualData.actual <= expected.maxThreshold; expected = expected.maxThreshold; actual = actualData.actual }
                    };
                    case (#Throughput(expected), #Throughput(actualData)) {
                        { metricName = "Throughput"; passed = actualData.actual >= expected.minThreshold; expected = expected.minThreshold; actual = actualData.actual }
                    };
                    case (#Confidence(expected), #Confidence(actualData)) {
                        { metricName = "Confidence"; passed = actualData.actual >= expected.minThreshold; expected = expected.minThreshold; actual = actualData.actual }
                    };
                    case (_, _) { { metricName = "Unknown"; passed = false; expected = 0.0; actual = 0.0 } };
                };
                
                if (matches.metricName != "Unknown") {
                    return matches;
                };
            };
            
            // No matching actual metric found
            { metricName = "NotFound"; passed = false; expected = 0.0; actual = 0.0 }
        };
    };

    // Supporting types for routing and evaluation
    public type CanaryRoutingDecision = {
        useCanary: Bool;
        canaryVersion: Text;
        rolloutId: ?Text;
        routingReason: Text;
        percentage: Float;
    };

    public type StepEvaluation = {
        passed: Bool;
        totalCriteria: Nat;
        passingCriteria: Nat;
        evaluations: [CriterionEvaluation];
        evaluatedAt: Time.Time;
    };

    public type CriterionEvaluation = {
        metricName: Text;
        passed: Bool;
        expected: Float;
        actual: Float;
    };

    public type ABAssignment = {
        assignment: AssignmentType;
        version: Text;
        testId: Text;
        cohort: Text;
    };

    public type AssignmentType = {
        #Control;
        #Treatment;
        #NotInTest;
    };
}
