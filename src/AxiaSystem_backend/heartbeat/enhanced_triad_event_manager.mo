// AxiaSystem Enhanced Triad Event Manager - Correlation-Aware Event Processing
// Extends existing event managers with triad identity, correlation tracking, and enhanced metadata

import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";

import EventTypes "../heartbeat/event_types";
import EventManager "../heartbeat/event_manager";
import TriadShared "../types/triad_shared";
import CorrelationUtils "../utils/correlation";

module {
    // Enhanced event manager with triad capabilities
    public class EnhancedTriadEventManager(
        baseEventManager: EventManager.EventManager
    ) {
        private var eventHistory = Buffer.Buffer<TriadShared.TriadEventEnvelope>(1000);
        private let correlationManager = CorrelationUtils.getCorrelationManager();
        
        // Emit event with correlation and priority
        public func emitTriadEvent(
            eventType: EventTypes.EventType,
            payload: EventTypes.EventPayload,
            correlation: TriadShared.CorrelationContext,
            priority: ?TriadShared.Priority,
            systems: [Text],
            tags: [Text],
            metadata: [(Text, Text)]
        ): async Result.Result<(), TriadShared.TriadError> {
            
            // Create base event
            let baseEvent: EventTypes.Event = {
                id = correlation.correlationId;
                eventType = eventType;
                payload = payload;
            };
            
            // Create triad envelope
            let triadEvent: TriadShared.TriadEventEnvelope = {
                base = baseEvent;
                correlation = correlation;
                priority = priority;
                systems = systems;
                retryCount = 0;
                tags = tags;
                metadata = metadata;
            };
            
            // Store in history
            eventHistory.add(triadEvent);
            
            // Emit base event
            let _result = await baseEventManager.emit(baseEvent);
            
            // Track correlation step
            correlationManager.trackFlowStep(
                correlation.correlationId,
                1,
                correlation.systemName,
                "event-emission",
                #inProgress
            );
            
            // Complete correlation step based on result
            correlationManager.completeFlowStep(
                correlation.correlationId,
                true, // Always successful for event emission
                null
            );
            
            #ok(())
        };

        // Emit project registered event with triad context
        public func emitProjectRegisteredTriad(
            projectId: Text,
            caller: Principal,
            name: Text,
            correlation: TriadShared.CorrelationContext
        ): async Result.Result<(), TriadShared.TriadError> {
            await emitTriadEvent(
                #ProjectRegistered,
                #ProjectRegistered({ 
                    projectId = projectId; 
                    owner = caller; 
                    name = name; 
                    timestamp = Nat64.fromIntWrap(Time.now());
                }),
                correlation,
                ?#normal,
                ["project-registry"],
                ["project", "registration"],
                [("projectId", projectId), ("projectName", name)]
            )
        };

        // Emit module linked event with triad context
        public func emitModuleLinkedTriad(
            projectId: Text,
            moduleName: Text,
            correlation: TriadShared.CorrelationContext
        ): async Result.Result<(), TriadShared.TriadError> {
            await emitTriadEvent(
                #ModuleLinkedToProject,
                #ModuleLinkedToProject({ 
                    projectId = projectId; 
                    moduleName = moduleName; 
                    linkedAt = Nat64.fromIntWrap(Time.now());
                }),
                correlation,
                ?#normal,
                ["project-registry"],
                ["project", "module", "linking"],
                [("projectId", projectId), ("moduleName", moduleName)]
            )
        };

        // Query methods
        public func getEventHistory(): [TriadShared.TriadEventEnvelope] {
            Buffer.toArray(eventHistory)
        };

        public func getEventsByCorrelation(correlationId: Nat64): [TriadShared.TriadEventEnvelope] {
            let history = Buffer.toArray(eventHistory);
            Array.filter(history, func(event: TriadShared.TriadEventEnvelope): Bool {
                event.correlation.correlationId == correlationId or
                (switch (event.correlation.parentId) {
                    case (?parentId) parentId == correlationId;
                    case null false;
                }) or
                (switch (event.correlation.rootId) {
                    case (?rootId) rootId == correlationId;
                    case null false;
                })
            })
        };

        public func getEventsByPriority(priority: TriadShared.Priority): [TriadShared.TriadEventEnvelope] {
            let history = Buffer.toArray(eventHistory);
            Array.filter(history, func(event: TriadShared.TriadEventEnvelope): Bool {
                switch (event.priority) {
                    case (?p) p == priority;
                    case null false;
                }
            })
        };

        public func getEventsBySystem(systemName: Text): [TriadShared.TriadEventEnvelope] {
            let history = Buffer.toArray(eventHistory);
            Array.filter(history, func(event: TriadShared.TriadEventEnvelope): Bool {
                Array.find(event.systems, func(s: Text): Bool { s == systemName }) != null
            })
        };

        // Statistics and monitoring
        public func getEventStats(): {
            totalEvents: Nat;
            eventsByPriority: [(TriadShared.Priority, Nat)];
            recentEvents: Nat; // Last hour
        } {
            let history = Buffer.toArray(eventHistory);
            let oneHourAgo = Nat64.fromIntWrap(Time.now() - (60 * 60 * 1_000_000_000));
            
            let recentEvents = Array.filter(history, func(event: TriadShared.TriadEventEnvelope): Bool {
                event.correlation.createdAt >= oneHourAgo
            }).size();
            
            // Count by priority
            var criticalCount = 0;
            var highCount = 0;
            var normalCount = 0;
            var lowCount = 0;
            
            for (event in history.vals()) {
                switch (event.priority) {
                    case (?#critical) criticalCount += 1;
                    case (?#high) highCount += 1;
                    case (?#normal) normalCount += 1;
                    case (?#low) lowCount += 1;
                    case (_) normalCount += 1; // Default to normal
                };
            };
            
            {
                totalEvents = history.size();
                eventsByPriority = [
                    (#critical, criticalCount),
                    (#high, highCount),
                    (#normal, normalCount),
                    (#low, lowCount)
                ];
                recentEvents = recentEvents;
            }
        };

        // Cleanup old events
        public func cleanup(retentionHours: Nat) {
            let cutoffTime = Nat64.fromIntWrap(Time.now() - (retentionHours * 60 * 60 * 1_000_000_000));
            let recentEvents = Buffer.Buffer<TriadShared.TriadEventEnvelope>(1000);
            
            for (event in eventHistory.vals()) {
                if (event.correlation.createdAt >= cutoffTime) {
                    recentEvents.add(event);
                };
            };
            
            eventHistory := recentEvents;
        };
    };

    // Factory function
    public func createEnhancedTriadEventManager(
        baseEventManager: EventManager.EventManager
    ): EnhancedTriadEventManager {
        EnhancedTriadEventManager(baseEventManager)
    };
};
