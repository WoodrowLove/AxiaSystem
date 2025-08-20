import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Int "mo:base/Int";

import ChaosEngineeringManager "chaos_engineering_manager";

// Week 12: Chaos Engineering & Production Readiness Actor
// Implements disaster recovery testing, fault injection, and resilience validation
persistent actor ChaosEngineeringSystem {
    
    type ChaosExperiment = ChaosEngineeringManager.ChaosExperiment;
    type DisasterRecoveryTest = ChaosEngineeringManager.DisasterRecoveryTest;
    type ProductionReadinessChecklist = ChaosEngineeringManager.ProductionReadinessChecklist;
    type SystemHardeningReport = ChaosEngineeringManager.SystemHardeningReport;
    type FaultType = ChaosEngineeringManager.FaultType;
    type SeverityLevel = ChaosEngineeringManager.SeverityLevel;
    type DisasterType = ChaosEngineeringManager.DisasterType;
    type RecoveryObjectives = ChaosEngineeringManager.RecoveryObjectives;
    type TestStep = ChaosEngineeringManager.TestStep;
    type ExperimentResults = ChaosEngineeringManager.ExperimentResults;
    type ExecutionResults = ChaosEngineeringManager.ExecutionResults;
    
    public type ChaosSystemConfig = {
        maxConcurrentExperiments : Nat;
        safetyOverrideEnabled : Bool;
        autoRecoveryEnabled : Bool;
        emergencyStopEnabled : Bool;
        productionTestingAllowed : Bool;
        maxExperimentDuration : Nat;
    };
    
    private let defaultChaosConfig : ChaosSystemConfig = {
        maxConcurrentExperiments = 3;
        safetyOverrideEnabled = true;
        autoRecoveryEnabled = true;
        emergencyStopEnabled = true;
        productionTestingAllowed = false;
        maxExperimentDuration = 3600; // 1 hour
    };
    
    // Week 12: Stable storage for chaos engineering data
    private var chaosExperiments : [(Text, ChaosExperiment)] = [];
    private var disasterTests : [(Text, DisasterRecoveryTest)] = [];
    private var readinessReports : [(Text, ProductionReadinessChecklist)] = [];
    private var hardeningReports : [(Text, SystemHardeningReport)] = [];
    private var chaosConfig : ChaosSystemConfig = defaultChaosConfig;
    private var lastSystemHardeningDate : Int = 0;
    private var productionReadinessScore : Float = 0.0;
    
    // Week 12: Runtime state (transient)
    private transient var experimentMap = HashMap.fromIter<Text, ChaosExperiment>(chaosExperiments.vals(), 100, Text.equal, Text.hash);
    private transient var disasterTestMap = HashMap.fromIter<Text, DisasterRecoveryTest>(disasterTests.vals(), 50, Text.equal, Text.hash);
    private transient var readinessMap = HashMap.fromIter<Text, ProductionReadinessChecklist>(readinessReports.vals(), 20, Text.equal, Text.hash);
    private transient var hardeningMap = HashMap.fromIter<Text, SystemHardeningReport>(hardeningReports.vals(), 10, Text.equal, Text.hash);
    
    public type ChaosSystemStatus = {
        activeExperiments : Nat;
        completedExperiments : Nat;
        failedExperiments : Nat;
        systemResilience : Float;
        lastHardeningDate : Int;
        productionReadiness : Float;
        emergencyStopActive : Bool;
        safetyLevel : { #Safe; #Caution; #Warning; #Emergency };
    };
    
    // Week 12: System lifecycle management
    system func preupgrade() {
        chaosExperiments := Iter.toArray(experimentMap.entries());
        disasterTests := Iter.toArray(disasterTestMap.entries());
        readinessReports := Iter.toArray(readinessMap.entries());
        hardeningReports := Iter.toArray(hardeningMap.entries());
    };
    
    system func postupgrade() {
        chaosExperiments := [];
        disasterTests := [];
        readinessReports := [];
        hardeningReports := [];
    };
    
    // Week 12: Initialize chaos engineering system
    public func initializeChaosSystem() : async Result.Result<Text, Text> {
        Debug.print("Week 12: Initializing Chaos Engineering System");
        
        // Set initial system state
        lastSystemHardeningDate := Time.now();
        productionReadinessScore := 0.75; // Initial baseline
        
        // Validate system prerequisites
        let systemHealth = await validateSystemHealth();
        if (not systemHealth) {
            return #err("System health check failed - chaos testing not safe");
        };
        
        Debug.print("Week 12: Chaos Engineering System initialized successfully");
        #ok("Chaos Engineering System initialized with safety protocols active")
    };
    
    // Week 12: Create and execute chaos experiment
    public func createChaosExperiment(
        name : Text,
        description : Text,
        targetSystem : Text,
        faultType : FaultType,
        duration : Nat,
        severity : SeverityLevel,
        hypothesis : Text,
        successCriteria : [Text]
    ) : async Result.Result<Text, Text> {
        
        // Validate experiment safety
        if (duration > chaosConfig.maxExperimentDuration) {
            return #err("Experiment duration exceeds maximum allowed time");
        };
        
        if (experimentMap.size() >= chaosConfig.maxConcurrentExperiments) {
            return #err("Maximum concurrent experiments limit reached");
        };
        
        // Create experiment
        let experiment = ChaosEngineeringManager.createChaosExperiment(
            name, description, targetSystem, faultType, duration, severity, hypothesis, successCriteria
        );
        
        experimentMap.put(experiment.experimentId, experiment);
        
        Debug.print("Week 12: Created chaos experiment: " # experiment.experimentId);
        #ok(experiment.experimentId)
    };
    
    public func executeChaosExperiment(experimentId : Text) : async Result.Result<ExperimentResults, Text> {
        switch (experimentMap.get(experimentId)) {
            case null {
                return #err("Experiment not found: " # experimentId);
            };
            case (?experiment) {
                // Execute the experiment
                let result = await ChaosEngineeringManager.executeChaosExperiment(experiment);
                
                switch (result) {
                    case (#ok(experimentResults)) {
                        // Update experiment with results
                        let updatedExperiment = {
                            experiment with
                            status = #Completed;
                            endTime = ?Time.now();
                            results = ?experimentResults;
                        };
                        experimentMap.put(experimentId, updatedExperiment);
                        
                        Debug.print("Week 12: Chaos experiment " # experimentId # " completed successfully");
                        #ok(experimentResults)
                    };
                    case (#err(error)) {
                        // Mark experiment as failed
                        let failedExperiment = {
                            experiment with
                            status = #Failed;
                            endTime = ?Time.now();
                        };
                        experimentMap.put(experimentId, failedExperiment);
                        
                        Debug.print("Week 12: Chaos experiment " # experimentId # " failed: " # error);
                        #err(error)
                    };
                }
            };
        }
    };
    
    // Week 12: Disaster recovery testing
    public func createDisasterRecoveryTest(
        scenarioName : Text,
        disasterType : DisasterType,
        affectedSystems : [Text],
        recoveryObjectives : RecoveryObjectives,
        testPlan : [TestStep]
    ) : async Result.Result<Text, Text> {
        
        let testId = "dr_test_" # Int.toText(Time.now());
        
        let drTest : DisasterRecoveryTest = {
            testId = testId;
            scenarioName = scenarioName;
            disasterType = disasterType;
            affectedSystems = affectedSystems;
            recoveryObjectives = recoveryObjectives;
            testPlan = testPlan;
            executionResults = null;
            complianceValidation = null;
        };
        
        disasterTestMap.put(testId, drTest);
        
        Debug.print("Week 12: Created disaster recovery test: " # testId);
        #ok(testId)
    };
    
    public func executeDisasterRecoveryTest(testId : Text) : async Result.Result<ExecutionResults, Text> {
        switch (disasterTestMap.get(testId)) {
            case null {
                return #err("Disaster recovery test not found: " # testId);
            };
            case (?test) {
                let result = await ChaosEngineeringManager.runDisasterRecoveryTest(test);
                
                switch (result) {
                    case (#ok(executionResults)) {
                        // Update test with results
                        let updatedTest = {
                            test with
                            executionResults = ?executionResults;
                        };
                        disasterTestMap.put(testId, updatedTest);
                        
                        Debug.print("Week 12: Disaster recovery test " # testId # " completed");
                        #ok(executionResults)
                    };
                    case (#err(error)) {
                        Debug.print("Week 12: Disaster recovery test " # testId # " failed: " # error);
                        #err(error)
                    };
                }
            };
        }
    };
    
    // Week 12: Production readiness assessment
    public func assessProductionReadiness() : async Result.Result<[ProductionReadinessChecklist], Text> {
        let readinessReports = await ChaosEngineeringManager.generateProductionReadinessReport();
        
        // Store reports
        let timestamp = Int.toText(Time.now());
        for (report in readinessReports.vals()) {
            let reportId = report.category # "_" # timestamp;
            readinessMap.put(reportId, report);
        };
        
        // Calculate overall readiness score
        var totalScore : Float = 0.0;
        var reportCount : Float = 0.0;
        
        for (report in readinessReports.vals()) {
            totalScore += report.overallScore;
            reportCount += 1.0;
        };
        
        productionReadinessScore := if (reportCount > 0.0) {
            totalScore / reportCount
        } else {
            0.0
        };
        
        Debug.print("Week 12: Production readiness assessment completed. Score: " # 
                   Float.toText(productionReadinessScore * 100.0) # "%");
        
        #ok(readinessReports)
    };
    
    // Week 12: System hardening
    public func performSystemHardening() : async Result.Result<SystemHardeningReport, Text> {
        let hardeningReport = await ChaosEngineeringManager.performSystemHardening();
        
        // Store hardening report
        hardeningMap.put(hardeningReport.hardeningId, hardeningReport);
        lastSystemHardeningDate := hardeningReport.timestamp;
        
        Debug.print("Week 12: System hardening completed. Security score: " # 
                   Float.toText(hardeningReport.securityScore * 100.0) # "%");
        
        #ok(hardeningReport)
    };
    
    // Week 12: Emergency stop functionality
    public func emergencyStop(reason : Text) : async Result.Result<Text, Text> {
        if (not chaosConfig.emergencyStopEnabled) {
            return #err("Emergency stop is disabled");
        };
        
        // Stop all running experiments
        var stoppedCount = 0;
        for ((experimentId, experiment) in experimentMap.entries()) {
            if (experiment.status == #Running) {
                let stoppedExperiment = {
                    experiment with
                    status = #SafetyStop;
                    endTime = ?Time.now();
                };
                experimentMap.put(experimentId, stoppedExperiment);
                stoppedCount += 1;
            };
        };
        
        Debug.print("Week 12: Emergency stop executed. Reason: " # reason # ". Stopped " # 
                   debug_show(stoppedCount) # " experiments");
        
        #ok("Emergency stop completed. " # debug_show(stoppedCount) # " experiments stopped")
    };
    
    // Week 12: System status monitoring
    public query func getChaosSystemStatus() : async ChaosSystemStatus {
        var activeExperiments = 0;
        var completedExperiments = 0;
        var failedExperiments = 0;
        var totalResilience : Float = 0.0;
        var resilienceCount : Float = 0.0;
        
        for ((_, experiment) in experimentMap.entries()) {
            switch (experiment.status) {
                case (#Running) { activeExperiments += 1; };
                case (#Completed) { 
                    completedExperiments += 1;
                    switch (experiment.results) {
                        case (?results) {
                            totalResilience += results.systemResilience;
                            resilienceCount += 1.0;
                        };
                        case null {};
                    };
                };
                case (#Failed) { failedExperiments += 1; };
                case (#SafetyStop) { failedExperiments += 1; };
                case (_) {};
            };
        };
        
        let systemResilience = if (resilienceCount > 0.0) {
            totalResilience / resilienceCount
        } else {
            0.0
        };
        
        // Determine safety level
        let safetyLevel = if (activeExperiments > chaosConfig.maxConcurrentExperiments) {
            #Emergency
        } else if (systemResilience < 0.7) {
            #Warning
        } else if (activeExperiments > (chaosConfig.maxConcurrentExperiments / 2)) {
            #Caution
        } else {
            #Safe
        };
        
        {
            activeExperiments = activeExperiments;
            completedExperiments = completedExperiments;
            failedExperiments = failedExperiments;
            systemResilience = systemResilience;
            lastHardeningDate = lastSystemHardeningDate;
            productionReadiness = productionReadinessScore;
            emergencyStopActive = false; // Would be tracked in real implementation
            safetyLevel = safetyLevel;
        }
    };
    
    // Week 12: Configuration management
    public func updateChaosConfig(newConfig : ChaosSystemConfig) : async Result.Result<(), Text> {
        chaosConfig := newConfig;
        
        Debug.print("Week 12: Chaos system configuration updated");
        #ok(())
    };
    
    public query func getChaosConfig() : async ChaosSystemConfig {
        chaosConfig
    };
    
    // Week 12: Query functions for monitoring and analysis
    public query func getChaosExperiments() : async [(Text, ChaosExperiment)] {
        Iter.toArray(experimentMap.entries())
    };
    
    public query func getDisasterRecoveryTests() : async [(Text, DisasterRecoveryTest)] {
        Iter.toArray(disasterTestMap.entries())
    };
    
    public query func getProductionReadinessReports() : async [(Text, ProductionReadinessChecklist)] {
        Iter.toArray(readinessMap.entries())
    };
    
    public query func getSystemHardeningReports() : async [(Text, SystemHardeningReport)] {
        Iter.toArray(hardeningMap.entries())
    };
    
    public query func getExperimentById(experimentId : Text) : async ?ChaosExperiment {
        experimentMap.get(experimentId)
    };
    
    public query func getDisasterTestById(testId : Text) : async ?DisasterRecoveryTest {
        disasterTestMap.get(testId)
    };
    
    // Week 12: Analytics and reporting
    public func generateChaosEngineeringReport() : async {
        reportId : Text;
        timestamp : Int;
        totalExperiments : Nat;
        successRate : Float;
        averageResilience : Float;
        criticalFindings : [Text];
        recommendations : [Text];
        systemMaturity : Float;
    } {
        let reportId = "chaos_report_" # Int.toText(Time.now());
        let timestamp = Time.now();
        
        var totalExperiments = 0;
        var successfulExperiments = 0;
        var totalResilience : Float = 0.0;
        var resilienceCount : Float = 0.0;
        var criticalFindings : [Text] = [];
        
        for ((_, experiment) in experimentMap.entries()) {
            totalExperiments += 1;
            
            switch (experiment.status) {
                case (#Completed) {
                    successfulExperiments += 1;
                    switch (experiment.results) {
                        case (?results) {
                            totalResilience += results.systemResilience;
                            resilienceCount += 1.0;
                            
                            if (results.systemResilience < 0.8) {
                                criticalFindings := Array.append(criticalFindings, 
                                    ["Low resilience in " # experiment.name # ": " # 
                                     Float.toText(results.systemResilience * 100.0) # "%"]);
                            };
                        };
                        case null {};
                    };
                };
                case (#Failed) {
                    criticalFindings := Array.append(criticalFindings, 
                        ["Experiment failure: " # experiment.name]);
                };
                case (_) {};
            };
        };
        
        let successRate = if (totalExperiments > 0) {
            Float.fromInt(successfulExperiments) / Float.fromInt(totalExperiments)
        } else {
            0.0
        };
        
        let averageResilience = if (resilienceCount > 0.0) {
            totalResilience / resilienceCount
        } else {
            0.0
        };
        
        let systemMaturity = (successRate * 0.4) + (averageResilience * 0.4) + (productionReadinessScore * 0.2);
        
        let recommendations = [
            "Continue regular chaos engineering exercises",
            "Focus on improving system resilience below 80%",
            "Implement automated recovery procedures",
            "Enhance monitoring and alerting systems"
        ];
        
        {
            reportId = reportId;
            timestamp = timestamp;
            totalExperiments = totalExperiments;
            successRate = successRate;
            averageResilience = averageResilience;
            criticalFindings = criticalFindings;
            recommendations = recommendations;
            systemMaturity = systemMaturity;
        }
    };
    
    // Week 12: Test data creation for validation
    public func createTestChaosExperiment() : async Result.Result<Text, Text> {
        let faultType : FaultType = #ResourceExhaustion({
            resourceType = "memory";
            exhaustionPercentage = 0.8;
        });
        
        await createChaosExperiment(
            "Test Memory Exhaustion",
            "Test system behavior under memory pressure",
            "ai_router",
            faultType,
            300, // 5 minutes
            #Medium,
            "System will maintain core functionality under memory pressure",
            ["Core services remain available", "Recovery within 2 minutes", "No data loss"]
        )
    };
    
    // Helper functions
    private func validateSystemHealth() : async Bool {
        // Simplified system health validation
        // In real implementation, would check system metrics, load, errors, etc.
        true
    };
}
