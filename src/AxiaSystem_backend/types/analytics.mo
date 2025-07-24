/// 📊 NamoraAI Analytics Engine Types
/// 
/// Advanced analytics capabilities for system intelligence and predictive insights

module {
  /// Time-series metric for trend analysis
  public type Metric = {
    name: Text;
    value: Float;
    timestamp: Int;
    source: Text;
    tags: [(Text, Text)];        // Key-value metadata
  };

  /// Aggregated metrics for dashboard display
  public type MetricSummary = {
    name: Text;
    current: Float;
    average: Float;
    min: Float;
    max: Float;
    trend: Text;                 // "increasing", "decreasing", "stable"
    changePercent: Float;
    timeRange: Text;
  };

  /// System health score components
  public type HealthDimension = {
    name: Text;                  // e.g., "performance", "security", "reliability"
    score: Float;                // 0.0 to 100.0
    weight: Float;               // Importance weight
    factors: [Text];             // Contributing factors
    status: Text;                // "excellent", "good", "fair", "poor"
  };

  /// Overall system health assessment
  public type SystemHealth = {
    overallScore: Float;
    timestamp: Int;
    dimensions: [HealthDimension];
    criticalIssues: [Text];
    recommendations: [Text];
    lastUpdated: Int;
  };

  /// Predictive model output
  public type Prediction = {
    metric: Text;
    predictedValue: Float;
    confidence: Float;
    timeHorizon: Nat;            // Minutes into the future
    factors: [Text];             // What influences this prediction
    timestamp: Int;
  };

  /// Usage analytics for system optimization
  public type UsagePattern = {
    pattern: Text;               // Description of the pattern
    frequency: Nat;              // How often it occurs
    impact: Text;                // "high", "medium", "low"
    canistersInvolved: [Text];
    timeOfDay: ?Text;            // Peak usage times
    seasonality: ?Text;          // Weekly/monthly patterns
    recommendations: [Text];
  };

  /// Performance baseline for comparison
  public type PerformanceBaseline = {
    metric: Text;
    baseline: Float;
    standardDeviation: Float;
    sampleSize: Nat;
    calculatedAt: Int;
    validUntil: Int;
  };
}
