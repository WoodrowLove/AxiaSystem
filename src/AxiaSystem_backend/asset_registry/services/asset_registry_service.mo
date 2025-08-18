import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import AssetRegistryModule "../modules/asset_registry_module";

module {
    public func createAssetRegistryService(): AssetRegistryModule.AssetRegistryManager {
        AssetRegistryModule.AssetRegistryManager()
    };

    // Legacy functions that wrap the new module for backward compatibility
    public func registerAssetLegacy(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        owner: Principal,
        nftId: Nat,
        metadata: Text
    ): Result.Result<AssetRegistryModule.Asset, Text> {
        if (Text.size(metadata) == 0) {
            return #err("Metadata cannot be empty.");
        };
        
        let asset = assetRegistryManager.create(
            owner,     // ownerIdentity
            nftId,     // nftId
            metadata,  // metadata
            null,      // userId (legacy has none)
            null,      // walletId (legacy has none)
            false      // triadVerified = false for legacy
        );
        #ok(asset)
    };

    public func transferAssetLegacy(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat,
        newOwner: Principal
    ): Result.Result<AssetRegistryModule.Asset, Text> {
        switch (assetRegistryManager.get(assetId)) {
            case null #err("Asset not found.");
            case (?asset) {
                if (not asset.isActive) {
                    return #err("Asset is inactive.");
                };
                
                switch (assetRegistryManager.transfer(assetId, newOwner)) {
                    case null #err("Transfer failed.");
                    case (?updated) #ok(updated);
                }
            };
        }
    };

    public func deactivateAssetLegacy(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat
    ): Result.Result<AssetRegistryModule.Asset, Text> {
        switch (assetRegistryManager.get(assetId)) {
            case null #err("Asset not found.");
            case (?asset) {
                if (not asset.isActive) {
                    return #err("Asset is already inactive.");
                };
                
                switch (assetRegistryManager.setActive(assetId, false)) {
                    case null #err("Deactivation failed.");
                    case (?updated) #ok(updated);
                }
            };
        }
    };

    public func reactivateAssetLegacy(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat
    ): Result.Result<AssetRegistryModule.Asset, Text> {
        switch (assetRegistryManager.get(assetId)) {
            case null #err("Asset not found.");
            case (?asset) {
                if (asset.isActive) {
                    return #err("Asset is already active.");
                };
                
                switch (assetRegistryManager.setActive(assetId, true)) {
                    case null #err("Reactivation failed.");
                    case (?updated) #ok(updated);
                }
            };
        }
    };

    // Direct query wrappers
    public func getAsset(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat
    ): Result.Result<AssetRegistryModule.Asset, Text> {
        switch (assetRegistryManager.get(assetId)) {
            case null #err("Asset not found.");
            case (?asset) #ok(asset);
        }
    };

    public func getAssetsByOwner(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        owner: Principal
    ): [AssetRegistryModule.Asset] {
        assetRegistryManager.getByOwner(owner)
    };

    public func getAssetsByNFT(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        nftId: Nat
    ): [AssetRegistryModule.Asset] {
        assetRegistryManager.getByNFT(nftId)
    };

    public func getAllAssets(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager
    ): [AssetRegistryModule.Asset] {
        assetRegistryManager.getAll()
    };

    public func getAssetOwnershipHistory(
        assetRegistryManager: AssetRegistryModule.AssetRegistryManager,
        assetId: Nat
    ): [Principal] {
        assetRegistryManager.getHistory(assetId)
    };
};