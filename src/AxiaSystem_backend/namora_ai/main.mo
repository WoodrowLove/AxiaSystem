/// 🧠 NamoraAI Central Intelligence Hub
/// 
/// This canister serves as the central nervous system for the entire AxiaSystem,
/// collecting insights from all canisters and providing real-time system intelligence,
/// advanced analytics, predictive monitoring, and intelligent alerting.

import Time "mo:base/Time";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";

import Insight "../types/insight";
import Alert "../types/alert";
import Analytics "../types/analytics";
import IntelligenceEngine "intelligence_engine";

actor NamoraAI {
  
  /// Stable storage for insights across upgrades
  private stable var stableInsights : [Insight.SystemInsight] = [];
  
  /// Working buffer for efficient insight management
  private var insights = Buffer.Buffer<Insight.SystemInsight>(0);
  
  /// Intelligence engine for advanced analytics and alerting
  private let intelligenceEngine = IntelligenceEngine.IntelligenceEngine();
  
  /// Maximum insights to keep in memory (prevents unbounded growth)
  private let MAX_INSIGHTS : Nat = 10000;
  
  /// Initialize from stable storage
  system func preupgrade() {
    stableInsights := Buffer.toArray(insights);
  };
  
  system func postupgrade() {
    insights := Buffer.fromArray<Insight.SystemInsight>(stableInsights);
    stableInsights := [];
  };

  /// 📥 Accepts insights from any system module
  public shared func pushInsight(insight: Insight.SystemInsight) : async () {
    // Add the insight to our buffer
    insights.add(insight);
    
    // Maintain reasonable buffer size
    if (insights.size() > MAX_INSIGHTS) {
      ignore insights.remove(0); // Remove oldest insight
    };
    
    // Log for debugging (optional)
    Debug.print("🧠 NamoraAI received insight from " # insight.source # ": " # insight.message);
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
    await pushInsight(selfInsight);
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
}
