// AxiaSystem Triad Coordinator - Enhanced Cross-System Integration with Operation Pruning
// Provides coordinated operations across Asset, Asset Registry, and Escrow systems
// Enhanced with triad architecture, correlation tracking, and intelligent operation management

import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import _Int "mo:base/Int";

// Cross-system imports
import AssetProxy "../asset/utils/asset_proxy";
import AssetRegistryProxy "../asset_registry/utils/asset_registry_proxy";
import EscrowProxy "../escrow/utils/escrow_canister_proxy";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";

// Enhanced triad imports
import TriadShared "../types/triad_shared";
import CorrelationUtils "../utils/correlation";
import EnhancedTriadEventManager "../heartbeat/enhanced_triad_event_manager";

module {
    // Enhanced Universal Triad Types with correlation support
    public type LinkProof = { 
        signature: Blob; 
        challenge: Blob; 
        device: ?Blob 
    };

    public type TriadIdentity = {
        identityId: Principal;
        userId: ?Principal;
        walletId: ?Principal;
        verified: Bool;
        linkedAt: Nat64;
    };

    public type OperationStatus = {
        #pending;
        #inProgress;
        #completed;
        #failed;
        #cancelled;
        #compensated;
    };

    public type OperationPriority = {
        #critical;
        #high;
        #normal;
        #low;
        #maintenance;
    };

    // Enhanced operation type with triad support
    public type CrossSystemOperation = {
        operationId: Nat;
        operationType: Text;
        involvedSystems: [Text];
        initiatedBy: TriadIdentity;
        status: OperationStatus;
        priority: OperationPriority;
        correlation: ?TriadShared.CorrelationContext;
        createdAt: Nat64;
        lastUpdatedAt: Nat64;
        completedAt: ?Nat64;
        errorMessage: ?TriadShared.TriadError;
        retryCount: Nat;
        compensationActions: [CompensationAction];
        prunable: Bool; // Can this operation be pruned?
        tags: [Text]; // Operation tags for filtering
    };

    // Compensation actions for failed operations
    public type CompensationAction = {
        #RevertAssetCreation: { assetId: Nat };
        #RevertRegistryEntry: { registryAssetId: Nat };
        #RevertEscrowCreation: { escrowId: Nat };
        #RevertAssetTransfer: { assetId: Nat; originalOwner: Principal };
        #NotifyAdmin: { severity: TriadShared.Priority; message: Text };
        #AuditLog: { action: Text; details: Text };
    };

    // Operation pruning configuration
    public type PruningConfig = {
        maxOperations: Nat;
        retentionDays: Nat;
        autoPreune: Bool;
        preserveCritical: Bool;
        preserveFailed: Bool;
    };

    // Batch operation result
    public type BatchOperationResult<T> = {
        totalOperations: Nat;
        successfulOperations: Nat;
        failedOperations: Nat;
        results: [Result.Result<T, TriadShared.TriadError>];
        batchCorrelation: TriadShared.CorrelationContext;
    };

    // Enhanced Triad Coordinator Class with Operation Pruning
    public class TriadCoordinator(
        assetCanisterId: Principal,
        assetRegistryCanisterId: Principal,
        escrowCanisterId: Principal,
        eventManager: EventManager.EventManager
    ) {
        private let assetProxy = AssetProxy.AssetProxy(assetCanisterId);
        private let assetRegistryProxy = AssetRegistryProxy.AssetRegistryProxy(assetRegistryCanisterId);
        private let escrowProxy = EscrowProxy.EscrowCanisterProxy(escrowCanisterId);
        
        // Enhanced managers for triad support
        private let correlationManager = CorrelationUtils.CorrelationManager();
        private let _idempotencyManager = CorrelationUtils.IdempotencyManager();
        private let enhancedEventManager = EnhancedTriadEventManager.EnhancedTriadEventManager(eventManager);
        
        // Operation management
        private var operations = Buffer.Buffer<CrossSystemOperation>(100);
        private var nextOperationId: Nat = 1;
        
        // Pruning configuration
        private var _pruningConfig: PruningConfig = {
            maxOperations = 1000;
            retentionDays = 30;
            autoPreune = true;
            preserveCritical = true;
            preserveFailed = true;
        };

        // Operation retry configuration
        private let _maxRetries: Nat = 3;
        private let _retryDelayNanos: Nat64 = 5_000_000_000; // 5 seconds

        // ================================
        // ENHANCED UNIFIED TRIAD OPERATIONS
        // ================================

        // 🎯 Enhanced Complete Asset Creation with Correlation
        public func createCompleteAsset(
            identity: TriadIdentity,
            metadata: Text,
            nftId: Nat,
            proof: LinkProof
        ): async Result.Result<{assetId: Nat; registryAssetId: Nat}, TriadShared.TriadError> {
            
            let correlation = correlationManager.createCorrelation(
                "complete-asset-creation",
                identity.identityId,
                "triad-coordinator",
                "create-complete-asset"
            );

            let operation = createEnhancedOperation(
                "complete-asset-creation", 
                identity, 
                ["asset", "registry"],
                #high,
                correlation,
                ["asset-creation", "registry"]
            );
            
            // Step 1: Create asset in Asset Canister with correlation
            let assetResult = await assetProxy.registerAssetTriad(
                identity.identityId, 
                metadata, 
                proof, 
                identity.userId, 
                identity.walletId
            );
            
            switch (assetResult) {
                case (#err(error)) { 
                    await failEnhancedOperation(operation.operationId, #Upstream({ systemName = "asset-canister"; error = error }));
                    return #err(#Upstream({ systemName = "asset-canister"; error = error }));
                };
                case (#ok(assetId)) {
                    // Step 2: Register in Asset Registry
                    let registryResult = await assetRegistryProxy.registerAsset(
                        identity.identityId,
                        nftId,
                        metadata
                    );
                    
                    switch (registryResult) {
                        case (#err(error)) {
                            // Compensate: Would need to revert asset creation
                            await failEnhancedOperation(operation.operationId, #Upstream({ systemName = "asset-registry"; error = error }));
                            return #err(#Upstream({ systemName = "asset-registry"; error = error }));
                        };
                        case (#ok(registryAsset)) {
                            await completeEnhancedOperation(operation.operationId);
                            
                            // Emit enhanced completion event
                            let _ = await enhancedEventManager.emitTriadEvent(
                                #AssetRegistered,
                                #AssetRegistered({
                                    assetId = assetId;
                                    owner = identity.identityId;
                                    metadata = metadata;
                                    registeredAt = Time.now();
                                }),
                                correlation,
                                ?#high,
                                ["asset", "registry"],
                                ["creation", "success"],
                                [("assetId", Nat.toText(assetId)), ("registryId", Nat.toText(registryAsset.id))]
                            );

                            return #ok({
                                assetId = assetId;
                                registryAssetId = registryAsset.id;
                            });
                        };
                    };
                };
            };
        };

        // 🔄 Coordinated Asset Transfer (Asset + Registry)
        public func transferCompleteAsset(
            currentOwner: TriadIdentity,
            newOwner: TriadIdentity,
            assetId: Nat,
            registryAssetId: Nat,
            proof: LinkProof
        ): async Result.Result<(), Text> {
            
            let operation = createOperation("complete-asset-transfer", currentOwner, ["asset", "registry"]);
            
            // Step 1: Transfer in Asset Canister
            let assetTransferResult = await assetProxy.transferAssetTriad(
                currentOwner.identityId,
                assetId,
                newOwner.identityId,
                proof,
                currentOwner.userId
            );
            
            switch (assetTransferResult) {
                case (#err(error)) {
                    await failOperation(operation.operationId, "Asset transfer failed: " # error);
                    return #err(error);
                };
                case (#ok(_)) {
                    // Step 2: Transfer in Registry
                    let registryTransferResult = await assetRegistryProxy.transferAsset(
                        registryAssetId,
                        newOwner.identityId
                    );
                    
                    switch (registryTransferResult) {
                        case (#err(error)) {
                            await failOperation(operation.operationId, "Registry transfer failed: " # error);
                            return #err(error);
                        };
                        case (#ok(_)) {
                            await completeOperation(operation.operationId);
                            return #ok(());
                        };
                    };
                };
            };
        };

        // 🔒 Coordinated Asset Deactivation (Asset + Registry)
        public func deactivateCompleteAsset(
            identity: TriadIdentity,
            assetId: Nat,
            registryAssetId: Nat,
            proof: LinkProof
        ): async Result.Result<(), Text> {
            
            let operation = createOperation("complete-asset-deactivation", identity, ["asset", "registry"]);
            
            // Step 1: Deactivate in Asset Canister
            let assetResult = await assetProxy.deactivateAssetTriad(identity.identityId, assetId, proof);
            switch (assetResult) {
                case (#err(error)) {
                    await failOperation(operation.operationId, "Asset deactivation failed: " # error);
                    return #err(error);
                };
                case (#ok(_)) {
                    // Step 2: Deactivate in Registry
                    let registryResult = await assetRegistryProxy.deactivateAsset(registryAssetId);
                    switch (registryResult) {
                        case (#err(error)) {
                            await failOperation(operation.operationId, "Registry deactivation failed: " # error);
                            return #err(error);
                        };
                        case (#ok(_)) {
                            await completeOperation(operation.operationId);
                            return #ok(());
                        };
                    };
                };
            };
        };

        // 💰 Create Asset with Escrow Protection - Enhanced Triad Version
        public func createAssetWithEscrow(
            identity: TriadIdentity,
            metadata: Text,
            nftId: Nat,
            proof: LinkProof,
            escrowConditions: Text
        ): async Result.Result<{assetId: Nat; registryAssetId: Nat; escrowId: Nat}, TriadShared.TriadError> {
            
            let correlation = correlationManager.createCorrelation(
                "asset-with-escrow-creation",
                identity.identityId,
                "triad-coordinator",
                "create-asset-with-escrow"
            );

            let operation = createEnhancedOperation(
                "asset-with-escrow-creation", 
                identity, 
                ["asset", "registry", "escrow"],
                #high,
                correlation,
                ["asset-creation", "escrow", "protection"]
            );
            
            // First create the complete asset
            let assetResult = await createCompleteAsset(identity, metadata, nftId, proof);
            
            switch (assetResult) {
                case (#err(error)) {
                    await failEnhancedOperation(operation.operationId, error);
                    return #err(error);
                };
                case (#ok(assetData)) {
                    // Create escrow for asset protection
                    let escrowResult = await escrowProxy.createEscrow(
                        identity.identityId,
                        identity.identityId, // Self-escrow for asset protection
                        assetData.assetId,
                        1, // Quantity
                        escrowConditions
                    );
                    
                    switch (escrowResult) {
                        case (#err(error)) {
                            let triadeError = #Upstream({ systemName = "escrow-canister"; error = error });
                            await failEnhancedOperation(operation.operationId, triadeError);
                            return #err(triadeError);
                        };
                        case (#ok(escrowId)) {
                            await completeEnhancedOperation(operation.operationId);
                            
                            // Emit enhanced completion event
                            let _ = await enhancedEventManager.emitTriadEvent(
                                #AssetRegistered,
                                #AssetRegistered({
                                    assetId = assetData.assetId;
                                    owner = identity.identityId;
                                    metadata = metadata;
                                    registeredAt = Time.now();
                                }),
                                correlation,
                                ?#high,
                                ["asset", "escrow"],
                                ["creation", "escrow", "success"],
                                [("assetId", Nat.toText(assetData.assetId)), ("escrowId", Nat.toText(escrowId))]
                            );

                            return #ok({
                                assetId = assetData.assetId;
                                registryAssetId = assetData.registryAssetId;
                                escrowId = escrowId;
                            });
                        };
                    };
                };
            };
        };

        // 🔗 Coordinated Asset Transfer with Escrow Release
        public func transferAssetWithEscrowRelease(
            currentOwner: TriadIdentity,
            newOwner: TriadIdentity,
            assetId: Nat,
            registryAssetId: Nat,
            escrowId: Nat,
            proof: LinkProof
        ): async Result.Result<(), Text> {
            
            let operation = createOperation("asset-transfer-with-escrow", currentOwner, ["asset", "registry", "escrow"]);
            
            // Step 1: Release escrow
            let escrowResult = await escrowProxy.releaseEscrow(escrowId);
            switch (escrowResult) {
                case (#err(error)) {
                    await failOperation(operation.operationId, "Escrow release failed: " # error);
                    return #err(error);
                };
                case (#ok(_)) {
                    // Step 2: Perform coordinated transfer
                    let transferResult = await transferCompleteAsset(
                        currentOwner,
                        newOwner,
                        assetId,
                        registryAssetId,
                        proof
                    );
                    
                    switch (transferResult) {
                        case (#err(error)) {
                            await failOperation(operation.operationId, "Transfer failed after escrow release: " # error);
                            return #err(error);
                        };
                        case (#ok(_)) {
                            await completeOperation(operation.operationId);
                            return #ok(());
                        };
                    };
                };
            };
        };

        // ================================
        // SYSTEM STATUS & MONITORING
        // ================================

        // Get comprehensive system health with Buffer support
        public func getSystemHealth(): async {
            assetSystem: Bool;
            registrySystem: Bool;
            escrowSystem: Bool;
            activeOperations: Nat;
            completedOperations: Nat;
            failedOperations: Nat;
        } {
            let operationsArray = Buffer.toArray(operations);
            let activeOps = Array.filter(operationsArray, func(op: CrossSystemOperation): Bool { 
                switch (op.status) { case (#pending or #inProgress) true; case _ false; }
            });
            let completedOps = Array.filter(operationsArray, func(op: CrossSystemOperation): Bool { 
                switch (op.status) { case (#completed) true; case _ false; }
            });
            let failedOps = Array.filter(operationsArray, func(op: CrossSystemOperation): Bool { 
                switch (op.status) { case (#failed) true; case _ false; }
            });
            
            {
                assetSystem = true; // TODO: Add health checks
                registrySystem = true;
                escrowSystem = true;
                activeOperations = activeOps.size();
                completedOperations = completedOps.size();
                failedOperations = failedOps.size();
            }
        };

        // List all operations for monitoring with Buffer support
        public func getOperations(): [CrossSystemOperation] {
            Buffer.toArray(operations)
        };

        // Get operation details with Buffer support
        public func getOperation(operationId: Nat): ?CrossSystemOperation {
            let operationsArray = Buffer.toArray(operations);
            Array.find(operationsArray, func(op: CrossSystemOperation): Bool { op.operationId == operationId })
        };

        // Get operations by status with Buffer support
        public func getOperationsByStatus(status: OperationStatus): [CrossSystemOperation] {
            let operationsArray = Buffer.toArray(operations);
            Array.filter(operationsArray, func(op: CrossSystemOperation): Bool { op.status == status })
        };

        // Get recent operations (last 24 hours) with Buffer support
        public func getRecentOperations(): [CrossSystemOperation] {
            let twentyFourHoursAgo = Nat64.fromIntWrap(Time.now() - (24 * 60 * 60 * 1_000_000_000));
            let operationsArray = Buffer.toArray(operations);
            Array.filter(operationsArray, func(op: CrossSystemOperation): Bool { 
                op.createdAt >= twentyFourHoursAgo 
            })
        };

        // ================================
        // OPERATION PRUNING MANAGEMENT
        // ================================

        // 🎯 Prune Old Operations based on retention policy
        public func pruneOperations(): async {prunedCount: Nat; retainedCount: Nat} {
            let retentionPeriod = Nat64.fromIntWrap(7 * 24 * 60 * 60 * 1_000_000_000); // 7 days
            let cutoffTime = Nat64.fromIntWrap(Time.now()) - retentionPeriod;
            let operationsArray = Buffer.toArray(operations);
            
            let newBuffer = Buffer.Buffer<CrossSystemOperation>(operations.size());
            var prunedCount = 0;
            
            for (op in operationsArray.vals()) {
                let shouldRetain = switch (op.status) {
                    case (#pending or #inProgress) true; // Always retain active operations
                    case (#failed) {
                        // Retain failed operations for longer analysis
                        op.createdAt >= (cutoffTime - Nat64.fromIntWrap(7 * 24 * 60 * 60 * 1_000_000_000))
                    };
                    case (#completed) {
                        // Retain if within retention period or marked as non-prunable
                        not op.prunable or op.createdAt >= cutoffTime
                    };
                    case (#cancelled) {
                        // Retain cancelled operations for audit
                        op.createdAt >= cutoffTime
                    };
                    case (#compensated) {
                        // Retain compensated operations for audit
                        not op.prunable or op.createdAt >= cutoffTime
                    };
                };
                
                if (shouldRetain) {
                    newBuffer.add(op);
                } else {
                    prunedCount += 1;
                };
            };
            
            operations := newBuffer;
            
            {
                prunedCount = prunedCount;
                retainedCount = operations.size();
            }
        };

        // 🎯 Mark Operation as Non-Prunable (for important audit trails)
        public func markOperationNonPrunable(operationId: Nat): async Bool {
            let operationsArray = Buffer.toArray(operations);
            for (i in operationsArray.keys()) {
                if (operationsArray[i].operationId == operationId) {
                    let updatedOp = {
                        operationsArray[i] with
                        prunable = false;
                        lastUpdatedAt = Nat64.fromIntWrap(Time.now());
                    };
                    operations.put(i, updatedOp);
                    return true;
                };
            };
            false
        };

        // 🎯 Get Operations Statistics for monitoring
        public func getOperationStatistics(): async {
            totalOperations: Nat;
            byStatus: {pending: Nat; inProgress: Nat; completed: Nat; failed: Nat};
            byPriority: {critical: Nat; high: Nat; normal: Nat; low: Nat; maintenance: Nat};
            prunableOperations: Nat;
            oldestOperation: ?Nat64;
            newestOperation: ?Nat64;
        } {
            let operationsArray = Buffer.toArray(operations);
            
            var pendingCount = 0;
            var inProgressCount = 0;
            var completedCount = 0;
            var failedCount = 0;
            
            var criticalCount = 0;
            var highCount = 0;
            var normalCount = 0;
            var lowCount = 0;
            var maintenanceCount = 0;
            
            var prunableCount = 0;
            var oldestTime: ?Nat64 = null;
            var newestTime: ?Nat64 = null;
            
            for (op in operationsArray.vals()) {
                // Count by status
                switch (op.status) {
                    case (#pending) pendingCount += 1;
                    case (#inProgress) inProgressCount += 1;
                    case (#completed) completedCount += 1;
                    case (#failed) failedCount += 1;
                    case (#cancelled) failedCount += 1; // Count cancelled as failed for statistics
                    case (#compensated) completedCount += 1; // Count compensated as completed for statistics
                };
                
                // Count by priority
                switch (op.priority) {
                    case (#critical) criticalCount += 1;
                    case (#high) highCount += 1;
                    case (#normal) normalCount += 1;
                    case (#low) lowCount += 1;
                    case (#maintenance) maintenanceCount += 1;
                };
                
                // Count prunable
                if (op.prunable) prunableCount += 1;
                
                // Track oldest/newest
                switch (oldestTime) {
                    case (null) oldestTime := ?op.createdAt;
                    case (?current) {
                        if (op.createdAt < current) oldestTime := ?op.createdAt;
                    };
                };
                
                switch (newestTime) {
                    case (null) newestTime := ?op.createdAt;
                    case (?current) {
                        if (op.createdAt > current) newestTime := ?op.createdAt;
                    };
                };
            };
            
            {
                totalOperations = operationsArray.size();
                byStatus = {
                    pending = pendingCount;
                    inProgress = inProgressCount;
                    completed = completedCount;
                    failed = failedCount;
                };
                byPriority = {
                    critical = criticalCount;
                    high = highCount;
                    normal = normalCount;
                    low = lowCount;
                    maintenance = maintenanceCount;
                };
                prunableOperations = prunableCount;
                oldestOperation = oldestTime;
                newestOperation = newestTime;
            }
        };

        // ================================
        // BATCH OPERATIONS
        // ================================

        // Batch create multiple complete assets with enhanced triad support
        public func batchCreateCompleteAssets(
            identity: TriadIdentity,
            assetSpecs: [{metadata: Text; nftId: Nat}],
            proof: LinkProof
        ): async Result.Result<[{assetId: Nat; registryAssetId: Nat}], TriadShared.TriadError> {
            
            let correlation = correlationManager.createCorrelation(
                "batch-asset-creation",
                identity.identityId,
                "triad-coordinator",
                "batch-create-assets"
            );

            let operation = createEnhancedOperation(
                "batch-asset-creation", 
                identity, 
                ["asset", "registry"],
                #high,
                correlation,
                ["batch", "asset-creation"]
            );
            
            var results: [{assetId: Nat; registryAssetId: Nat}] = [];
            
            for (spec in assetSpecs.vals()) {
                let result = await createCompleteAsset(identity, spec.metadata, spec.nftId, proof);
                switch (result) {
                    case (#err(error)) {
                        await failEnhancedOperation(operation.operationId, error);
                        return #err(error);
                    };
                    case (#ok(assetData)) {
                        results := Array.append(results, [assetData]);
                    };
                };
            };
            
            await completeEnhancedOperation(operation.operationId);
            #ok(results)
        };

        // ================================
        // PRIVATE HELPERS - ENHANCED TRIAD OPERATIONS
        // ================================

        // 🎯 Create Enhanced Operation with Correlation and Priority
        private func createEnhancedOperation(
            operationType: Text,
            identity: TriadIdentity,
            systems: [Text],
            priority: TriadShared.Priority,
            correlation: TriadShared.CorrelationContext,
            tags: [Text]
        ): CrossSystemOperation {
            let operation: CrossSystemOperation = {
                operationId = nextOperationId;
                operationType = operationType;
                involvedSystems = systems;
                initiatedBy = identity;
                status = #pending;
                createdAt = Nat64.fromIntWrap(Time.now());
                lastUpdatedAt = Nat64.fromIntWrap(Time.now());
                completedAt = null;
                errorMessage = null;
                correlation = ?correlation;
                priority = switch (priority) {
                    case (#emergency) #critical;
                    case (#critical) #critical;
                    case (#high) #high;
                    case (#normal) #normal;
                    case (#low) #low;
                };
                retryCount = 0;
                tags = tags;
                compensationActions = [];
                prunable = true;
            };
            
            operations.add(operation);
            nextOperationId += 1;
            
            operation
        };

        private func createOperation(operationType: Text, identity: TriadIdentity, systems: [Text]): CrossSystemOperation {
            let operation: CrossSystemOperation = {
                operationId = nextOperationId;
                operationType = operationType;
                involvedSystems = systems;
                initiatedBy = identity;
                status = #pending;
                createdAt = Nat64.fromIntWrap(Time.now());
                lastUpdatedAt = Nat64.fromIntWrap(Time.now());
                completedAt = null;
                errorMessage = null;
                correlation = null;
                priority = #normal;
                retryCount = 0;
                tags = [];
                compensationActions = [];
                prunable = true;
            };
            
            operations.add(operation);
            nextOperationId += 1;
            
            operation
        };

        // 🎯 Complete Enhanced Operation with Correlation
        private func completeEnhancedOperation(operationId: Nat): async () {
            let operationsArray = Buffer.toArray(operations);
            for (i in operationsArray.keys()) {
                if (operationsArray[i].operationId == operationId) {
                    let updatedOp = {
                        operationsArray[i] with
                        status = #completed;
                        completedAt = ?Nat64.fromIntWrap(Time.now());
                        lastUpdatedAt = Nat64.fromIntWrap(Time.now());
                    };
                    operations.put(i, updatedOp);
                };
            };
            
            await emitCoordinatorEvent("operation-completed", "Operation " # Nat.toText(operationId) # " completed successfully");
        };

        // 🎯 Fail Enhanced Operation with TriadError
        private func failEnhancedOperation(operationId: Nat, error: TriadShared.TriadError): async () {
            let operationsArray = Buffer.toArray(operations);
            for (i in operationsArray.keys()) {
                if (operationsArray[i].operationId == operationId) {
                    let updatedOp = {
                        operationsArray[i] with
                        status = #failed;
                        completedAt = ?Nat64.fromIntWrap(Time.now());
                        lastUpdatedAt = Nat64.fromIntWrap(Time.now());
                        errorMessage = ?error;
                    };
                    operations.put(i, updatedOp);
                };
            };
            
            await emitCoordinatorEvent("operation-failed", "Operation " # Nat.toText(operationId) # " failed");
        };

        private func completeOperation(operationId: Nat): async () {
            let operationsArray = Buffer.toArray(operations);
            for (i in operationsArray.keys()) {
                if (operationsArray[i].operationId == operationId) {
                    let updatedOp = {
                        operationsArray[i] with
                        status = #completed;
                        completedAt = ?Nat64.fromIntWrap(Time.now());
                        lastUpdatedAt = Nat64.fromIntWrap(Time.now());
                    };
                    operations.put(i, updatedOp);
                };
            };
            
            await emitCoordinatorEvent("operation-completed", "Operation " # Nat.toText(operationId) # " completed successfully");
        };

        private func failOperation(operationId: Nat, reason: Text): async () {
            let operationsArray = Buffer.toArray(operations);
            for (i in operationsArray.keys()) {
                if (operationsArray[i].operationId == operationId) {
                    let updatedOp = {
                        operationsArray[i] with
                        status = #failed;
                        completedAt = ?Nat64.fromIntWrap(Time.now());
                        lastUpdatedAt = Nat64.fromIntWrap(Time.now());
                        errorMessage = ?#Internal({ code = "OPERATION_FAILED"; message = reason });
                    };
                    operations.put(i, updatedOp);
                };
            };
            
            await emitCoordinatorEvent("operation-failed", "Operation " # Nat.toText(operationId) # " failed: " # reason);
        };

        private func emitCoordinatorEvent(eventType: Text, message: Text): async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = #AlertRaised;
                payload = #AlertRaised({ 
                    alertType = eventType; 
                    message = message; 
                    timestamp = Nat64.fromIntWrap(Time.now());
                });
            };
            await eventManager.emit(event);
        };
    };

    // Factory function
    public func createTriadCoordinator(
        assetCanisterId: Principal,
        assetRegistryCanisterId: Principal,
        escrowCanisterId: Principal,
        eventManager: EventManager.EventManager
    ): TriadCoordinator {
        TriadCoordinator(assetCanisterId, assetRegistryCanisterId, escrowCanisterId, eventManager)
    };
};
