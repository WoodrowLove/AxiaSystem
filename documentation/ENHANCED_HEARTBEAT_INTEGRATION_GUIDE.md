# Enhanced Heartbeat Module Integration Example

This document demonstrates how to integrate and use the enhanced heartbeat module with triad-native patterns.

## 🚀 **Quick Start Integration**

### **1. Import the Enhanced Event Manager**

```motoko
import TriadEventManager "../heartbeat/triad_event_manager";
import EventTypes "../heartbeat/event_types";

actor Main {
    // Initialize the enhanced event manager
    private let eventManager = TriadEventManager.ProductionEventManager.EnhancedEventManager();
}
```

### **2. Basic Event Emission with Priority**

```motoko
// Critical event (immediate processing)
public func reportSecurityIncident(details: Text) : async () {
    let securityEvent = {
        id = 0;
        eventType = #AlertRaised;
        payload = #AlertRaised({
            alertType = "SECURITY_INCIDENT";
            message = details;
            timestamp = Int.abs(Time.now());
        });
    };
    
    let _ = await eventManager.emitWithPriority(
        securityEvent, 
        #critical, 
        ?"SecurityModule"
    );
};

// High priority governance event
public func submitGovernanceProposal(proposalId: Nat, title: Text) : async () {
    let proposalEvent = {
        id = 0;
        eventType = #ProposalCreated;
        payload = #ProposalCreated({
            proposalId = proposalId;
            proposer = "GovernanceCanister";
            description = title;
            createdAt = Int.abs(Time.now());
        });
    };
    
    let _ = await eventManager.emitWithPriority(
        proposalEvent, 
        #high, 
        ?"GovernanceModule"
    );
};
```

### **3. Advanced Subscription with Filtering**

```motoko
// Subscribe to governance events only
public func setupGovernanceSubscription() : async () {
    let governanceFilter: TriadEventManager.ProductionEventManager.EventFilter = {
        eventTypes = ?[#ProposalCreated, #ProposalVoted, #ProposalExecuted];
        sources = ?["GovernanceModule"];
        principals = null;
        minTimestamp = null;
        maxTimestamp = null;
        priority = ?#high;
    };
    
    let config: TriadEventManager.ProductionEventManager.SubscriptionConfig = {
        filter = ?governanceFilter;
        batchSize = 25;
        priority = #high;
        maxRetries = 3;
        retryBackoffMs = 1000;
    };
    
    let _ = await eventManager.subscribeWithFilter(
        "GovernanceEventHandler",
        config,
        handleGovernanceEvent
    );
};

// Event handler for governance events
private func handleGovernanceEvent(event: EventTypes.Event) : async () {
    switch (event.payload) {
        case (#ProposalCreated(data)) {
            Debug.print("New proposal: " # data.description);
            // Handle proposal creation logic
        };
        case (#ProposalVoted(data)) {
            Debug.print("Vote cast on proposal " # debug_show(data.proposalId));
            // Handle vote processing logic
        };
        case (#ProposalExecuted(data)) {
            Debug.print("Proposal executed: " # data.outcome);
            // Handle proposal execution logic
        };
        case (_) {
            Debug.print("Unexpected governance event");
        };
    };
};
```

### **4. Real-Time System Monitoring**

```motoko
// Monitor system health
public func getSystemHealth() : async {
    eventMetrics: TriadEventManager.ProductionEventManager.EventMetrics;
    queueStatus: {
        critical: Nat;
        high: Nat;
        normal: Nat;
        low: Nat;
        retry: Nat;
        crossCanister: Nat;
        totalCapacity: Nat;
        utilizationPercent: Float;
    };
    healthCheck: {
        status: Text;
        queueHealth: Text;
        processingHealth: Text;
        subscriberHealth: Text;
        lastProcessed: Int;
    };
} {
    let metrics = await eventManager.getMetrics();
    let queueStatus = await eventManager.getQueueStatus();
    let healthCheck = await eventManager.healthCheck();
    
    {
        eventMetrics = metrics;
        queueStatus = queueStatus;
        healthCheck = healthCheck;
    }
};

// Get detailed subscriber information
public func getSubscriberAnalytics() : async {
    totalSubscribers: Nat;
    activeSubscribers: [Text];
} {
    await eventManager.getSubscriberInfo()
};
```

