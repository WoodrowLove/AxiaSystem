// AxiaSystem Correlation Utilities - Enhanced Operation Tracking and Context Management
// Provides correlation ID generation, context propagation, and operation flow tracking

import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";

import TriadShared "../types/triad_shared";

module {
    // Enhanced correlation state management
    public class CorrelationManager() {
        private var correlationCounter: Nat64 = 1;
        private var correlationHistory = Buffer.Buffer<TriadShared.CorrelationContext>(100);
        private var activeFlows = HashMap.HashMap<Nat64, TriadShared.FlowStep>(10, Nat64.equal, func(n: Nat64): Nat32 { Nat32.fromNat(Nat64.toNat(n)) });
        
        // Generate unique correlation ID with entropy
        public func nextCorrelation(): Nat64 {
            let timestamp = Nat64.fromIntWrap(Time.now());
            let counter = correlationCounter;
            correlationCounter += 1;
            
            // Combine timestamp and counter for uniqueness
            timestamp + counter * 1000000
        };

        // Create new correlation context
        public func createCorrelation(
            flow: Text,
            initiatedBy: Principal,
            systemName: Text,
            operationType: Text
        ): TriadShared.CorrelationContext {
            let correlation = {
                correlationId = nextCorrelation();
                parentId = null;
                rootId = null;
                flow = flow;
                initiatedBy = initiatedBy;
                createdAt = Nat64.fromIntWrap(Time.now());
                systemName = systemName;
                operationType = operationType;
            };
            
            correlationHistory.add(correlation);
            correlation
        };

        // Create child correlation from parent
        public func deriveChild(
            parent: TriadShared.CorrelationContext,
            systemName: Text,
            operationType: Text
        ): TriadShared.CorrelationContext {
            let child = {
                correlationId = nextCorrelation();
                parentId = ?parent.correlationId;
                rootId = switch (parent.rootId) {
                    case (?rootId) ?rootId;
                    case null ?parent.correlationId;
                };
                flow = parent.flow;
                initiatedBy = parent.initiatedBy;
                createdAt = Nat64.fromIntWrap(Time.now());
                systemName = systemName;
                operationType = operationType;
            };
            
            correlationHistory.add(child);
            child
        };

        // Track flow step
        public func trackFlowStep(
            correlationId: Nat64,
            stepId: Nat,
            systemName: Text,
            operationType: Text,
            status: TriadShared.OperationStatus
        ) {
            let step: TriadShared.FlowStep = {
                stepId = stepId;
                systemName = systemName;
                operationType = operationType;
                status = status;
                startedAt = Nat64.fromIntWrap(Time.now());
                completedAt = null;
                errorMsg = null;
            };
            
            activeFlows.put(correlationId, step);
        };

        // Complete flow step
        public func completeFlowStep(
            correlationId: Nat64,
            success: Bool,
            errorMsg: ?Text
        ) {
            switch (activeFlows.get(correlationId)) {
                case (?step) {
                    let completedStep = {
                        step with
                        status = if (success) #completed else #failed;
                        completedAt = ?Nat64.fromIntWrap(Time.now());
                        errorMsg = errorMsg;
                    };
                    activeFlows.put(correlationId, completedStep);
                };
                case null {
                    // Step not found - could be already completed or never started
                };
            };
        };

        // Get correlation by ID
        public func getCorrelation(correlationId: Nat64): ?TriadShared.CorrelationContext {
            Buffer.toArray(correlationHistory) |> Array.find<TriadShared.CorrelationContext>(_, func(c: TriadShared.CorrelationContext): Bool {
                c.correlationId == correlationId
            })
        };

        // Get correlation chain (parent -> child relationships)
        public func getCorrelationChain(correlationId: Nat64): [TriadShared.CorrelationContext] {
            let allCorrelations = Buffer.toArray(correlationHistory);
            var chain: [TriadShared.CorrelationContext] = [];
            
            // Find root correlation
            let rootOpt = Array.find(allCorrelations, func(c: TriadShared.CorrelationContext): Bool {
                c.correlationId == correlationId or 
                (switch (c.rootId) { case (?rootId) rootId == correlationId; case null false; })
            });
            
            switch (rootOpt) {
                case (?root) {
                    chain := [root];
                    
                    // Find all children recursively
                    func findChildren(parentId: Nat64): [TriadShared.CorrelationContext] {
                        Array.filter(allCorrelations, func(c: TriadShared.CorrelationContext): Bool {
                            switch (c.parentId) {
                                case (?pid) pid == parentId;
                                case null false;
                            }
                        })
                    };
                    
                    let children = findChildren(root.correlationId);
                    chain := Array.append(chain, children);
                };
                case null {
                    // Correlation not found
                };
            };
            
            chain
        };

        // Get active flows
        public func getActiveFlows(): [(Nat64, TriadShared.FlowStep)] {
            Iter.toArray(activeFlows.entries())
        };

        // Get flow history for correlation
        public func getFlowHistory(correlationId: Nat64): [TriadShared.FlowStep] {
            switch (activeFlows.get(correlationId)) {
                case (?step) [step];
                case null [];
            }
        };

        // Cleanup old correlations (for memory management)
        public func cleanup(olderThanHours: Nat) {
            let cutoffTime = Nat64.fromIntWrap(Time.now() - (olderThanHours * 60 * 60 * 1_000_000_000));
            
            // Clean correlation history
            let recentCorrelations = Buffer.Buffer<TriadShared.CorrelationContext>(100);
            for (correlation in correlationHistory.vals()) {
                if (correlation.createdAt >= cutoffTime) {
                    recentCorrelations.add(correlation);
                };
            };
            correlationHistory := recentCorrelations;
            
            // Clean active flows
            for ((correlationId, step) in activeFlows.entries()) {
                if (step.startedAt < cutoffTime) {
                    activeFlows.delete(correlationId);
                };
            };
        };

        // Get statistics
        public func getStats(): {
            totalCorrelations: Nat;
            activeFlows: Nat;
            oldestCorrelation: ?Nat64;
            newestCorrelation: ?Nat64;
        } {
            let correlations = Buffer.toArray(correlationHistory);
            let oldest = if (correlations.size() > 0) ?correlations[0].createdAt else null;
            let newest = if (correlations.size() > 0) ?correlations[correlations.size() - 1].createdAt else null;
            
            {
                totalCorrelations = correlations.size();
                activeFlows = activeFlows.size();
                oldestCorrelation = oldest;
                newestCorrelation = newest;
            }
        };
    };

    // Idempotency key management
    public class IdempotencyManager() {
        private var idempotencyKeys = HashMap.HashMap<Text, TriadShared.IdempotencyKey>(10, Text.equal, Text.hash);
        private var results = HashMap.HashMap<Text, Text>(10, Text.equal, Text.hash); // Key -> JSON result
        
        // Generate idempotency key
        public func generateKey(
            operation: Text,
            principal: Principal,
            params: Text
        ): Text {
            let timestamp = Nat64.toText(Nat64.fromIntWrap(Time.now()));
            let principalText = Principal.toText(principal);
            operation # "-" # principalText # "-" # timestamp # "-" # params
        };

        // Check idempotency
        public func checkIdempotency(key: Text): TriadShared.IdempotencyResult<Text> {
            switch (idempotencyKeys.get(key)) {
                case (?idempotencyKey) {
                    let now = Nat64.fromIntWrap(Time.now());
                    if (now <= idempotencyKey.expiresAt) {
                        // Key is still valid
                        switch (results.get(key)) {
                            case (?result) #existing(result);
                            case null #expired({ key = key });
                        }
                    } else {
                        // Key expired
                        idempotencyKeys.delete(key);
                        results.delete(key);
                        #expired({ key = key })
                    }
                };
                case null {
                    // New operation
                    #new("")
                };
            }
        };

        // Store idempotency result
        public func storeResult(
            key: Text,
            operation: Text,
            principal: Principal,
            result: Text,
            ttlHours: Nat
        ) {
            let now = Nat64.fromIntWrap(Time.now());
            let idempotencyKey: TriadShared.IdempotencyKey = {
                key = key;
                operation = operation;
                principal = principal;
                createdAt = now;
                expiresAt = now + Nat64.fromNat(ttlHours * 60 * 60 * 1_000_000_000);
            };
            
            idempotencyKeys.put(key, idempotencyKey);
            results.put(key, result);
        };

        // Cleanup expired keys
        public func cleanup() {
            let now = Nat64.fromIntWrap(Time.now());
            
            for ((key, idempotencyKey) in idempotencyKeys.entries()) {
                if (now > idempotencyKey.expiresAt) {
                    idempotencyKeys.delete(key);
                    results.delete(key);
                };
            };
        };

        // Get statistics
        public func getStats(): {
            activeKeys: Nat;
            totalStored: Nat;
        } {
            {
                activeKeys = idempotencyKeys.size();
                totalStored = results.size();
            }
        };
    };

    // Global correlation manager instance factory
    public func getCorrelationManager(): CorrelationManager {
        CorrelationManager()
    };

    // Get or create global idempotency manager  
    public func getIdempotencyManager(): IdempotencyManager {
        IdempotencyManager()
    };

    // Utility functions for common operations
    public func createOperationCorrelation(
        operation: Text,
        initiatedBy: Principal,
        systemName: Text
    ): TriadShared.CorrelationContext {
        let manager = getCorrelationManager();
        manager.createCorrelation(operation, initiatedBy, systemName, operation)
    };

    public func createIdempotentOperation<T>(
        key: Text,
        operation: Text,
        principal: Principal,
        ttlHours: Nat,
        executeOperation: () -> T,
        serializeResult: (T) -> Text,
        deserializeResult: (Text) -> T
    ): TriadShared.IdempotencyResult<T> {
        let manager = getIdempotencyManager();
        
        switch (manager.checkIdempotency(key)) {
            case (#existing(resultStr)) {
                #existing(deserializeResult(resultStr))
            };
            case (#expired(_)) {
                let result = executeOperation();
                let resultStr = serializeResult(result);
                manager.storeResult(key, operation, principal, resultStr, ttlHours);
                #new(result)
            };
            case (#new(_)) {
                let result = executeOperation();
                let resultStr = serializeResult(result);
                manager.storeResult(key, operation, principal, resultStr, ttlHours);
                #new(result)
            };
        }
    };

    // Cleanup utilities
    public func performMaintenance(
        correlationManager: CorrelationManager,
        idempotencyManager: IdempotencyManager
    ) {
        correlationManager.cleanup(24); // Keep 24 hours of history
        idempotencyManager.cleanup();
    };
};
