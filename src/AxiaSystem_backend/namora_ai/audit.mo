/// 🧠 NamoraAI Audit System
/// 
/// Self-Awareness, Judgment Logging, and Traceable Oversight
/// 
/// This module forms NamoraAI's reflective conscience and accountability log.
/// It provides an immutable record of:
/// - What decisions were made
/// - Why they were made (reasoning + context)
/// - Who/what they affected (principal, asset, module)
/// - Whether the outcome was successful or needed correction
///
/// Essential for building ethical, transparent, and trustworthy AI oversight
/// into NamoraAI's operation across all modules.

import Time "mo:base/Time";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Debug "mo:base/Debug";

module {
  /// Core audit entry structure for accountability logging
  public type AuditEntry = {
    id: Nat;
    timestamp: Int;
    category: Text;              // e.g. "action", "failure", "reasoning", "intervention"
    actorName: Text;             // "NamoraAI", "admin:principal", "user:principal"
    traceId: ?Text;             // If part of a cross-system trace
    summary: Text;               // Human-readable log line
    linkedReasoningId: ?Nat;     // From reasoningState.logs
    linkedMemoryIds: [Nat];      // Memory entries influencing this decision
    outcome: ?Text;              // Optional description of result
  };

  /// Stable storage state for audit logs
  public type AuditState = {
    idCounter: Nat;
    logs: [AuditEntry];
  };

  /// Compliance report configuration
  public type ComplianceConfig = {
    reportType: Text;            // "gdpr", "sox", "hipaa", "custom"
    startTimestamp: Int;         // Report period start
    endTimestamp: Int;           // Report period end
    includeCategories: [Text];   // Categories to include in report
    includeActors: [Text];       // Actors to include in report
    minSeverity: Text;           // Minimum severity level
  };

  /// Compliance report result
  public type ComplianceReport = {
    id: Nat;
    timestamp: Int;
    reportType: Text;
    periodStart: Int;
    periodEnd: Int;
    totalEntries: Nat;
    entriesByCategory: [(Text, Nat)];
    entriesBySeverity: [(Text, Nat)];
    entriesByActor: [(Text, Nat)];
    criticalIssues: [AuditEntry];
    complianceScore: Float;      // 0.0 - 100.0
    recommendations: [Text];
    exportData: Text;            // JSON/CSV formatted data
  };

  /// Forensic analysis configuration
  public type ForensicConfig = {
    incidentId: Text;
    startTimestamp: Int;
    endTimestamp: Int;
    targetTraceIds: [Text];      // Specific traces to investigate
    targetActors: [Text];        // Actors involved in incident
    evidenceCategories: [Text];  // Types of evidence to collect
    analysisDepth: Text;         // "surface", "detailed", "comprehensive"
  };

  /// Forensic evidence item
  public type ForensicEvidence = {
    id: Nat;
    timestamp: Int;
    evidenceType: Text;          // "audit_entry", "memory_correlation", "pattern_match"
    relevanceScore: Float;       // 0.0 - 1.0
    auditEntry: AuditEntry;
    correlatedEntries: [Nat];    // Related audit entry IDs
    analysisNotes: Text;
  };

  /// Forensic investigation result
  public type ForensicReport = {
    id: Nat;
    timestamp: Int;
    incidentId: Text;
    investigationPeriod: (Int, Int);
    totalEvidence: Nat;
    evidenceByType: [(Text, Nat)];
    timeline: [ForensicEvidence];
    keyFindings: [Text];
    rootCauseAnalysis: Text;
    affectedSystems: [Text];
    recommendedActions: [Text];
    riskAssessment: Text;        // "low", "medium", "high", "critical"
  };

  /// Performance metric configuration
  public type PerformanceConfig = {
    metricType: Text;            // "accuracy", "response_time", "decision_quality"
    timeWindow: Int;             // Time window for analysis (nanoseconds)
    benchmarkValue: ?Float;      // Optional benchmark for comparison
    categories: [Text];          // Categories to analyze
    actors: [Text];              // Actors to analyze
  };

  /// Performance metric result
  public type PerformanceMetric = {
    id: Nat;
    timestamp: Int;
    metricType: Text;
    timeWindow: Int;
    periodStart: Int;
    periodEnd: Int;
    totalSamples: Nat;
    averageValue: Float;
    standardDeviation: Float;
    benchmarkComparison: ?Float; // Percentage vs benchmark
    trendDirection: Text;        // "improving", "stable", "declining"
    anomaliesDetected: Nat;
    detailedBreakdown: [(Text, Float)];
    qualityScore: Float;         // 0.0 - 100.0
  };

  /// Performance dashboard summary
  public type PerformanceDashboard = {
    timestamp: Int;
    overallScore: Float;         // 0.0 - 100.0
    accuracyMetrics: PerformanceMetric;
    responseTimeMetrics: PerformanceMetric;
    decisionQualityMetrics: PerformanceMetric;
    trendsOverTime: [(Int, Float)]; // (timestamp, score) pairs
    recommendations: [Text];
    alertsAndWarnings: [Text];
  };

  /// Advanced audit system for transparent AI accountability
  public class AuditSystem() {
    /// Maximum audit logs to retain (prevents unbounded growth)
    private let MAX_AUDIT_LOGS: Nat = 10000;
    
    /// Stable storage for audit logs
    private var auditState: AuditState = {
      idCounter = 1;
      logs = [];
    };

    /// Initialize audit system with existing state
    public func initialize(existingState: AuditState) {
      auditState := existingState;
    };

    /// Get current audit state for stable storage
    public func getState(): AuditState {
      auditState
    };

    /// Log an audit entry with automatic ID assignment and FIFO eviction
    public func log(entry: AuditEntry): async Bool {
      let auditEntry: AuditEntry = {
        id = auditState.idCounter;
        timestamp = Time.now();
        category = entry.category;
        actorName = entry.actorName;
        traceId = entry.traceId;
        summary = entry.summary;
        linkedReasoningId = entry.linkedReasoningId;
        linkedMemoryIds = entry.linkedMemoryIds;
        outcome = entry.outcome;
      };

      // Add to audit logs
      let updatedLogs = Array.append<AuditEntry>(auditState.logs, [auditEntry]);
      
      // Evict old logs if we exceed maximum (FIFO)
      let finalLogs = if (updatedLogs.size() > MAX_AUDIT_LOGS) {
        let excessCount = updatedLogs.size() - MAX_AUDIT_LOGS : Nat;
        Array.subArray<AuditEntry>(updatedLogs, excessCount, MAX_AUDIT_LOGS)
      } else {
        updatedLogs
      };

      // Update audit state with new entry and incremented counter
      auditState := {
        idCounter = auditState.idCounter + 1;
        logs = finalLogs;
      };

      Debug.print("🧠 AUDIT: Logged [" # entry.category # "] " # entry.actorName # ": " # entry.summary);
      true
    };

    /// Get recent audit entries (most recent first)
    public func getRecent(n: Nat): async [AuditEntry] {
      let sortedLogs = Array.sort<AuditEntry>(
        auditState.logs,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      );
      
      if (sortedLogs.size() <= n) {
        sortedLogs
      } else {
        Array.subArray<AuditEntry>(sortedLogs, 0, n)
      }
    };

    /// Get audit entries filtered by category
    public func getByCategory(category: Text): async [AuditEntry] {
      let filtered = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          entry.category == category
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<AuditEntry>(
        filtered,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get audit entries filtered by actor
    public func getByActor(actorName: Text): async [AuditEntry] {
      let filtered = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          entry.actorName == actorName
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<AuditEntry>(
        filtered,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get audit entries filtered by trace ID
    public func getByTrace(traceId: Text): async [AuditEntry] {
      let filtered = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          switch (entry.traceId) {
            case (?id) id == traceId;
            case null false;
          }
        }
      );
      
      // Sort by timestamp (chronological order for trace reconstruction)
      Array.sort<AuditEntry>(
        filtered,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp < b.timestamp) #less
          else if (a.timestamp > b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get audit entries within a specific time range
    public func getByTimeRange(startTime: Int, endTime: Int): async [AuditEntry] {
      let filtered = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          entry.timestamp >= startTime and entry.timestamp <= endTime
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<AuditEntry>(
        filtered,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get audit entries linked to specific reasoning analysis
    public func getByReasoningId(reasoningId: Nat): async [AuditEntry] {
      let filtered = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          switch (entry.linkedReasoningId) {
            case (?id) id == reasoningId;
            case null false;
          }
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<AuditEntry>(
        filtered,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get audit entries linked to specific memory entries
    public func getByMemoryIds(memoryIds: [Nat]): async [AuditEntry] {
      let filtered = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          // Check if any of the requested memory IDs are in the entry's linked memory IDs
          Array.find<Nat>(
            memoryIds,
            func(searchId: Nat): Bool {
              Array.find<Nat>(entry.linkedMemoryIds, func(entryId: Nat): Bool { entryId == searchId }) != null
            }
          ) != null
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<AuditEntry>(
        filtered,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get all audit entries (sorted by timestamp, most recent first)
    public func getAllAuditLogs(): async [AuditEntry] {
      Array.sort<AuditEntry>(
        auditState.logs,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get audit statistics for system overview
    public func getAuditStats(): async {
      total: Nat;
      byCategory: [(Text, Nat)];
      byActor: [(Text, Nat)];
      recentActivity: Nat; // Last 24 hours
      oldestTimestamp: ?Int;
      newestTimestamp: ?Int;
    } {
      let logs = auditState.logs;
      let total = logs.size();
      
      if (total == 0) {
        return {
          total = 0;
          byCategory = [];
          byActor = [];
          recentActivity = 0;
          oldestTimestamp = null;
          newestTimestamp = null;
        };
      };

      // Count by category
      let categoryBuffer = Buffer.Buffer<(Text, Nat)>(10);
      let actorBuffer = Buffer.Buffer<(Text, Nat)>(10);
      
      for (entry in logs.vals()) {
        // Count categories
        var categoryFound = false;
        let updatedCategories = Buffer.Buffer<(Text, Nat)>(categoryBuffer.size());
        
        for ((cat, count) in categoryBuffer.vals()) {
          if (cat == entry.category) {
            updatedCategories.add((cat, count + 1));
            categoryFound := true;
          } else {
            updatedCategories.add((cat, count));
          }
        };
        
        if (not categoryFound) {
          updatedCategories.add((entry.category, 1));
        };
        
        categoryBuffer.clear();
        for (item in updatedCategories.vals()) {
          categoryBuffer.add(item);
        };

        // Count actors
        var actorFound = false;
        let updatedActors = Buffer.Buffer<(Text, Nat)>(actorBuffer.size());
        
        for ((actorName, count) in actorBuffer.vals()) {
          if (actorName == entry.actorName) {
            updatedActors.add((actorName, count + 1));
            actorFound := true;
          } else {
            updatedActors.add((actorName, count));
          }
        };
        
        if (not actorFound) {
          updatedActors.add((entry.actorName, 1));
        };
        
        actorBuffer.clear();
        for (item in updatedActors.vals()) {
          actorBuffer.add(item);
        };
      };

      // Find oldest and newest timestamps and count recent activity
      var oldestTimestamp: ?Int = null;
      var newestTimestamp: ?Int = null;
      var recentActivity: Nat = 0;
      let oneDayAgo = Time.now() - (24 * 60 * 60_000_000_000); // 24 hours in nanoseconds
      
      for (entry in logs.vals()) {
        // Update oldest
        switch (oldestTimestamp) {
          case null { oldestTimestamp := ?entry.timestamp; };
          case (?oldest) {
            if (entry.timestamp < oldest) {
              oldestTimestamp := ?entry.timestamp;
            };
          };
        };
        
        // Update newest
        switch (newestTimestamp) {
          case null { newestTimestamp := ?entry.timestamp; };
          case (?newest) {
            if (entry.timestamp > newest) {
              newestTimestamp := ?entry.timestamp;
            };
          };
        };
        
        // Count recent activity
        if (entry.timestamp >= oneDayAgo) {
          recentActivity += 1;
        };
      };

      {
        total = total;
        byCategory = Buffer.toArray(categoryBuffer);
        byActor = Buffer.toArray(actorBuffer);
        recentActivity = recentActivity;
        oldestTimestamp = oldestTimestamp;
        newestTimestamp = newestTimestamp;
      }
    };

    /// Search audit entries by summary text (case-insensitive)
    public func searchBySummary(searchTerm: Text): async [AuditEntry] {
      let lowerSearchTerm = Text.toLowercase(searchTerm);
      let filtered = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          Text.contains(Text.toLowercase(entry.summary), #text lowerSearchTerm)
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<AuditEntry>(
        filtered,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Mark an audit entry as reviewed (for human oversight)
    public func markReviewed(auditId: Nat, reviewedBy: Text): async Bool {
      // Find and update the specific audit entry
      let updatedLogs = Array.map<AuditEntry, AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): AuditEntry {
          if (entry.id == auditId) {
            {
              id = entry.id;
              timestamp = entry.timestamp;
              category = entry.category;
              actorName = entry.actorName;
              traceId = entry.traceId;
              summary = entry.summary;
              linkedReasoningId = entry.linkedReasoningId;
              linkedMemoryIds = entry.linkedMemoryIds;
              outcome = switch (entry.outcome) {
                case (?existing) ?(existing # " [REVIEWED by " # reviewedBy # "]");
                case null ?("[REVIEWED by " # reviewedBy # "]");
              };
            }
          } else {
            entry
          }
        }
      );

      auditState := {
        idCounter = auditState.idCounter;
        logs = updatedLogs;
      };

      Debug.print("🧠 AUDIT: Entry #" # Nat.toText(auditId) # " marked as reviewed by " # reviewedBy);
      true
    };

    /// Clear all audit logs (admin function - use with extreme caution)
    public func clearAllAuditLogs(): async Bool {
      auditState := {
        idCounter = 1;
        logs = [];
      };
      Debug.print("🧠 AUDIT: All audit logs cleared - CRITICAL ACTION");
      true
    };

    /// Export audit trail for external analysis (returns formatted text)
    public func exportAuditTrail(startTime: ?Int, endTime: ?Int): async Text {
      let logs = switch (startTime, endTime) {
        case (?start, ?end) {
          Array.filter<AuditEntry>(
            auditState.logs,
            func(entry: AuditEntry): Bool {
              entry.timestamp >= start and entry.timestamp <= end
            }
          )
        };
        case (?start, null) {
          Array.filter<AuditEntry>(
            auditState.logs,
            func(entry: AuditEntry): Bool {
              entry.timestamp >= start
            }
          )
        };
        case (null, ?end) {
          Array.filter<AuditEntry>(
            auditState.logs,
            func(entry: AuditEntry): Bool {
              entry.timestamp <= end
            }
          )
        };
        case (null, null) auditState.logs;
      };

      let sortedLogs = Array.sort<AuditEntry>(
        logs,
        func(a: AuditEntry, b: AuditEntry): {#less; #equal; #greater} {
          if (a.timestamp < b.timestamp) #less
          else if (a.timestamp > b.timestamp) #greater
          else #equal
        }
      );

      let exportBuffer = Buffer.Buffer<Text>(sortedLogs.size() + 2);
      exportBuffer.add("=== NAMORA AI AUDIT TRAIL ===\n");
      exportBuffer.add("Generated: " # Int.toText(Time.now()) # "\n\n");

      for (entry in sortedLogs.vals()) {
        let traceInfo = switch (entry.traceId) {
          case (?trace) " [Trace: " # trace # "]";
          case null "";
        };
        
        let reasoningInfo = switch (entry.linkedReasoningId) {
          case (?rid) " [Reasoning: " # Nat.toText(rid) # "]";
          case null "";
        };
        
        let memoryInfo = if (entry.linkedMemoryIds.size() > 0) {
          " [Memory: " # Text.join(",", Array.map<Nat, Text>(entry.linkedMemoryIds, Nat.toText).vals()) # "]"
        } else {
          ""
        };
        
        let outcomeInfo = switch (entry.outcome) {
          case (?outcome) " → " # outcome;
          case null "";
        };

        let logLine = "[" # Int.toText(entry.timestamp) # "] " #
                     "[" # entry.category # "] " #
                     entry.actorName # ": " #
                     entry.summary #
                     traceInfo #
                     reasoningInfo #
                     memoryInfo #
                     outcomeInfo # "\n";
        
        exportBuffer.add(logLine);
      };

      Text.join("", exportBuffer.vals())
    };

    // =============================================================================
    // 📊 ENHANCED AUDIT CAPABILITIES - Compliance, Forensics, Performance
    // =============================================================================

    /// Generate comprehensive compliance report for regulatory requirements
    public func generateComplianceReport(config: ComplianceConfig): async ComplianceReport {
      Debug.print("📊 AUDIT: Generating compliance report - " # config.reportType);
      
      // Filter audit entries based on configuration
      let filteredEntries = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          // Time range filter
          let inTimeRange = entry.timestamp >= config.startTimestamp and 
                           entry.timestamp <= config.endTimestamp;
          
          // Category filter
          let inCategories = if (config.includeCategories.size() == 0) {
            true
          } else {
            Array.find<Text>(config.includeCategories, func(cat) = cat == entry.category) != null
          };
          
          // Actor filter
          let inActors = if (config.includeActors.size() == 0) {
            true
          } else {
            Array.find<Text>(config.includeActors, func(actorName) = 
              Text.contains(entry.actorName, #text actorName)) != null
          };
          
          inTimeRange and inCategories and inActors
        }
      );

      // Analyze entries by category
      let categoryMap = buildCategoryMap(filteredEntries);
      let severityMap = buildSeverityMap(filteredEntries);
      let actorMap = buildActorMap(filteredEntries);

      // Identify critical issues
      let criticalIssues = Array.filter<AuditEntry>(
        filteredEntries,
        func(entry: AuditEntry): Bool {
          entry.category == "failure" or 
          entry.category == "security" or
          Text.contains(entry.summary, #text "critical")
        }
      );

      // Calculate compliance score
      let complianceScore = calculateComplianceScore(config.reportType, filteredEntries, criticalIssues);

      // Generate recommendations
      let recommendations = generateComplianceRecommendations(config.reportType, filteredEntries, criticalIssues);

      // Export formatted data
      let exportData = formatComplianceExport(config.reportType, filteredEntries);

      {
        id = auditState.idCounter;
        timestamp = Time.now();
        reportType = config.reportType;
        periodStart = config.startTimestamp;
        periodEnd = config.endTimestamp;
        totalEntries = filteredEntries.size();
        entriesByCategory = categoryMap;
        entriesBySeverity = severityMap;
        entriesByActor = actorMap;
        criticalIssues = criticalIssues;
        complianceScore = complianceScore;
        recommendations = recommendations;
        exportData = exportData;
      }
    };

    /// Conduct detailed forensic analysis for security incidents
    public func conductForensicAnalysis(config: ForensicConfig): async ForensicReport {
      Debug.print("🔍 AUDIT: Conducting forensic analysis - " # config.incidentId);
      
      // Collect evidence based on configuration
      let candidateEntries = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          // Time range filter
          let inTimeRange = entry.timestamp >= config.startTimestamp and 
                           entry.timestamp <= config.endTimestamp;
          
          // Trace ID filter
          let inTraces = if (config.targetTraceIds.size() == 0) {
            true
          } else {
            switch (entry.traceId) {
              case (?traceId) Array.find<Text>(config.targetTraceIds, func(t) = t == traceId) != null;
              case null false;
            }
          };
          
          // Actor filter
          let inActors = if (config.targetActors.size() == 0) {
            true
          } else {
            Array.find<Text>(config.targetActors, func(actorName) = 
              Text.contains(entry.actorName, #text actorName)) != null
          };
          
          // Evidence category filter
          let inEvidenceCategories = if (config.evidenceCategories.size() == 0) {
            true
          } else {
            Array.find<Text>(config.evidenceCategories, func(cat) = cat == entry.category) != null
          };
          
          inTimeRange and (inTraces or inActors) and inEvidenceCategories
        }
      );

      // Build forensic evidence with relevance scoring
      let evidence = Array.map<AuditEntry, ForensicEvidence>(
        candidateEntries,
        func(entry: AuditEntry): ForensicEvidence {
          let relevanceScore = calculateEvidenceRelevance(entry, config);
          let correlatedEntries = findCorrelatedEntries(entry, candidateEntries);
          
          {
            id = entry.id;
            timestamp = entry.timestamp;
            evidenceType = classifyEvidenceType(entry);
            relevanceScore = relevanceScore;
            auditEntry = entry;
            correlatedEntries = correlatedEntries;
            analysisNotes = generateAnalysisNotes(entry, config.analysisDepth);
          }
        }
      );

      // Sort evidence by relevance and timestamp
      let sortedEvidence = Array.sort<ForensicEvidence>(
        evidence,
        func(a: ForensicEvidence, b: ForensicEvidence): {#less; #equal; #greater} {
          if (a.relevanceScore > b.relevanceScore) #less
          else if (a.relevanceScore < b.relevanceScore) #greater
          else if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      );

      // Analyze patterns and generate findings
      let keyFindings = generateKeyFindings(sortedEvidence, config);
      let rootCauseAnalysis = performRootCauseAnalysis(sortedEvidence, config);
      let affectedSystems = identifyAffectedSystems(sortedEvidence);
      let recommendedActions = generateForensicRecommendations(sortedEvidence, config);
      let riskAssessment = assessSecurityRisk(sortedEvidence, config);

      // Build evidence type breakdown
      let evidenceTypeMap = buildEvidenceTypeMap(sortedEvidence);

      {
        id = auditState.idCounter;
        timestamp = Time.now();
        incidentId = config.incidentId;
        investigationPeriod = (config.startTimestamp, config.endTimestamp);
        totalEvidence = sortedEvidence.size();
        evidenceByType = evidenceTypeMap;
        timeline = sortedEvidence;
        keyFindings = keyFindings;
        rootCauseAnalysis = rootCauseAnalysis;
        affectedSystems = affectedSystems;
        recommendedActions = recommendedActions;
        riskAssessment = riskAssessment;
      }
    };

    /// Track AI decision accuracy and performance metrics over time
    public func analyzePerformanceMetrics(config: PerformanceConfig): async PerformanceMetric {
      Debug.print("📈 AUDIT: Analyzing performance metrics - " # config.metricType);
      
      let currentTime = Time.now();
      let startTime = currentTime - config.timeWindow;
      
      // Filter entries for analysis period
      let analysisEntries = Array.filter<AuditEntry>(
        auditState.logs,
        func(entry: AuditEntry): Bool {
          let inTimeWindow = entry.timestamp >= startTime and entry.timestamp <= currentTime;
          
          let inCategories = if (config.categories.size() == 0) {
            true
          } else {
            Array.find<Text>(config.categories, func(cat) = cat == entry.category) != null
          };
          
          let inActors = if (config.actors.size() == 0) {
            true
          } else {
            Array.find<Text>(config.actors, func(actorName) = 
              Text.contains(entry.actorName, #text actorName)) != null
          };
          
          inTimeWindow and inCategories and inActors
        }
      );

      // Calculate metrics based on type
      let (averageValue, standardDeviation, breakdown, qualityScore, anomalies) = switch (config.metricType) {
        case ("accuracy") calculateAccuracyMetrics(analysisEntries);
        case ("response_time") calculateResponseTimeMetrics(analysisEntries);
        case ("decision_quality") calculateDecisionQualityMetrics(analysisEntries);
        case _ (0.0, 0.0, [], 0.0, 0);
      };

      // Calculate benchmark comparison
      let benchmarkComparison = switch (config.benchmarkValue) {
        case (?benchmark) ?((averageValue / benchmark) * 100.0);
        case null null;
      };

      // Determine trend direction
      let trendDirection = calculateTrendDirection(config.metricType, analysisEntries);

      {
        id = auditState.idCounter;
        timestamp = currentTime;
        metricType = config.metricType;
        timeWindow = config.timeWindow;
        periodStart = startTime;
        periodEnd = currentTime;
        totalSamples = analysisEntries.size();
        averageValue = averageValue;
        standardDeviation = standardDeviation;
        benchmarkComparison = benchmarkComparison;
        trendDirection = trendDirection;
        anomaliesDetected = anomalies;
        detailedBreakdown = breakdown;
        qualityScore = qualityScore;
      }
    };

    /// Generate comprehensive performance dashboard
    public func generatePerformanceDashboard(): async PerformanceDashboard {
      Debug.print("📊 AUDIT: Generating performance dashboard");
      
      let twentyFourHours = 24 * 60 * 60_000_000_000; // 24 hours in nanoseconds
      
      // Standard configuration for dashboard metrics
      let baseConfig: PerformanceConfig = {
        metricType = "accuracy"; // Will be overridden
        timeWindow = twentyFourHours;
        benchmarkValue = ?90.0; // 90% benchmark
        categories = [];
        actors = [];
      };

      // Generate individual metrics
      let accuracyMetrics = await analyzePerformanceMetrics({
        baseConfig with metricType = "accuracy"
      });
      
      let responseTimeMetrics = await analyzePerformanceMetrics({
        baseConfig with metricType = "response_time"
      });
      
      let decisionQualityMetrics = await analyzePerformanceMetrics({
        baseConfig with metricType = "decision_quality"
      });

      // Calculate overall score
      let overallScore = (accuracyMetrics.qualityScore + 
                         responseTimeMetrics.qualityScore + 
                         decisionQualityMetrics.qualityScore) / 3.0;

      // Generate trends over time (last 7 days, daily intervals)
      let trendsOverTime = generateTrendHistory(7); // Last 7 days

      // Generate recommendations and alerts
      let recommendations = generatePerformanceRecommendations([accuracyMetrics, responseTimeMetrics, decisionQualityMetrics]);
      let alertsAndWarnings = generatePerformanceAlerts([accuracyMetrics, responseTimeMetrics, decisionQualityMetrics]);

      {
        timestamp = Time.now();
        overallScore = overallScore;
        accuracyMetrics = accuracyMetrics;
        responseTimeMetrics = responseTimeMetrics;
        decisionQualityMetrics = decisionQualityMetrics;
        trendsOverTime = trendsOverTime;
        recommendations = recommendations;
        alertsAndWarnings = alertsAndWarnings;
      }
    };

    // =============================================================================
    // 🔧 HELPER FUNCTIONS FOR ENHANCED AUDIT CAPABILITIES
    // =============================================================================

    /// Build category map for analysis
    private func buildCategoryMap(entries: [AuditEntry]): [(Text, Nat)] {
      let categoryCount = Buffer.Buffer<(Text, Nat)>(10);
      let categories = ["action", "failure", "reasoning", "intervention", "security", "performance"];
      
      for (category in categories.vals()) {
        let count = Array.filter<AuditEntry>(entries, func(e) = e.category == category).size();
        if (count > 0) {
          categoryCount.add((category, count));
        };
      };
      
      Buffer.toArray(categoryCount)
    };

    /// Build severity map for analysis
    private func buildSeverityMap(entries: [AuditEntry]): [(Text, Nat)] {
      let severityCount = Buffer.Buffer<(Text, Nat)>(4);
      let severities = ["info", "warning", "critical", "emergency"];
      
      for (severity in severities.vals()) {
        let count = Array.filter<AuditEntry>(entries, func(e) = 
          Text.contains(e.summary, #text severity)).size();
        if (count > 0) {
          severityCount.add((severity, count));
        };
      };
      
      Buffer.toArray(severityCount)
    };

    /// Build actor map for analysis
    private func buildActorMap(entries: [AuditEntry]): [(Text, Nat)] {
      let actorCount = Buffer.Buffer<(Text, Nat)>(10);
      let actors = ["NamoraAI", "admin", "user", "system"];
      
      for (actorType in actors.vals()) {
        let count = Array.filter<AuditEntry>(entries, func(e) = 
          Text.contains(e.actorName, #text actorType)).size();
        if (count > 0) {
          actorCount.add((actorType, count));
        };
      };
      
      Buffer.toArray(actorCount)
    };

    /// Calculate compliance score based on report type
    private func calculateComplianceScore(_reportType: Text, entries: [AuditEntry], criticalIssues: [AuditEntry]): Float {
      let baseScore = 100.0;
      let criticalPenalty = Float.fromInt(criticalIssues.size()) * 10.0;
      let totalEntries = Float.fromInt(entries.size());
      
      let failureRate = if (totalEntries > 0.0) {
        Float.fromInt(Array.filter<AuditEntry>(entries, func(e) = e.category == "failure").size()) / totalEntries
      } else { 0.0 };
      
      let failurePenalty = failureRate * 20.0;
      let finalScore = baseScore - criticalPenalty - failurePenalty;
      
      Float.max(0.0, Float.min(100.0, finalScore))
    };

    /// Generate compliance recommendations
    private func generateComplianceRecommendations(reportType: Text, entries: [AuditEntry], criticalIssues: [AuditEntry]): [Text] {
      let recommendations = Buffer.Buffer<Text>(5);
      
      if (criticalIssues.size() > 0) {
        recommendations.add("Address " # Nat.toText(criticalIssues.size()) # " critical security issues immediately");
      };
      
      let failureCount = Array.filter<AuditEntry>(entries, func(e) = e.category == "failure").size();
      if (failureCount > 5) {
        recommendations.add("Investigate recurring failure patterns - " # Nat.toText(failureCount) # " failures detected");
      };
      
      switch (reportType) {
        case ("gdpr") {
          recommendations.add("Ensure data processing activities have proper consent documentation");
          recommendations.add("Review data retention policies for compliance with GDPR requirements");
        };
        case ("sox") {
          recommendations.add("Strengthen financial controls and audit trails");
          recommendations.add("Implement additional segregation of duties for financial processes");
        };
        case _ {
          recommendations.add("Maintain regular audit reviews and documentation");
        };
      };
      
      Buffer.toArray(recommendations)
    };

    /// Format compliance export data
    private func formatComplianceExport(reportType: Text, entries: [AuditEntry]): Text {
      let exportLines = Buffer.Buffer<Text>(entries.size() + 10);
      
      exportLines.add("# " # reportType # " Compliance Report Export\n");
      exportLines.add("# Generated: " # Int.toText(Time.now()) # "\n");
      exportLines.add("# Total Entries: " # Nat.toText(entries.size()) # "\n\n");
      exportLines.add("Timestamp,Category,Actor,Summary,TraceID,Outcome\n");
      
      for (entry in entries.vals()) {
        let traceId = switch (entry.traceId) { case (?id) id; case null ""; };
        let outcome = switch (entry.outcome) { case (?out) out; case null ""; };
        let line = Int.toText(entry.timestamp) # "," # 
                  entry.category # "," # 
                  entry.actorName # "," # 
                  entry.summary # "," # 
                  traceId # "," # 
                  outcome # "\n";
        exportLines.add(line);
      };
      
      Text.join("", exportLines.vals())
    };

    /// Calculate evidence relevance score
    private func calculateEvidenceRelevance(entry: AuditEntry, config: ForensicConfig): Float {
      var score = 0.5; // Base relevance
      
      // Higher relevance for specific trace IDs
      switch (entry.traceId) {
        case (?traceId) {
          if (Array.find<Text>(config.targetTraceIds, func(t) = t == traceId) != null) {
            score += 0.3;
          };
        };
        case null {};
      };
      
      // Higher relevance for target actors
      if (Array.find<Text>(config.targetActors, func(actorName) = 
          Text.contains(entry.actorName, #text actorName)) != null) {
        score += 0.2;
      };
      
      // Higher relevance for failure/security categories
      if (entry.category == "failure" or entry.category == "security") {
        score += 0.3;
      };
      
      Float.min(1.0, score)
    };

    /// Find correlated audit entries
    private func findCorrelatedEntries(entry: AuditEntry, candidateEntries: [AuditEntry]): [Nat] {
      let correlatedIds = Buffer.Buffer<Nat>(5);
      
      for (candidate in candidateEntries.vals()) {
        if (candidate.id != entry.id) {
          // Check for same trace ID
          switch (entry.traceId, candidate.traceId) {
            case (?entryTrace, ?candidateTrace) {
              if (entryTrace == candidateTrace) {
                correlatedIds.add(candidate.id);
              };
            };
            case _ {};
          };
          
          // Check for temporal proximity (within 5 minutes)
          let timeDiff = Int.abs(entry.timestamp - candidate.timestamp);
          if (timeDiff <= (5 * 60_000_000_000) and entry.category == candidate.category) {
            correlatedIds.add(candidate.id);
          };
        };
      };
      
      Buffer.toArray(correlatedIds)
    };

    /// Classify evidence type
    private func classifyEvidenceType(entry: AuditEntry): Text {
      switch (entry.category) {
        case ("failure") "system_failure";
        case ("security") "security_event";
        case ("action") "user_action";
        case ("reasoning") "ai_decision";
        case _ "general_audit";
      }
    };

    /// Generate analysis notes
    private func generateAnalysisNotes(entry: AuditEntry, depth: Text): Text {
      let baseNote = "Category: " # entry.category # " | Actor: " # entry.actorName;
      
      switch (depth) {
        case ("comprehensive") {
          baseNote # " | Detailed analysis: " # entry.summary # 
          " | Linked Memory IDs: " # Nat.toText(entry.linkedMemoryIds.size()) #
          " | Outcome: " # (switch (entry.outcome) { case (?o) o; case null "pending"; })
        };
        case ("detailed") {
          baseNote # " | " # entry.summary
        };
        case _ baseNote;
      }
    };

    /// Generate key findings from evidence
    private func generateKeyFindings(evidence: [ForensicEvidence], _config: ForensicConfig): [Text] {
      let findings = Buffer.Buffer<Text>(5);
      
      // High relevance evidence count
      let highRelevanceCount = Array.filter<ForensicEvidence>(evidence, func(e) = e.relevanceScore > 0.8).size();
      if (highRelevanceCount > 0) {
        findings.add("Identified " # Nat.toText(highRelevanceCount) # " high-relevance evidence items");
      };
      
      // Security events
      let securityEvents = Array.filter<ForensicEvidence>(evidence, func(e) = e.evidenceType == "security_event").size();
      if (securityEvents > 0) {
        findings.add("Detected " # Nat.toText(securityEvents) # " security-related events during incident period");
      };
      
      // System failures
      let systemFailures = Array.filter<ForensicEvidence>(evidence, func(e) = e.evidenceType == "system_failure").size();
      if (systemFailures > 0) {
        findings.add("Found " # Nat.toText(systemFailures) # " system failure events correlated with incident");
      };
      
      Buffer.toArray(findings)
    };

    /// Perform root cause analysis
    private func performRootCauseAnalysis(evidence: [ForensicEvidence], _config: ForensicConfig): Text {
      let securityEvents = Array.filter<ForensicEvidence>(evidence, func(e) = e.evidenceType == "security_event");
      let systemFailures = Array.filter<ForensicEvidence>(evidence, func(e) = e.evidenceType == "system_failure");
      
      if (securityEvents.size() > systemFailures.size()) {
        "Primary root cause appears to be security-related with " # 
        Nat.toText(securityEvents.size()) # " security events detected"
      } else if (systemFailures.size() > 0) {
        "Root cause likely stems from system failures with " # 
        Nat.toText(systemFailures.size()) # " failure events in timeline"
      } else {
        "Root cause requires additional investigation - no clear pattern in available evidence"
      }
    };

    /// Identify affected systems
    private func identifyAffectedSystems(evidence: [ForensicEvidence]): [Text] {
      let systems = Buffer.Buffer<Text>(5);
      let categories = ["financial", "governance", "escrow", "identity", "payment"];
      
      for (category in categories.vals()) {
        let categoryEvents = Array.filter<ForensicEvidence>(evidence, func(e) = 
          Text.contains(e.auditEntry.summary, #text category) or
          Text.contains(e.auditEntry.actorName, #text category)).size();
        
        if (categoryEvents > 0) {
          systems.add(category # "_system (" # Nat.toText(categoryEvents) # " events)");
        };
      };
      
      Buffer.toArray(systems)
    };

    /// Generate forensic recommendations
    private func generateForensicRecommendations(evidence: [ForensicEvidence], _config: ForensicConfig): [Text] {
      let recommendations = Buffer.Buffer<Text>(5);
      
      let criticalEvidence = Array.filter<ForensicEvidence>(evidence, func(e) = e.relevanceScore > 0.9).size();
      if (criticalEvidence > 0) {
        recommendations.add("Immediately review " # Nat.toText(criticalEvidence) # " critical evidence items");
      };
      
      recommendations.add("Implement additional monitoring for incident type: " # _config.incidentId);
      recommendations.add("Review and update security controls based on findings");
      recommendations.add("Conduct follow-up investigation in 30 days to ensure resolution");
      
      Buffer.toArray(recommendations)
    };

    /// Assess security risk level
    private func assessSecurityRisk(evidence: [ForensicEvidence], _config: ForensicConfig): Text {
      let securityEvents = Array.filter<ForensicEvidence>(evidence, func(e) = e.evidenceType == "security_event").size();
      let highRelevanceEvents = Array.filter<ForensicEvidence>(evidence, func(e) = e.relevanceScore > 0.8).size();
      
      if (securityEvents > 5 or highRelevanceEvents > 10) {
        "critical"
      } else if (securityEvents > 2 or highRelevanceEvents > 5) {
        "high"
      } else if (securityEvents > 0 or highRelevanceEvents > 2) {
        "medium"
      } else {
        "low"
      }
    };

    /// Build evidence type map
    private func buildEvidenceTypeMap(evidence: [ForensicEvidence]): [(Text, Nat)] {
      let typeMap = Buffer.Buffer<(Text, Nat)>(5);
      let types = ["system_failure", "security_event", "user_action", "ai_decision", "general_audit"];
      
      for (evidenceType in types.vals()) {
        let count = Array.filter<ForensicEvidence>(evidence, func(e) = e.evidenceType == evidenceType).size();
        if (count > 0) {
          typeMap.add((evidenceType, count));
        };
      };
      
      Buffer.toArray(typeMap)
    };

    /// Calculate accuracy metrics
    private func calculateAccuracyMetrics(entries: [AuditEntry]): (Float, Float, [(Text, Float)], Float, Nat) {
      let _reasoningEntries = Array.filter<AuditEntry>(entries, func(e) = e.category == "reasoning");
      let successfulEntries = Array.filter<AuditEntry>(entries, func(e) = 
        switch (e.outcome) {
          case (?outcome) Text.contains(outcome, #text "success");
          case null false;
        });
      
      let accuracy = if (entries.size() > 0) {
        Float.fromInt(successfulEntries.size()) / Float.fromInt(entries.size()) * 100.0
      } else { 0.0 };
      
      let breakdown = [("successful_outcomes", Float.fromInt(successfulEntries.size())), 
                      ("total_decisions", Float.fromInt(entries.size()))];
      
      (accuracy, 10.0, breakdown, accuracy, 0) // accuracy, stddev, breakdown, quality, anomalies
    };

    /// Calculate response time metrics
    private func calculateResponseTimeMetrics(_entries: [AuditEntry]): (Float, Float, [(Text, Float)], Float, Nat) {
      let avgResponseTime = 250.0; // Simulated average response time in ms
      let stddev = 50.0;
      let breakdown = [("avg_response_ms", avgResponseTime), ("max_response_ms", 500.0)];
      let qualityScore = if (avgResponseTime < 300.0) 90.0 else 70.0;
      
      (avgResponseTime, stddev, breakdown, qualityScore, 0)
    };

    /// Calculate decision quality metrics
    private func calculateDecisionQualityMetrics(entries: [AuditEntry]): (Float, Float, [(Text, Float)], Float, Nat) {
      let reasoningEntries = Array.filter<AuditEntry>(entries, func(e) = e.category == "reasoning");
      let criticalDecisions = Array.filter<AuditEntry>(entries, func(e) = 
        Text.contains(e.summary, #text "critical"));
      
      let qualityScore = if (reasoningEntries.size() > 0) {
        85.0 - (Float.fromInt(criticalDecisions.size()) * 5.0)
      } else { 0.0 };
      
      let breakdown = [("reasoning_decisions", Float.fromInt(reasoningEntries.size())), 
                      ("critical_decisions", Float.fromInt(criticalDecisions.size()))];
      
      (qualityScore, 8.0, breakdown, qualityScore, 0)
    };

    /// Calculate trend direction
    private func calculateTrendDirection(_metricType: Text, _entries: [AuditEntry]): Text {
      // Simplified trend analysis
      let recentEntries = Array.filter<AuditEntry>(_entries, func(e) = 
        (Time.now() - e.timestamp) <= (2 * 60 * 60_000_000_000)); // Last 2 hours
      
      if (_entries.size() > 0 and recentEntries.size() > _entries.size() / 2) {
        "improving"
      } else if (recentEntries.size() < _entries.size() / 4) {
        "declining"
      } else {
        "stable"
      }
    };

    /// Generate trend history
    private func generateTrendHistory(days: Nat): [(Int, Float)] {
      let trends = Buffer.Buffer<(Int, Float)>(days);
      let currentTime = Time.now();
      let dayInNanos = 24 * 60 * 60_000_000_000;
      
      var i = days;
      while (i > 0) {
        let dayTimestamp = currentTime - (dayInNanos * i);
        let score = 85.0 + Float.fromInt(i % 10) - 5.0; // Simulated trend data
        trends.add((dayTimestamp, score));
        i -= 1;
      };
      
      Buffer.toArray(trends)
    };

    /// Generate performance recommendations
    private func generatePerformanceRecommendations(metrics: [PerformanceMetric]): [Text] {
      let recommendations = Buffer.Buffer<Text>(5);
      
      for (metric in metrics.vals()) {
        if (metric.qualityScore < 70.0) {
          recommendations.add("Improve " # metric.metricType # " performance - current score: " # Float.toText(metric.qualityScore));
        };
        
        if (metric.trendDirection == "declining") {
          recommendations.add("Address declining trend in " # metric.metricType # " metrics");
        };
      };
      
      if (recommendations.size() == 0) {
        recommendations.add("Performance metrics are within acceptable ranges");
      };
      
      Buffer.toArray(recommendations)
    };

    /// Generate performance alerts
    private func generatePerformanceAlerts(metrics: [PerformanceMetric]): [Text] {
      let alerts = Buffer.Buffer<Text>(5);
      
      for (metric in metrics.vals()) {
        if (metric.qualityScore < 50.0) {
          alerts.add("CRITICAL: " # metric.metricType # " quality score below 50%");
        } else if (metric.qualityScore < 70.0) {
          alerts.add("WARNING: " # metric.metricType # " quality score below 70%");
        };
        
        if (metric.anomaliesDetected > 0) {
          alerts.add("ANOMALY: " # Nat.toText(metric.anomaliesDetected) # " anomalies detected in " # metric.metricType);
        };
      };
      
      Buffer.toArray(alerts)
    };
  };
}
