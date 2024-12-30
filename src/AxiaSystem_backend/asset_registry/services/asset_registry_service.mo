import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import AssetRegistryModule "../modules/asset_registry_module";
import EventManager "../../heartbeat/event_manager";

module {
    public func createAssetRegistryService(
        eventManager: EventManager.EventManager
    ): AssetRegistryModule.AssetRegistryManager {
        AssetRegistryModule.AssetRegistryManager(eventManager)
    };

    // Register a new asset
    public func registerAssetInRegistry(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        owner: Principal,
        nftId: Nat,
        metadata: Text
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        await assetRegistryManager.registerAssetInRegistry(owner, nftId, metadata);
    };

    // Transfer ownership of an asset
    public func transferAssetInRegistry(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat,
        newOwner: Principal
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        await assetRegistryManager.transferAssetInRegistry(assetId, newOwner);
    };

    // Deactivate an asset
    public func deactivateAssetInRegistry(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        await assetRegistryManager.deactivateAssetInRegistry(assetId);
    };

    // Reactivate an asset
    public func reactivateAssetInRegistry(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        await assetRegistryManager.reactivateAssetInRegistry(assetId);
    };

    // Retrieve asset details by ID
    public func getAssetInRegistry(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        await assetRegistryManager.getAssetInRegistry(assetId);
    };

    // Retrieve all assets owned by a specific user
    public func getAssetsByOwnerInRegistry(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        owner: Principal
    ): async [AssetRegistryModule.Asset] {
        await assetRegistryManager.getAssetsByOwnerInRegistry(owner);
    };

    // Retrieve all assets linked to a specific NFT
    public func getAssetsByNFTInRegistry(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        nftId: Nat
    ): async [AssetRegistryModule.Asset] {
        await assetRegistryManager.getAssetsByNFTInRegistry(nftId);
    };

    // Retrieve all assets in the registry
    public func getAllAssetsInRegistry(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager
    ): async [AssetRegistryModule.Asset] {
        await assetRegistryManager.getAllAssetsInRegistry();
    };

    // Retrieve ownership history of an asset
    public func getAssetOwnershipHistoryInRegistry(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat
    ): async Result.Result<[Principal], Text> {
        await assetRegistryManager.getAssetOwnershipHistoryInRegistry(assetId);
    };
};