### **5. Heartbeat Integration for Continuous Processing**

```motoko
// System heartbeat for continuous event processing
system func heartbeat() : async () {
    // Process events with priority-based scheduling
    switch (await eventManager.processEvents()) {
        case (#ok(result)) {
            if (result.processed > 0) {
                Debug.print("Processed " # debug_show(result.processed) # " events");
            };
            if (result.failed > 0) {
                Debug.print("Failed to process " # debug_show(result.failed) # " events");
            };
            if (result.retried > 0) {
                Debug.print("Retried " # debug_show(result.retried) # " events");
            };
        };
        case (#err(msg)) {
            Debug.print("Event processing error: " # msg);
        };
    };
    
    // Monitor system health periodically
    let health = await eventManager.healthCheck();
    if (health.status != "HEALTHY") {
        Debug.print("System health warning: " # health.status);
        
        // Emit health alert for critical issues
        if (health.status == "UNHEALTHY") {
            let alertEvent = {
                id = 0;
                eventType = #AlertRaised;
                payload = #AlertRaised({
                    alertType = "SYSTEM_HEALTH";
                    message = "Event system health degraded: " # health.queueHealth # " queues, " # health.processingHealth # " processing";
                    timestamp = Int.abs(Time.now());
                });
            };
            let _ = await eventManager.emitWithPriority(alertEvent, #critical, ?"SystemMonitor");
        };
    };
};
```

## 🎯 **Advanced Usage Patterns**

### **Identity-Anchored Event Processing**

```motoko
// Subscribe to events for specific identity
public func subscribeToIdentityEvents(identityId: Principal) : async () {
    let identityFilter: TriadEventManager.ProductionEventManager.EventFilter = {
        eventTypes = ?[#IdentityCreated, #IdentityUpdated, #DeviceRegistered];
        sources = ?["IdentityModule"];
        principals = ?[identityId];
        minTimestamp = null;
        maxTimestamp = null;
        priority = null;
    };
    
    let config: TriadEventManager.ProductionEventManager.SubscriptionConfig = {
        filter = ?identityFilter;
        batchSize = 10;
        priority = #normal;
        maxRetries = 2;
        retryBackoffMs = 500;
    };
    
    let _ = await eventManager.subscribeWithFilter(
        "Identity_" # Principal.toText(identityId),
        config,
        handleIdentityEvent
    );
};

private func handleIdentityEvent(event: EventTypes.Event) : async () {
    switch (event.payload) {
        case (#IdentityCreated(data)) {
            Debug.print("Identity created: " # Principal.toText(data.id));
            // Handle identity creation
        };
        case (#IdentityUpdated(data)) {
            Debug.print("Identity updated: " # Principal.toText(data.id));
            // Handle identity update
        };
        case (#DeviceRegistered(data)) {
            Debug.print("Device registered for user: " # data.userId);
            // Handle device registration
        };
        case (_) { /* Handle other events */ };
    };
};
```

### **Governance Event Coordination**

```motoko
// Emit governance events with triad coordination
public func castGovernanceVote(
    proposalId: Nat,
    voter: Principal,
    choice: Text,
    weight: Nat
) : async () {
    let voteEvent = {
        id = 0;
        eventType = #ProposalVoted;
        payload = #ProposalVoted({
            proposalId = proposalId;
            voter = Principal.toText(voter);
            vote = choice;
            weight = weight;
            votedAt = Int.abs(Time.now());
        });
    };
    
    // Emit as high priority governance event
    let _ = await eventManager.emitWithPriority(
        voteEvent, 
        #high, 
        ?"GovernanceCanister"
    );
    
    Debug.print("Governance vote submitted for proposal " # debug_show(proposalId));
};
```

### **Cross-Canister Event Coordination**

