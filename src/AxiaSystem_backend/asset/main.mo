import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import AssetService "./services/asset_service";
import EventManager "../heartbeat/event_manager";
import AssetModule "./modules/asset_module";

actor AssetCanister {
    // Initialize the event manager
    private let eventManager = EventManager.EventManager();

    // Initialize the Asset Manager
    private let assetManager = AssetService.createAssetService(eventManager);

    // Public APIs

    // Register a new asset
    public func registerAsset(
        owner: Principal,
        metadata: Text
    ): async Result.Result<Nat, Text> {
        let result = await AssetService.registerAsset(assetManager, owner, metadata);
        switch (result) {
            case (#ok(asset)) #ok(asset.id);
            case (#err(error)) #err(error);
        }
    };

    // Transfer ownership of an asset
    // Transfer ownership of an asset
public func transferAsset(
    assetId: Nat,
    newOwner: Principal
): async Result.Result<(), Text> {
    let result = await AssetService.transferAsset(assetManager, assetId, newOwner);
    switch (result) {
        case (#ok(_)) { #ok(()) };
        case (#err(e)) { #err(e) };
    }
};

    // Deactivate an asset
public func deactivateAsset(assetId: Nat): async Result.Result<(), Text> {
    let result = await AssetService.deactivateAsset(assetManager, assetId);
    switch (result) {
        case (#ok(_)) { #ok(()) };
        case (#err(e)) { #err(e) };
    }
};

// Reactivate an asset
public func reactivateAsset(assetId: Nat): async Result.Result<(), Text> {
    let result = await AssetService.reactivateAsset(assetManager, assetId);
    switch (result) {
        case (#ok(_)) { #ok(()) };
        case (#err(e)) { #err(e) };
    }
};
    // Retrieve asset details by ID
    public func getAsset(
        assetId: Nat
    ): async Result.Result<AssetModule.Asset, Text> {
        await AssetService.getAsset(assetManager, assetId);
    };

    // Retrieve all assets
    public func getAllAssets(): async [AssetModule.Asset] {
        await AssetService.getAllAssets(assetManager);
    };

    // Retrieve assets owned by a specific user
    public func getAssetsByOwner(owner: Principal): async [AssetModule.Asset] {
        await AssetService.getAssetsByOwner(assetManager, owner);
    };

    // Retrieve all active assets
    public func getActiveAssets(): async [AssetModule.Asset] {
        await AssetService.getActiveAssets(assetManager);
    };

    // Search assets by metadata keyword
    public func searchAssetsByMetadata(keyword: Text): async [AssetModule.Asset] {
        await AssetService.searchAssetsByMetadata(assetManager, keyword);
    };

    // Batch transfer ownership of assets
    public func batchTransferAssets(
        assetIds: [Nat],
        newOwner: Principal
    ): async Result.Result<[AssetModule.Asset], Text> {
        await AssetService.batchTransferAssets(assetManager, assetIds, newOwner);
    };
};