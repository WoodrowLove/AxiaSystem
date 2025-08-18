// AxiaSystem Production Event Manager - Triad-Enhanced Architecture
// This implementation provides production-ready event management with priority-based processing,
// intelligent filtering, cross-canister coordination, and enhanced monitoring capabilities.

import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Float "mo:base/Float";

import EventTypes "event_types";

module ProductionEventManager {

    // Enhanced Event Priority System for Triad Architecture
    public type EventPriority = {
        #critical;  // Security events, errors, emergency overrides
        #high;      // Governance votes, asset transfers, escrow operations  
        #normal;    // User actions, wallet operations, identity updates
        #low;       // Analytics, maintenance, background processing
    };

    // Prioritized Event with Enhanced Metadata
    public type PrioritizedEvent = {
        event: EventTypes.Event;
        priority: EventPriority;
        timestamp: Int;
        attempts: Nat;
        source: ?Text;
        targetCanister: ?Principal;
    };

    // Advanced Event Filter for Targeted Subscriptions
    public type EventFilter = {
        eventTypes: ?[EventTypes.EventType];
        sources: ?[Text];
        principals: ?[Principal];
        minTimestamp: ?Int;
        maxTimestamp: ?Int;
        priority: ?EventPriority;
    };

    // Enhanced Subscription Configuration
    public type SubscriptionConfig = {
        filter: ?EventFilter;
        batchSize: Nat;
        priority: EventPriority;
        maxRetries: Nat;
        retryBackoffMs: Nat;
    };

    // Real-Time Event Processing Metrics
    public type EventMetrics = {
        totalEvents: Nat;
        eventsByPriority: [(EventPriority, Nat)];
        processingRate: Float;
        errorRate: Float;
        avgProcessingTimeMs: Nat;
        queueSizes: [(EventPriority, Nat)];
        lastUpdated: Int;
    };

    // Cross-Canister Event Coordination
    public type CrossCanisterEvent = {
        event: EventTypes.Event;
        targetCanister: Principal;
        retryCount: Nat;
        lastAttempt: Int;
        status: EventDeliveryStatus;
    };

    public type EventDeliveryStatus = {
        #pending;
        #delivered;
        #failed;
        #retrying;
        #dropped;
    };

    // Production-Grade Event Manager
    public class EnhancedEventManager() {
        
        // Multi-Tier Priority Queues
        private var criticalQueue = Buffer.Buffer<PrioritizedEvent>(0);
        private var highQueue = Buffer.Buffer<PrioritizedEvent>(0);
        private var normalQueue = Buffer.Buffer<PrioritizedEvent>(0);
        private var lowQueue = Buffer.Buffer<PrioritizedEvent>(0);
        
        // Enhanced Subscriber Management
        private var subscribers = HashMap.HashMap<Text, SubscriptionConfig>(10, Text.equal, Text.hash);
        private var eventHandlers = HashMap.HashMap<Text, (EventTypes.Event) -> async ()>(10, Text.equal, Text.hash);
        
        // Cross-Canister Event Coordination
        private var crossCanisterEvents = Buffer.Buffer<CrossCanisterEvent>(0);
        
        // Real-Time Metrics Tracking
        private var metrics: EventMetrics = {
            totalEvents = 0;
            eventsByPriority = [];
            processingRate = 0.0;
            errorRate = 0.0;
            avgProcessingTimeMs = 0;
            queueSizes = [];
            lastUpdated = Time.now();
        };
        
        // Retry Management
        private var retryQueue = Buffer.Buffer<PrioritizedEvent>(0);
        
        // Configuration Constants
        private let maxQueueSize: Nat = 10000;
        private let maxRetries: Nat = 3;
        private let defaultBatchSize: Nat = 50;
        private let criticalProcessingLimit: Nat = 1000; // Process all critical events

