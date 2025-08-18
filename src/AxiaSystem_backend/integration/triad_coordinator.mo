// AxiaSystem Triad Coordinator - Unified Cross-System Integration
// Provides coordinated operations across Asset, Asset Registry, and Escrow systems

import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";

// Cross-system imports
import AssetProxy "../asset/utils/asset_proxy";
import AssetRegistryProxy "../asset_registry/utils/asset_registry_proxy";
import EscrowProxy "../escrow/utils/escrow_canister_proxy";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";

module {
    // Universal Triad Types
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
    };

    public type CrossSystemOperation = {
        operationId: Nat;
        operationType: Text;
        involvedSystems: [Text];
        initiatedBy: TriadIdentity;
        status: OperationStatus;
        createdAt: Nat64;
        completedAt: ?Nat64;
        errorMessage: ?Text;
    };

    // Triad Coordinator Class
    public class TriadCoordinator(
        assetCanisterId: Principal,
        assetRegistryCanisterId: Principal,
        escrowCanisterId: Principal,
        eventManager: EventManager.EventManager
    ) {
        private let assetProxy = AssetProxy.AssetProxy(assetCanisterId);
        private let assetRegistryProxy = AssetRegistryProxy.AssetRegistryProxy(assetRegistryCanisterId);
        private let escrowProxy = EscrowProxy.EscrowCanisterProxy(escrowCanisterId);
        
        private var operations: [CrossSystemOperation] = [];
        private var nextOperationId: Nat = 1;

        // ================================
        // UNIFIED TRIAD OPERATIONS
        // ================================

        // 🎯 Complete Asset Creation (Asset + Registry)
        public func createCompleteAsset(
            identity: TriadIdentity,
            metadata: Text,
            nftId: Nat,
            proof: LinkProof
        ): async Result.Result<{assetId: Nat; registryAssetId: Nat}, Text> {
            
            let operation = createOperation("complete-asset-creation", identity, ["asset", "registry"]);
            
            // Step 1: Create asset in Asset Canister
            let assetResult = await assetProxy.registerAssetTriad(
                identity.identityId, 
                metadata, 
                proof, 
                identity.userId, 
                identity.walletId
            );
            
            switch (assetResult) {
                case (#err(error)) { 
                    await failOperation(operation.operationId, "Asset creation failed: " # error);
                    return #err(error);
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
                            await failOperation(operation.operationId, "Registry creation failed: " # error);
                            return #err(error);
                        };
                        case (#ok(registryAsset)) {
                            await completeOperation(operation.operationId);
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

        // 💰 Create Asset with Escrow Protection
        public func createAssetWithEscrow(
            identity: TriadIdentity,
            metadata: Text,
            nftId: Nat,
            proof: LinkProof,
            escrowConditions: Text
        ): async Result.Result<{assetId: Nat; registryAssetId: Nat; escrowId: Nat}, Text> {
            
            let operation = createOperation("asset-with-escrow-creation", identity, ["asset", "registry", "escrow"]);
            
            // First create the complete asset
            let assetResult = await createCompleteAsset(identity, metadata, nftId, proof);
            
            switch (assetResult) {
                case (#err(error)) {
                    await failOperation(operation.operationId, "Asset creation failed: " # error);
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
                            await failOperation(operation.operationId, "Escrow creation failed: " # error);
                            return #err(error);
                        };
                        case (#ok(escrowId)) {
                            await completeOperation(operation.operationId);
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

        // Get comprehensive system health
        public func getSystemHealth(): async {
            assetSystem: Bool;
            registrySystem: Bool;
            escrowSystem: Bool;
            activeOperations: Nat;
            completedOperations: Nat;
            failedOperations: Nat;
        } {
            let activeOps = Array.filter(operations, func(op: CrossSystemOperation): Bool { 
                switch (op.status) { case (#pending or #inProgress) true; case _ false; }
            });
            let completedOps = Array.filter(operations, func(op: CrossSystemOperation): Bool { 
                switch (op.status) { case (#completed) true; case _ false; }
            });
            let failedOps = Array.filter(operations, func(op: CrossSystemOperation): Bool { 
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

        // List all operations for monitoring
        public func getOperations(): [CrossSystemOperation] {
            operations
        };

        // Get operation details
        public func getOperation(operationId: Nat): ?CrossSystemOperation {
            Array.find(operations, func(op: CrossSystemOperation): Bool { op.operationId == operationId })
        };

        // Get operations by status
        public func getOperationsByStatus(status: OperationStatus): [CrossSystemOperation] {
            Array.filter(operations, func(op: CrossSystemOperation): Bool { op.status == status })
        };

        // Get recent operations (last 24 hours)
        public func getRecentOperations(): [CrossSystemOperation] {
            let twentyFourHoursAgo = Nat64.fromIntWrap(Time.now() - (24 * 60 * 60 * 1_000_000_000));
            Array.filter(operations, func(op: CrossSystemOperation): Bool { 
                op.createdAt >= twentyFourHoursAgo 
            })
        };

        // ================================
        // BATCH OPERATIONS
        // ================================

        // Batch create multiple complete assets
        public func batchCreateCompleteAssets(
            identity: TriadIdentity,
            assetSpecs: [{metadata: Text; nftId: Nat}],
            proof: LinkProof
        ): async Result.Result<[{assetId: Nat; registryAssetId: Nat}], Text> {
            
            let operation = createOperation("batch-asset-creation", identity, ["asset", "registry"]);
            var results: [{assetId: Nat; registryAssetId: Nat}] = [];
            
            for (spec in assetSpecs.vals()) {
                let result = await createCompleteAsset(identity, spec.metadata, spec.nftId, proof);
                switch (result) {
                    case (#err(error)) {
                        await failOperation(operation.operationId, "Batch creation failed: " # error);
                        return #err(error);
                    };
                    case (#ok(assetData)) {
                        results := Array.append(results, [assetData]);
                    };
                };
            };
            
            await completeOperation(operation.operationId);
            #ok(results)
        };

        // ================================
        // PRIVATE HELPERS
        // ================================

        private func createOperation(operationType: Text, identity: TriadIdentity, systems: [Text]): CrossSystemOperation {
            let operation: CrossSystemOperation = {
                operationId = nextOperationId;
                operationType = operationType;
                involvedSystems = systems;
                initiatedBy = identity;
                status = #pending;
                createdAt = Nat64.fromIntWrap(Time.now());
                completedAt = null;
                errorMessage = null;
            };
            
            operations := Array.append(operations, [operation]);
            nextOperationId += 1;
            
            operation
        };

        private func completeOperation(operationId: Nat): async () {
            operations := Array.map(operations, func(op: CrossSystemOperation): CrossSystemOperation {
                if (op.operationId == operationId) {
                    {
                        op with
                        status = #completed;
                        completedAt = ?Nat64.fromIntWrap(Time.now());
                    }
                } else { op }
            });
            
            await emitCoordinatorEvent("operation-completed", "Operation " # Nat.toText(operationId) # " completed successfully");
        };

        private func failOperation(operationId: Nat, reason: Text): async () {
            operations := Array.map(operations, func(op: CrossSystemOperation): CrossSystemOperation {
                if (op.operationId == operationId) {
                    {
                        op with
                        status = #failed;
                        completedAt = ?Nat64.fromIntWrap(Time.now());
                        errorMessage = ?reason;
                    }
                } else { op }
            });
            
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
