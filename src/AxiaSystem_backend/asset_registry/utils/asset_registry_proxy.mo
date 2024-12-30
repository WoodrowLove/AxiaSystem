import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import AssetRegistryModule "../modules/asset_registry_module";
import Error "mo:base/Error";

module {
    public type AssetRegistryCanisterInterface = actor {
        registerAsset: (Principal, Nat, Text) -> async Result.Result<AssetRegistryModule.Asset, Text>;
        transferAsset: (Nat, Principal) -> async Result.Result<AssetRegistryModule.Asset, Text>;
        deactivateAsset: (Nat) -> async Result.Result<AssetRegistryModule.Asset, Text>;
        reactivateAsset: (Nat) -> async Result.Result<AssetRegistryModule.Asset, Text>;
        getAsset: (Nat) -> async Result.Result<AssetRegistryModule.Asset, Text>;
        getAssetsByOwner: (Principal) -> async [AssetRegistryModule.Asset];
        getAssetsByNFT: (Nat) -> async [AssetRegistryModule.Asset];
        getAllAssets: () -> async [AssetRegistryModule.Asset];
        getAssetOwnershipHistory: (Nat) -> async Result.Result<[Principal], Text>;
    };

    public class AssetRegistryProxy(canisterId: Principal) {
        private let assetRegistryCanister: AssetRegistryCanisterInterface = actor(Principal.toText(canisterId));

        // Register a new asset
        public func registerAsset(
            owner: Principal,
            nftId: Nat,
            metadata: Text
        ): async Result.Result<AssetRegistryModule.Asset, Text> {
            try {
                await assetRegistryCanister.registerAsset(owner, nftId, metadata);
            } catch (e) {
                #err("Failed to register asset: " # Error.message(e));
            }
        };

        // Transfer ownership of an asset
        public func transferAsset(
            assetId: Nat,
            newOwner: Principal
        ): async Result.Result<AssetRegistryModule.Asset, Text> {
            try {
                await assetRegistryCanister.transferAsset(assetId, newOwner);
            } catch (e) {
                #err("Failed to transfer asset ownership: " # Error.message(e));
            }
        };

        // Deactivate an asset
        public func deactivateAsset(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
            try {
                await assetRegistryCanister.deactivateAsset(assetId);
            } catch (e) {
                #err("Failed to deactivate asset: " # Error.message(e));
            }
        };

        // Reactivate an asset
        public func reactivateAsset(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
            try {
                await assetRegistryCanister.reactivateAsset(assetId);
            } catch (e) {
                #err("Failed to reactivate asset: " # Error.message(e));
            }
        };

        // Retrieve asset details by ID
        public func getAsset(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
            try {
                await assetRegistryCanister.getAsset(assetId);
            } catch (e) {
                #err("Failed to retrieve asset details: " # Error.message(e));
            }
        };

        // Retrieve all assets owned by a specific user
        public func getAssetsByOwner(owner: Principal): async [AssetRegistryModule.Asset] {
            try {
                await assetRegistryCanister.getAssetsByOwner(owner);
            } catch (_e) {
                [];
            }
        };

        // Retrieve all assets linked to a specific NFT
        public func getAssetsByNFT(nftId: Nat): async [AssetRegistryModule.Asset] {
            try {
                await assetRegistryCanister.getAssetsByNFT(nftId);
            } catch (_e) {
                [];
            }
        };

        // Retrieve all assets in the registry
        public func getAllAssets(): async [AssetRegistryModule.Asset] {
            try {
                await assetRegistryCanister.getAllAssets();
            } catch (_e) {
                [];
            }
        };

        // Retrieve ownership history of an asset
        public func getAssetOwnershipHistory(assetId: Nat): async Result.Result<[Principal], Text> {
            try {
                await assetRegistryCanister.getAssetOwnershipHistory(assetId);
            } catch (e) {
                #err("Failed to retrieve asset ownership history: " # Error.message(e));
            }
        };
    };
};