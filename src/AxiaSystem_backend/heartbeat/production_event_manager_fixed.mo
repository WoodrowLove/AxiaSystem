import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Trie "mo:base/Trie";

import EventTypes "event_types";

module ProductionEventManager {

    // Enhanced Event Priority System
    public type EventPriority = {
        #critical;  // Immediate processing (security, errors)
        #high;      // Priority processing (governance, payments)
        #normal;    // Standard processing (user actions)
        #low;       // Background processing (analytics, cleanup)
    };

    // Prioritized Event with metadata
    public type PrioritizedEvent = {
        event: EventTypes.Event;
        priority: EventPriority;
        timestamp: Int;
        attempts: Nat;
    };

    // Event Filter for subscriptions
    public type EventFilter = {
        eventTypes: ?[EventTypes.EventType];
        sources: ?[Text];
        principals: ?[Principal];
        minTimestamp: ?Int;
        maxTimestamp: ?Int;
    };

    // Subscription Configuration
    public type SubscriptionConfig = {
        filter: ?EventFilter;
        enabled: Bool;
        lastProcessed: ?Int;
        maxEvents: ?Nat;
    };

    // Event Metrics
    public type EventMetrics = {
        totalEvents: Nat;
        processedEvents: Nat;
        failedEvents: Nat;
        avgProcessingTime: Nat64;
        queueSizes: [Nat];
    };

