# 🔥 Real-time Streaming Analysis Testing Guide

## Overview
The NamoraAI system now includes comprehensive real-time streaming analysis with event-driven triggers, sliding window monitoring, and threshold-based alerting.

## Test Scenarios

### 1. Enable Streaming Analysis
```bash
# Enable real-time analysis with default configuration
dfx canister call AxiaSystem_backend enableStreamingAnalysis
```

### 2. Process Real-time Events
```bash
# Test error clustering detection
dfx canister call AxiaSystem_backend processRealtimeEvent '(
  "Database connection timeout", 
  "error", 
  "Connection to primary database failed after 30 seconds", 
  vec { ("severity", "high"); ("system", "database") }
)'

# Test financial anomaly detection  
dfx canister call AxiaSystem_backend processRealtimeEvent '(
  "Large payment processed", 
  "financial", 
  "Payment of 50000 XRP processed for user_12345", 
  vec { ("amount", "50000"); ("currency", "XRP") }
)'

# Test critical system event
dfx canister call AxiaSystem_backend processRealtimeEvent '(
  "Critical system failure", 
  "critical", 
  "Main processing pipeline has stopped responding", 
  vec { ("component", "pipeline"); ("impact", "critical") }
)'
```

### 3. Sliding Window Analysis
```bash
# Run continuous monitoring analysis
dfx canister call AxiaSystem_backend runSlidingWindowAnalysis
```

### 4. Check Real-time Alerts
```bash
# Get all current alerts
dfx canister call AxiaSystem_backend getCurrentRealtimeAlerts

# Get only active (unacknowledged) alerts
dfx canister call AxiaSystem_backend getActiveRealtimeAlerts

# Get critical alerts requiring immediate attention
dfx canister call AxiaSystem_backend getCriticalRealtimeAlerts
```

### 5. Alert Management
```bash
# Acknowledge an alert (replace 1 with actual alert ID)
dfx canister call AxiaSystem_backend acknowledgeRealtimeAlert '(1)'
```

### 6. Streaming Status
```bash
# Get comprehensive streaming analysis status
dfx canister call AxiaSystem_backend getStreamingStatus
```

## Key Features Implemented

### 🚨 Event Triggers
- **Keyword Triggers**: Detect specific terms like "error", "fail", "critical"
- **Frequency Triggers**: Alert when event volume exceeds thresholds 
- **Severity Triggers**: Immediate alerts for critical events
- **Cooldown Periods**: Prevent alert spam with configurable delays

### 📊 Sliding Window Analysis  
- **5-minute windows**: Short-term event monitoring (20 event threshold)
- **1-hour windows**: Medium-term trend analysis (100 event threshold)
- **Automatic sliding**: Windows update every 30 seconds to 5 minutes
- **Queue management**: Maintains last 1000 events for analysis

### 🔥 Real-time Pattern Detection
- **Error Clustering**: Detects 3+ errors in 30 seconds
- **Financial Anomalies**: Monitors unusual payment activity spikes
- **System Health**: Rapid assessment of critical components
- **Auto-escalation**: Critical patterns trigger immediate escalation

### 📈 Alert Management
- **Severity Levels**: Info, warning, critical with auto-escalation
- **Acknowledgment**: Manual review and resolution tracking
- **Source Tracking**: Links alerts to triggering patterns/events
- **Audit Integration**: All streaming activity logged for transparency

## Expected Results

### Normal Operation
- Streaming enabled with 3 default triggers
- 2 sliding windows (5-minute and 1-hour) monitoring  
- Event queue processing real-time events
- Background pattern detection running continuously

### Alert Generation
- Immediate alerts for keyword matches ("error", "critical")
- Threshold alerts when event volume exceeds windows limits
- Pattern alerts for error clusters and anomalies
- Auto-escalation for critical severity events

### System Health
- Real-time health score based on recent anomalies
- Trend prediction for proactive monitoring
- Behavioral analysis for unusual patterns
- Cascading failure detection for system-wide issues

## Integration Points

### Memory System
- All events stored in reflexive memory for pattern learning
- Historical analysis for baseline establishment  
- Cross-system trace correlation

### Audit System
- Complete transparency of AI decision-making
- Alert generation and acknowledgment tracking
- Pattern detection reasoning logs

### Advanced Analytics
- Statistical anomaly detection with Z-score analysis
- Trend prediction using linear regression
- Behavioral profiling for entities and systems
- Cascading failure risk assessment

## Performance Considerations

- Event queue limited to 1000 entries (automatic pruning)
- Sliding windows process incrementally to reduce compute
- Cooldown periods prevent excessive processing
- Background processing doesn't block real-time responses

## Next Steps

1. **Test with real system events** to validate pattern detection
2. **Configure custom triggers** for specific business rules  
3. **Adjust thresholds** based on normal system behavior
4. **Integrate with external alerting** systems for notifications
5. **Extend pattern detection** with domain-specific algorithms
