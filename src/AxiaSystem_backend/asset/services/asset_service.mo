import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import AssetModule "../modules/asset_module";
import EventManager "../../heartbeat/event_manager";

module {
    public func createAssetService(
        eventManager: EventManager.EventManager
    ): AssetModule.AssetManager {
        AssetModule.AssetManager(eventManager)
    };

    // 🔄 LEGACY COMPATIBILITY LAYER
    // These functions maintain backward compatibility while new integrations use Triad

    // Register a new asset (Legacy - marks triadVerified=false)
    public func registerAsset(
        assetManager: AssetModule.AssetManager,
        owner: Principal,
        metadata: Text
    ): async Result.Result<AssetModule.Asset, Text> {
        await assetManager.registerAsset(owner, metadata);
    };

    // Transfer ownership of an asset (Legacy)
    public func transferAsset(
        assetManager: AssetModule.AssetManager,
        assetId: Nat,
        newOwner: Principal
    ): async Result.Result<AssetModule.Asset, Text> {
        await assetManager.transferAsset(assetId, newOwner);
    };

    // Deactivate an asset (Legacy)
    public func deactivateAsset(
        assetManager: AssetModule.AssetManager,
        assetId: Nat
    ): async Result.Result<AssetModule.Asset, Text> {
        await assetManager.deactivateAsset(assetId);
    };

    // Reactivate an asset (Legacy)
    public func reactivateAsset(
        assetManager: AssetModule.AssetManager,
        assetId: Nat
    ): async Result.Result<AssetModule.Asset, Text> {
        await assetManager.reactivateAsset(assetId);
    };

    // Retrieve asset details by ID
    public func getAsset(
        assetManager: AssetModule.AssetManager,
        assetId: Nat
    ): async Result.Result<AssetModule.Asset, Text> {
        await assetManager.getAsset(assetId);
    };

    // Retrieve all assets
    public func getAllAssets(
        assetManager: AssetModule.AssetManager
    ): async [AssetModule.Asset] {
        await assetManager.getAllAssets();
    };

    // Retrieve assets owned by a specific user
    public func getAssetsByOwner(
        assetManager: AssetModule.AssetManager,
        owner: Principal
    ): async [AssetModule.Asset] {
        await assetManager.getAssetsByOwner(owner);
    };

    // Retrieve all active assets
    public func getActiveAssets(
        assetManager: AssetModule.AssetManager
    ): async [AssetModule.Asset] {
        assetManager.getActiveAssets();
    };

    // Search assets by metadata keyword
    public func searchAssetsByMetadata(
        assetManager: AssetModule.AssetManager,
        keyword: Text
    ): async [AssetModule.Asset] {
        assetManager.searchByMetadata(keyword);
    };

    // Batch transfer ownership of assets
    public func batchTransferAssets(
        assetManager: AssetModule.AssetManager,
        assetIds: [Nat],
        newOwner: Principal
    ): async Result.Result<[AssetModule.Asset], Text> {
        await assetManager.batchTransferAssets(assetIds, newOwner);
    };
};