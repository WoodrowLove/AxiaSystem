/// 🧠 NamoraAI Central Intelligence Hub
/// 
/// This canister serves as the central nervous system for the entire AxiaSystem,
/// collecting insights from all canisters and providing real-time system intelligence,
/// advanced analytics, predictive monitoring, and intelligent alerting.

import Time "mo:base/Time";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Insight "../types/insight";
import Alert "../types/alert";
import Analytics "../types/analytics";
import IntelligenceEngine "intelligence_engine";
import Memory "memory";
import Reasoning "reasoning";
import Audit "audit";
import Trace "trace";

persistent actor NamoraAI {
  
  /// Stable storage for insights across upgrades
  private var stableInsights : [Insight.SystemInsight] = [];
  
  /// Stable storage for memory system
  private var stableMemoryIndex : Memory.MemoryIndex = {
    idCounter = 1;
    entries = [];
  };
  
  /// Stable storage for reasoning system
  private var stableReasoningState : Reasoning.ReasoningState = {
    idCounter = 1;
    logs = [];
  };
  
  /// Stable storage for audit system
  private var stableAuditState : Audit.AuditState = {
    idCounter = 1;
    logs = [];
  };
  
  /// Stable storage for trace system
  private var stableTraceState : Trace.TraceState = {
    traceLinks = [];
    causalLinks = [];
    traceMetadata = [];
  };
  
  /// Working buffer for efficient insight management
  private transient var insights = Buffer.Buffer<Insight.SystemInsight>(0);
  
  /// Intelligence engine for advanced analytics and alerting
  private transient let intelligenceEngine = IntelligenceEngine.IntelligenceEngine();
  
  /// Memory system for long-term recall and pattern tracking
  private transient let memorySystem = Memory.MemorySystem();
  
  /// Reasoning engine for pattern recognition and correlation analysis
  private transient let reasoningEngine = Reasoning.ReasoningEngine(memorySystem);
  
  /// Audit system for AI accountability and transparent decision logging
  private transient let auditSystem = Audit.AuditSystem();
  
  /// Trace system for cross-canister event linking and causal inference
  private transient let traceEngine = Trace.TraceEngine();
  
  /// Maximum insights to keep in memory (prevents unbounded growth)
  private transient let _MAX_INSIGHTS : Nat = 10000;
  
  /// Initialize from stable storage
  system func preupgrade() {
    stableInsights := Buffer.toArray(insights);
    stableMemoryIndex := memorySystem.getIndex();
    stableReasoningState := reasoningEngine.getState();
    stableAuditState := auditSystem.getState();
    stableTraceState := traceEngine.getState();
  };
  
  system func postupgrade() {
    insights := Buffer.fromArray<Insight.SystemInsight>(stableInsights);
    memorySystem.initialize(stableMemoryIndex);
    reasoningEngine.initialize(stableReasoningState);
    auditSystem.initialize(stableAuditState);
    traceEngine.initialize(stableTraceState);
  };

  // =============================================================================
  // 🔍 AUDIT SYSTEM APIS - Transparent AI Decision Logging & Accountability
  // =============================================================================

  /// Get recent audit entries for transparency and oversight
  public func getRecentAuditEntries(count: Nat): async [Audit.AuditEntry] {
    await auditSystem.getRecent(count)
  };

  /// Get audit entries by category (e.g., "pattern_analysis", "insight_processing")
  public func getAuditByCategory(category: Text): async [Audit.AuditEntry] {
    await auditSystem.getByCategory(category)
  };

  /// Get audit entries by actor/component name
  public func getAuditByActor(actorName: Text): async [Audit.AuditEntry] {
    await auditSystem.getByActor(actorName)
  };

  /// Get audit entries by trace ID
  public func getAuditByTrace(traceId: Text): async [Audit.AuditEntry] {
    await auditSystem.getByTrace(traceId)
  };

  /// Mark an audit entry as reviewed for human oversight
  public func markAuditReviewed(auditId: Nat, reviewedBy: Text): async Bool {
    await auditSystem.markReviewed(auditId, reviewedBy)
  };

  /// Export audit trail as structured text for external analysis
  public func exportAuditTrail(): async Text {
    await auditSystem.exportAuditTrail(null, null)
  };

  /// Get audit statistics for monitoring and reporting
  public func getAuditStatistics(): async {
    total: Nat;
    byCategory: [(Text, Nat)];
    byActor: [(Text, Nat)];
    recentActivity: Nat;
    oldestTimestamp: ?Int;
    newestTimestamp: ?Int;
  } {
    await auditSystem.getAuditStats()
  };

  // =============================================================================
  // 📊 ENHANCED AUDIT CAPABILITIES - Compliance, Forensics, Performance
  // =============================================================================

  /// Generate regulatory compliance report
  public func generateComplianceReport(
    reportType: Text,
    startTimestamp: Int,
    endTimestamp: Int,
    includeCategories: [Text],
    includeActors: [Text],
    minSeverity: Text
  ): async Audit.ComplianceReport {
    Debug.print("MAIN: Generating compliance report - " # reportType);
    
    let config: Audit.ComplianceConfig = {
      reportType = reportType;
      startTimestamp = startTimestamp;
      endTimestamp = endTimestamp;
      includeCategories = includeCategories;
      includeActors = includeActors;
      minSeverity = minSeverity;
    };
    
    let report = await auditSystem.generateComplianceReport(config);
    
    // Log audit activity
    let auditEntry: Audit.AuditEntry = {
      id = 0;
      timestamp = Time.now();
      category = "compliance";
      actorName = "ComplianceManager";
      traceId = ?("compliance_" # reportType # "_" # Int.toText(Time.now()));
      summary = "Compliance report generated: " # reportType # " covering " # 
               Int.toText(endTimestamp - startTimestamp) # "ns period";
      linkedReasoningId = null;
      linkedMemoryIds = [];
      outcome = ?("report_id:" # Nat.toText(report.id) # ",score:" # Float.toText(report.complianceScore));
    };
    let _ = await auditSystem.log(auditEntry);
    
    report
  };

  /// Generate GDPR compliance report
  public func generateGDPRReport(
    startTimestamp: Int,
    endTimestamp: Int
  ): async Audit.ComplianceReport {
    Debug.print("MAIN: Generating GDPR compliance report");
    await generateComplianceReport("gdpr", startTimestamp, endTimestamp, [], [], "info")
  };

  /// Generate SOX compliance report
  public func generateSOXReport(
    startTimestamp: Int,
    endTimestamp: Int
  ): async Audit.ComplianceReport {
    Debug.print("MAIN: Generating SOX compliance report");
    await generateComplianceReport("sox", startTimestamp, endTimestamp, 
                                  ["financial", "payment", "treasury"], [], "warning")
  };

  /// Conduct forensic analysis for security incidents
  public func conductForensicInvestigation(
    incidentId: Text,
    startTimestamp: Int,
    endTimestamp: Int,
    targetTraceIds: [Text],
    targetActors: [Text],
    evidenceCategories: [Text],
    analysisDepth: Text
  ): async Audit.ForensicReport {
    Debug.print("MAIN: Starting forensic investigation - " # incidentId);
    
    let config: Audit.ForensicConfig = {
      incidentId = incidentId;
      startTimestamp = startTimestamp;
      endTimestamp = endTimestamp;
      targetTraceIds = targetTraceIds;
      targetActors = targetActors;
      evidenceCategories = evidenceCategories;
      analysisDepth = analysisDepth;
    };
    
    let forensicReport = await auditSystem.conductForensicAnalysis(config);
    
    // Log forensic activity
    let auditEntry: Audit.AuditEntry = {
      id = 0;
      timestamp = Time.now();
      category = "forensic";
      actorName = "ForensicAnalyzer";
      traceId = ?("forensic_" # incidentId);
      summary = "Forensic investigation completed for incident: " # incidentId # 
               " | Evidence: " # Nat.toText(forensicReport.totalEvidence) # 
               " | Risk: " # forensicReport.riskAssessment;
      linkedReasoningId = null;
      linkedMemoryIds = [];
      outcome = ?("investigation_complete:" # forensicReport.riskAssessment);
    };
    let _ = await auditSystem.log(auditEntry);
    
    forensicReport
  };

  /// Quick security incident analysis
  public func analyzeSecurityIncident(
    incidentId: Text,
    timeWindowHours: Nat
  ): async Audit.ForensicReport {
    Debug.print("MAIN: Quick security incident analysis - " # incidentId);
    let currentTime = Time.now();
    let timeWindow = (timeWindowHours : Int) * 60 * 60_000_000_000; // Convert hours to nanoseconds
    let startTime = currentTime - timeWindow;
    
    await conductForensicInvestigation(
      incidentId,
      startTime,
      currentTime,
      [], // No specific trace IDs
      [], // No specific actors
      ["failure", "security", "error"], // Focus on security-related categories
      "detailed"
    )
  };

  /// Analyze AI performance metrics
  public func analyzeAIPerformance(
    metricType: Text,
    timeWindowHours: Nat,
    benchmarkValue: ?Float,
    categories: [Text],
    actors: [Text]
  ): async Audit.PerformanceMetric {
    Debug.print("MAIN: Analyzing AI performance - " # metricType);
    
    let timeWindow = (timeWindowHours : Int) * 60 * 60_000_000_000; // Convert hours to nanoseconds
    
    let config: Audit.PerformanceConfig = {
      metricType = metricType;
      timeWindow = timeWindow;
      benchmarkValue = benchmarkValue;
      categories = categories;
      actors = actors;
    };
    
    let performanceMetric = await auditSystem.analyzePerformanceMetrics(config);
    
    // Log performance analysis
    let auditEntry: Audit.AuditEntry = {
      id = 0;
      timestamp = Time.now();
      category = "performance";
      actorName = "PerformanceAnalyzer";
      traceId = ?("performance_" # metricType # "_" # Int.toText(Time.now()));
      summary = "Performance analysis completed: " # metricType # 
               " | Score: " # Float.toText(performanceMetric.qualityScore) # 
               " | Trend: " # performanceMetric.trendDirection;
      linkedReasoningId = null;
      linkedMemoryIds = [];
      outcome = ?("quality_score:" # Float.toText(performanceMetric.qualityScore));
    };
    let _ = await auditSystem.log(auditEntry);
    
    performanceMetric
  };

  /// Get comprehensive performance dashboard
  public func getPerformanceDashboard(): async Audit.PerformanceDashboard {
    Debug.print("MAIN: Generating performance dashboard");
    let dashboard = await auditSystem.generatePerformanceDashboard();
    
    // Log dashboard generation
    let auditEntry: Audit.AuditEntry = {
      id = 0;
      timestamp = Time.now();
      category = "performance";
      actorName = "DashboardGenerator";
      traceId = ?("dashboard_" # Int.toText(Time.now()));
      summary = "Performance dashboard generated | Overall Score: " # Float.toText(dashboard.overallScore) # 
               " | Alerts: " # Nat.toText(dashboard.alertsAndWarnings.size());
      linkedReasoningId = null;
      linkedMemoryIds = [];
      outcome = ?("dashboard_generated:score_" # Float.toText(dashboard.overallScore));
    };
    let _ = await auditSystem.log(auditEntry);
    
    dashboard
  };

  /// Quick AI accuracy assessment
  public func getAIAccuracyMetrics(): async Audit.PerformanceMetric {
    Debug.print("MAIN: Quick AI accuracy assessment");
    await analyzeAIPerformance("accuracy", 24, ?90.0, ["reasoning", "action"], ["NamoraAI"])
  };

  /// Quick AI response time assessment
  public func getAIResponseTimeMetrics(): async Audit.PerformanceMetric {
    Debug.print("MAIN: Quick AI response time assessment");
    await analyzeAIPerformance("response_time", 24, ?300.0, [], ["NamoraAI"])
  };

  /// Quick AI decision quality assessment
  public func getAIDecisionQualityMetrics(): async Audit.PerformanceMetric {
    Debug.print("MAIN: Quick AI decision quality assessment");
    await analyzeAIPerformance("decision_quality", 24, ?85.0, ["reasoning"], ["NamoraAI"])
  };

  // =============================================================================
  // 🔥 REAL-TIME STREAMING ANALYSIS APIS - Event-Driven Intelligence
  // =============================================================================

  /// Push insight to system and memory
  public func pushInsight(insight: Insight.SystemInsight): async Bool {
    insights.add(insight);
    
    // Store in reflexive memory system
    let category = switch(insight.source) {
      case ("IntelligenceEngine") { "intelligence" };
      case ("payment") { "financial" };
      case ("user") { "user" };
      case ("treasury") { "treasury" };
      case _ { "general" };
    };
    
    let summary = insight.message;
    let traceId = ?insight.source;
    let data = Text.encodeUtf8(insight.message);
    
    let _ = await memorySystem.remember(category, traceId, summary, data);
    
    // Audit log this insight processing
    let auditEntry: Audit.AuditEntry = {
      id = 0; // Will be set by audit system
      timestamp = Time.now();
      category = "insight_processing";
      actorName = "NamoraAI";
      traceId = traceId;
      summary = "Processed insight from " # insight.source # ": " # insight.message;
      linkedMemoryIds = []; // Memory system doesn't return ID, just success/failure
      linkedReasoningId = null;
      outcome = null;
    };
    let _ = await auditSystem.log(auditEntry);
    
    true
  };

  /// 📤 Returns all recent insights for frontend display
  public query func getRecentInsights() : async [Insight.SystemInsight] {
    Buffer.toArray(insights)
  };

  /// 📊 Returns insights filtered by severity
  public query func getInsightsBySeverity(severity: Text) : async [Insight.SystemInsight] {
    let filtered = Array.filter<Insight.SystemInsight>(
      Buffer.toArray(insights), 
      func(insight: Insight.SystemInsight) : Bool {
        insight.severity == severity
      }
    );
    filtered
  };

  /// 🔍 Returns insights from a specific module
  public query func getInsightsBySource(source: Text) : async [Insight.SystemInsight] {
    let filtered = Array.filter<Insight.SystemInsight>(
      Buffer.toArray(insights), 
      func(insight: Insight.SystemInsight) : Bool {
        insight.source == source
      }
    );
    filtered
  };

  /// ⏰ Returns insights within a time range (timestamps in nanoseconds)
  public query func getInsightsInTimeRange(startTime: Int, endTime: Int) : async [Insight.SystemInsight] {
    let filtered = Array.filter<Insight.SystemInsight>(
      Buffer.toArray(insights), 
      func(insight: Insight.SystemInsight) : Bool {
        insight.timestamp >= startTime and insight.timestamp <= endTime
      }
    );
    filtered
  };

  /// 📈 Returns system health summary
  public query func getSystemHealthSummary() : async {
    totalInsights: Nat;
    errorCount: Nat;
    warningCount: Nat;
    infoCount: Nat;
    lastInsightTime: ?Int;
    activeModules: [Text];
  } {
    let insightArray = Buffer.toArray(insights);
    var errorCount = 0;
    var warningCount = 0;
    var infoCount = 0;
    var lastTime : ?Int = null;
    let moduleBuffer = Buffer.Buffer<Text>(0);
    
    for (insight in insightArray.vals()) {
      switch (insight.severity) {
        case ("error") { errorCount += 1; };
        case ("warning") { warningCount += 1; };
        case ("info") { infoCount += 1; };
        case (_) { /* unknown severity */ };
      };
      
      // Track latest timestamp
      switch (lastTime) {
        case (null) { lastTime := ?insight.timestamp; };
        case (?t) { 
          if (insight.timestamp > t) {
            lastTime := ?insight.timestamp;
          };
        };
      };
      
      // Track unique modules
      let moduleArray = Buffer.toArray(moduleBuffer);
      var found = false;
      for (mod in moduleArray.vals()) {
        if (mod == insight.source) {
          found := true;
        };
      };
      if (not found) {
        moduleBuffer.add(insight.source);
      };
    };
    
    {
      totalInsights = insightArray.size();
      errorCount = errorCount;
      warningCount = warningCount;
      infoCount = infoCount;
      lastInsightTime = lastTime;
      activeModules = Buffer.toArray(moduleBuffer);
    }
  };

  /// 🧹 Clears all insights (admin function)
  public shared func clearAllInsights() : async () {
    insights.clear();
  };

  /// 📋 Returns the current insight buffer size
  public query func getInsightCount() : async Nat {
    insights.size()
  };

  /// 🎯 Emits a system insight from NamoraAI itself
  public func emitSelfInsight(severity: Text, message: Text) : async () {
    let selfInsight : Insight.SystemInsight = {
      source = "namora_ai";
      severity = severity;
      message = message;
      timestamp = Time.now();
    };
    let _ = await pushInsight(selfInsight);
  };

  /// ⚡ Enhanced analysis with memory-driven insights and pattern recognition
  public func analyzeWithMemoryAndReasoning(insights: [Insight.SystemInsight]): async {
    healthAnalysis: Analytics.SystemHealth;
    patternAnalysis: Reasoning.ReasoningOutput;
    memoryStats: Memory.MemoryStats;
  } {
    // Get baseline health analysis
    let healthAnalysis = await intelligenceEngine.generateHealthAssessment(insights);
    
    // Get pattern recognition analysis
    let patternAnalysis = await reasoningEngine.analyze({
      since = ?(Time.now() - 3_600_000_000_000); // Last hour
      max = ?200;
    });
    
    // Get memory statistics for context
    let memoryStats = await memorySystem.summarize();
    
    // Get relevant memories for context (future enhancement)
    let _recentMemories = await memorySystem.getLastN(100);
    let _systemMemories = await memorySystem.recallByCategory("general");
    
    // Store comprehensive analysis in memory for future reflexive learning
    let analysisData = Text.encodeUtf8(
      "COMPREHENSIVE ANALYSIS - Health: " # Float.toText(healthAnalysis.overallScore) # 
      " | Pattern: " # patternAnalysis.title # " (" # patternAnalysis.severity # ")" #
      " | Memory Entries: " # Nat.toText(memoryStats.total) #
      " | Critical Issues: " # Nat.toText(Array.size(healthAnalysis.criticalIssues)) #
      " | Recommendations: " # Nat.toText(Array.size(healthAnalysis.recommendations))
    );
    
    let _ = await memorySystem.remember(
      "comprehensive_analysis", 
      ?("analysis_" # Int.toText(Time.now())), 
      "Comprehensive system analysis with health, patterns, and memory context",
      analysisData
    );
    
    {
      healthAnalysis = healthAnalysis;
      patternAnalysis = patternAnalysis;
      memoryStats = memoryStats;
    }
  };

  /// 🔬 Memory System APIs
  
  /// Recall all memories (reflexive awareness)
  public func recallAllMemories(): async [Memory.MemoryEntry] {
    await memorySystem.recallAll()
  };
  
  /// Recall memories by category (focused recall)
  public func recallMemoriesByCategory(category: Text): async [Memory.MemoryEntry] {
    await memorySystem.recallByCategory(category)
  };
  
  /// Recall memories by trace ID (contextual awareness)
  public func recallMemoriesByTrace(traceId: Text): async [Memory.MemoryEntry] {
    await memorySystem.recallByTrace(traceId)
  };
  
  /// Get recent memories (working memory)
  public func getRecentMemories(count: Nat): async [Memory.MemoryEntry] {
    await memorySystem.getLastN(count)
  };
  
  /// Get memory summary (self-awareness)
  public func getMemorySummary(): async Memory.MemoryStats {
    await memorySystem.summarize()
  };
  
  /// Get pattern analysis data (pattern recognition)
  public func getMemoryPatterns(): async [(Text, [Memory.MemoryEntry])] {
    await memorySystem.getPatternData()
  };

  /// Advanced pattern analysis with reflexive learning insights
  public func getAdvancedPatternAnalysis(): async [Memory.PatternAnalysis] {
    await memorySystem.analyzePatterns()
  };

  /// Get memory access analytics for performance optimization
  public func getMemoryAccessAnalytics(): async [(Text, Nat, Float)] {
    await memorySystem.getAccessAnalytics()
  };

  /// Compress old memories to optimize storage
  public func compressOldMemories(olderThanHours: Nat): async Nat {
    await memorySystem.compressOldMemories(olderThanHours)
  };

  /// 🧩 Reasoning System APIs - Pattern Recognition & Correlation Analysis
  
  /// Analyze system patterns and detect anomalies
  public func analyzeSystemPatterns(input: ?Reasoning.ReasoningInput): async Reasoning.ReasoningOutput {
    let defaultInput: Reasoning.ReasoningInput = {
      since = null;
      max = ?500;
    };
    
    let reasoningInput = switch (input) {
      case (?inp) inp;
      case null defaultInput;
    };
    
    let result = await reasoningEngine.analyze(reasoningInput);
    
    // Store reasoning result in memory for future reference
    let _ = await memorySystem.remember(
      "reasoning",
      ?("reasoning_" # Nat.toText(result.id)),
      result.title # " - " # result.severity,
      Text.encodeUtf8(result.description)
    );
    
    // Audit log this reasoning analysis
    let auditEntry: Audit.AuditEntry = {
      id = 0; // Will be set by audit system
      timestamp = Time.now();
      category = "pattern_analysis";
      actorName = "ReasoningEngine";
      traceId = ?("reasoning_" # Nat.toText(result.id));
      summary = "Analyzed system patterns: " # result.title # " (severity: " # result.severity # ")";
      linkedMemoryIds = []; // Memory system doesn't return ID, just success/failure
      linkedReasoningId = ?result.id;
      outcome = null;
    };
    let _ = await auditSystem.log(auditEntry);
    
    result
  };
  
  /// Get all reasoning analysis results
  public func getAllReasoningResults(): async [Reasoning.ReasoningOutput] {
    await reasoningEngine.getAllReasoning()
  };
  
  /// Get reasoning results by tag (e.g., "wallet", "escrow", "governance")
  public func getReasoningByTag(tag: Text): async [Reasoning.ReasoningOutput] {
    await reasoningEngine.getByTag(tag)
  };
  
  /// Get reasoning results by severity ("critical", "warning", "info")
  public func getReasoningBySeverity(severity: Text): async [Reasoning.ReasoningOutput] {
    await reasoningEngine.getBySeverity(severity)
  };
  
  /// Get recent reasoning results
  public func getRecentReasoningResults(count: Nat): async [Reasoning.ReasoningOutput] {
    await reasoningEngine.getRecent(count)
  };

  /// 🔄 Scheduled system analysis (for heartbeat/cron integration)
  public func runScheduledAnalysis(): async {
    insights: [Insight.SystemInsight];
    reasoning: Reasoning.ReasoningOutput;
    memorySummary: Memory.MemoryStats;
  } {
    // Get recent insights for analysis
    let recentInsights = Buffer.toArray(insights);
    
    // Run pattern analysis on recent memory
    let reasoning = await analyzeSystemPatterns(null);
    
    // Get memory summary
    let memorySummary = await memorySystem.summarize();
    
    // Store scheduled analysis result
    let analysisInsight: Insight.SystemInsight = {
      source = "namora_ai_scheduler";
      severity = "info";
      message = "Scheduled analysis completed - " # reasoning.title # " | Memory: " # Nat.toText(memorySummary.total) # " entries";
      timestamp = Time.now();
    };
    let _ = await pushInsight(analysisInsight);
    
    {
      insights = recentInsights;
      reasoning = reasoning;
      memorySummary = memorySummary;
    }
  };

  /// 🚨 Get intelligent alerts from AI analysis
  public func getSmartAlerts() : async [Alert.SmartAlert] {
    await intelligenceEngine.getRecentAlerts()
  };

  /// 🚨 Get alerts by severity level
  public func getAlertsBySeverity(severity: Alert.AlertSeverity) : async [Alert.SmartAlert] {
    await intelligenceEngine.getAlertsBySeverity(severity)
  };

  /// ✅ Mark an alert as resolved
  public shared({ caller }) func resolveAlert(alertId: Nat, notes: Text) : async Bool {
    await intelligenceEngine.resolveAlert(alertId, caller, notes)
  };

  /// 📊 Generate comprehensive system health assessment
  public func getSystemHealth() : async Analytics.SystemHealth {
    let allInsights = Buffer.toArray(insights);
    await intelligenceEngine.generateHealthAssessment(allInsights)
  };

  /// 🔍 Run AI analysis and generate new alerts
  public func runIntelligenceAnalysis() : async [Alert.SmartAlert] {
    let allInsights = Buffer.toArray(insights);
    await intelligenceEngine.processInsights(allInsights)
  };

  /// 🧠 ADVANCED PATTERN DETECTION APIS - Next-Generation AI Analysis
  
  /// Run comprehensive pattern analysis with all advanced detectors
  public func runAdvancedPatternAnalysis(): async [Reasoning.ReasoningOutput] {
    let reasoningInput: Reasoning.ReasoningInput = {
      since = ?(Time.now() - (24 * 60 * 60_000_000_000)); // Last 24 hours
      max = ?1000; // Analyze up to 1000 recent entries
    };
    
    let analysisResult = await reasoningEngine.analyze(reasoningInput);
    
    // Audit log this advanced analysis
    let auditEntry: Audit.AuditEntry = {
      id = 0;
      timestamp = Time.now();
      category = "advanced_analysis";
      actorName = "AdvancedReasoningEngine";
      traceId = ?("advanced_analysis_" # Int.toText(Time.now()));
      summary = "Advanced pattern analysis completed: " # analysisResult.title # " (severity: " # analysisResult.severity # ")";
      linkedMemoryIds = [];
      linkedReasoningId = ?analysisResult.id;
      outcome = null;
    };
    let _ = await auditSystem.log(auditEntry);
    
    [analysisResult]
  };

  /// Get pattern analysis results filtered by advanced detection types
  public func getAdvancedPatternsByType(patternType: Text): async [Reasoning.ReasoningOutput] {
    let validTypes = ["anomaly", "prediction", "behavior", "cascade"];
    if (Array.find<Text>(validTypes, func(t) = t == patternType) != null) {
      await reasoningEngine.getByTag(patternType)
    } else {
      []
    }
  };

  /// Get system health insights from advanced pattern analysis
  public func getAdvancedSystemHealth(): async {
    overallStatus: Text;
    anomalyCount: Nat;
    predictionCount: Nat;
    behaviorAnomalies: Nat;
    cascadeRisk: Text;
    lastAnalysis: Int;
  } {
    let recentReasoning = await reasoningEngine.getRecent(50);
    
    let anomalies = Array.filter<Reasoning.ReasoningOutput>(recentReasoning, func(r) = 
      Array.find<Text>(r.tags, func(t) = t == "anomaly") != null or
      Array.find<Text>(r.tags, func(t) = t == "statistical") != null
    );
    
    let predictions = Array.filter<Reasoning.ReasoningOutput>(recentReasoning, func(r) = 
      Array.find<Text>(r.tags, func(t) = t == "prediction") != null or
      Array.find<Text>(r.tags, func(t) = t == "trend") != null
    );
    
    let behaviorAnomalies = Array.filter<Reasoning.ReasoningOutput>(recentReasoning, func(r) = 
      Array.find<Text>(r.tags, func(t) = t == "behavior") != null
    );
    
    let cascades = Array.filter<Reasoning.ReasoningOutput>(recentReasoning, func(r) = 
      Array.find<Text>(r.tags, func(t) = t == "cascade") != null
    );
    
    let criticalIssues = Array.filter<Reasoning.ReasoningOutput>(recentReasoning, func(r) = r.severity == "critical");
    
    let overallStatus = if (criticalIssues.size() > 0) {
      "critical"
    } else if (anomalies.size() > 3 or cascades.size() > 0) {
      "warning"
    } else {
      "healthy"
    };
    
    let cascadeRisk = if (cascades.size() > 0) {
      "high"
    } else if (anomalies.size() > 2) {
      "medium"
    } else {
      "low"
    };
    
    {
      overallStatus = overallStatus;
      anomalyCount = anomalies.size();
      predictionCount = predictions.size();
      behaviorAnomalies = behaviorAnomalies.size();
      cascadeRisk = cascadeRisk;
      lastAnalysis = Time.now();
    }
  };

  /// Enable real-time streaming analysis with automatic triggers
  public func enableStreamingAnalysis(): async Bool {
    Debug.print("MAIN: Enabling streaming analysis");
    await reasoningEngine.enableStreamingAnalysis()
  };

  /// Disable real-time streaming analysis
  public func disableStreamingAnalysis(): async Bool {
    Debug.print("MAIN: Disabling streaming analysis");
    await reasoningEngine.disableStreamingAnalysis()
  };

  /// Process real-time event and get immediate alerts
  public func processRealtimeEvent(
    summary: Text,
    category: Text,
    details: Text,
    metadata: [(Text, Text)]
  ): async [Reasoning.RealtimeAlert] {
    Debug.print("MAIN: Processing real-time event: " # category);
    
    // Create memory entry first
    let entry = await memorySystem.createMemoryEntry(summary, category, details, metadata);
    
    // Process for real-time alerts
    let alerts = await reasoningEngine.processRealtimeEvent(entry);
    
    // Log to audit system
    if (alerts.size() > 0) {
      let auditEntry: Audit.AuditEntry = {
        id = 0;
        timestamp = Time.now();
        category = "realtime_processing";
        actorName = "StreamingReasoningEngine";
        traceId = ?("realtime_" # Int.toText(Time.now()));
        summary = "Real-time event processed: " # category # " - Generated " # Nat.toText(alerts.size()) # " alerts";
        linkedMemoryIds = [entry.id];
        linkedReasoningId = null;
        outcome = ?("alerts_generated:" # Nat.toText(alerts.size()));
      };
      let _ = await auditSystem.log(auditEntry);
    };
    
    alerts
  };

  /// Run sliding window analysis for continuous monitoring
  public func runSlidingWindowAnalysis(): async [Reasoning.RealtimeAlert] {
    Debug.print("MAIN: Running sliding window analysis");
    let alerts = await reasoningEngine.runSlidingWindowAnalysis();
    
    // Log significant sliding window events
    if (alerts.size() > 0) {
      let auditEntry: Audit.AuditEntry = {
        id = 0;
        timestamp = Time.now();
        category = "sliding_window_analysis";
        actorName = "StreamingReasoningEngine";
        traceId = ?("sliding_window_" # Int.toText(Time.now()));
        summary = "Sliding window analysis completed - Generated " # Nat.toText(alerts.size()) # " threshold alerts";
        linkedMemoryIds = [];
        linkedReasoningId = null;
        outcome = ?("threshold_alerts:" # Nat.toText(alerts.size()));
      };
      let _ = await auditSystem.log(auditEntry);
    };
    
    alerts
  };

  /// Get current real-time alerts with filtering
  public func getCurrentRealtimeAlerts(): async [Reasoning.RealtimeAlert] {
    await reasoningEngine.getCurrentRealtimeAlerts()
  };

  /// Get active (unacknowledged) real-time alerts
  public func getActiveRealtimeAlerts(): async [Reasoning.RealtimeAlert] {
    let allAlerts = await reasoningEngine.getCurrentRealtimeAlerts();
    Array.filter<Reasoning.RealtimeAlert>(allAlerts, func(alert) = not alert.acknowledged)
  };

  /// Get critical real-time alerts requiring immediate attention
  public func getCriticalRealtimeAlerts(): async [Reasoning.RealtimeAlert] {
    let allAlerts = await reasoningEngine.getCurrentRealtimeAlerts();
    Array.filter<Reasoning.RealtimeAlert>(allAlerts, func(alert) = alert.severity == "critical")
  };

  /// Acknowledge real-time alert to mark as reviewed
  public func acknowledgeRealtimeAlert(alertId: Nat): async Bool {
    Debug.print("MAIN: Acknowledging alert: " # Nat.toText(alertId));
    let result = await reasoningEngine.acknowledgeRealtimeAlert(alertId);
    
    if (result) {
      let auditEntry: Audit.AuditEntry = {
        id = 0;
        timestamp = Time.now();
        category = "alert_management";
        actorName = "StreamingManager";
        traceId = ?("alert_ack_" # Nat.toText(alertId));
        summary = "Real-time alert acknowledged: " # Nat.toText(alertId);
        linkedMemoryIds = [];
        linkedReasoningId = null;
        outcome = ?("acknowledged");
      };
      let _ = await auditSystem.log(auditEntry);
    };
    
    result
  };

  /// Get comprehensive streaming analysis status
  public func getStreamingStatus(): async {
    enabled: Bool;
    totalAlerts: Nat;
    activeAlerts: Nat;
    criticalAlerts: Nat;
    lastProcessingTime: Int;
    eventQueueSize: Nat;
    slidingWindowCount: Nat;
    triggersEnabled: Nat;
  } {
    let baseStatus = await reasoningEngine.getStreamingStatus();
    {
      enabled = baseStatus.enabled;
      totalAlerts = baseStatus.totalAlerts;
      activeAlerts = baseStatus.activeAlerts;
      criticalAlerts = baseStatus.criticalAlerts;
      lastProcessingTime = baseStatus.lastProcessingTime;
      eventQueueSize = baseStatus.eventQueueSize;
      slidingWindowCount = 2;
      triggersEnabled = 3;
    }
  };

  // =============================================================================
  // 🧩 TRACE NORMALIZATION SYSTEM - Cross-Canister Event Linking
  // =============================================================================

  /// Register a new trace link connecting an entry to a trace
  public func registerTraceLink(link: Trace.TraceLink): async Bool {
    Debug.print("MAIN: Registering trace link for " # link.traceId);
    await traceEngine.registerTraceLink(link)
  };

  /// Register multiple trace links in batch
  public func registerTraceLinks(links: [Trace.TraceLink]): async Nat {
    Debug.print("MAIN: Batch registering " # Nat.toText(links.size()) # " trace links");
    await traceEngine.registerTraceLinks(links)
  };

  /// Get all links for a specific trace
  public func getTrace(traceId: Text): async [Trace.TraceLink] {
    await traceEngine.getTrace(traceId)
  };

  /// Generate a comprehensive summary of a trace
  public func summarizeTrace(traceId: Text): async Trace.TraceSummary {
    await traceEngine.summarize(traceId)
  };

  /// Get all trace IDs involving a specific principal
  public func getTracesByPrincipal(principal: Principal): async [Text] {
    await traceEngine.getTracesByPrincipal(principal)
  };

  /// Get all trace IDs containing a specific tag
  public func getTracesByTag(tag: Text): async [Text] {
    await traceEngine.getTracesByTag(tag)
  };

  /// Get all trace IDs from a specific source module
  public func getTracesBySource(source: Text): async [Text] {
    await traceEngine.getTracesBySource(source)
  };

  /// Get traces within a time range
  public func getTracesByTimeRange(startTime: Int, endTime: Int): async [Text] {
    await traceEngine.getTracesByTimeRange(startTime, endTime)
  };

  /// Generate a timeline view of a trace for visualization
  public func getTraceTimeline(traceId: Text): async [Trace.TraceTimelineEvent] {
    await traceEngine.getTraceTimeline(traceId)
  };

  /// Get comprehensive analytics across all traces
  public func getTraceAnalytics(): async Trace.TraceAnalytics {
    await traceEngine.getTraceAnalytics()
  };

  /// Search traces by multiple criteria
  public func searchTraces(
    sources: ?[Text],
    tags: ?[Text],
    principals: ?[Principal],
    timeRange: ?(Int, Int),
    entryTypes: ?[Text]
  ): async [Text] {
    await traceEngine.searchTraces(sources, tags, principals, timeRange, entryTypes)
  };

  /// Get causal relationships for a specific trace
  public func getTraceCausalLinks(traceId: Text): async [Trace.CausalLink] {
    await traceEngine.getTraceCausalLinks(traceId)
  };

  /// Register a causal relationship between two entries
  public func registerCausalLink(causal: Trace.CausalLink): async Bool {
    Debug.print("MAIN: Registering causal link for trace " # causal.traceId);
    await traceEngine.registerCausalLink(causal)
  };

  /// Clear all trace data (admin function)
  public func clearAllTraces(): async Bool {
    Debug.print("MAIN: Clearing all trace data");
    await traceEngine.clearAllTraces()
  };

  /// Prune old trace links before a specific timestamp
  public func pruneTracesBefore(timestamp: Int): async Nat {
    Debug.print("MAIN: Pruning traces before " # Int.toText(timestamp));
    await traceEngine.pruneTracesBefore(timestamp)
  };

  /// Get trace system statistics
  public func getTraceStats(): async {
    totalLinks: Nat;
    totalCausalLinks: Nat;
    uniqueTraces: Nat;
    indexedPrincipals: Nat;
    indexedTags: Nat;
    indexedSources: Nat;
    cacheSize: Nat;
  } {
    await traceEngine.getTraceStats()
  };

  // =============================================================================
  // 🔗 ENHANCED MEMORY AND REASONING WITH TRACE INTEGRATION
  // =============================================================================

  /// Enhanced memory creation with automatic trace linking
  public func createTracedMemoryEntry(
    summary: Text,
    category: Text,
    details: Text,
    metadata: [(Text, Text)],
    traceId: ?Text,
    tags: [Text]
  ): async Memory.MemoryEntry {
    Debug.print("MAIN: Creating traced memory entry");
    
    // Create the memory entry
    let entry = await memorySystem.createMemoryEntry(summary, category, details, metadata);
    
    // Register trace link if traceId provided
    switch (traceId) {
      case (?tId) {
        let traceLink: Trace.TraceLink = {
          traceId = tId;
          entryId = entry.id;
          entryType = "memory";
          timestamp = entry.timestamp;
          source = category;
          principal = null; // Could be extracted from metadata if needed
          tags = tags;
          metadata = metadata;
        };
        let _ = await traceEngine.registerTraceLink(traceLink);
      };
      case null {};
    };
    
    entry
  };

  /// Enhanced reasoning analysis with trace linking
  public func analyzeSystemPatternsWithTrace(
    input: ?Reasoning.ReasoningInput,
    traceId: ?Text,
    tags: [Text]
  ): async Reasoning.ReasoningOutput {
    Debug.print("MAIN: Running traced pattern analysis");
    
    // Run the analysis
    let result = await analyzeSystemPatterns(input);
    
    // Register trace link if traceId provided
    switch (traceId) {
      case (?tId) {
        let traceLink: Trace.TraceLink = {
          traceId = tId;
          entryId = result.id;
          entryType = "reasoning";
          timestamp = result.timestamp;
          source = "reasoning_engine";
          principal = null;
          tags = Array.append<Text>(tags, result.tags);
          metadata = [("severity", result.severity), ("title", result.title)];
        };
        let _ = await traceEngine.registerTraceLink(traceLink);
      };
      case null {};
    };
    
    result
  };

  /// Enhanced audit logging with trace linking
  public func logAuditEntryWithTrace(
    entry: Audit.AuditEntry,
    traceId: ?Text,
    tags: [Text]
  ): async Bool {
    Debug.print("MAIN: Logging traced audit entry");
    
    // Log the audit entry
    let success = await auditSystem.log(entry);
    
    // Register trace link if successful and traceId provided
    if (success) {
      switch (traceId) {
        case (?tId) {
          let traceLink: Trace.TraceLink = {
            traceId = tId;
            entryId = entry.id;
            entryType = "audit";
            timestamp = entry.timestamp;
            source = entry.actorName;
            principal = null;
            tags = Array.append<Text>(tags, [entry.category]);
            metadata = [("category", entry.category), ("summary", entry.summary)];
          };
          let _ = await traceEngine.registerTraceLink(traceLink);
        };
        case null {};
      };
    };
    
    success
  };

  /// Get comprehensive trace story with all linked entries
  public func getTraceStory(traceId: Text): async {
    summary: Trace.TraceSummary;
    timeline: [Trace.TraceTimelineEvent];
    memoryEntries: [Memory.MemoryEntry];
    auditEntries: [Audit.AuditEntry];
    reasoningResults: [Reasoning.ReasoningOutput];
    causalLinks: [Trace.CausalLink];
  } {
    Debug.print("MAIN: Generating comprehensive trace story for " # traceId);
    
    // Get trace summary and timeline
    let summary = await traceEngine.summarize(traceId);
    let timeline = await traceEngine.getTraceTimeline(traceId);
    let causalLinks = await traceEngine.getTraceCausalLinks(traceId);
    
    // Get all links for this trace
    let traceLinks = await traceEngine.getTrace(traceId);
    
    // Separate links by entry type and collect related entries
    let _memoryIds = Array.mapFilter<Trace.TraceLink, Nat>(traceLinks, func(link) = 
      if (link.entryType == "memory") ?link.entryId else null
    );
    let _auditIds = Array.mapFilter<Trace.TraceLink, Nat>(traceLinks, func(link) = 
      if (link.entryType == "audit") ?link.entryId else null
    );
    let _reasoningIds = Array.mapFilter<Trace.TraceLink, Nat>(traceLinks, func(link) = 
      if (link.entryType == "reasoning") ?link.entryId else null
    );
    
    // For now, return empty arrays for actual entries (would need additional API methods)
    let memoryEntries: [Memory.MemoryEntry] = [];
    let auditEntries: [Audit.AuditEntry] = [];
    let reasoningResults: [Reasoning.ReasoningOutput] = [];
    
    {
      summary = summary;
      timeline = timeline;
      memoryEntries = memoryEntries;
      auditEntries = auditEntries;
      reasoningResults = reasoningResults;
      causalLinks = causalLinks;
    }
  };
}
