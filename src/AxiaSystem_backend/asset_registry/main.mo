import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import EventManager "../heartbeat/event_manager";
import AssetRegistryModule "./modules/asset_registry_module";
import AssetRegistryService "./services/asset_registry_service";

persistent actor AssetRegistryCanister {
    // Initialize the event manager
    private transient let eventManager = EventManager.EventManager();

    // Initialize the Asset Registry Service
    private transient let assetRegistryService = AssetRegistryService.createAssetRegistryService(eventManager);

    // Public APIs

    // Register a new asset
    public func registerAsset(
        owner: Principal,
        nftId: Nat,
        metadata: Text
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        let result = await assetRegistryService.registerAssetInRegistry(owner, nftId, metadata);
        switch (result) {
            case (#ok(asset)) #ok(asset);
            case (#err(error)) #err(error);
        }
    };

    // Transfer ownership of an asset
    public func transferAsset(
        assetId: Nat,
        newOwner: Principal
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        let result = await assetRegistryService.transferAssetInRegistry(assetId, newOwner);
        switch (result) {
            case (#ok(asset)) #ok(asset);
            case (#err(error)) #err(error);
        }
    };

    // Deactivate an asset
    public func deactivateAsset(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
        let result = await assetRegistryService.deactivateAssetInRegistry(assetId);
        switch (result) {
            case (#ok(asset)) #ok(asset);
            case (#err(error)) #err(error);
        }
    };

    // Reactivate an asset
    public func reactivateAsset(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
        let result = await assetRegistryService.reactivateAssetInRegistry(assetId);
        switch (result) {
            case (#ok(asset)) #ok(asset);
            case (#err(error)) #err(error);
        }
    };

    // Retrieve asset details by ID
    public func getAsset(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
        let result = await assetRegistryService.getAssetInRegistry(assetId);
        switch (result) {
            case (#ok(asset)) #ok(asset);
            case (#err(error)) #err(error);
        }
    };

    // Retrieve all assets owned by a specific user
    public func getAssetsByOwner(owner: Principal): async [AssetRegistryModule.Asset] {
        await assetRegistryService.getAssetsByOwnerInRegistry(owner);
    };

    // Retrieve all assets linked to a specific NFT
    public func getAssetsByNFT(nftId: Nat): async [AssetRegistryModule.Asset] {
        await assetRegistryService.getAssetsByNFTInRegistry(nftId);
    };

    // Retrieve all assets in the registry
    public func getAllAssets(): async [AssetRegistryModule.Asset] {
        await assetRegistryService.getAllAssetsInRegistry();
    };

    // Retrieve ownership history of an asset
    public func getAssetOwnershipHistory(assetId: Nat): async Result.Result<[Principal], Text> {
        let result = await assetRegistryService.getAssetOwnershipHistoryInRegistry(assetId);
        switch (result) {
            case (#ok(history)) #ok(history);
            case (#err(error)) #err(error);
        }
    };

    // System Health Check
    public shared func healthCheck(): async Text {
        try {
            let allAssets = await assetRegistryService.getAllAssetsInRegistry();
            if (allAssets.size() > 0) {
                "Asset Registry is operational. Total assets: " # Nat.toText(allAssets.size())
            } else {
                "Asset Registry is operational. No assets found."
            }
        } catch (e) {
            "Asset Registry health check failed: " # Error.message(e);
        }
    };

    // Optional: Heartbeat Integration
    public shared func runHeartbeat(): async () {
        Debug.print("Asset Registry canister heartbeat executed.");
        // Add periodic tasks here, such as cleanup or reporting
    };
};