```motoko
// Emit events that need cross-canister coordination
public func synchronizeTriadState(
    sourceCanister: Principal,
    targetCanister: Principal,
    syncData: [Nat8]
) : async () {
    let syncEvent = {
        id = 0;
        eventType = #SystemMaintenanceCompleted;
        payload = #SystemMaintenanceCompleted({
            escrowsProcessed = 0;
            splitPaymentsRetried = 0;
            payoutsRetried = 0;
            timestamp = Int.abs(Time.now());
        });
    };
    
    // Emit as high priority for immediate coordination
    let _ = await eventManager.emitWithPriority(
        syncEvent, 
        #high, 
        ?"TriadCoordinator"
    );
    
    Debug.print("Triad state sync initiated between canisters");
};
```

## 🔧 **Performance Optimization**

### **Batch Processing Configuration**

```motoko
// Configure different batch sizes for different priorities
public func optimizeEventProcessing() : async () {
    // High-volume subscribers with large batch sizes
    let highVolumeConfig: TriadEventManager.ProductionEventManager.SubscriptionConfig = {
        filter = null; // Accept all events
        batchSize = 100; // Large batch for efficiency
        priority = #low; // Lower priority for batch processing
        maxRetries = 1; // Fewer retries for bulk processing
        retryBackoffMs = 2000;
    };
    
    let _ = await eventManager.subscribeWithFilter(
        "AnalyticsProcessor",
        highVolumeConfig,
        handleAnalyticsEvents
    );
    
    // Real-time subscribers with small batch sizes
    let realTimeConfig: TriadEventManager.ProductionEventManager.SubscriptionConfig = {
        filter = ?{
            eventTypes = ?[#AlertRaised, #EmergencyOverrideEnabled];
            sources = null;
            principals = null;
            minTimestamp = null;
            maxTimestamp = null;
            priority = ?#critical;
        };
        batchSize = 1; // Immediate processing
        priority = #critical;
        maxRetries = 5; // More retries for critical events
        retryBackoffMs = 100;
    };
    
    let _ = await eventManager.subscribeWithFilter(
        "EmergencyHandler",
        realTimeConfig,
        handleEmergencyEvents
    );
};

private func handleAnalyticsEvents(event: EventTypes.Event) : async () {
    // Batch analytics processing
    Debug.print("Processing analytics event: " # debug_show(event.eventType));
};

private func handleEmergencyEvents(event: EventTypes.Event) : async () {
    // Immediate emergency response
    Debug.print("EMERGENCY EVENT: " # debug_show(event.eventType));
};
```

## 📊 **Monitoring and Alerts**

### **System Health Monitoring**

```motoko
// Continuous health monitoring
public func monitorSystemHealth() : async () {
    let health = await eventManager.healthCheck();
    
    switch (health.status) {
        case ("HEALTHY") {
            // System operating normally
        };
        case ("WARNING") {
            Debug.print("System health warning - monitoring closely");
            // Could emit warning events or adjust processing
        };
        case ("UNHEALTHY") {
            Debug.print("CRITICAL: System health degraded");
            // Emergency procedures, scaling, or maintenance mode
            
            // Example: Emergency queue management if needed
            // let _ = await eventManager.emergencyClearQueues("EMERGENCY_CLEAR_AUTH");
        };
        case (_) {
            Debug.print("Unknown health status: " # health.status);
        };
    };
};
```

This enhanced heartbeat module transforms AxiaSystem's event processing into a production-grade, intelligent system that supports the triad architecture with priority-based processing, advanced filtering, real-time monitoring, and sophisticated error handling.

## 🎉 **Key Benefits Achieved**

1. **Priority-Based Processing**: Critical events processed immediately, governance events get high priority
2. **Advanced Filtering**: Subscribers only receive relevant events, reducing noise and improving performance  
3. **Real-Time Monitoring**: Live metrics, health checks, and performance tracking
4. **Enhanced Reliability**: Intelligent retry mechanisms, circuit breakers, and error handling
5. **Triad-Native Integration**: Built specifically for identity, governance, and wallet coordination
6. **Production Ready**: Comprehensive error handling, monitoring, and emergency management features

The enhanced heartbeat module is now ready for production use and will significantly improve the coordination and reliability of the entire AxiaSystem triad architecture.