    // Triad-specific Event Types
    public type TriadEventType = {
        #IdentityDeviceRegistered : {
            identityId: Principal;
            deviceId: Principal;
            deviceType: Text;
            trust: Text;
        };
        #IdentityVerificationChanged : {
            identityId: Principal;
            oldLevel: Text;
            newLevel: Text;
            deviceId: ?Principal;
        };
        #GovernanceProposalTriad : {
            proposalId: Nat64;
            proposer: Principal;
            action: Text;
            requiredVotes: Nat;
            currentVotes: Nat;
        };
        #GovernanceVoteTriad : {
            proposalId: Nat64;
            voter: Principal;
            vote: Bool;
            votingPower: Nat64;
        };
        #TriadStateSync : {
            canister: Text;
            syncType: Text;
            data: Trie.Trie<Text, Text>;
            timestamp: Int;
        };
    };

    // Production Event Manager Class
    public class ProductionEventManager() {
        // Priority Queues
        private var criticalQueue = Buffer.Buffer<PrioritizedEvent>(0);
        private var highQueue = Buffer.Buffer<PrioritizedEvent>(0);
        private var normalQueue = Buffer.Buffer<PrioritizedEvent>(0);
        private var lowQueue = Buffer.Buffer<PrioritizedEvent>(0);

        // Subscribers
        private var subscribers = HashMap.HashMap<Text, SubscriptionConfig>(10, Text.equal, Text.hash);

        // Event Handlers
        private var eventHandlers = HashMap.HashMap<Text, (EventTypes.Event) -> async ()>(10, Text.equal, Text.hash);

        // Metrics
        private var metrics: EventMetrics = {
            totalEvents = 0;
            processedEvents = 0;
            failedEvents = 0;
            avgProcessingTime = 0;
            queueSizes = [0, 0, 0, 0];
        };

        // Retry queue for failed events
        private var retryQueue = Buffer.Buffer<PrioritizedEvent>(0);

        // Configuration
        private let maxQueueSize: Nat = 10000;
        private let maxRetries: Nat = 3;
        private let batchSize: Nat = 50;

        // Main event emission function
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
            };

            // Route to appropriate queue based on priority
            let targetQueue = switch (priority) {
                case (#critical) { criticalQueue };
                case (#high) { highQueue };
                case (#normal) { normalQueue };
                case (#low) { lowQueue };
            };

            // Check queue capacity
            if (targetQueue.size() >= maxQueueSize) {
                return #err("Queue capacity exceeded for priority: " # debug_show(priority));
            };

            // Add to queue
            targetQueue.add(prioritizedEvent);
            
            // Update metrics
            metrics := {
                metrics with
                totalEvents = metrics.totalEvents + 1;
                queueSizes = [
                    criticalQueue.size(),
                    highQueue.size(), 
                    normalQueue.size(),
                    lowQueue.size()
                ];
            };

            #ok()
        };

        // Process events from all queues (heartbeat handler)
        public func processAllQueues() : async Result.Result<Nat, Text> {
            var totalProcessed: Nat = 0;

            // Process in priority order
            switch (await processPriorityQueue(criticalQueue, #critical)) {
                case (#ok(count)) { totalProcessed += count; };
                case (#err(_msg)) { /* Log error but continue */ };
            };

            switch (await processPriorityQueue(highQueue, #high)) {
                case (#ok(count)) { totalProcessed += count; };
                case (#err(_msg)) { /* Log error but continue */ };
            };

            switch (await processPriorityQueue(normalQueue, #normal)) {
                case (#ok(count)) { totalProcessed += count; };
                case (#err(_msg)) { /* Log error but continue */ };
            };

            switch (await processPriorityQueue(lowQueue, #low)) {
                case (#ok(count)) { totalProcessed += count; };
                case (#err(_msg)) { /* Log error but continue */ };
            };

            // Process retry queue
            switch (await processRetryQueue()) {
                case (#ok(count)) { totalProcessed += count; };
                case (#err(_msg)) { /* Log error */ };
            };

            // Update metrics
            metrics := {
                metrics with
                processedEvents = metrics.processedEvents + totalProcessed;
                queueSizes = [
                    criticalQueue.size(),
                    highQueue.size(),
                    normalQueue.size(), 
                    lowQueue.size()
                ];
            };

            #ok(totalProcessed)
        };

        // Process events in batches for efficiency
        public func processBatch() : async Result.Result<Nat, Text> {
            var totalProcessed: Nat = 0;

            // Process critical queue with higher batch limits
            switch (await processPriorityQueueBatch(criticalQueue, #critical, batchSize * 2)) {
                case (#ok(count)) { totalProcessed += count; };
                case (#err(_msg)) { /* Continue processing */ };
            };

            // Process other queues with standard batch size
            switch (await processPriorityQueueBatch(highQueue, #high, batchSize)) {
                case (#ok(count)) { totalProcessed += count; };
                case (#err(_msg)) { /* Continue processing */ };
            };

            switch (await processPriorityQueueBatch(normalQueue, #normal, batchSize)) {
                case (#ok(count)) { totalProcessed += count; };
                case (#err(_msg)) { /* Continue processing */ };
            };

            switch (await processPriorityQueueBatch(lowQueue, #low, batchSize / 2)) {
                case (#ok(count)) { totalProcessed += count; };
                case (#err(_msg)) { /* Continue processing */ };
            };

            #ok(totalProcessed)
        };

        // Process a single priority queue
        private func processPriorityQueue(
            queue: Buffer.Buffer<PrioritizedEvent>,
            _priority: EventPriority
        ) : async Result.Result<Nat, Text> {
            
            var processedCount: Nat = 0;
            let queueSize = queue.size();
            
            // Process all events in queue
            for (i in Iter.range(0, queueSize - 1)) {
                if (queue.size() > 0) {
                    let prioritizedEvent = queue.remove(0);
                    
                    switch (await processEvent(prioritizedEvent)) {
                        case (#ok()) { processedCount += 1; };
                        case (#err(_msg)) { 
                            // Add to retry queue if within retry limits
                            if (prioritizedEvent.attempts < maxRetries) {
                                let retryEvent = {
                                    event = prioritizedEvent.event;
                                    priority = prioritizedEvent.priority;
                                    timestamp = prioritizedEvent.timestamp;
                                    attempts = prioritizedEvent.attempts + 1;
                                };
                                retryQueue.add(retryEvent);
                            };
                        };
                    };
                };
            };
            
            #ok(processedCount)
        };

        // Process queue in batches
        private func processPriorityQueueBatch(
            queue: Buffer.Buffer<PrioritizedEvent>,
            _priority: EventPriority,
            batchLimit: Nat
        ) : async Result.Result<Nat, Text> {
            
            var processedCount: Nat = 0;
            let processLimit = if (queue.size() < batchLimit) { queue.size() } else { batchLimit };
            
            for (i in Iter.range(0, processLimit - 1)) {
                if (queue.size() > 0) {
                    let prioritizedEvent = queue.remove(0);
                    
                    switch (await processEvent(prioritizedEvent)) {
                        case (#ok()) { processedCount += 1; };
                        case (#err(_msg)) { 
                            if (prioritizedEvent.attempts < maxRetries) {
                                let retryEvent = {
                                    event = prioritizedEvent.event;
                                    priority = prioritizedEvent.priority;
                                    timestamp = prioritizedEvent.timestamp;
                                    attempts = prioritizedEvent.attempts + 1;
                                };
                                retryQueue.add(retryEvent);
                            };
                        };
                    };
                };
            };
            
            #ok(processedCount)
        };

        // Process individual event
        private func processEvent(prioritizedEvent: PrioritizedEvent) : async Result.Result<(), Text> {
            // Notify all subscribers
            for ((subscriberId, config) in subscribers.entries()) {
                if (config.enabled and eventMatchesFilter(prioritizedEvent.event, config.filter)) {
                    switch (eventHandlers.get(subscriberId)) {
                        case (?handler) {
                            try {
                                await handler(prioritizedEvent.event);
                            } catch (_error) {
                                Debug.print("Handler error for " # subscriberId);
                            };
                        };
                        case null { /* No handler found */ };
                    };
                };
            };
            
            #ok()
        };

        // Process retry queue
        private func processRetryQueue() : async Result.Result<Nat, Text> {
            var processedCount: Nat = 0;
            let queueSize = retryQueue.size();
            
            for (i in Iter.range(0, queueSize - 1)) {
                if (retryQueue.size() > 0) {
                    let retryEvent = retryQueue.remove(0);
                    
                    switch (await processEvent(retryEvent)) {
                        case (#ok()) { processedCount += 1; };
                        case (#err(_msg)) {
                            // If still failing after retries, log and discard
                            if (retryEvent.attempts >= maxRetries) {
                                metrics := {
                                    metrics with
                                    failedEvents = metrics.failedEvents + 1;
                                };
                            };
                        };
                    };
                };
            };
            
            #ok(processedCount)
        };

        // Register event handler
        public func subscribe(
            subscriberId: Text,
            handler: (EventTypes.Event) -> async (),
            config: SubscriptionConfig
        ) : () {
            eventHandlers.put(subscriberId, handler);
            subscribers.put(subscriberId, config);
        };

        // Unregister event handler
        public func unsubscribe(subscriberId: Text) : () {
            eventHandlers.delete(subscriberId);
            subscribers.delete(subscriberId);
        };

        // Update subscription configuration
        public func updateSubscription(subscriberId: Text, config: SubscriptionConfig) : () {
            subscribers.put(subscriberId, config);
        };

        // Check if event matches filter
        private func eventMatchesFilter(event: EventTypes.Event, filter: ?EventFilter) : Bool {
            switch (filter) {
                case null { true }; // No filter means accept all
                case (?f) {
                    // Check event type filter
                    switch (f.eventTypes) {
                        case (?types) {
                            var found = false;
                            for (eventType in types.vals()) {
                                if (eventType == event.eventType) {
                                    found := true;
                                };
                            };
                            if (not found) { return false; };
                        };
                        case null { /* No event type filter */ };
                    };
                    
                    // Check timestamp filter
                    let eventTime = getEventTimestamp(event);
                    switch (f.minTimestamp) {
                        case (?minTime) {
                            if (eventTime < minTime) { return false; };
                        };
                        case null { /* No min timestamp filter */ };
                    };
                    
                    switch (f.maxTimestamp) {
                        case (?maxTime) {
                            if (eventTime > maxTime) { return false; };
                        };
                        case null { /* No max timestamp filter */ };
                    };
                    
                    true
                };
            }
        };

        // Extract timestamp from event payload
        private func getEventTimestamp(event: EventTypes.Event) : Int {
            switch (event.payload) {
                case (#AssetRegistered(data)) { data.registeredAt };
                case (#AssetTransferred(data)) { data.transferTime };
                case (#WalletCreated(_data)) { Time.now() };
                case (#WalletUpdated(_data)) { Time.now() };
                case (#IdentityCreated(data)) { data.createdAt };
                case (#IdentityUpdated(data)) { data.updatedAt };
                case (#ProposalCreated(_data)) { Time.now() };
                case (#ProposalVoted(_data)) { Time.now() };
                case (#EscrowCreated(_data)) { Time.now() };
                case (#LoginAttempt(_data)) { Time.now() };
                case (#UserCreated(_data)) { Time.now() }; // Default to current time
                case (_) { Time.now() }; // Default for all other events
            }
        };

        // Get current metrics
        public func getMetrics() : EventMetrics {
            {
                metrics with
                queueSizes = [
                    criticalQueue.size(),
                    highQueue.size(),
                    normalQueue.size(),
                    lowQueue.size()
                ];
            }
        };

        // Clear all queues (emergency function)
        public func clearAllQueues() : () {
            criticalQueue.clear();
            highQueue.clear();
            normalQueue.clear();
            lowQueue.clear();
            retryQueue.clear();
        };

        // Get queue sizes for monitoring
        public func getQueueSizes() : [Nat] {
            [
                criticalQueue.size(),
                highQueue.size(),
                normalQueue.size(),
                lowQueue.size(),
                retryQueue.size()
            ]
        };

        // Health check function
        public func healthCheck() : {
            status: Text;
            totalQueued: Nat;
            metrics: EventMetrics;
        } {
            let totalQueued = criticalQueue.size() + highQueue.size() + normalQueue.size() + lowQueue.size();
            let status = if (totalQueued > maxQueueSize * 3 / 4) { "warning" } else { "healthy" };
            
            {
                status = status;
                totalQueued = totalQueued;
                metrics = getMetrics();
            }
        };
    };
};
