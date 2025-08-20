import Debug "mo:base/Debug";
import Time "mo:base/Time";
import _Timer "mo:base/Timer";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat32 "mo:base/Nat32";

import AIEnvelope "../types/ai_envelope";
import PolicyEngine "../policy/policy_engine";
import CorrelationReporting "correlation_reporting";

// Week 10: AI Reporting System Actor  
// Generates weekly summaries with batch pattern jobs (pull model)
// Data minimized: insights only, no PII, stored per retention class
persistent actor AIReportingSystem {
    
    type AIRequest = AIEnvelope.AIRequest;
    type AIResponse = AIEnvelope.AIResponse;
    type PolicyDecision = PolicyEngine.PolicyDecision;
    type AIInsightReport = CorrelationReporting.AIInsightReport;
    type CorrelationPattern = CorrelationReporting.CorrelationPattern;
    type TimeWindow = CorrelationReporting.TimeWindow;
    type BatchConfig = CorrelationReporting.BatchConfig;
    
    // Week 10: Stable storage for reports and configuration
    private var _reportCounter : Nat = 0;
    private var lastWeeklyReport : Int = 0;
    private var batchJobs : [(Text, BatchJobState)] = [];
    private var reportMetrics : [(Text, ReportPerformanceMetrics)] = [];
    
    // Week 10: Runtime state (transient)
    private transient var batchJobMap = HashMap.fromIter<Text, BatchJobState>(batchJobs.vals(), 10, Text.equal, Text.hash);
    private transient var metricsMap = HashMap.fromIter<Text, ReportPerformanceMetrics>(reportMetrics.vals(), 10, Text.equal, Text.hash);
    private transient var reportStorage = HashMap.HashMap<Text, AIInsightReport>(10, Text.equal, Text.hash);
    
    // Week 10: Batch job management
    public type BatchJobState = {
        jobId : Text;
        status : { #Pending; #Running; #Completed; #Failed };
        startTime : Int;
        endTime : ?Int;
        config : BatchConfig;
        processedRecords : Nat;
        errors : [Text];
    };
    
    public type ReportPerformanceMetrics = {
        reportId : Text;
        generationTimeMs : Nat32;
        dataPointsProcessed : Nat;
        patternsIdentified : Nat;
        complianceScore : Float;
        targetMet : Bool; // <10s generation time
    };
    
    // Week 10: Configuration for reporting system
    public type ReportingConfig = {
        weeklyScheduleEnabled : Bool;
        batchConfig : BatchConfig;
        retentionPolicyEnabled : Bool;
        piiValidationEnabled : Bool;
        maxReportsStored : Nat;
    };
    
    private var systemConfig : ReportingConfig = {
        weeklyScheduleEnabled = true;
        batchConfig = CorrelationReporting.defaultBatchConfig;
        retentionPolicyEnabled = true;
        piiValidationEnabled = true;
        maxReportsStored = 100;
    };
    
    // Week 10: System lifecycle management
    system func preupgrade() {
        batchJobs := Iter.toArray(batchJobMap.entries());
        reportMetrics := Iter.toArray(metricsMap.entries());
    };
    
    system func postupgrade() {
        batchJobs := [];
        reportMetrics := [];
    };
    
    // Week 10: Initialize weekly reporting schedule
    public func initializeWeeklyReporting() : async Result.Result<Text, Text> {
        if (not systemConfig.weeklyScheduleEnabled) {
            return #err("Weekly reporting is disabled");
        };
        
        let _weeklyInterval = 7 * 24 * 60 * 60 * 1_000_000_000; // 1 week in nanoseconds
        let currentTime = Time.now();
        
        // Schedule weekly report generation (simplified for now)
        // let timerId = Timer.recurringTimer<system>(#nanoseconds(weeklyInterval), generateWeeklyReport);
        
        lastWeeklyReport := currentTime;
        
        #ok("Weekly reporting initialized")
    };
    
    // Week 10: Core batch processing function  
    public func processBatchData(
        requests : [AIRequest],
        responses : [AIResponse], 
        decisions : [PolicyDecision]
    ) : async Result.Result<Text, Text> {
        let jobId = "batch_" # debug_show(Time.now());
        let startTime = Time.now();
        
        // Create batch job record
        let job : BatchJobState = {
            jobId = jobId;
            status = #Running;
            startTime = startTime;
            endTime = null;
            config = systemConfig.batchConfig;
            processedRecords = requests.size();
            errors = [];
        };
        
        batchJobMap.put(jobId, job);
        
        try {
            // Validate batch size
            if (requests.size() > systemConfig.batchConfig.maxBatchSize) {
                let errorJob = { job with 
                    status = #Failed; 
                    endTime = ?Time.now();
                    errors = ["Batch size exceeds maximum: " # debug_show(requests.size())];
                };
                batchJobMap.put(jobId, errorJob);
                return #err("Batch size too large");
            };
            
            // Process correlation patterns  
            let timeWindow : TimeWindow = {
                startTime = startTime - (24 * 60 * 60 * 1_000_000_000); // 24 hours ago
                endTime = startTime;
                duration = "24h";
            };
            
            let patterns = CorrelationReporting.analyzeCorrelationPatterns(
                requests, responses, decisions, timeWindow
            );
            
            // Generate insights report
            let reportId = "insights_" # debug_show(Time.now());
            let report = CorrelationReporting.generateInsightsReport(
                requests, responses, decisions, timeWindow, reportId
            );
            
            // Validate PII compliance
            switch (CorrelationReporting.validatePIICompliance(report)) {
                case (#err(msg)) {
                    let errorJob = { job with 
                        status = #Failed; 
                        endTime = ?Time.now();
                        errors = ["PII validation failed: " # msg];
                    };
                    batchJobMap.put(jobId, errorJob);
                    return #err("PII validation failed: " # msg);
                };
                case (#ok()) {};
            };
            
            // Store report with performance tracking
            let endTime = Time.now();
            let generationTime = Int.abs(endTime - startTime) / 1_000_000; // Convert to milliseconds
            
            let perfMetrics : ReportPerformanceMetrics = {
                reportId = reportId;
                generationTimeMs = Nat32.fromNat(Int.abs(generationTime));
                dataPointsProcessed = requests.size() + responses.size() + decisions.size();
                patternsIdentified = patterns.size();
                complianceScore = report.metrics.piiComplianceScore;
                targetMet = Int.abs(generationTime) < 10000; // <10s target
            };
            
            metricsMap.put(reportId, perfMetrics);
            reportStorage.put(reportId, report);
            
            // Update job status
            let completedJob = { job with 
                status = #Completed; 
                endTime = ?endTime;
            };
            batchJobMap.put(jobId, completedJob);
            
            Debug.print("Week 10: Batch processing completed for " # debug_show(requests.size()) # " records");
            Debug.print("Generation time: " # debug_show(generationTime) # "ms (target met: " # debug_show(perfMetrics.targetMet) # ")");
            
            #ok("Batch processed successfully: " # reportId)
            
        } catch (_error) {
            let errorJob = { job with 
                status = #Failed; 
                endTime = ?Time.now();
                errors = ["Processing error occurred"];
            };
            batchJobMap.put(jobId, errorJob);
            #err("Batch processing failed")
        }
    };
    
    // Week 10: Generate weekly summary report
    public func generateWeeklyReport() : async () {
        Debug.print("Week 10: Generating weekly summary report...");
        
        let currentTime = Time.now();
        let weekStart = currentTime - (7 * 24 * 60 * 60 * 1_000_000_000);
        
        // Collect reports from the past week
        var weeklyReports : [AIInsightReport] = [];
        for ((reportId, report) in reportStorage.entries()) {
            if (report.generatedAt >= weekStart) {
                weeklyReports := Array.append(weeklyReports, [report]);
            };
        };
        
        // Generate aggregate summary
        let _weeklySummary = generateWeeklySummary(weeklyReports);
        let summaryReportId = "weekly_" # debug_show(currentTime);
        
        Debug.print("Week 10: Weekly summary generated with " # debug_show(weeklyReports.size()) # " reports");
        Debug.print("Summary ID: " # summaryReportId);
        
        lastWeeklyReport := currentTime;
    };
    
    // Week 10: Query functions for reports and metrics
    public query func getReportMetrics(reportId : Text) : async ?ReportPerformanceMetrics {
        metricsMap.get(reportId)
    };
    
    public query func getBatchJobStatus(jobId : Text) : async ?BatchJobState {
        batchJobMap.get(jobId)
    };
    
    public query func getSystemMetrics() : async {
        totalReports : Nat;
        averageGenerationTime : Float;
        complianceRate : Float;
        targetMetRate : Float;
    } {
        let allMetrics = metricsMap.vals();
        var totalTime : Nat32 = 0;
        var complianceSum : Float = 0.0;
        var targetsMet : Nat = 0;
        var count : Nat = 0;
        
        for (metrics in allMetrics) {
            totalTime += metrics.generationTimeMs;
            complianceSum += metrics.complianceScore;
            if (metrics.targetMet) targetsMet += 1;
            count += 1;
        };
        
        let avgTime = if (count > 0) {
            Float.fromInt(Nat32.toNat(totalTime)) / Float.fromInt(count)
        } else { 0.0 };
        
        let avgCompliance = if (count > 0) {
            complianceSum / Float.fromInt(count)
        } else { 0.0 };
        
        let targetRate = if (count > 0) {
            Float.fromInt(targetsMet) / Float.fromInt(count)
        } else { 0.0 };
        
        {
            totalReports = reportStorage.size();
            averageGenerationTime = avgTime;
            complianceRate = avgCompliance;
            targetMetRate = targetRate;
        }
    };
    
    // Week 10: Configuration management
    public func updateConfig(newConfig : ReportingConfig) : async Result.Result<(), Text> {
        // Validate configuration
        if (newConfig.batchConfig.maxBatchSize == 0 or newConfig.batchConfig.timeoutMs == 0) {
            return #err("Invalid batch configuration");
        };
        
        systemConfig := newConfig;
        
        Debug.print("Week 10: Reporting configuration updated");
        #ok(())
    };
    
    public query func getConfig() : async ReportingConfig {
        systemConfig
    };
    
    // Week 10: Cleanup old reports based on retention policy
    public func cleanupOldReports() : async {
        purgedCount : Nat;
        retainedCount : Nat;
    } {
        if (not systemConfig.retentionPolicyEnabled) {
            return { purgedCount = 0; retainedCount = reportStorage.size() };
        };
        
        let currentTime = Time.now();
        let retentionLimit = currentTime - (2 * 365 * 24 * 60 * 60 * 1_000_000_000); // 2 years
        
        var purgedCount = 0;
        var toRemove : [Text] = [];
        
        for ((reportId, report) in reportStorage.entries()) {
            if (report.generatedAt < retentionLimit) {
                toRemove := Array.append(toRemove, [reportId]);
            };
        };
        
        for (reportId in toRemove.vals()) {
            reportStorage.delete(reportId);
            metricsMap.delete(reportId);
            purgedCount += 1;
        };
        
        Debug.print("Week 10: Cleaned up " # debug_show(purgedCount) # " old reports");
        
        { purgedCount = purgedCount; retainedCount = reportStorage.size() }
    };
    
    // Private helper for weekly summary generation
    private func generateWeeklySummary(reports : [AIInsightReport]) : Text {
        var totalPatterns = 0;
        var totalRecommendations = 0;
        var avgCompliance : Float = 0.0;
        
        for (report in reports.vals()) {
            totalPatterns += report.patterns.size();
            totalRecommendations += report.recommendations.size();
            avgCompliance += report.metrics.piiComplianceScore;
        };
        
        if (reports.size() > 0) {
            avgCompliance := avgCompliance / Float.fromInt(reports.size());
        };
        
        "Weekly Summary: " # debug_show(reports.size()) # " reports, " #
        debug_show(totalPatterns) # " patterns, " #
        debug_show(totalRecommendations) # " recommendations, " #
        debug_show(avgCompliance) # " avg compliance"
    };
}
