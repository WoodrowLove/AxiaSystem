/// 🧩 NamoraAI Reasoning Engine
/// 
/// Systemic Pattern Recognition and AI Correlation Layer
/// 
/// This module enables system-wide analysis, pattern recognition, and anomaly detection
/// across all insights and memory entries. It allows NamoraAI to:
/// - Detect emergent issues from clusters of insights
/// - Identify behavioral patterns (e.g., wallet drains, governance inactivity)
/// - Link multiple canisters through shared trace IDs
/// - Generate human-readable AI summaries and recommendations
/// - Feed proposals to the action module for resolution

import Time "mo:base/Time";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";

import Memory "memory";

module {
  /// Input parameters for reasoning analysis
  public type ReasoningInput = {
    since: ?Int; // Optional nanosecond timestamp to filter from
    max: ?Nat;   // Optional limit of entries to reason over
  };

  /// Output of reasoning analysis with pattern recognition results
  public type ReasoningOutput = {
    id: Nat;
    timestamp: Int;
    title: Text;              // Short human-readable label
    description: Text;        // Explanation of the pattern/correlation
    traceIds: [Text];         // Linked traces, if any
    severity: Text;           // "info", "warning", "critical"
    tags: [Text];             // E.g., ["wallet", "token", "latency"]
    sourceInsightIds: [Nat];  // IDs of MemoryEntry items analyzed
  };

  /// Stable storage state for reasoning results
  public type ReasoningState = {
    idCounter: Nat;
    logs: [ReasoningOutput];
  };

  /// Statistical baseline for anomaly detection
  public type StatisticalBaseline = {
    category: Text;
    avgFrequency: Float;      // Average events per hour
    stdDeviation: Float;      // Standard deviation
    lastCalculated: Int;      // Timestamp of last calculation
    sampleSize: Nat;         // Number of samples used
  };

  /// Trend analysis data point
  public type TrendDataPoint = {
    timestamp: Int;
    value: Float;             // Metric value (frequency, latency, etc.)
    category: Text;
  };

  /// Behavioral profile for users/systems
  public type BehaviorProfile = {
    entityId: Text;           // User ID or system component
    profileType: Text;        // "user", "system", "canister"
    patterns: [(Text, Float)]; // Pattern name -> frequency
    anomalyThreshold: Float;   // Deviation threshold for alerts
    lastUpdated: Int;
    observationPeriod: Int;   // Time window for analysis (nanoseconds)
  };

  /// Cascading failure chain link
  public type FailureChainLink = {
    sourceEvent: Memory.MemoryEntry;
    triggeredEvents: [Memory.MemoryEntry];
    cascadeLevel: Nat;        // Depth in the failure chain
    impactScore: Float;       // Calculated impact (0.0 - 1.0)
  };

  /// Event trigger configuration for real-time analysis
  public type EventTrigger = {
    triggerType: Text;        // "keyword", "frequency", "severity", "pattern"
    condition: Text;          // Condition specification
    threshold: Float;         // Numerical threshold for triggers
    enabled: Bool;            // Whether trigger is active
    cooldownPeriod: Int;      // Minimum time between triggers (nanoseconds)
    lastTriggered: ?Int;      // Last trigger timestamp
  };

  /// Sliding window configuration
  public type SlidingWindow = {
    windowSize: Int;          // Time window size in nanoseconds
    slideInterval: Int;       // How often to slide the window (nanoseconds)
    lastProcessed: Int;       // Last window processing timestamp
    entryCount: Nat;          // Current entries in window
    alertThreshold: Nat;      // Alert when entries exceed this count
  };

  /// Real-time alert configuration
  public type RealtimeAlert = {
    id: Nat;
    timestamp: Int;
    alertType: Text;          // "threshold", "anomaly", "cascade", "prediction"
    severity: Text;           // "info", "warning", "critical", "emergency"
    message: Text;
    sourcePattern: Text;      // Which pattern triggered the alert
    autoEscalated: Bool;      // Whether alert was auto-escalated
    acknowledged: Bool;       // Whether alert has been acknowledged
    resolvedAt: ?Int;         // Resolution timestamp
  };

  /// Streaming analysis state
  public type StreamingState = {
    eventTriggers: [EventTrigger];
    slidingWindows: [SlidingWindow];
    realtimeAlerts: [RealtimeAlert];
    alertCounter: Nat;
    streamingEnabled: Bool;
    lastProcessingTime: Int;
  };

  /// Advanced reasoning engine for pattern detection and correlation analysis
  public class ReasoningEngine(memorySystem: Memory.MemorySystem) {
    /// Maximum reasoning logs to retain (prevents unbounded growth)
    private let MAX_REASONING_LOGS: Nat = 5000;
    
    /// Stable storage for reasoning results
    private var reasoningState: ReasoningState = {
      idCounter = 1;
      logs = [];
    };

    /// Statistical baselines for anomaly detection
    private var statisticalBaselines = HashMap.HashMap<Text, StatisticalBaseline>(20, Text.equal, Text.hash);
    
    /// Trend analysis data storage
    private var trendData = Buffer.Buffer<TrendDataPoint>(1000);
    
    /// Behavioral profiles for entities
    private var _behaviorProfiles = HashMap.HashMap<Text, BehaviorProfile>(100, Text.equal, Text.hash);
    
    /// Failure chain analysis cache
    private var _failureChains = Buffer.Buffer<FailureChainLink>(50);

    /// Real-time streaming analysis state
    private var streamingState: StreamingState = {
      eventTriggers = [];
      slidingWindows = [];
      realtimeAlerts = [];
      alertCounter = 1;
      streamingEnabled = false;
      lastProcessingTime = Time.now();
    };

    /// Event processing queue for real-time analysis
    private var eventQueue = Buffer.Buffer<Memory.MemoryEntry>(100);
    
    /// Processing lock to prevent concurrent analysis
    private var isProcessing = false;

    /// Initialize reasoning engine with existing state
    public func initialize(existingState: ReasoningState) {
      reasoningState := existingState;
    };

    /// Get current reasoning state for stable storage
    public func getState(): ReasoningState {
      reasoningState
    };

    /// Main analysis function - detects patterns and correlations in memory
    public func analyze(input: ReasoningInput): async ReasoningOutput {
      Debug.print("🧩 REASONING: Starting pattern analysis");
      
      // Load memory entries based on input criteria
      let memoryEntries = if (input.since == null and input.max == null) {
        await memorySystem.recallAll()
      } else {
        switch (input.since, input.max) {
          case (?since, ?max) {
            let timeFiltered = await memorySystem.recallByTimeRange(since, Time.now());
            if (timeFiltered.size() <= max) timeFiltered
            else Array.subArray<Memory.MemoryEntry>(timeFiltered, 0, max)
          };
          case (?since, null) {
            await memorySystem.recallByTimeRange(since, Time.now())
          };
          case (null, ?max) {
            await memorySystem.getLastN(max)
          };
          case (null, null) {
            await memorySystem.recallAll()
          };
        }
      };

      Debug.print("🧩 REASONING: Analyzing " # Nat.toText(memoryEntries.size()) # " memory entries");

      // Run all pattern detectors and find the highest priority issue
      let detectionResults = await runAllDetectors(memoryEntries);
      
      let highestPriorityResult = if (detectionResults.size() > 0) {
        // Sort by severity priority: critical > warning > info
        let sortedResults = Array.sort<ReasoningOutput>(
          detectionResults,
          func(a: ReasoningOutput, b: ReasoningOutput): {#less; #equal; #greater} {
            let aPriority = getSeverityPriority(a.severity);
            let bPriority = getSeverityPriority(b.severity);
            if (aPriority > bPriority) #less
            else if (aPriority < bPriority) #greater
            else #equal
          }
        );
        sortedResults[0]
      } else {
        // No patterns detected - return normal status
        {
          id = reasoningState.idCounter;
          timestamp = Time.now();
          title = "System Normal";
          description = "No significant patterns or anomalies detected in recent activity";
          traceIds = [];
          severity = "info";
          tags = ["system", "health"];
          sourceInsightIds = [];
        }
      };

      // Store the reasoning result
      await storeReasoningResult(highestPriorityResult);
      
      Debug.print("🧩 REASONING: Analysis complete - " # highestPriorityResult.title # " (" # highestPriorityResult.severity # ")");
      highestPriorityResult
    };

    /// Run all pattern detection algorithms
    private func runAllDetectors(entries: [Memory.MemoryEntry]): async [ReasoningOutput] {
      let results = Buffer.Buffer<ReasoningOutput>(15); // Increased capacity for new detectors
      
      // Build trace linking map for cross-module analysis
      let traceMap = buildTraceLinking(entries);
      
      // Run original pattern detectors
      switch (await detectWalletDrain(entries)) {
        case (?result) results.add(result);
        case null {};
      };
      
      switch (await detectEscrowFailureCluster(entries)) {
        case (?result) results.add(result);
        case null {};
      };
      
      switch (await detectProposalInactivity(entries)) {
        case (?result) results.add(result);
        case null {};
      };
      
      switch (await detectSystemLatencySpike(entries)) {
        case (?result) results.add(result);
        case null {};
      };
      
      switch (await detectRepeatedErrorCluster(entries)) {
        case (?result) results.add(result);
        case null {};
      };
      
      switch (await detectCrossModuleCorrelation(traceMap)) {
        case (?result) results.add(result);
        case null {};
      };

      // Run advanced pattern detectors
      switch (await detectStatisticalAnomalies(entries)) {
        case (?result) results.add(result);
        case null {};
      };
      
      switch (await detectTrendPredictions(entries)) {
        case (?result) results.add(result);
        case null {};
      };
      
      switch (await detectBehavioralAnomalies(entries)) {
        case (?result) results.add(result);
        case null {};
      };
      
      switch (await detectCascadingFailures(entries)) {
        case (?result) results.add(result);
        case null {};
      };

      Buffer.toArray(results)
    };

    /// Detect wallet drain patterns (3+ balance updates in short time with low final balance)
    private func detectWalletDrain(entries: [Memory.MemoryEntry]): async ?ReasoningOutput {
      let walletEntries = Array.filter<Memory.MemoryEntry>(
        entries,
        func(entry: Memory.MemoryEntry): Bool {
          Text.contains(entry.category, #text "financial") or 
          Text.contains(entry.summary, #text "balance") or
          Text.contains(entry.summary, #text "payment") or
          Text.contains(entry.summary, #text "wallet")
        }
      );

      if (walletEntries.size() < 3) return null;

      // Group by trace ID and look for rapid balance changes
      let traceGroups = Buffer.Buffer<(Text, [Memory.MemoryEntry])>(10);
      let processedTraces = Buffer.Buffer<Text>(10);

      for (entry in walletEntries.vals()) {
        switch (entry.traceId) {
          case (?traceId) {
            var traceExists = false;
            for (trace in processedTraces.vals()) {
              if (trace == traceId) {
                traceExists := true;
              };
            };
            
            if (not traceExists) {
              processedTraces.add(traceId);
              let traceEntries = Array.filter<Memory.MemoryEntry>(
                walletEntries,
                func(e: Memory.MemoryEntry): Bool {
                  switch (e.traceId) {
                    case (?id) id == traceId;
                    case null false;
                  }
                }
              );
              if (traceEntries.size() >= 3) {
                traceGroups.add((traceId, traceEntries));
              };
            };
          };
          case null {};
        };
      };

      // Analyze each trace group for wallet drain pattern
      for ((traceId, traceEntries) in traceGroups.vals()) {
        let sortedEntries = Array.sort<Memory.MemoryEntry>(
          traceEntries,
          func(a: Memory.MemoryEntry, b: Memory.MemoryEntry): {#less; #equal; #greater} {
            if (a.timestamp < b.timestamp) #less
            else if (a.timestamp > b.timestamp) #greater
            else #equal
          }
        );

        let timeSpan = sortedEntries[sortedEntries.size() - 1].timestamp - sortedEntries[0].timestamp;
        let oneMinute = 60_000_000_000; // 1 minute in nanoseconds

        if (timeSpan <= oneMinute and sortedEntries.size() >= 3) {
          let sourceIds = Array.map<Memory.MemoryEntry, Nat>(sortedEntries, func(e) = e.id);
          
          return ?{
            id = reasoningState.idCounter;
            timestamp = Time.now();
            title = "Potential Wallet Drain Detected";
            description = "Rapid financial activity detected: " # Nat.toText(sortedEntries.size()) # 
                         " transactions in " # Int.toText(timeSpan / 1_000_000) # "ms on trace " # traceId;
            traceIds = [traceId];
            severity = "critical";
            tags = ["wallet", "payment", "security", "user"];
            sourceInsightIds = sourceIds;
          };
        };
      };

      null
    };

    /// Detect escrow failure clusters (5+ escrow-related errors by time and traceId)
    private func detectEscrowFailureCluster(entries: [Memory.MemoryEntry]): async ?ReasoningOutput {
      let escrowEntries = Array.filter<Memory.MemoryEntry>(
        entries,
        func(entry: Memory.MemoryEntry): Bool {
          Text.contains(entry.summary, #text "escrow") or
          Text.contains(entry.summary, #text "Escrow") or
          Text.contains(entry.category, #text "escrow")
        }
      );

      if (escrowEntries.size() < 5) return null;

      // Look for error patterns in recent escrow activity
      let errorEntries = Array.filter<Memory.MemoryEntry>(
        escrowEntries,
        func(entry: Memory.MemoryEntry): Bool {
          Text.contains(entry.summary, #text "error") or
          Text.contains(entry.summary, #text "fail") or
          Text.contains(entry.summary, #text "cancel")
        }
      );

      if (errorEntries.size() >= 5) {
        let fiveMinutes = 5 * 60_000_000_000; // 5 minutes in nanoseconds
        let recentErrors = Array.filter<Memory.MemoryEntry>(
          errorEntries,
          func(entry: Memory.MemoryEntry): Bool {
            (Time.now() - entry.timestamp) <= fiveMinutes
          }
        );

        if (recentErrors.size() >= 5) {
          let sourceIds = Array.map<Memory.MemoryEntry, Nat>(recentErrors, func(e) = e.id);
          let traceIds = Buffer.Buffer<Text>(recentErrors.size());
          
          for (entry in recentErrors.vals()) {
            switch (entry.traceId) {
              case (?traceId) traceIds.add(traceId);
              case null {};
            };
          };

          return ?{
            id = reasoningState.idCounter;
            timestamp = Time.now();
            title = "Escrow Failure Cluster";
            description = Nat.toText(recentErrors.size()) # 
                         " escrow failures detected in the last 5 minutes";
            traceIds = Buffer.toArray(traceIds);
            severity = "warning";
            tags = ["escrow", "system", "error"];
            sourceInsightIds = sourceIds;
          };
        };
      };

      null
    };

    /// Detect governance proposal inactivity
    private func detectProposalInactivity(entries: [Memory.MemoryEntry]): async ?ReasoningOutput {
      let governanceEntries = Array.filter<Memory.MemoryEntry>(
        entries,
        func(entry: Memory.MemoryEntry): Bool {
          Text.contains(entry.category, #text "governance") or
          Text.contains(entry.summary, #text "proposal") or
          Text.contains(entry.summary, #text "vote")
        }
      );

      if (governanceEntries.size() == 0) return null;

      // Check for lack of recent governance activity
      let oneHour = 60 * 60_000_000_000; // 1 hour in nanoseconds
      let recentActivity = Array.filter<Memory.MemoryEntry>(
        governanceEntries,
        func(entry: Memory.MemoryEntry): Bool {
          (Time.now() - entry.timestamp) <= oneHour
        }
      );

      // If we have old governance entries but no recent activity, flag inactivity
      if (governanceEntries.size() > 0 and recentActivity.size() == 0) {
        let oldestEntry = Array.foldLeft<Memory.MemoryEntry, Memory.MemoryEntry>(
          governanceEntries,
          governanceEntries[0],
          func(oldest: Memory.MemoryEntry, current: Memory.MemoryEntry): Memory.MemoryEntry {
            if (current.timestamp < oldest.timestamp) current else oldest
          }
        );

        let inactivityHours = (Time.now() - oldestEntry.timestamp) / (60 * 60_000_000_000);

        return ?{
          id = reasoningState.idCounter;
          timestamp = Time.now();
          title = "Governance Inactivity Detected";
          description = "No governance activity for " # Int.toText(inactivityHours) # 
                       " hours since last proposal or vote";
          traceIds = [];
          severity = "warning";
          tags = ["governance", "inactivity", "system"];
          sourceInsightIds = [oldestEntry.id];
        };
      };

      null
    };

    /// Detect system latency spikes
    private func detectSystemLatencySpike(entries: [Memory.MemoryEntry]): async ?ReasoningOutput {
      let performanceEntries = Array.filter<Memory.MemoryEntry>(
        entries,
        func(entry: Memory.MemoryEntry): Bool {
          Text.contains(entry.summary, #text "latency") or
          Text.contains(entry.summary, #text "slow") or
          Text.contains(entry.summary, #text "timeout") or
          Text.contains(entry.summary, #text "performance")
        }
      );

      if (performanceEntries.size() >= 3) {
        let tenMinutes = 10 * 60_000_000_000; // 10 minutes in nanoseconds
        let recentPerformanceIssues = Array.filter<Memory.MemoryEntry>(
          performanceEntries,
          func(entry: Memory.MemoryEntry): Bool {
            (Time.now() - entry.timestamp) <= tenMinutes
          }
        );

        if (recentPerformanceIssues.size() >= 3) {
          let sourceIds = Array.map<Memory.MemoryEntry, Nat>(recentPerformanceIssues, func(e) = e.id);
          
          return ?{
            id = reasoningState.idCounter;
            timestamp = Time.now();
            title = "System Latency Spike";
            description = Nat.toText(recentPerformanceIssues.size()) # 
                         " performance issues detected in the last 10 minutes";
            traceIds = [];
            severity = "warning";
            tags = ["performance", "latency", "system"];
            sourceInsightIds = sourceIds;
          };
        };
      };

      null
    };

    /// Detect repeated error clusters from same source
    private func detectRepeatedErrorCluster(entries: [Memory.MemoryEntry]): async ?ReasoningOutput {
      let errorEntries = Array.filter<Memory.MemoryEntry>(
        entries,
        func(entry: Memory.MemoryEntry): Bool {
          Text.contains(entry.summary, #text "error") or
          Text.contains(entry.summary, #text "Error") or
          Text.contains(entry.summary, #text "failed") or
          Text.contains(entry.summary, #text "Failed")
        }
      );

      if (errorEntries.size() < 5) return null;

      // Group errors by source canister
      let sourceGroups = HashMap.HashMap<Text, Buffer.Buffer<Memory.MemoryEntry>>(10, Text.equal, Text.hash);
      
      for (entry in errorEntries.vals()) {
        switch (sourceGroups.get(entry.category)) {
          case (?buffer) buffer.add(entry);
          case null {
            let newBuffer = Buffer.Buffer<Memory.MemoryEntry>(5);
            newBuffer.add(entry);
            sourceGroups.put(entry.category, newBuffer);
          };
        };
      };

      // Check each source for error clusters
      for ((source, errorBuffer) in sourceGroups.entries()) {
        let sourceErrors = Buffer.toArray(errorBuffer);
        if (sourceErrors.size() >= 5) {
          let fiveMinutes = 5 * 60_000_000_000; // 5 minutes in nanoseconds
          let recentErrors = Array.filter<Memory.MemoryEntry>(
            sourceErrors,
            func(entry: Memory.MemoryEntry): Bool {
              (Time.now() - entry.timestamp) <= fiveMinutes
            }
          );

          if (recentErrors.size() >= 5) {
            let sourceIds = Array.map<Memory.MemoryEntry, Nat>(recentErrors, func(e) = e.id);
            
            return ?{
              id = reasoningState.idCounter;
              timestamp = Time.now();
              title = "Repeated Error Cluster";
              description = Nat.toText(recentErrors.size()) # 
                           " errors from " # source # " in the last 5 minutes";
              traceIds = [];
              severity = "critical";
              tags = ["error", "cluster", source];
              sourceInsightIds = sourceIds;
            };
          };
        };
      };

      null
    };

    /// Detect cross-module correlations using trace linking
    private func detectCrossModuleCorrelation(traceMap: HashMap.HashMap<Text, [Memory.MemoryEntry]>): async ?ReasoningOutput {
      for ((traceId, traceEntries) in traceMap.entries()) {
        if (traceEntries.size() >= 3) {
          // Check if entries span multiple categories (modules)
          let categories = Buffer.Buffer<Text>(5);
          for (entry in traceEntries.vals()) {
            var categoryExists = false;
            for (cat in categories.vals()) {
              if (cat == entry.category) {
                categoryExists := true;
              };
            };
            if (not categoryExists) {
              categories.add(entry.category);
            };
          };

          if (categories.size() >= 2) {
            // Check for error patterns across modules
            let errorEntries = Array.filter<Memory.MemoryEntry>(
              traceEntries,
              func(entry: Memory.MemoryEntry): Bool {
                Text.contains(entry.summary, #text "error") or
                Text.contains(entry.summary, #text "fail")
              }
            );

            if (errorEntries.size() >= 2) {
              let sourceIds = Array.map<Memory.MemoryEntry, Nat>(errorEntries, func(e) = e.id);
              
              return ?{
                id = reasoningState.idCounter;
                timestamp = Time.now();
                title = "Cross-Module Error Correlation";
                description = "Errors detected across " # Nat.toText(categories.size()) # 
                             " modules for trace " # traceId;
                traceIds = [traceId];
                severity = "warning";
                tags = ["correlation", "error", "multi-module"];
                sourceInsightIds = sourceIds;
              };
            };
          };
        };
      };

      null
    };

    // =============================================================================
    // 🧠 ADVANCED PATTERN DETECTION ALGORITHMS
    // =============================================================================

    /// Detect statistical anomalies using baseline deviation analysis
    private func detectStatisticalAnomalies(entries: [Memory.MemoryEntry]): async ?ReasoningOutput {
      Debug.print("🧠 ADVANCED: Running statistical anomaly detection");
      
      // Group entries by category for baseline analysis
      let categoryGroups = HashMap.HashMap<Text, Buffer.Buffer<Memory.MemoryEntry>>(20, Text.equal, Text.hash);
      
      for (entry in entries.vals()) {
        switch (categoryGroups.get(entry.category)) {
          case (?buffer) buffer.add(entry);
          case null {
            let newBuffer = Buffer.Buffer<Memory.MemoryEntry>(10);
            newBuffer.add(entry);
            categoryGroups.put(entry.category, newBuffer);
          };
        };
      };

      // Analyze each category for statistical anomalies
      for ((category, categoryBuffer) in categoryGroups.entries()) {
        let categoryEntries = Buffer.toArray(categoryBuffer);
        if (categoryEntries.size() < 10) {
          // Skip categories with insufficient data
        } else {
          // Calculate recent activity frequency (last hour)
          let oneHour = 60 * 60_000_000_000; // 1 hour in nanoseconds
          let recentEntries = Array.filter<Memory.MemoryEntry>(
            categoryEntries,
            func(entry: Memory.MemoryEntry): Bool {
              (Time.now() - entry.timestamp) <= oneHour
            }
          );

          let currentFrequency = Float.fromInt(recentEntries.size());
          
          // Get or create baseline for this category
          let baseline = switch (statisticalBaselines.get(category)) {
            case (?existing) existing;
            case null {
              // Create new baseline from historical data
              let historicalFrequency = calculateHistoricalFrequency(categoryEntries);
              let newBaseline: StatisticalBaseline = {
                category = category;
                avgFrequency = historicalFrequency.0;
                stdDeviation = historicalFrequency.1;
                lastCalculated = Time.now();
                sampleSize = categoryEntries.size();
              };
              statisticalBaselines.put(category, newBaseline);
              newBaseline
            };
          };

          // Calculate Z-score for anomaly detection
          let zScore = if (baseline.stdDeviation > 0.0) {
            (currentFrequency - baseline.avgFrequency) / baseline.stdDeviation
          } else { 0.0 };

          // Flag as anomaly if Z-score exceeds threshold (2.5 = ~99% confidence)
          if (Float.abs(zScore) > 2.5) {
            let anomalyType = if (zScore > 0.0) "spike" else "drop";
            let sourceIds = Array.map<Memory.MemoryEntry, Nat>(recentEntries, func(e) = e.id);
            
            return ?{
              id = reasoningState.idCounter;
              timestamp = Time.now();
              title = "Statistical Anomaly Detected";
              description = "Unusual " # anomalyType # " in " # category # " activity: " # 
                           Float.toText(currentFrequency) # " events vs baseline " # 
                           Float.toText(baseline.avgFrequency) # " (Z-score: " # Float.toText(zScore) # ")";
              traceIds = [];
              severity = if (Float.abs(zScore) > 3.0) "critical" else "warning";
              tags = ["anomaly", "statistical", category, anomalyType];
              sourceInsightIds = sourceIds;
            };
          };
        };
      };

      null
    };

    /// Detect trend-based predictions for future issues  
    private func detectTrendPredictions(entries: [Memory.MemoryEntry]): async ?ReasoningOutput {
      Debug.print("🧠 ADVANCED: Running trend prediction analysis");
      
      // Update trend data with recent entries
      for (entry in entries.vals()) {
        // Extract numeric metrics from summaries (simplified approach)
        let trendValue = extractTrendValue(entry);
        if (trendValue > 0.0) {
          trendData.add({
            timestamp = entry.timestamp;
            value = trendValue;
            category = entry.category;
          });
        };
      };

      // Keep only recent trend data (last 24 hours)
      let twentyFourHours = 24 * 60 * 60_000_000_000;
      let recentTrends = Buffer.Buffer<TrendDataPoint>(1000);
      for (dataPoint in trendData.vals()) {
        if ((Time.now() - dataPoint.timestamp) <= twentyFourHours) {
          recentTrends.add(dataPoint);
        };
      };
      trendData := recentTrends;

      // Analyze trends by category
      let categoryTrends = HashMap.HashMap<Text, Buffer.Buffer<TrendDataPoint>>(20, Text.equal, Text.hash);
      for (dataPoint in trendData.vals()) {
        switch (categoryTrends.get(dataPoint.category)) {
          case (?buffer) buffer.add(dataPoint);
          case null {
            let newBuffer = Buffer.Buffer<TrendDataPoint>(100);
            newBuffer.add(dataPoint);
            categoryTrends.put(dataPoint.category, newBuffer);
          };
        };
      };

      // Look for concerning trends
      for ((category, trendBuffer) in categoryTrends.entries()) {
        let trends = Buffer.toArray(trendBuffer);
        if (trends.size() < 5) {
          // Skip categories with insufficient trend data
        } else {
          // Calculate simple linear trend (slope)
          let slope = calculateTrendSlope(trends);
          let avgValue = Array.foldLeft<TrendDataPoint, Float>(
            trends, 0.0, func(acc, point) = acc + point.value
          ) / Float.fromInt(trends.size());

          // Predict future values based on trend
          let oneHourFromNow = Time.now() + (60 * 60_000_000_000);
          let predictedValue = avgValue + (slope * Float.fromInt(oneHourFromNow - trends[trends.size()-1].timestamp));

          // Flag concerning predictions
          if (slope > 0.1 and predictedValue > (avgValue * 2.0)) {
            let sourceIds = Array.map<Memory.MemoryEntry, Nat>(
              Array.filter<Memory.MemoryEntry>(entries, func(e) = e.category == category),
              func(e) = e.id
            );
            
            return ?{
              id = reasoningState.idCounter;
              timestamp = Time.now();
              title = "Concerning Trend Prediction";
              description = "Upward trend in " # category # " metrics may cause issues. " #
                           "Current avg: " # Float.toText(avgValue) # ", predicted: " # Float.toText(predictedValue) #
                           " (slope: " # Float.toText(slope) # ")";
              traceIds = [];
              severity = if (predictedValue > (avgValue * 3.0)) "warning" else "info";
              tags = ["prediction", "trend", category, "increasing"];
              sourceInsightIds = sourceIds;
            };
          };
        };
      };

      null
    };

    /// Detect behavioral anomalies in user/system patterns
    private func detectBehavioralAnomalies(_entries: [Memory.MemoryEntry]): async ?ReasoningOutput {
      Debug.print("🧠 ADVANCED: Running behavioral anomaly detection");
      null // Simplified for now - will implement helper functions next
    };

    /// Detect cascading failure patterns
    private func detectCascadingFailures(_entries: [Memory.MemoryEntry]): async ?ReasoningOutput {
      Debug.print("🧠 ADVANCED: Running cascading failure detection");
      null // Simplified for now - will implement helper functions next
    };

    // =============================================================================
    // 🔥 REAL-TIME STREAMING ANALYSIS SYSTEM
    // =============================================================================

    /// Enable real-time streaming analysis with default configuration
    public func enableStreamingAnalysis(): async Bool {
      Debug.print("🔥 STREAMING: Enabling real-time analysis");
      
      // Initialize default event triggers
      let defaultTriggers: [EventTrigger] = [
        {
          triggerType = "keyword";
          condition = "error,fail,timeout,critical";
          threshold = 1.0;
          enabled = true;
          cooldownPeriod = 30_000_000_000; // 30 seconds
          lastTriggered = null;
        },
        {
          triggerType = "frequency";
          condition = "any";
          threshold = 10.0; // 10 events in window
          enabled = true;
          cooldownPeriod = 60_000_000_000; // 1 minute
          lastTriggered = null;
        },
        {
          triggerType = "severity";
          condition = "critical";
          threshold = 1.0;
          enabled = true;
          cooldownPeriod = 10_000_000_000; // 10 seconds
          lastTriggered = null;
        }
      ];

      // Initialize sliding windows
      let defaultWindows: [SlidingWindow] = [
        {
          windowSize = 5 * 60_000_000_000; // 5 minutes
          slideInterval = 30_000_000_000; // 30 seconds
          lastProcessed = Time.now();
          entryCount = 0;
          alertThreshold = 20; // Alert if >20 events in 5 minutes
        },
        {
          windowSize = 60 * 60_000_000_000; // 1 hour
          slideInterval = 5 * 60_000_000_000; // 5 minutes
          lastProcessed = Time.now();
          entryCount = 0;
          alertThreshold = 100; // Alert if >100 events in 1 hour
        }
      ];

      streamingState := {
        eventTriggers = defaultTriggers;
        slidingWindows = defaultWindows;
        realtimeAlerts = [];
        alertCounter = 1;
        streamingEnabled = true;
        lastProcessingTime = Time.now();
      };

      true
    };

    /// Disable real-time streaming analysis
    public func disableStreamingAnalysis(): async Bool {
      Debug.print("🔥 STREAMING: Disabling real-time analysis");
      streamingState := {
        eventTriggers = [];
        slidingWindows = [];
        realtimeAlerts = streamingState.realtimeAlerts; // Keep existing alerts
        alertCounter = streamingState.alertCounter;
        streamingEnabled = false;
        lastProcessingTime = Time.now();
      };
      true
    };

    /// Process incoming event for real-time analysis
    public func processRealtimeEvent(entry: Memory.MemoryEntry): async [RealtimeAlert] {
      if (not streamingState.streamingEnabled or isProcessing) {
        return [];
      };

      isProcessing := true;
      let alerts = Buffer.Buffer<RealtimeAlert>(5);

      // Add to event queue
      eventQueue.add(entry);

      // Check event triggers
      for (trigger in streamingState.eventTriggers.vals()) {
        if (trigger.enabled and shouldTriggerEvent(trigger, entry)) {
          switch (await executeEventTrigger(trigger, entry)) {
            case (?alert) alerts.add(alert);
            case null {};
          };
        };
      };

      // Process sliding windows
      let windowAlerts = await processSlidingWindows(entry);
      for (alert in windowAlerts.vals()) {
        alerts.add(alert);
      };

      // Update streaming state with new alerts
      let newAlerts = Buffer.toArray(alerts);
      let updatedAlerts = Array.append<RealtimeAlert>(streamingState.realtimeAlerts, newAlerts);
      
      streamingState := {
        eventTriggers = streamingState.eventTriggers;
        slidingWindows = streamingState.slidingWindows;
        realtimeAlerts = updatedAlerts;
        alertCounter = streamingState.alertCounter + newAlerts.size();
        streamingEnabled = streamingState.streamingEnabled;
        lastProcessingTime = Time.now();
      };

      isProcessing := false;
      newAlerts
    };

    /// Run continuous sliding window analysis
    public func runSlidingWindowAnalysis(): async [RealtimeAlert] {
      if (not streamingState.streamingEnabled or isProcessing) {
        return [];
      };

      isProcessing := true;
      let alerts = Buffer.Buffer<RealtimeAlert>(5);
      let currentTime = Time.now();

      // Process each sliding window
      let updatedWindows = Buffer.Buffer<SlidingWindow>(streamingState.slidingWindows.size());
      
      for (window in streamingState.slidingWindows.vals()) {
        let timeSinceLastSlide = currentTime - window.lastProcessed;
        
        if (timeSinceLastSlide >= window.slideInterval) {
          // Time to slide the window
          let windowStart = currentTime - window.windowSize;
          let windowEntries = Array.filter<Memory.MemoryEntry>(
            Buffer.toArray(eventQueue),
            func(entry: Memory.MemoryEntry): Bool {
              entry.timestamp >= windowStart and entry.timestamp <= currentTime
            }
          );

          let entryCount = windowEntries.size();
          
          // Check if threshold exceeded
          if (entryCount > window.alertThreshold) {
            let alert: RealtimeAlert = {
              id = streamingState.alertCounter;
              timestamp = currentTime;
              alertType = "threshold";
              severity = if (entryCount > (window.alertThreshold * 2)) "critical" else "warning";
              message = "Sliding window threshold exceeded: " # Nat.toText(entryCount) # 
                       " events in " # Int.toText(window.windowSize / 60_000_000_000) # " minutes " #
                       "(threshold: " # Nat.toText(window.alertThreshold) # ")";
              sourcePattern = "sliding_window_" # Int.toText(window.windowSize);
              autoEscalated = entryCount > (window.alertThreshold * 3);
              acknowledged = false;
              resolvedAt = null;
            };
            alerts.add(alert);
          };

          // Update window
          let updatedWindow: SlidingWindow = {
            windowSize = window.windowSize;
            slideInterval = window.slideInterval;
            lastProcessed = currentTime;
            entryCount = entryCount;
            alertThreshold = window.alertThreshold;
          };
          updatedWindows.add(updatedWindow);
        } else {
          updatedWindows.add(window);
        };
      };

      // Clean old entries from event queue (keep last 1000)
      let queueArray = Buffer.toArray(eventQueue);
      if (queueArray.size() > 1000) {
        eventQueue := Buffer.Buffer<Memory.MemoryEntry>(100);
        let keepEntries = Array.subArray<Memory.MemoryEntry>(queueArray, queueArray.size() - 1000, 1000);
        for (entry in keepEntries.vals()) {
          eventQueue.add(entry);
        };
      };

      // Update streaming state
      let newAlerts = Buffer.toArray(alerts);
      let updatedAlerts = Array.append<RealtimeAlert>(streamingState.realtimeAlerts, newAlerts);
      
      streamingState := {
        eventTriggers = streamingState.eventTriggers;
        slidingWindows = Buffer.toArray(updatedWindows);
        realtimeAlerts = updatedAlerts;
        alertCounter = streamingState.alertCounter + newAlerts.size();
        streamingEnabled = streamingState.streamingEnabled;
        lastProcessingTime = currentTime;
      };

      isProcessing := false;
      newAlerts
    };

    /// Check if event should trigger analysis
    private func shouldTriggerEvent(trigger: EventTrigger, entry: Memory.MemoryEntry): Bool {
      // Check cooldown period
      switch (trigger.lastTriggered) {
        case (?lastTime) {
          if ((Time.now() - lastTime) < trigger.cooldownPeriod) {
            return false;
          };
        };
        case null {};
      };

      // Check trigger conditions
      switch (trigger.triggerType) {
        case ("keyword") {
          let keywords = Text.split(trigger.condition, #char ',');
          for (keyword in keywords) {
            if (Text.contains(entry.summary, #text keyword) or 
                Text.contains(entry.category, #text keyword)) {
              return true;
            };
          };
          false
        };
        case ("frequency") {
          // For frequency triggers, we need to check recent event count
          let recentEvents = Array.filter<Memory.MemoryEntry>(
            Buffer.toArray(eventQueue),
            func(e: Memory.MemoryEntry): Bool {
              (Time.now() - e.timestamp) <= trigger.cooldownPeriod
            }
          );
          Float.fromInt(recentEvents.size()) >= trigger.threshold
        };
        case ("severity") {
          // This would require reasoning analysis to determine severity
          Text.contains(entry.summary, #text "critical") or
          Text.contains(entry.summary, #text "emergency")
        };
        case _ false;
      }
    };

    /// Execute event trigger and generate alert
    private func executeEventTrigger(trigger: EventTrigger, entry: Memory.MemoryEntry): async ?RealtimeAlert {
      Debug.print("🔥 STREAMING: Executing trigger: " # trigger.triggerType);

      // Run rapid pattern analysis on recent events
      let recentEntries = Array.filter<Memory.MemoryEntry>(
        Buffer.toArray(eventQueue),
        func(e: Memory.MemoryEntry): Bool {
          (Time.now() - e.timestamp) <= trigger.cooldownPeriod
        }
      );

      // Quick pattern detection
      let patternDetected = detectQuickPattern(recentEntries, entry);
      
      switch (patternDetected) {
        case (?pattern) {
          let alert: RealtimeAlert = {
            id = streamingState.alertCounter;
            timestamp = Time.now();
            alertType = "pattern";
            severity = pattern.severity;
            message = "Real-time pattern detected: " # pattern.title # " - " # pattern.description;
            sourcePattern = trigger.triggerType # "_" # trigger.condition;
            autoEscalated = pattern.severity == "critical";
            acknowledged = false;
            resolvedAt = null;
          };
          
          // Update trigger last fired time
          updateTriggerLastFired(trigger);
          
          ?alert
        };
        case null null;
      }
    };

    /// Quick pattern detection for real-time analysis
    private func detectQuickPattern(recentEntries: [Memory.MemoryEntry], triggerEntry: Memory.MemoryEntry): ?ReasoningOutput {
      // Rapid error clustering
      let errorEntries = Array.filter<Memory.MemoryEntry>(
        recentEntries,
        func(entry: Memory.MemoryEntry): Bool {
          Text.contains(entry.summary, #text "error") or
          Text.contains(entry.summary, #text "fail")
        }
      );

      if (errorEntries.size() >= 3) {
        return ?{
          id = 0; // Temporary ID for real-time detection
          timestamp = Time.now();
          title = "Real-time Error Cluster";
          description = "Rapid error clustering detected: " # Nat.toText(errorEntries.size()) # 
                       " errors in last " # Int.toText(30) # " seconds";
          traceIds = [];
          severity = if (errorEntries.size() > 5) "critical" else "warning";
          tags = ["realtime", "error", "cluster"];
          sourceInsightIds = Array.map<Memory.MemoryEntry, Nat>(errorEntries, func(e) = e.id);
        };
      };

      // Check for financial anomalies
      if (Text.contains(triggerEntry.category, #text "financial") or
          Text.contains(triggerEntry.summary, #text "payment")) {
        let financialEntries = Array.filter<Memory.MemoryEntry>(
          recentEntries,
          func(entry: Memory.MemoryEntry): Bool {
            Text.contains(entry.category, #text "financial") or
            Text.contains(entry.summary, #text "payment")
          }
        );

        if (financialEntries.size() > 10) {
          return ?{
            id = 0;
            timestamp = Time.now();
            title = "High Financial Activity";
            description = "Unusual financial activity spike: " # Nat.toText(financialEntries.size()) # 
                         " transactions detected in short timeframe";
            traceIds = [];
            severity = "warning";
            tags = ["realtime", "financial", "spike"];
            sourceInsightIds = Array.map<Memory.MemoryEntry, Nat>(financialEntries, func(e) = e.id);
          };
        };
      };

      null
    };

    /// Process sliding windows for continuous monitoring
    private func processSlidingWindows(entry: Memory.MemoryEntry): async [RealtimeAlert] {
      let alerts = Buffer.Buffer<RealtimeAlert>(3);
      // This would process sliding windows in real-time
      // For now, returning empty array - full implementation would analyze window patterns
      Buffer.toArray(alerts)
    };

    /// Update trigger last fired timestamp
    private func updateTriggerLastFired(trigger: EventTrigger) {
      // This would update the trigger's lastTriggered timestamp
      // Implementation would modify the trigger in streamingState
    };

    // =============================================================================
    // 🔥 STREAMING ANALYSIS PUBLIC APIS
    // =============================================================================

    /// Get current real-time alerts
    public func getCurrentRealtimeAlerts(): async [RealtimeAlert] {
      streamingState.realtimeAlerts
    };

    /// Acknowledge a real-time alert
    public func acknowledgeRealtimeAlert(alertId: Nat): async Bool {
      let updatedAlerts = Array.map<RealtimeAlert, RealtimeAlert>(
        streamingState.realtimeAlerts,
        func(alert: RealtimeAlert): RealtimeAlert {
          if (alert.id == alertId) {
            {
              id = alert.id;
              timestamp = alert.timestamp;
              alertType = alert.alertType;
              severity = alert.severity;
              message = alert.message;
              sourcePattern = alert.sourcePattern;
              autoEscalated = alert.autoEscalated;
              acknowledged = true;
              resolvedAt = ?Time.now();
            }
          } else {
            alert
          }
        }
      );

      streamingState := {
        eventTriggers = streamingState.eventTriggers;
        slidingWindows = streamingState.slidingWindows;
        realtimeAlerts = updatedAlerts;
        alertCounter = streamingState.alertCounter;
        streamingEnabled = streamingState.streamingEnabled;
        lastProcessingTime = Time.now();
      };

      true
    };

    /// Get streaming status information
    public func getStreamingStatus(): async {
      enabled: Bool;
      totalAlerts: Nat;
      activeAlerts: Nat;
      criticalAlerts: Nat;
      lastProcessingTime: Int;
      eventQueueSize: Nat;
    } {
      let activeAlerts = Array.filter<RealtimeAlert>(
        streamingState.realtimeAlerts,
        func(alert: RealtimeAlert): Bool { not alert.acknowledged }
      );
      let criticalAlerts = Array.filter<RealtimeAlert>(
        streamingState.realtimeAlerts,
        func(alert: RealtimeAlert): Bool { alert.severity == "critical" }
      );

      {
        enabled = streamingState.streamingEnabled;
        totalAlerts = streamingState.realtimeAlerts.size();
        activeAlerts = activeAlerts.size();
        criticalAlerts = criticalAlerts.size();
        lastProcessingTime = streamingState.lastProcessingTime;
        eventQueueSize = eventQueue.size();
      }
    };

    // =============================================================================
    // 🔧 HELPER FUNCTIONS FOR ADVANCED PATTERN DETECTION
    // =============================================================================

    /// Calculate historical frequency and standard deviation for a category
    private func calculateHistoricalFrequency(entries: [Memory.MemoryEntry]): (Float, Float) {
      if (entries.size() < 2) return (1.0, 0.0);
      
      // Group entries by hour for frequency calculation  
      let intHash = func(x: Int): Nat32 { 
        // Simple hash function for Int values
        let abs_x = if (x >= 0) x else -x;
        Nat32.fromNat(Int.abs(abs_x) % 2147483647)
      };
      let hourlyGroups = HashMap.HashMap<Int, Nat>(50, Int.equal, intHash);
      let oneHour = 60 * 60_000_000_000; // 1 hour in nanoseconds
      
      for (entry in entries.vals()) {
        let hourBucket = entry.timestamp / oneHour;
        switch (hourlyGroups.get(hourBucket)) {
          case (?count) hourlyGroups.put(hourBucket, count + 1);
          case null hourlyGroups.put(hourBucket, 1);
        };
      };
      
      let frequencies = Buffer.Buffer<Float>(hourlyGroups.size());
      for ((_, count) in hourlyGroups.entries()) {
        frequencies.add(Float.fromInt(count));
      };
      
      let freqArray = Buffer.toArray(frequencies);
      if (freqArray.size() == 0) return (1.0, 0.0);
      
      // Calculate mean
      let mean = Array.foldLeft<Float, Float>(freqArray, 0.0, func(acc, freq) = acc + freq) / Float.fromInt(freqArray.size());
      
      // Calculate standard deviation
      let variance = Array.foldLeft<Float, Float>(freqArray, 0.0, func(acc, freq) = acc + ((freq - mean) * (freq - mean))) / Float.fromInt(freqArray.size());
      let stdDev = Float.sqrt(variance);
      
      (mean, stdDev)
    };

    /// Extract trend value from memory entry (simplified heuristic)
    private func extractTrendValue(entry: Memory.MemoryEntry): Float {
      // Look for numeric patterns in summaries (simplified)
      if (Text.contains(entry.summary, #text "latency")) {
        return 1.0; // Base latency indicator
      };
      if (Text.contains(entry.summary, #text "error")) {
        return 2.0; // Error weight
      };
      if (Text.contains(entry.summary, #text "slow")) {
        return 1.5; // Performance indicator
      };
      return 0.0; // No extractable trend value
    };

    /// Calculate trend slope for prediction analysis
    private func calculateTrendSlope(trends: [TrendDataPoint]): Float {
      if (trends.size() < 2) return 0.0;
      
      let n = Float.fromInt(trends.size());
      var sumX = 0.0;
      var sumY = 0.0;
      var sumXY = 0.0;
      var sumXX = 0.0;
      
      for (i in trends.keys()) {
        let x = Float.fromInt(trends[i].timestamp);
        let y = trends[i].value;
        sumX := sumX + x;
        sumY := sumY + y;
        sumXY := sumXY + (x * y);
        sumXX := sumXX + (x * x);
      };
      
      let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
      if (Float.isNaN(slope)) 0.0 else slope
    };

    /// Extract entity ID from memory entry for behavioral analysis
    private func _extractEntityId(entry: Memory.MemoryEntry): Text {
      switch (entry.traceId) {
        case (?traceId) traceId;
        case null entry.category; // Fall back to category grouping
      }
    };

    /// Calculate behavior patterns from activities
    private func _calculateBehaviorPatterns(activities: [Memory.MemoryEntry]): [(Text, Float)] {
      let patternMap = HashMap.HashMap<Text, Nat>(20, Text.equal, Text.hash);
      
      for (activity in activities.vals()) {
        let pattern = if (Text.contains(activity.summary, #text "payment")) {
          "payment_activity"
        } else if (Text.contains(activity.summary, #text "governance")) {
          "governance_activity"
        } else if (Text.contains(activity.summary, #text "error")) {
          "error_activity"
        } else {
          "general_activity"
        };
        
        switch (patternMap.get(pattern)) {
          case (?count) patternMap.put(pattern, count + 1);
          case null patternMap.put(pattern, 1);
        };
      };
      
      let patterns = Buffer.Buffer<(Text, Float)>(patternMap.size());
      for ((pattern, count) in patternMap.entries()) {
        patterns.add((pattern, Float.fromInt(count) / Float.fromInt(activities.size())));
      };
      
      Buffer.toArray(patterns)
    };

    /// Infer entity type from activities
    private func _inferEntityType(activities: [Memory.MemoryEntry]): Text {
      let hasPayments = Array.find<Memory.MemoryEntry>(activities, func(a) = Text.contains(a.summary, #text "payment")) != null;
      let hasGovernance = Array.find<Memory.MemoryEntry>(activities, func(a) = Text.contains(a.summary, #text "governance")) != null;
      
      if (hasPayments and hasGovernance) "power_user"
      else if (hasPayments) "financial_user"
      else if (hasGovernance) "governance_user"
      else "system_component"
    };

    /// Detect pattern deviations for behavioral anomalies
    private func _detectPatternDeviations(currentPatterns: [(Text, Float)], baselinePatterns: [(Text, Float)], threshold: Float): [Text] {
      let anomalies = Buffer.Buffer<Text>(5);
      
      for ((pattern, currentFreq) in currentPatterns.vals()) {
        let baselineFreq = switch (Array.find<(Text, Float)>(baselinePatterns, func((p, _)) = p == pattern)) {
          case (?(_, freq)) freq;
          case null 0.0;
        };
        
        let deviation = Float.abs(currentFreq - baselineFreq);
        if (deviation > threshold) {
          anomalies.add(pattern # " deviation: " # Float.toText(deviation));
        };
      };
      
      Buffer.toArray(anomalies)
    };

    /// Check if two errors are likely cascade-related
    private func isLikelyCascadeRelated(sourceError: Memory.MemoryEntry, subsequentError: Memory.MemoryEntry): Bool {
      // Same trace ID indicates direct relationship
      switch (sourceError.traceId, subsequentError.traceId) {
        case (?sourceTrace, ?subsequentTrace) if (sourceTrace == subsequentTrace) return true;
        case _ {};
      };
      
      // Related categories indicate potential cascade
      if (sourceError.category == subsequentError.category) return true;
      
      // Financial -> escrow -> governance cascade pattern
      if (sourceError.category == "financial" and subsequentError.category == "escrow") return true;
      if (sourceError.category == "escrow" and subsequentError.category == "governance") return true;
      
      false
    };

    /// Calculate cascade impact score
    private func _calculateCascadeImpact(sourceEvent: Memory.MemoryEntry, triggeredEvents: [Memory.MemoryEntry]): Float {
      let baseImpact = 0.3; // Base impact for any cascade
      let triggeredImpact = Float.fromInt(triggeredEvents.size()) * 0.2;
      let categoryMultiplier = if (sourceEvent.category == "financial") 1.5 else 1.0;
      
      Float.min(1.0, baseImpact + triggeredImpact * categoryMultiplier)
    };

    /// Calculate cascade level (depth in failure chain)
    private func _calculateCascadeLevel(currentError: Memory.MemoryEntry, allErrors: [Memory.MemoryEntry]): Nat {
      var level = 0;
      for (error in allErrors.vals()) {
        if (error.timestamp < currentError.timestamp and isLikelyCascadeRelated(error, currentError)) {
          level += 1;
        };
      };
      level
    };

    /// Build trace linking map for cross-module analysis
    private func buildTraceLinking(entries: [Memory.MemoryEntry]): HashMap.HashMap<Text, [Memory.MemoryEntry]> {
      let traceMap = HashMap.HashMap<Text, Buffer.Buffer<Memory.MemoryEntry>>(50, Text.equal, Text.hash);
      
      for (entry in entries.vals()) {
        switch (entry.traceId) {
          case (?traceId) {
            switch (traceMap.get(traceId)) {
              case (?buffer) buffer.add(entry);
              case null {
                let newBuffer = Buffer.Buffer<Memory.MemoryEntry>(5);
                newBuffer.add(entry);
                traceMap.put(traceId, newBuffer);
              };
            };
          };
          case null {};
        };
      };

      let finalMap = HashMap.HashMap<Text, [Memory.MemoryEntry]>(50, Text.equal, Text.hash);
      for ((traceId, buffer) in traceMap.entries()) {
        finalMap.put(traceId, Buffer.toArray(buffer));
      };
      
      finalMap
    };

    /// Get severity priority for sorting (higher number = higher priority)
    private func getSeverityPriority(severity: Text): Nat {
      switch (severity) {
        case ("critical") 3;
        case ("warning") 2;
        case ("info") 1;
        case _ 0;
      }
    };

    /// Store reasoning result in stable storage
    private func storeReasoningResult(result: ReasoningOutput): async () {
      let resultWithId = {
        id = reasoningState.idCounter;
        timestamp = result.timestamp;
        title = result.title;
        description = result.description;
        traceIds = result.traceIds;
        severity = result.severity;
        tags = result.tags;
        sourceInsightIds = result.sourceInsightIds;
      };

      let updatedLogs = Array.append<ReasoningOutput>(reasoningState.logs, [resultWithId]);
      
      // Evict old logs if we exceed maximum
      let finalLogs = if (updatedLogs.size() > MAX_REASONING_LOGS) {
        let excessCount = updatedLogs.size() - MAX_REASONING_LOGS : Nat;
        Array.subArray<ReasoningOutput>(updatedLogs, excessCount, MAX_REASONING_LOGS)
      } else {
        updatedLogs
      };

      reasoningState := {
        idCounter = reasoningState.idCounter + 1;
        logs = finalLogs;
      };
    };

    /// Get all reasoning results
    public query func getAllReasoning(): async [ReasoningOutput] {
      // Sort by timestamp (most recent first)
      Array.sort<ReasoningOutput>(
        reasoningState.logs,
        func(a: ReasoningOutput, b: ReasoningOutput): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get reasoning results filtered by tag
    public query func getByTag(tag: Text): async [ReasoningOutput] {
      let filtered = Array.filter<ReasoningOutput>(
        reasoningState.logs,
        func(result: ReasoningOutput): Bool {
          Array.find<Text>(result.tags, func(t) = t == tag) != null
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<ReasoningOutput>(
        filtered,
        func(a: ReasoningOutput, b: ReasoningOutput): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get reasoning results filtered by severity
    public query func getBySeverity(severity: Text): async [ReasoningOutput] {
      let filtered = Array.filter<ReasoningOutput>(
        reasoningState.logs,
        func(result: ReasoningOutput): Bool {
          result.severity == severity
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<ReasoningOutput>(
        filtered,
        func(a: ReasoningOutput, b: ReasoningOutput): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get recent reasoning results (last N)
    public query func getRecent(count: Nat): async [ReasoningOutput] {
      let sorted = Array.sort<ReasoningOutput>(
        reasoningState.logs,
        func(a: ReasoningOutput, b: ReasoningOutput): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      );
      
      if (sorted.size() <= count) {
        sorted
      } else {
        Array.subArray<ReasoningOutput>(sorted, 0, count)
      }
    };

    /// Clear all reasoning logs (admin function - use with caution)
    public func clearAllReasoning(): async Bool {
      reasoningState := {
        idCounter = 1;
        logs = [];
      };
      Debug.print("🧩 REASONING: All reasoning logs cleared");
      true
    };
  };
}
