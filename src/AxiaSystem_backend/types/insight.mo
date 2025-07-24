/// 🧠 NamoraAI Insight Types
/// 
/// This module defines the shared types for the observability layer that enables
/// NamoraAI to monitor and understand system-wide behavior across all canisters.
///
/// Every canister can emit SystemInsight events at critical junctions to provide
/// real-time visibility into system health, user behavior, and operational metrics.

module {
  /// Core insight structure for system-wide observability
  public type SystemInsight = {
    source: Text;        // Which canister/module emitted this insight
    severity: Text;      // "info", "warning", or "error"
    message: Text;       // Human-readable description of what happened
    timestamp: Int;      // Nanoseconds since epoch (Time.now())
  };

  /// Enhanced insight with optional contextual data
  public type EnhancedInsight = {
    source: Text;
    severity: Text;
    message: Text;
    timestamp: Int;
    principal: ?Text;    // Related user principal if applicable
    assetId: ?Text;      // Related asset ID if applicable
    amount: ?Nat;        // Related amount for financial operations
    txHash: ?Text;       // Related transaction hash if applicable
    metadata: ?Text;     // Additional structured data as JSON string
  };

  /// Helper function to create a basic insight
  public func createInsight(source: Text, severity: Text, message: Text, timestamp: Int) : SystemInsight {
    {
      source = source;
      severity = severity;
      message = message;
      timestamp = timestamp;
    }
  };

  /// Helper function to create an enhanced insight with context
  public func createEnhancedInsight(
    source: Text, 
    severity: Text, 
    message: Text, 
    timestamp: Int,
    principal: ?Text,
    assetId: ?Text,
    amount: ?Nat,
    txHash: ?Text,
    metadata: ?Text
  ) : EnhancedInsight {
    {
      source = source;
      severity = severity;
      message = message;
      timestamp = timestamp;
      principal = principal;
      assetId = assetId;
      amount = amount;
      txHash = txHash;
      metadata = metadata;
    }
  };
}
