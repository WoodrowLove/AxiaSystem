/// 🚨 NamoraAI Alert System Types
/// 
/// This module defines intelligent alerting capabilities that enable NamoraAI
/// to proactively detect patterns, anomalies, and critical system events.

module {
  /// Alert severity levels
  public type AlertSeverity = {
    #critical;    // System-threatening issues requiring immediate action
    #high;        // Significant issues requiring prompt attention
    #medium;      // Important issues that should be addressed soon
    #low;         // Minor issues or informational alerts
  };

  /// Alert categories for intelligent routing
  public type AlertCategory = {
    #security;         // Security breaches, unusual access patterns
    #performance;      // System performance degradation
    #financial;        // Financial anomalies, unusual transactions
    #operational;      // Operational issues, system health
    #compliance;       // Regulatory or policy violations
    #userBehavior;     // Unusual user behavior patterns
  };

  /// Smart alert that includes pattern analysis and recommendations
  public type SmartAlert = {
    id: Nat;
    timestamp: Int;
    severity: AlertSeverity;
    category: AlertCategory;
    title: Text;
    description: Text;
    affectedSources: [Text];     // Which canisters/modules are affected
    confidence: Float;           // AI confidence score (0.0 - 1.0)
    recommendations: [Text];     // Suggested actions
    relatedInsights: [Nat];      // IDs of insights that triggered this alert
    isResolved: Bool;
    resolvedAt: ?Int;
    resolvedBy: ?Principal;
    resolutionNotes: ?Text;
  };

  /// Anomaly detection configuration
  public type AnomalyThreshold = {
    metric: Text;                // e.g., "error_rate", "transaction_volume"
    baselineWindow: Nat;         // Minutes to calculate baseline
    deviationMultiplier: Float;  // How many standard deviations = anomaly
    minSamples: Nat;             // Minimum samples needed for analysis
  };

  /// Pattern detection rule
  public type PatternRule = {
    id: Text;
    description: Text;
    conditions: [Text];          // Conditions that must be met
    timeWindow: Nat;             // Time window in minutes
    threshold: Nat;              // How many occurrences trigger alert
    isActive: Bool;
  };

  /// Alert subscription for different stakeholders
  public type AlertSubscription = {
    subscriber: Principal;
    categories: [AlertCategory];
    severities: [AlertSeverity];
    channels: [Text];            // "dashboard", "email", "webhook"
    isActive: Bool;
  };
}
