// Enhanced Event Integration for Governance Canister
// Provides safe integration with enhanced event management systems

import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Debug "mo:base/Debug";

// Import enhanced event managers
import EnhancedEventManager "../../heartbeat/enhanced_event_manager";
import ProductionEventManager "../../heartbeat/production_event_manager";
import TriadEventManager "../../heartbeat/triad_event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    // ================================
    // ENHANCED EVENT COORDINATION
    // ================================
    
    public type EventCoordinator = {
        enhanced: EnhancedEventManager.EnhancedEventManager;
        production: ProductionEventManager.ProductionEventManager;
        triad: TriadEventManager.EnhancedEventManager;
    };
    
    // Create enhanced event coordinator
    public func createEventCoordinator(): EventCoordinator {
        {
            enhanced = EnhancedEventManager.EnhancedEventManager();
            production = ProductionEventManager.ProductionEventManager();
            triad = TriadEventManager.EnhancedEventManager();
        }
    };
    
    // Emit governance event across all enhanced systems
    public func emitGovernanceEventEnhanced(
        coordinator: EventCoordinator,
        event: EventTypes.Event
    ): async Result.Result<(), Text> {
        try {
            // Emit to enhanced event manager
            await coordinator.enhanced.emit(event);
            
            // Emit to production event manager with priority
            let priority = switch (event.eventType) {
                case (#ProposalCreated or #ProposalExecuted) #high;
                case (#ProposalVoted) #normal;
                case (_) #low;
            };
            let _ = await coordinator.production.emitWithPriority(event, priority, ?"governance");
            
            // Emit to triad event manager for cross-canister coordination
            let _ = await coordinator.triad.emitWithPriority(event, priority, ?"governance-coordination");
            
            #ok(())
        } catch (_error) {
            #err("Enhanced event emission failed")
        };
    };
    
    // Get health status across all enhanced systems
    public func getEnhancedSystemHealth(
        coordinator: EventCoordinator
    ): async {
        enhanced: {
            totalEvents: Nat;
            avgProcessingTime: Nat64;
        };
        production: {
            totalQueued: Nat;
            status: Text;
        };
        triad: {
            utilizationPercent: Float;
            status: Text;
        };
    } {
        let enhancedMetrics = await coordinator.enhanced.getEventMetrics();
        let productionHealth = coordinator.production.healthCheck();
        let triadQueueStatus = await coordinator.triad.getQueueStatus();
        let triadHealth = await coordinator.triad.healthCheck();
        
        {
            enhanced = {
                totalEvents = enhancedMetrics.totalEvents;
                avgProcessingTime = enhancedMetrics.avgProcessingTime;
            };
            production = {
                totalQueued = productionHealth.totalQueued;
                status = productionHealth.status;
            };
            triad = {
                utilizationPercent = triadQueueStatus.utilizationPercent;
                status = triadHealth.status;
            };
        }
    };
    
    // Process all pending events across enhanced systems
    public func processAllEnhancedEvents(
        coordinator: EventCoordinator
    ): async Result.Result<{
        enhanced: Nat;
        production: Nat;
        triad: Nat;
        total: Nat;
    }, Text> {
        try {
            // Process enhanced events
            await coordinator.enhanced.processQueuedEvents();
            let enhancedMetrics = await coordinator.enhanced.getEventMetrics();
            
            // Process production events
            let productionResult = await coordinator.production.processAllQueues();
            let productionProcessed = switch (productionResult) {
                case (#ok(count)) count;
                case (#err(_)) 0;
            };
            
            // Process triad events
            let triadResult = await coordinator.triad.processEvents();
            let triadProcessed = switch (triadResult) {
                case (#ok(result)) result.processed;
                case (#err(_)) 0;
            };
            
            let total = enhancedMetrics.totalEvents + productionProcessed + triadProcessed;
            
            #ok({
                enhanced = enhancedMetrics.totalEvents;
                production = productionProcessed;
                triad = triadProcessed;
                total = total;
            })
        } catch (_error) {
            #err("Enhanced event processing failed")
        };
    };
    
    // Coordinate triad governance events with identity and wallet systems
    public func coordinateTriadGovernanceEvent(
        coordinator: EventCoordinator,
        event: EventTypes.Event
    ): async () {
        switch (event.payload) {
            case (#ProposalCreated { proposalId; proposer; description = _; createdAt = _ }) {
                Debug.print("🔺 Coordinating proposal creation across triad: #" # debug_show(proposalId));
                
                // Enhanced triad coordination would go here
                // This is a placeholder for future triad event coordination
                await coordinator.enhanced.emitTriadGovernanceEvent(
                    "proposal.created",
                    Principal.fromText(proposer),
                    ?proposalId,
                    ?("proposal:" # debug_show(proposalId)),
                    ?{choice = "created"; weight = 1}
                );
            };
            
            case (#ProposalVoted { proposalId; voter; vote = _; weight = _; votedAt = _ }) {
                Debug.print("🔺 Coordinating vote across triad: #" # debug_show(proposalId) # " by " # voter);
                
                await coordinator.enhanced.emitTriadIdentityEvent(
                    "governance.activity",
                    Principal.fromText(voter),
                    null,
                    ?("governance-participation")
                );
            };
            
            case (#ProposalExecuted { proposalId; executedAt = _; outcome }) {
                Debug.print("🔺 Executing governance decision across triad: #" # debug_show(proposalId));
                
                // If outcome affects wallet operations, coordinate accordingly
                if (Text.contains(outcome, #text "treasury") or Text.contains(outcome, #text "funds")) {
                    await coordinator.enhanced.emitTriadWalletEvent(
                        "governance.directive",
                        Principal.fromText("governance"),
                        null,
                        null,
                        ?("proposal:" # debug_show(proposalId) # " outcome:" # outcome)
                    );
                };
            };
            
            case (_) ();
        };
    };
};
