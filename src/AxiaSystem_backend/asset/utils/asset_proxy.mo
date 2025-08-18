import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Blob "mo:base/Blob";

module {
    // 🔗 Triad-Enhanced Asset Canister Interface
    public type LinkProof = { 
        signature: Blob; 
        challenge: Blob; 
        device: ?Blob 
    };

    public type Asset = {
        id: Nat;
        ownerIdentity: Principal;
        userId: ?Principal;
        walletId: ?Principal;
        metadata: Text;
        registeredAt: Int;
        updatedAt: Int;
        isActive: Bool;
        triadVerified: Bool;
    };

    public type AssetCanisterInterface = actor {
        // 🔥 Triad-Compliant Endpoints
        registerAssetTriad: (Principal, Text, LinkProof, ?Principal, ?Principal) -> async Result.Result<Nat, Text>;
        transferAssetTriad: (Principal, Nat, Principal, LinkProof, ?Principal) -> async Result.Result<(), Text>;
        deactivateAssetTriad: (Principal, Nat, LinkProof) -> async Result.Result<(), Text>;
        reactivateAssetTriad: (Principal, Nat, LinkProof) -> async Result.Result<(), Text>;
        batchTransferAssetsTriad: ([Nat], Principal, LinkProof, ?Principal) -> async Result.Result<(), Text>;
        
        // 🔄 Legacy Endpoints (Deprecated)
        registerAsset: (Principal, Text) -> async Result.Result<Nat, Text>;
        transferAsset: (Nat, Principal) -> async Result.Result<(), Text>;
        deactivateAsset: (Nat) -> async Result.Result<(), Text>;
        reactivateAsset: (Nat) -> async Result.Result<(), Text>;
        batchTransferAssets: ([Nat], Principal) -> async Result.Result<[Asset], Text>;
        
        // 🔍 Query Endpoints (Compatible with both)
        getAsset: (Nat) -> async Result.Result<Asset, Text>;
        getAllAssets: () -> async [Asset];
        getAssetsByOwner: (Principal) -> async [Asset];
        getActiveAssets: () -> async [Asset];
        searchAssetsByMetadata: (Text) -> async [Asset];
        getSystemStats: () -> async { totalAssets: Nat; activeAssets: Nat; triadVerifiedAssets: Nat };
    };

    public class AssetProxy(canisterId: Principal) {
        private let assetCanister: AssetCanisterInterface = actor(Principal.toText(canisterId));

        // 🔥 TRIAD-COMPLIANT METHODS (Recommended for new integrations)

        // Register Asset with Triad Validation
        public func registerAssetTriad(
            identityId: Principal,
            metadata: Text,
            proof: LinkProof,
            userId: ?Principal,
            walletId: ?Principal
        ): async Result.Result<Nat, Text> {
            await assetCanister.registerAssetTriad(identityId, metadata, proof, userId, walletId);
        };

        // Transfer Asset with Triad Validation
        public func transferAssetTriad(
            identityId: Principal,
            assetId: Nat,
            newOwnerIdentity: Principal,
            proof: LinkProof,
            userId: ?Principal
        ): async Result.Result<(), Text> {
            await assetCanister.transferAssetTriad(identityId, assetId, newOwnerIdentity, proof, userId);
        };

        // Deactivate Asset with Triad Validation
        public func deactivateAssetTriad(
            identityId: Principal,
            assetId: Nat,
            proof: LinkProof
        ): async Result.Result<(), Text> {
            await assetCanister.deactivateAssetTriad(identityId, assetId, proof);
        };

        // Reactivate Asset with Triad Validation
        public func reactivateAssetTriad(
            identityId: Principal,
            assetId: Nat,
            proof: LinkProof
        ): async Result.Result<(), Text> {
            await assetCanister.reactivateAssetTriad(identityId, assetId, proof);
        };

        // Batch Transfer Assets with Triad Validation
        public func batchTransferAssetsTriad(
            assetIds: [Nat],
            newOwnerIdentity: Principal,
            proof: LinkProof,
            userId: ?Principal
        ): async Result.Result<(), Text> {
            await assetCanister.batchTransferAssetsTriad(assetIds, newOwnerIdentity, proof, userId);
        };

        // 🔄 LEGACY METHODS (Backward Compatibility - Deprecated)

        // Register a new asset (Legacy)
        public func registerAsset(
            owner: Principal,
            metadata: Text
        ): async Result.Result<Nat, Text> {
            await assetCanister.registerAsset(owner, metadata);
        };

        // Transfer ownership of an asset (Legacy)
        public func transferAsset(
            assetId: Nat,
            newOwner: Principal
        ): async Result.Result<(), Text> {
            await assetCanister.transferAsset(assetId, newOwner);
        };

        // Deactivate an asset (Legacy)
        public func deactivateAsset(
            assetId: Nat
        ): async Result.Result<(), Text> {
            await assetCanister.deactivateAsset(assetId);
        };

        // Reactivate an asset (Legacy)
        public func reactivateAsset(
            assetId: Nat
        ): async Result.Result<(), Text> {
            await assetCanister.reactivateAsset(assetId);
        };

        // 🔍 QUERY METHODS (Compatible with both Triad and Legacy)

        // Retrieve asset details by ID
        public func getAsset(
            assetId: Nat
        ): async Result.Result<Asset, Text> {
            await assetCanister.getAsset(assetId);
        };

        // Retrieve all assets
        public func getAllAssets(): async [Asset] {
            await assetCanister.getAllAssets();
        };

        // Retrieve assets owned by a specific user
        public func getAssetsByOwner(
            owner: Principal
        ): async [Asset] {
            await assetCanister.getAssetsByOwner(owner);
        };

        // Retrieve all active assets
        public func getActiveAssets(): async [Asset] {
            await assetCanister.getActiveAssets();
        };

        // Search assets by metadata keyword
        public func searchAssetsByMetadata(
            keyword: Text
        ): async [Asset] {
            await assetCanister.searchAssetsByMetadata(keyword);
        };

        // Batch transfer ownership of assets (Legacy)
        public func batchTransferAssets(
            assetIds: [Nat],
            newOwner: Principal
        ): async Result.Result<[Asset], Text> {
            await assetCanister.batchTransferAssets(assetIds, newOwner);
        };

        // 📊 SYSTEM INFORMATION

        // Get system statistics
        public func getSystemStats(): async { totalAssets: Nat; activeAssets: Nat; triadVerifiedAssets: Nat } {
            await assetCanister.getSystemStats();
        };
    };
};