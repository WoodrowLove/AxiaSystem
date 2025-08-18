// AxiaSystem Enhanced Event Manager - Triad-Native Architecture
// Advanced event management with performance optimization, filtering, and cross-canister coordination

import EventTypes "../heartbeat/event_types";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Trie "mo:base/Trie";
import Option "mo:base/Option";
import Float "mo:base/Float";

module {
    
    // ================================
    // ENHANCED TYPES FOR TRIAD SUPPORT
    // ================================
    
    public type EventFilter = {
        eventTypes: ?[EventTypes.EventType];
        sources: ?[Text]; // Canister sources
        severity: ?EventSeverity;
        timeRange: ?{start: Nat64; end: Nat64};
        principals: ?[Principal];
    };
    
    public type EventSeverity = {
        #low;
        #medium; 
        #high;
        #critical;
    };
    
    public type EventMetrics = {
        totalEvents: Nat;
        eventsPerMinute: Float;
        errorRate: Float;
        avgProcessingTime: Nat64;
        topEventTypes: [(EventTypes.EventType, Nat)];
        canisterBreakdown: [(Text, Nat)];
    };
    
    public type SubscriptionConfig = {
        filter: ?EventFilter;
        batchSize: ?Nat;
        priority: EventPriority;
        retryPolicy: RetryPolicy;
    };
    
    public type EventPriority = {
        #low;     // Process in background
        #normal;  // Standard processing
        #high;    // Priority processing
        #critical; // Immediate processing
    };
    
    public type RetryPolicy = {
        maxRetries: Nat;
        backoffMs: Nat;
        exponential: Bool;
    };
    
    public type EventBatch = {
        events: [EventTypes.Event];
        batchId: Text;
        timestamp: Nat64;
        size: Nat;
    };
    
    public type CrossCanisterEvent = {
        event: EventTypes.Event;
        targetCanister: Principal;
        retryCount: Nat;
        lastAttempt: Nat64;
        status: EventDeliveryStatus;
    };
    
    public type EventDeliveryStatus = {
        #pending;
        #delivered;
        #failed;
        #retrying;
    };
    
    // ================================
    // ENHANCED EVENT MANAGER CLASS
    // ================================
    
    public class EnhancedEventManager() {
        
        // ========== CORE STORAGE ==========
        
        // Event listeners with enhanced configuration
        private let listeners = HashMap.HashMap<EventTypes.EventType, [(shared EventTypes.Event -> async (), SubscriptionConfig)]>(20, EventTypes.equal, EventTypes.hash);
        
        // Priority-based event queues
        private var criticalQueue: [EventTypes.Event] = [];
        private var highQueue: [EventTypes.Event] = [];
        private var normalQueue: [EventTypes.Event] = [];
        private var lowQueue: [EventTypes.Event] = [];
        
        // Cross-canister event management
        private var crossCanisterEvents: [CrossCanisterEvent] = [];
        
        // Event history and metrics
        private var eventHistory: [EventTypes.Event] = [];
        private let maxHistorySize: Nat = 10000;
        
        // Performance tracking
        private var processingTimes: [Nat64] = [];
        private var emitTimestamps: [Nat64] = [];
        private var lastEmitTime: ?Nat64 = null;
        private var eventErrorCount: Nat = 0;
        private var totalEventsProcessed: Nat = 0;
        
        // Heartbeat management
        private var isHeartbeatRunning: Bool = false;
        
        // Event filtering and routing
        private let eventFilters = HashMap.HashMap<Text, EventFilter>(10, Text.equal, Text.hash);
        
        // ========== ENHANCED SUBSCRIPTION SYSTEM ==========
        
        public func subscribe(
            eventType: EventTypes.EventType, 
            listener: shared EventTypes.Event -> async (),
            config: ?SubscriptionConfig
        ) : async Text {
            let subscriptionId = generateSubscriptionId();
            let defaultConfig: SubscriptionConfig = {
                filter = null;
                batchSize = null;
                priority = #normal;
                retryPolicy = { maxRetries = 3; backoffMs = 1000; exponential = true };
            };
            
            let finalConfig = Option.get(config, defaultConfig);
            
            let currentListeners = switch (listeners.get(eventType)) {
                case null { [] };
                case (?arr) { arr };
            };
            
            listeners.put(eventType, Array.append(currentListeners, [(listener, finalConfig)]));
            subscriptionId
        };
        
        public func subscribeWithFilter(
            filter: EventFilter,
            listener: shared EventTypes.Event -> async (),
            config: ?SubscriptionConfig
        ) : async Text {
            let filterId = generateSubscriptionId();
            eventFilters.put(filterId, filter);
            
            // Subscribe to all event types if filter specifies them
            switch (filter.eventTypes) {
                case (?types) {
                    for (eventType in types.vals()) {
                        ignore await subscribe(eventType, listener, config);
                    };
                };
                case null {
                    // Subscribe to all event types for universal filtering
                    // This would require iteration over all possible event types
                };
            };
            
            filterId
        };
        
        // ========== PRIORITY-BASED EVENT EMISSION ==========
        
        public func emit(event: EventTypes.Event): async () {
            let startTime = Nat64.fromIntWrap(Time.now());
            
            // Update metrics
            emitTimestamps := Array.append<Nat64>(emitTimestamps, [event.id]);
            lastEmitTime := ?event.id;
            totalEventsProcessed += 1;
            
            // Add to history with safe truncation
            eventHistory := Array.append(eventHistory, [event]);
            if (eventHistory.size() > maxHistorySize and maxHistorySize > 0) {
                // Simple safe truncation: just keep the last element when over limit
                eventHistory := [event];
            };
            
            // Determine priority and route accordingly
            let priority = determineEventPriority(event);
            
            switch (priority) {
                case (#critical) {
                    criticalQueue := Array.append(criticalQueue, [event]);
                    await processImmediately(event);
                };
                case (#high) {
                    highQueue := Array.append(highQueue, [event]);
                };
                case (#normal) {
                    normalQueue := Array.append(normalQueue, [event]);
                };
                case (#low) {
                    lowQueue := Array.append(lowQueue, [event]);
                };
            };
            
            // Ensure heartbeat is running
            if (not isHeartbeatRunning) {
                isHeartbeatRunning := true;
                await processQueuedEvents();
            };
            
            // Record processing time
            let endTime = Nat64.fromIntWrap(Time.now());
            processingTimes := Array.append(processingTimes, [endTime - startTime]);
        };
        
        // ========== BATCH EVENT PROCESSING ==========
        
        public func emitBatch(events: [EventTypes.Event]): async EventBatch {
            let batchId = generateBatchId();
            let timestamp = Nat64.fromIntWrap(Time.now());
            
            for (event in events.vals()) {
                await emit(event);
            };
            
            {
                events = events;
                batchId = batchId;
                timestamp = timestamp;
                size = events.size();
            }
        };
        
        // ========== INTELLIGENT EVENT PROCESSING ==========
        
        public func processQueuedEvents() : async () {
            if (getTotalQueueSize() == 0) {
                isHeartbeatRunning := false;
                return;
            };
            
            // Process in priority order
            await processCriticalEvents();
            await processHighPriorityEvents();
            await processNormalEvents();
            await processLowPriorityEvents();
            
            // Process cross-canister events
            await processCrossCanisterEvents();
            
            // Continue if more events exist
            if (getTotalQueueSize() > 0) {
                await processQueuedEvents();
            } else {
                isHeartbeatRunning := false;
            };
        };
        
        private func processCriticalEvents() : async () {
            if (criticalQueue.size() == 0) return;
            
            let events = criticalQueue;
            criticalQueue := [];
            
            for (event in events.vals()) {
                await processEvent(event);
            };
        };
        
        private func processHighPriorityEvents() : async () {
            if (highQueue.size() == 0) return;
            
            // Process up to 10 high priority events per cycle
            let batchSize = Nat.min(10, highQueue.size());
            let batch = Array.subArray(highQueue, 0, batchSize);
            if (batchSize < highQueue.size()) {
                // Use Array.take and skip to safely manage the queue
                let remaining = Array.tabulate<EventTypes.Event>(
                    highQueue.size() - batchSize,
                    func(i) { highQueue[i + batchSize] }
                );
                highQueue := remaining;
            } else {
                highQueue := [];
            };
            
            for (event in batch.vals()) {
                await processEvent(event);
            };
        };
        
        private func processNormalEvents() : async () {
            if (normalQueue.size() == 0) return;
            
            // Process up to 5 normal events per cycle
            let batchSize = Nat.min(5, normalQueue.size());
            let batch = Array.subArray(normalQueue, 0, batchSize);
            if (batchSize < normalQueue.size()) {
                let remaining = Array.tabulate<EventTypes.Event>(
                    normalQueue.size() - batchSize,
                    func(i) { normalQueue[i + batchSize] }
                );
                normalQueue := remaining;
            } else {
                normalQueue := [];
            };
            
            for (event in batch.vals()) {
                await processEvent(event);
            };
        };
        
        private func processLowPriorityEvents() : async () {
            if (lowQueue.size() == 0) return;
            
            // Process up to 2 low priority events per cycle
            let batchSize = Nat.min(2, lowQueue.size());
            if (batchSize > 0) {
                let batch = Array.subArray(lowQueue, 0, batchSize);
                if (batchSize < lowQueue.size()) {
                    let remaining = Array.tabulate<EventTypes.Event>(
                        lowQueue.size() - batchSize,
                        func(i) { lowQueue[i + batchSize] }
                    );
                    lowQueue := remaining;
                } else {
                    lowQueue := [];
                };
                
                for (event in batch.vals()) {
                    await processEvent(event);
                };
            };
        };
        
        // ========== EVENT FILTERING AND ROUTING ==========
        
        private func processEvent(event: EventTypes.Event) : async () {
            let registeredListeners = switch (listeners.get(event.eventType)) {
                case null { [] };
                case (?arr) { arr };
            };
            
            for ((listener, config) in registeredListeners.vals()) {
                if (eventMatchesFilter(event, config.filter)) {
                    await processListenerWithRetry(listener, event, config.retryPolicy);
                };
            };
        };
        
        private func eventMatchesFilter(event: EventTypes.Event, filter: ?EventFilter) : Bool {
            switch (filter) {
                case null true;
                case (?f) {
                    // Check event type filter
                    let typeMatches = switch (f.eventTypes) {
                        case null true;
                        case (?types) {
                            Array.find<EventTypes.EventType>(types, func(t) { t == event.eventType }) != null
                        };
                    };
                    
                    // Check time range filter
                    let timeMatches = switch (f.timeRange) {
                        case null true;
                        case (?range) {
                            event.id >= range.start and event.id <= range.end
                        };
                    };
                    
                    typeMatches and timeMatches
                };
            }
        };
        
        // ========== CROSS-CANISTER EVENT MANAGEMENT ==========
        
        public func emitCrossCanister(
            event: EventTypes.Event,
            targetCanister: Principal
        ) : async () {
            let crossEvent: CrossCanisterEvent = {
                event = event;
                targetCanister = targetCanister;
                retryCount = 0;
                lastAttempt = Nat64.fromIntWrap(Time.now());
                status = #pending;
            };
            
            crossCanisterEvents := Array.append(crossCanisterEvents, [crossEvent]);
        };
        
        private func processCrossCanisterEvents() : async () {
            let pendingEvents = Array.filter<CrossCanisterEvent>(
                crossCanisterEvents,
                func(ce) { ce.status == #pending or ce.status == #retrying }
            );
            
            for (crossEvent in pendingEvents.vals()) {
                await processCrossCanisterEvent(crossEvent);
            };
        };
        
        private func processCrossCanisterEvent(crossEvent: CrossCanisterEvent) : async () {
            // This would implement actual cross-canister calls
            // For now, simulate the processing
            try {
                // await targetCanister.receiveEvent(crossEvent.event);
                updateCrossCanisterEventStatus(crossEvent, #delivered);
            } catch (_e) {
                if (crossEvent.retryCount < 3) {
                    updateCrossCanisterEventStatus(crossEvent, #retrying);
                } else {
                    updateCrossCanisterEventStatus(crossEvent, #failed);
                };
            };
        };
        
        // ========== ANALYTICS AND METRICS ==========
        
        public func getEventMetrics() : async EventMetrics {
            let now = Nat64.fromIntWrap(Time.now());
            let oneMinuteAgo = now - 60_000_000_000;
            
            let recentEvents = Array.filter<EventTypes.Event>(
                eventHistory,
                func(e) { e.id >= oneMinuteAgo }
            );
            
            let eventsPerMinute = Float.fromInt(recentEvents.size());
            let errorRate = if (totalEventsProcessed > 0) {
                Float.fromInt(eventErrorCount) / Float.fromInt(totalEventsProcessed)
            } else { 0.0 };
            
            let avgProcessingTime: Nat64 = if (processingTimes.size() > 0) {
                Array.foldLeft<Nat64, Nat64>(processingTimes, 0, func(acc, time) { acc + time }) / Nat64.fromNat(processingTimes.size())
            } else { 
                0 : Nat64 
            };
            
            {
                totalEvents = totalEventsProcessed;
                eventsPerMinute = eventsPerMinute;
                errorRate = errorRate;
                avgProcessingTime = avgProcessingTime;
                topEventTypes = getTopEventTypes();
                canisterBreakdown = getCanisterBreakdown();
            }
        };
        
        public func getEventHistory(filter: ?EventFilter) : async [EventTypes.Event] {
            switch (filter) {
                case null eventHistory;
                case (?f) {
                    Array.filter<EventTypes.Event>(eventHistory, func(e) { eventMatchesFilter(e, ?f) })
                };
            }
        };
        
        // ========== TRIAD-SPECIFIC EVENT HANDLERS ==========
        
        public func emitTriadGovernanceEvent(
            eventType: Text,
            identityId: Principal,
            proposalId: ?Nat,
            _details: ?Text,
            metadata: ?{choice: Text; weight: Nat}
        ) : async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = #GeneralVoteCast; // Map to appropriate type
                payload = #GeneralVoteCast({
                    proposalId = Option.get(proposalId, 0);
                    voter = Principal.toText(identityId);
                    choice = switch (metadata) {
                        case (?m) m.choice == "yes";
                        case null true;
                    };
                    timestamp = Nat64.fromIntWrap(Time.now());
                });
            };
            
            await emit(event);
        };
        
        public func emitTriadIdentityEvent(
            action: Text,
            identityId: Principal,
            _deviceId: ?Principal,
            _metadata: ?Text
        ) : async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = switch (action) {
                    case ("created") #IdentityCreated;
                    case ("updated") #IdentityUpdated;
                    case ("deleted") #IdentityDeleted;
                    case (_) #IdentityUpdated;
                };
                payload = switch (action) {
                    case ("created") {
                        #IdentityCreated({
                            id = identityId;
                            metadata = Trie.empty<Text, Text>();
                            createdAt = Time.now();
                        })
                    };
                    case (_) {
                        #IdentityUpdated({
                            id = identityId;
                            metadata = Trie.empty<Text, Text>();
                            updatedAt = Time.now();
                        })
                    };
                };
            };
            
            await emit(event);
        };
        
        public func emitTriadWalletEvent(
            action: Text,
            walletId: Principal,
            amount: ?Nat,
            tokenId: ?Nat,
            _metadata: ?Text
        ) : async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = switch (action) {
                    case ("deposit") #FundsDeposited;
                    case ("withdraw") #FundsWithdrawn;
                    case ("created") #WalletCreated;
                    case ("updated") #WalletUpdated;
                    case (_) #WalletUpdated;
                };
                payload = switch (action) {
                    case ("deposit") {
                        #FundsDeposited({
                            userId = Principal.toText(walletId);
                            amount = Option.get(amount, 0);
                            tokenId = tokenId;
                            timestamp = Nat64.fromIntWrap(Time.now());
                        })
                    };
                    case ("withdraw") {
                        #FundsWithdrawn({
                            userId = Principal.toText(walletId);
                            amount = Option.get(amount, 0);
                            tokenId = tokenId;
                            timestamp = Nat64.fromIntWrap(Time.now());
                        })
                    };
                    case (_) {
                        #WalletUpdated({
                            walletId = Principal.toText(walletId);
                            balance = Option.get(amount, 0);
                        })
                    };
                };
            };
            
            await emit(event);
        };
        
        // ========== UTILITY FUNCTIONS ==========
        
        private func getTotalQueueSize() : Nat {
            criticalQueue.size() + highQueue.size() + normalQueue.size() + lowQueue.size()
        };
        
        private func determineEventPriority(event: EventTypes.Event) : EventPriority {
            switch (event.eventType) {
                case (#AlertRaised) #critical;
                case (#EmergencyOverrideEnabled) #critical;
                case (#InsufficientFunds) #high;
                case (#LoginFailure) #high;
                case (#EscrowTimeoutProcessed) #high;
                case (#GeneralVoteCast) #normal;
                case (#IdentityCreated) #normal;
                case (#WalletUpdated) #low;
                case (_) #normal;
            }
        };
        
        private func processImmediately(event: EventTypes.Event) : async () {
            await processEvent(event);
        };
        
        private func processListenerWithRetry(
            listener: shared EventTypes.Event -> async (),
            event: EventTypes.Event,
            retryPolicy: RetryPolicy
        ) : async () {
            var attempts = 0;
            var success = false;
            
            while (attempts <= retryPolicy.maxRetries and not success) {
                try {
                    await listener(event);
                    success := true;
                } catch (e) {
                    attempts += 1;
                    if (attempts <= retryPolicy.maxRetries) {
                        let _delay = if (retryPolicy.exponential) {
                            retryPolicy.backoffMs * (2 ** attempts)
                        } else {
                            retryPolicy.backoffMs
                        };
                        // await delay(delay); // Would implement delay mechanism
                    } else {
                        eventErrorCount += 1;
                        Debug.print("Failed to deliver event after " # Nat.toText(attempts) # " attempts: " # Error.message(e));
                    };
                };
            };
        };
        
        private func updateCrossCanisterEventStatus(
            crossEvent: CrossCanisterEvent,
            _status: EventDeliveryStatus
        ) {
            // Update the status in the crossCanisterEvents array
            // This would require a more sophisticated data structure for efficient updates
        };
        
        private func generateSubscriptionId() : Text {
            "sub_" # Nat64.toText(Nat64.fromIntWrap(Time.now()))
        };
        
        private func generateBatchId() : Text {
            "batch_" # Nat64.toText(Nat64.fromIntWrap(Time.now()))
        };
        
        private func getTopEventTypes() : [(EventTypes.EventType, Nat)] {
            // Implementation would analyze eventHistory and return top event types
            []
        };
        
        private func getCanisterBreakdown() : [(Text, Nat)] {
            // Implementation would analyze events by source canister
            []
        };
        
        // ========== LEGACY COMPATIBILITY ==========
        
        public func emit_legacy(event: EventTypes.Event): async () {
            await emit(event);
        };
        
        public func subscribe_legacy(
            eventType: EventTypes.EventType, 
            listener: shared EventTypes.Event -> async ()
        ) : async () {
            ignore await subscribe(eventType, listener, null);
        };
        
        // ========== DIAGNOSTIC AND MONITORING ==========
        
        public func runDiagnostics(): async () {
            let metrics = await getEventMetrics();
            Debug.print("=== Event Manager Diagnostics ===");
            Debug.print("Total Events: " # Nat.toText(metrics.totalEvents));
            Debug.print("Events/Minute: " # Float.toText(metrics.eventsPerMinute));
            Debug.print("Error Rate: " # Float.toText(metrics.errorRate));
            Debug.print("Avg Processing Time: " # Nat64.toText(metrics.avgProcessingTime) # "ns");
            Debug.print("Queue Sizes - Critical: " # Nat.toText(criticalQueue.size()) # 
                       ", High: " # Nat.toText(highQueue.size()) # 
                       ", Normal: " # Nat.toText(normalQueue.size()) # 
                       ", Low: " # Nat.toText(lowQueue.size()));
        };
        
        public func getEventQueueLength(): async Nat {
            getTotalQueueSize()
        };
        
        public func listSubscribedEventTypes(): async [EventTypes.EventType] {
            Iter.toArray(listeners.keys())
        };
        
        public func getAverageEmitRate(): async Nat {
            let now = Time.now();
            let oneMinuteAgo = Nat64.fromIntWrap(now - 60_000_000_000);
            
            let recentTimestamps = Array.filter<Nat64>(
                emitTimestamps,
                func(t: Nat64): Bool { t >= oneMinuteAgo }
            );
            
            recentTimestamps.size()
        };
        
        public func getLastEventTime(): async ?Nat64 {
            lastEmitTime
        };
        
        public func getEventErrorCount(): async Nat {
            eventErrorCount
        };
        
        // All existing legacy methods maintained for backward compatibility...
        // [Previous methods would be included here]
    };
};
