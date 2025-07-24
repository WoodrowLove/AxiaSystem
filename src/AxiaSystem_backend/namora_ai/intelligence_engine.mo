/// 🎯 NamoraAI Intelligence Engine
/// 
/// Advanced AI-powered analysis engine that processes insights to generate
/// intelligent alerts, predictions, and system health assessments.

import Time "mo:base/Time";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Nat "mo:base/Nat";

import Insight "../types/insight";
import Alert "../types/alert";
import Analytics "../types/analytics";

module {
  /// Advanced intelligence engine for pattern detection and predictions
  public class IntelligenceEngine() {
    
    // Alert management
    private var alerts = Buffer.Buffer<Alert.SmartAlert>(0);
    private var nextAlertId: Nat = 1;
    
    // Analytics storage
    private var _metrics = Buffer.Buffer<Analytics.Metric>(0);
    private var healthHistory = Buffer.Buffer<Analytics.SystemHealth>(0);
    
    // Pattern detection state
    private var _errorCounts = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
    private var _lastAnalysis: Int = 0;
    
    /// Process new insights and generate intelligent alerts
    public func processInsights(insights: [Insight.SystemInsight]) : async [Alert.SmartAlert] {
      let newAlerts = Buffer.Buffer<Alert.SmartAlert>(0);
      
      // Analyze error patterns
      let errorSpikes = detectErrorSpikes(insights);
      for (alert in errorSpikes.vals()) {
        newAlerts.add(alert);
      };
      
      // Detect security anomalies
      let securityAlerts = detectSecurityAnomalies(insights);
      for (alert in securityAlerts.vals()) {
        newAlerts.add(alert);
      };
      
      // Analyze performance patterns
      let performanceAlerts = analyzePerformancePatterns(insights);
      for (alert in performanceAlerts.vals()) {
        newAlerts.add(alert);
      };
      
      // Store generated alerts
      for (alert in newAlerts.vals()) {
        alerts.add(alert);
      };
      
      Buffer.toArray(newAlerts)
    };
    
    /// Detect error spikes across the system
    private func detectErrorSpikes(insights: [Insight.SystemInsight]) : [Alert.SmartAlert] {
      let spikes = Buffer.Buffer<Alert.SmartAlert>(0);
      let now = Time.now();
      let fiveMinutesAgo = now - (5 * 60 * 1_000_000_000);
      
      // Count recent errors by source
      let recentErrors = Array.filter<Insight.SystemInsight>(insights, func(insight) {
        insight.severity == "error" and insight.timestamp > fiveMinutesAgo
      });
      
      let errorsBySource = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
      for (error in recentErrors.vals()) {
        let count = switch(errorsBySource.get(error.source)) {
          case null 1;
          case (?c) c + 1;
        };
        errorsBySource.put(error.source, count);
      };
      
      // Generate alerts for sources with >3 errors in 5 minutes
      for ((source, count) in errorsBySource.entries()) {
        if (count >= 3) {
          let alert: Alert.SmartAlert = {
            id = nextAlertId;
            timestamp = now;
            severity = #high;
            category = #operational;
            title = "Error Spike Detected";
            description = source # " has generated " # Nat.toText(count) # " errors in the last 5 minutes";
            affectedSources = [source];
            confidence = 0.9;
            recommendations = [
              "Investigate recent changes to " # source,
              "Check system resources and dependencies",
              "Review error logs for common patterns"
            ];
            relatedInsights = [];
            isResolved = false;
            resolvedAt = null;
            resolvedBy = null;
            resolutionNotes = null;
          };
          spikes.add(alert);
          nextAlertId += 1;
        };
      };
      
      Buffer.toArray(spikes)
    };
    
    /// Detect potential security anomalies
    private func detectSecurityAnomalies(insights: [Insight.SystemInsight]) : [Alert.SmartAlert] {
      let anomalies = Buffer.Buffer<Alert.SmartAlert>(0);
      let now = Time.now();
      
      // Look for unusual admin activities
      let adminInsights = Array.filter<Insight.SystemInsight>(insights, func(insight) {
        insight.source == "admin" or insight.source == "governance"
      });
      
      if (adminInsights.size() > 10) {
        let alert: Alert.SmartAlert = {
          id = nextAlertId;
          timestamp = now;
          severity = #medium;
          category = #security;
          title = "Unusual Administrative Activity";
          description = "High volume of administrative operations detected";
          affectedSources = ["admin", "governance"];
          confidence = 0.7;
          recommendations = [
            "Review recent administrative actions",
            "Verify all admin operations were authorized",
            "Check for unusual access patterns"
          ];
          relatedInsights = [];
          isResolved = false;
          resolvedAt = null;
          resolvedBy = null;
          resolutionNotes = null;
        };
        anomalies.add(alert);
        nextAlertId += 1;
      };
      
      Buffer.toArray(anomalies)
    };
    
    /// Analyze performance patterns and predict issues
    private func analyzePerformancePatterns(insights: [Insight.SystemInsight]) : [Alert.SmartAlert] {
      let performanceAlerts = Buffer.Buffer<Alert.SmartAlert>(0);
      let now = Time.now();
      
      // Look for wallet balance warnings
      let walletWarnings = Array.filter<Insight.SystemInsight>(insights, func(insight) {
        insight.source == "wallet" and insight.severity == "warning" and 
        Text.contains(insight.message, #text "Low balance")
      });
      
      if (walletWarnings.size() >= 5) {
        let alert: Alert.SmartAlert = {
          id = nextAlertId;
          timestamp = now;
          severity = #medium;
          category = #financial;
          title = "Multiple Low Balance Warnings";
          description = "Detected " # Nat.toText(walletWarnings.size()) # " low balance warnings across the system";
          affectedSources = ["wallet"];
          confidence = 0.8;
          recommendations = [
            "Review user wallet funding patterns",
            "Consider implementing balance alerts for users",
            "Analyze if this indicates system-wide liquidity issues"
          ];
          relatedInsights = [];
          isResolved = false;
          resolvedAt = null;
          resolvedBy = null;
          resolutionNotes = null;
        };
        performanceAlerts.add(alert);
        nextAlertId += 1;
      };
      
      Buffer.toArray(performanceAlerts)
    };
    
    /// Generate system health assessment
    public func generateHealthAssessment(insights: [Insight.SystemInsight]) : async Analytics.SystemHealth {
      let now = Time.now();
      let hourAgo = now - (60 * 60 * 1_000_000_000);
      
      let recentInsights = Array.filter<Insight.SystemInsight>(insights, func(insight) {
        insight.timestamp > hourAgo
      });
      
      let errorCount = Array.size(Array.filter<Insight.SystemInsight>(recentInsights, func(i) { i.severity == "error" }));
      let warningCount = Array.size(Array.filter<Insight.SystemInsight>(recentInsights, func(i) { i.severity == "warning" }));
      let totalCount = recentInsights.size();
      
      // Calculate health dimensions
      let performanceScore = if (totalCount == 0) 100.0 else {
        Float.max(0.0, 100.0 - (Float.fromInt(errorCount * 15) + Float.fromInt(warningCount * 5)))
      };
      
      let reliabilityScore = if (errorCount == 0) 100.0 else {
        Float.max(0.0, 100.0 - Float.fromInt(errorCount * 10))
      };
      
      let securityScore = 95.0; // Placeholder - would analyze security-specific metrics
      
      let dimensions: [Analytics.HealthDimension] = [
        {
          name = "Performance";
          score = performanceScore;
          weight = 0.4;
          factors = ["Error rate", "Warning frequency"];
          status = if (performanceScore >= 80.0) "excellent" else if (performanceScore >= 60.0) "good" else "poor";
        },
        {
          name = "Reliability";
          score = reliabilityScore;
          weight = 0.4;
          factors = ["System uptime", "Error frequency"];
          status = if (reliabilityScore >= 80.0) "excellent" else if (reliabilityScore >= 60.0) "good" else "poor";
        },
        {
          name = "Security";
          score = securityScore;
          weight = 0.2;
          factors = ["Access patterns", "Authentication events"];
          status = "excellent";
        }
      ];
      
      let overallScore = performanceScore * 0.4 + reliabilityScore * 0.4 + securityScore * 0.2;
      
      let health: Analytics.SystemHealth = {
        overallScore = overallScore;
        timestamp = now;
        dimensions = dimensions;
        criticalIssues = if (errorCount > 5) ["High error rate detected"] else [];
        recommendations = 
          if (overallScore < 70.0) ["Investigate system performance issues", "Review error logs"] 
          else ["System operating normally"];
        lastUpdated = now;
      };
      
      healthHistory.add(health);
      health
    };
    
    /// Get recent alerts
    public query func getRecentAlerts() : async [Alert.SmartAlert] {
      let recentAlerts = Buffer.toArray(alerts);
      // Return last 20 alerts
      if (recentAlerts.size() <= 20) {
        recentAlerts
      } else {
        Array.subArray<Alert.SmartAlert>(recentAlerts, recentAlerts.size() - 20, 20)
      }
    };
    
    /// Get alerts by severity
    public query func getAlertsBySeverity(severity: Alert.AlertSeverity) : async [Alert.SmartAlert] {
      let allAlerts = Buffer.toArray(alerts);
      Array.filter<Alert.SmartAlert>(allAlerts, func(alert) {
        alert.severity == severity
      })
    };
    
    /// Mark alert as resolved
    public func resolveAlert(alertId: Nat, resolvedBy: Principal, notes: Text) : async Bool {
      let allAlerts = Buffer.toArray(alerts);
      var found = false;
      let updatedAlerts = Array.map<Alert.SmartAlert, Alert.SmartAlert>(allAlerts, func(alert) {
        if (alert.id == alertId and not alert.isResolved) {
          found := true;
          {
            alert with
            isResolved = true;
            resolvedAt = ?Time.now();
            resolvedBy = ?resolvedBy;
            resolutionNotes = ?notes;
          }
        } else {
          alert
        }
      });
      
      if (found) {
        alerts := Buffer.fromArray<Alert.SmartAlert>(updatedAlerts);
      };
      found
    };
  };
}
