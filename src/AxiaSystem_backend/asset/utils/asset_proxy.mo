import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

module {
    public type AssetCanisterInterface = actor {
        registerAsset: (Principal, Text) -> async Result.Result<Nat, Text>;
        transferAsset: (Nat, Principal) -> async Result.Result<(), Text>;
        deactivateAsset: (Nat) -> async Result.Result<(), Text>;
        reactivateAsset: (Nat) -> async Result.Result<(), Text>;
        getAsset: (Nat) -> async Result.Result<{ id: Nat; owner: Principal; metadata: Text }, Text>;
        getAllAssets: () -> async [Nat];
        getAssetsByOwner: (Principal) -> async [Nat];
        getActiveAssets: () -> async [Nat];
        searchAssetsByMetadata: (Text) -> async [Nat];
        batchTransferAssets: ([Nat], Principal) -> async Result.Result<[Nat], Text>;
    };

    public class AssetProxy(canisterId: Principal) {
        private let assetCanister: AssetCanisterInterface = actor(Principal.toText(canisterId));

        // Register a new asset
        public func registerAsset(
            owner: Principal,
            metadata: Text
        ): async Result.Result<Nat, Text> {
            await assetCanister.registerAsset(owner, metadata);
        };

        // Transfer ownership of an asset
        public func transferAsset(
            assetId: Nat,
            newOwner: Principal
        ): async Result.Result<(), Text> {
            await assetCanister.transferAsset(assetId, newOwner);
        };

        // Deactivate an asset
        public func deactivateAsset(
            assetId: Nat
        ): async Result.Result<(), Text> {
            await assetCanister.deactivateAsset(assetId);
        };

        // Reactivate an asset
        public func reactivateAsset(
            assetId: Nat
        ): async Result.Result<(), Text> {
            await assetCanister.reactivateAsset(assetId);
        };

        // Retrieve asset details by ID
        public func getAsset(
            assetId: Nat
        ): async Result.Result<{ id: Nat; owner: Principal; metadata: Text }, Text> {
            await assetCanister.getAsset(assetId);
        };

        // Retrieve all assets
        public func getAllAssets(): async [Nat] {
            await assetCanister.getAllAssets();
        };

        // Retrieve assets owned by a specific user
        public func getAssetsByOwner(
            owner: Principal
        ): async [Nat] {
            await assetCanister.getAssetsByOwner(owner);
        };

        // Retrieve all active assets
        public func getActiveAssets(): async [Nat] {
            await assetCanister.getActiveAssets();
        };

        // Search assets by metadata keyword
        public func searchAssetsByMetadata(
            keyword: Text
        ): async [Nat] {
            await assetCanister.searchAssetsByMetadata(keyword);
        };

        // Batch transfer ownership of assets
        public func batchTransferAssets(
            assetIds: [Nat],
            newOwner: Principal
        ): async Result.Result<[Nat], Text> {
            await assetCanister.batchTransferAssets(assetIds, newOwner);
        };
    };
};