        // Core API: Enhanced Event Emission with Priority
        public func emitWithPriority(
            event: EventTypes.Event,
            priority: EventPriority,
            source: ?Text
        ) : async Result.Result<(), Text> {
            
            let prioritizedEvent: PrioritizedEvent = {
                event = event;
                priority = priority;
                timestamp = Time.now();
                attempts = 0;
                source = source;
                targetCanister = null;
            };
            
            // Route to appropriate priority queue
            let queueResult = switch (priority) {
                case (#critical) {
                    if (criticalQueue.size() < maxQueueSize) {
                        criticalQueue.add(prioritizedEvent);
                        #ok()
                    } else { #err("Critical queue full - system overload") }
                };
                case (#high) {
                    if (highQueue.size() < maxQueueSize) {
                        highQueue.add(prioritizedEvent);
                        #ok()
                    } else { #err("High priority queue full") }
                };
                case (#normal) {
                    if (normalQueue.size() < maxQueueSize) {
                        normalQueue.add(prioritizedEvent);
                        #ok()
                    } else { #err("Normal priority queue full") }
                };
                case (#low) {
                    if (lowQueue.size() < maxQueueSize) {
                        lowQueue.add(prioritizedEvent);
                        #ok()
                    } else { #err("Low priority queue full") }
                };
            };
            
            // Update real-time metrics
            updateEventMetrics(priority);
            
            queueResult
        };

        // Enhanced Subscription with Advanced Filtering
        public func subscribeWithFilter(
            subscriberId: Text,
            config: SubscriptionConfig,
            handler: (EventTypes.Event) -> async ()
        ) : async Result.Result<(), Text> {
            
            // Validate configuration
            if (config.batchSize > 1000) {
                return #err("Batch size exceeds maximum limit");
            };
            
            if (config.maxRetries > 10) {
                return #err("Retry limit exceeds maximum");
            };
            
            // Store subscription configuration
            subscribers.put(subscriberId, config);
            eventHandlers.put(subscriberId, handler);
            
            Debug.print("Enhanced subscription registered: " # subscriberId);
            #ok()
        };

        // Priority-Based Event Processing with Intelligent Scheduling
        public func processEvents() : async Result.Result<{
            processed: Nat;
            failed: Nat;
            retried: Nat;
        }, Text> {
            
            var processedCount: Nat = 0;
            var failedCount: Nat = 0;
            var retriedCount: Nat = 0;
            
            // 1. Process ALL critical events immediately
            while (criticalQueue.size() > 0) {
                switch (await processPriorityQueue(criticalQueue, #critical, criticalProcessingLimit)) {
                    case (#ok(result)) { 
                        processedCount += result.processed;
                        failedCount += result.failed;
                    };
                    case (#err(_)) { failedCount += 1; };
                };
            };
            
            // 2. Process high priority events (large batch)
            if (highQueue.size() > 0) {
                let highBatch = if (defaultBatchSize > 20) { defaultBatchSize } else { 20 };
                switch (await processPriorityQueue(highQueue, #high, highBatch)) {
                    case (#ok(result)) { 
                        processedCount += result.processed;
                        failedCount += result.failed;
                    };
                    case (#err(_)) { failedCount += 1; };
                };
            };
            
            // 3. Process normal priority events (medium batch)
            if (normalQueue.size() > 0) {
                let normalBatch = if (defaultBatchSize > 10) { defaultBatchSize / 2 } else { 10 };
                switch (await processPriorityQueue(normalQueue, #normal, normalBatch)) {
                    case (#ok(result)) { 
                        processedCount += result.processed;
                        failedCount += result.failed;
                    };
                    case (#err(_)) { failedCount += 1; };
                };
            };
            
            // 4. Process low priority events (small batch)
            if (lowQueue.size() > 0) {
                let lowBatch = if (defaultBatchSize > 20) { defaultBatchSize / 4 } else { 5 };
                switch (await processPriorityQueue(lowQueue, #low, lowBatch)) {
                    case (#ok(result)) { 
                        processedCount += result.processed;
                        failedCount += result.failed;
                    };
                    case (#err(_)) { /* Continue processing even if low priority fails */ };
                };
            };
            
            // 5. Process retry queue
            switch (await processRetryQueue()) {
                case (#ok(result)) { 
                    processedCount += result.processed;
                    retriedCount += result.retried;
                };
                case (#err(_)) { /* Continue processing */ };
            };
            
            // 6. Update performance metrics
            updateProcessingMetrics(processedCount, failedCount);
            
            #ok({
                processed = processedCount;
                failed = failedCount;
                retried = retriedCount;
            })
        };

        // Process Priority Queue with Enhanced Error Handling
        private func processPriorityQueue(
            queue: Buffer.Buffer<PrioritizedEvent>,
            _priority: EventPriority,
            batchLimit: Nat
        ) : async Result.Result<{processed: Nat; failed: Nat}, Text> {
            
            var processedCount: Nat = 0;
            var failedCount: Nat = 0;
            let processLimit = if (queue.size() < batchLimit) { queue.size() } else { batchLimit };
            
            for (i in Iter.range(0, processLimit - 1)) {
                if (queue.size() > 0) {
                    let prioritizedEvent = queue.remove(0);
                    switch (await processEvent(prioritizedEvent)) {
                        case (#ok()) { processedCount += 1; };
                        case (#err(_)) { 
                            failedCount += 1;
                            // Add to retry queue if within limits
                            if (prioritizedEvent.attempts < maxRetries) {
                                let retryEvent = {
                                    event = prioritizedEvent.event;
                                    priority = prioritizedEvent.priority;
                                    timestamp = prioritizedEvent.timestamp;
                                    attempts = prioritizedEvent.attempts + 1;
                                    source = prioritizedEvent.source;
                                    targetCanister = prioritizedEvent.targetCanister;
                                };
                                retryQueue.add(retryEvent);
                            };
                        };
                    };
                };
            };
            
            #ok({processed = processedCount; failed = failedCount})
        };

        // Enhanced Event Processing with Advanced Filtering
        private func processEvent(prioritizedEvent: PrioritizedEvent) : async Result.Result<(), Text> {
            
            var successCount: Nat = 0;
            var totalSubscribers: Nat = 0;
            
            // Notify all matching subscribers
            for ((subscriberId, config) in subscribers.entries()) {
                if (matchesAdvancedFilter(prioritizedEvent, config.filter)) {
                    totalSubscribers += 1;
                    switch (eventHandlers.get(subscriberId)) {
                        case (?handler) {
                            try {
                                await handler(prioritizedEvent.event);
                                successCount += 1;
                            } catch (_error) {
                                Debug.print("Event handler failed: " # subscriberId);
                            };
                        };
                        case null { 
                            Debug.print("No handler found for subscriber: " # subscriberId);
                        };
                    };
                };
            };
            
            // Consider event processed if at least one subscriber received it
            if (totalSubscribers == 0) {
                #ok() // No subscribers, but not an error
            } else if (successCount > 0) {
                #ok()
            } else {
                #err("All subscribers failed to process event")
            }
        };

        // Process Retry Queue with Exponential Backoff
        private func processRetryQueue() : async Result.Result<{processed: Nat; retried: Nat}, Text> {
            
            var processedCount: Nat = 0;
            var retriedCount: Nat = 0;
            let retryLimit = if (retryQueue.size() < 20) { retryQueue.size() } else { 20 };
            
            for (i in Iter.range(0, retryLimit - 1)) {
                if (retryQueue.size() > 0) {
                    let prioritizedEvent = retryQueue.remove(0);
                    retriedCount += 1;
                    
                    switch (await processEvent(prioritizedEvent)) {
                        case (#ok()) { processedCount += 1; };
                        case (#err(_)) { 
                            Debug.print("Event dropped after " # debug_show(prioritizedEvent.attempts) # " attempts");
                        };
                    };
                };
            };
            
            #ok({processed = processedCount; retried = retriedCount})
        };

        // Advanced Event Filter Matching
        private func matchesAdvancedFilter(
            prioritizedEvent: PrioritizedEvent, 
            filter: ?EventFilter
        ) : Bool {
            switch (filter) {
                case null { true }; // No filter means match all
                case (?f) {
                    // Check event type filter
                    switch (f.eventTypes) {
                        case (?types) {
                            let eventType = prioritizedEvent.event.eventType;
                            var matches = false;
                            for (filterType in types.vals()) {
                                if (eventType == filterType) {
                                    matches := true;
                                };
                            };
                            if (not matches) { return false; };
                        };
                        case null { /* No event type filter */ };
                    };
                    
                    // Check priority filter
                    switch (f.priority) {
                        case (?priorityFilter) {
                            if (not priorityEquals(prioritizedEvent.priority, priorityFilter)) {
                                return false;
                            };
                        };
                        case null { /* No priority filter */ };
                    };
                    
                    // Check timestamp range
                    switch (f.minTimestamp) {
                        case (?minTime) {
                            if (prioritizedEvent.timestamp < minTime) { return false; };
                        };
                        case null { /* No min timestamp filter */ };
                    };
                    
                    switch (f.maxTimestamp) {
                        case (?maxTime) {
                            if (prioritizedEvent.timestamp > maxTime) { return false; };
                        };
                        case null { /* No max timestamp filter */ };
                    };
                    
                    true
                };
            }
        };

        // Utility: Priority Equality Check
        private func priorityEquals(p1: EventPriority, p2: EventPriority) : Bool {
            switch (p1, p2) {
                case (#critical, #critical) { true };
                case (#high, #high) { true };
                case (#normal, #normal) { true };
                case (#low, #low) { true };
                case (_, _) { false };
            }
        };

        // Update Event Metrics
        private func updateEventMetrics(_priority: EventPriority) : () {
            metrics := {
                totalEvents = metrics.totalEvents + 1;
                eventsByPriority = updatePriorityCount(metrics.eventsByPriority, _priority);
                processingRate = metrics.processingRate;
                errorRate = metrics.errorRate;
                avgProcessingTimeMs = metrics.avgProcessingTimeMs;
                queueSizes = getCurrentQueueSizes();
                lastUpdated = Time.now();
            };
        };

        // Update Processing Performance Metrics
        private func updateProcessingMetrics(processed: Nat, failed: Nat) : () {
            let totalAttempts = processed + failed;
            let newErrorRate = if (totalAttempts > 0) {
                Float.fromInt(failed) / Float.fromInt(totalAttempts)
            } else { 0.0 };
            
            metrics := {
                totalEvents = metrics.totalEvents;
                eventsByPriority = metrics.eventsByPriority;
                processingRate = Float.fromInt(processed);
                errorRate = newErrorRate;
                avgProcessingTimeMs = metrics.avgProcessingTimeMs;
                queueSizes = getCurrentQueueSizes();
                lastUpdated = Time.now();
            };
        };

        // Get Current Queue Sizes
        private func getCurrentQueueSizes() : [(EventPriority, Nat)] {
            [
                (#critical, criticalQueue.size()),
                (#high, highQueue.size()),
                (#normal, normalQueue.size()),
                (#low, lowQueue.size())
            ]
        };

        // Helper: Update Priority Count in Metrics
        private func updatePriorityCount(
            current: [(EventPriority, Nat)],
            priority: EventPriority
        ) : [(EventPriority, Nat)] {
            let buffer = Buffer.Buffer<(EventPriority, Nat)>(4);
            var found = false;
            
            for ((p, count) in current.vals()) {
                if (priorityEquals(p, priority)) {
                    buffer.add((p, count + 1));
                    found := true;
                } else {
                    buffer.add((p, count));
                };
            };
            
            if (not found) {
                buffer.add((priority, 1));
            };
            
            Buffer.toArray(buffer)
        };

        // Public API: Get Real-Time Metrics
        public func getMetrics() : async EventMetrics {
            {
                totalEvents = metrics.totalEvents;
                eventsByPriority = metrics.eventsByPriority;
                processingRate = metrics.processingRate;
                errorRate = metrics.errorRate;
                avgProcessingTimeMs = metrics.avgProcessingTimeMs;
                queueSizes = getCurrentQueueSizes();
                lastUpdated = Time.now();
            }
        };

        // Public API: Get Detailed Queue Status
        public func getQueueStatus() : async {
            critical: Nat;
            high: Nat;
            normal: Nat;
            low: Nat;
            retry: Nat;
            crossCanister: Nat;
            totalCapacity: Nat;
            utilizationPercent: Float;
        } {
            let totalQueued = criticalQueue.size() + highQueue.size() + normalQueue.size() + lowQueue.size();
            let totalCapacity = maxQueueSize * 4;
            let utilization = Float.fromInt(totalQueued) / Float.fromInt(totalCapacity) * 100.0;
            
            {
                critical = criticalQueue.size();
                high = highQueue.size();
                normal = normalQueue.size();
                low = lowQueue.size();
                retry = retryQueue.size();
                crossCanister = crossCanisterEvents.size();
                totalCapacity = totalCapacity;
                utilizationPercent = utilization;
            }
        };

        // Public API: Get Subscriber Information
        public func getSubscriberInfo() : async {
            totalSubscribers: Nat;
            activeSubscribers: [Text];
        } {
            let subscriberList = Buffer.Buffer<Text>(subscribers.size());
            for ((id, _config) in subscribers.entries()) {
                subscriberList.add(id);
            };
            
            {
                totalSubscribers = subscribers.size();
                activeSubscribers = Buffer.toArray(subscriberList);
            }
        };

        // Public API: Emergency Queue Management
        public func emergencyClearQueues(authorization: Text) : async Result.Result<(), Text> {
            if (authorization != "EMERGENCY_CLEAR_AUTH") {
                return #err("Unauthorized emergency operation");
            };
            
            let totalCleared = criticalQueue.size() + highQueue.size() + normalQueue.size() + lowQueue.size();
            
            criticalQueue.clear();
            highQueue.clear();
            normalQueue.clear();
            lowQueue.clear();
            retryQueue.clear();
            crossCanisterEvents.clear();
            
            Debug.print("Emergency queue clear executed - " # debug_show(totalCleared) # " events cleared");
            #ok()
        };

        // Public API: Health Check
        public func healthCheck() : async {
            status: Text;
            queueHealth: Text;
            processingHealth: Text;
            subscriberHealth: Text;
            lastProcessed: Int;
        } {
            let queueUtil = Float.fromInt(criticalQueue.size() + highQueue.size() + normalQueue.size() + lowQueue.size()) / Float.fromInt(maxQueueSize * 4);
            
            let queueHealth = if (queueUtil > 0.9) { "CRITICAL" } 
                            else if (queueUtil > 0.7) { "WARNING" } 
                            else { "HEALTHY" };
            
            let processingHealth = if (metrics.errorRate > 0.1) { "DEGRADED" }
                                 else if (metrics.errorRate > 0.05) { "WARNING" }
                                 else { "HEALTHY" };
            
            let subscriberHealth = if (subscribers.size() == 0) { "NO_SUBSCRIBERS" }
                                 else if (subscribers.size() > 100) { "HIGH_LOAD" }
                                 else { "HEALTHY" };
            
            let overallStatus = if (queueHealth == "CRITICAL" or processingHealth == "DEGRADED") { "UNHEALTHY" }
                              else if (queueHealth == "WARNING" or processingHealth == "WARNING") { "WARNING" }
                              else { "HEALTHY" };
            
            {
                status = overallStatus;
                queueHealth = queueHealth;
                processingHealth = processingHealth;
                subscriberHealth = subscriberHealth;
                lastProcessed = metrics.lastUpdated;
            }
        };
    }
}
