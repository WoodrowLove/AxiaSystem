import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Hash "mo:base/Hash";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Text "mo:base/Text";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    // Type definition for Asset
    public type Asset = {
        id: Nat;                  // Unique asset identifier
        owner: Principal;         // Current owner
        metadata: Text;           // Asset metadata (e.g., description, category)
        registeredAt: Int;        // Timestamp of asset registration
        updatedAt: Int;           // Last update timestamp
        isActive: Bool;           // Asset activity status
    };

    // Custom type for AssetId
    public type AssetId = Nat;

    public class AssetManager(eventManager: EventManager.EventManager) {
        private var assets: [(AssetId, Asset)] = []; // Array to store assets
        private var nextAssetId: Nat = 1;           // Auto-incrementing asset ID

        // Helper function for generating unique hash values for asset IDs
        private func _hashAssetId(id: Nat): Hash.Hash {
            let hashValue = Nat32.fromNat(id);
            hashValue ^ (hashValue >> 16)
        };

        // Emit events for asset-related actions
        private func emitAssetEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload): async () {
            let event: EventTypes.Event = {
                id = Nat64.fromNat(Int.abs(Time.now()));
                eventType = eventType;
                payload = payload;
            };
            await eventManager.emit(event);
        };

        // Register a new asset
        public func registerAsset(
            owner: Principal,
            metadata: Text
        ): async Result.Result<Asset, Text> {
            if (metadata.size() == 0) {
                return #err("Metadata cannot be empty.");
            };

            let newAsset: Asset = {
                id = nextAssetId;
                owner = owner;
                metadata = metadata;
                registeredAt = Time.now();
                updatedAt = Time.now();
                isActive = true;
            };

            assets := Array.append(assets, [(nextAssetId, newAsset)]);
            nextAssetId += 1;

            await emitAssetEvent(#AssetRegistered, #AssetRegistered {
    assetId = newAsset.id;
    owner = owner;
    metadata = metadata;
    registeredAt = Time.now();
});

            #ok(newAsset)
        };

        public func transferAsset(
    assetId: AssetId,
    newOwner: Principal
): async Result.Result<Asset, Text> {
    let assetOpt = Array.find<(AssetId, Asset)>(assets, func((id, _): (AssetId, Asset)): Bool {
        id == assetId
    });

    switch (assetOpt) {
        case null {
            #err("Asset not found.")
        };
        case (?(_foundId, asset)) {
            if (not asset.isActive) {
                return #err("Asset is inactive.");
            };

            let updatedAsset = {
                asset with
                owner = newOwner;
                updatedAt = Time.now();
            };

            assets := Array.map<(AssetId, Asset), (AssetId, Asset)>(assets, func((id, a): (AssetId, Asset)): (AssetId, Asset) {
                if (id == assetId) {
                    (id, updatedAsset)
                } else {
                    (id, a)
                }
            });

            await emitAssetEvent(#AssetTransferred, #AssetTransferred {
    assetId = assetId;
    previousOwner = asset.owner;
    newOwner = newOwner;
    transferTime = Time.now();
});

            #ok(updatedAsset)
        };
    };
};

       public func deactivateAsset(assetId: AssetId): async Result.Result<Asset, Text> {
    let assetOpt = Array.find<(AssetId, Asset)>(assets, func((id, _): (AssetId, Asset)): Bool {
        id == assetId
    });

    switch (assetOpt) {
        case null {
            #err("Asset not found.")
        };
        case (?(_foundId, asset)) {
            if (not asset.isActive) {
                return #err("Asset is already inactive.");
            };

            let updatedAsset = { 
                asset with 
                isActive = false; 
                updatedAt = Time.now() 
            };

            assets := Array.map<(AssetId, Asset), (AssetId, Asset)>(assets, func((id, a): (AssetId, Asset)): (AssetId, Asset) {
                if (id == assetId) {
                    (id, updatedAsset)
                } else {
                    (id, a)
                }
            });

           await emitAssetEvent(#AssetDeactivated, #AssetDeactivated {
    assetId = assetId;
    owner = asset.owner;
    deactivatedAt = Time.now();
});

            #ok(updatedAsset)
        };
    };
};

        public func reactivateAsset(assetId: AssetId): async Result.Result<Asset, Text> {
    let assetOption = Array.find<(AssetId, Asset)>(assets, func((id, _): (AssetId, Asset)) : Bool {
        id == assetId
    });

    switch (assetOption) {
        case null {
            #err("Asset not found.")
        };
        case (?(_, asset)) {
            if (asset.isActive) {
                #err("Asset is already active.")
            } else {
                let now = Time.now();
                let updatedAsset = { asset with isActive = true; updatedAt = now };
                
                // Update the asset in the array
                assets := Array.map<(AssetId, Asset), (AssetId, Asset)>(assets, func((id, a)) {
                    if (id == assetId) (id, updatedAsset) else (id, a)
                });

                await emitAssetEvent(#AssetReactivated, #AssetReactivated {
                    assetId = assetId;
                    owner = asset.owner;
                    reactivatedAt = now;
                });

                #ok(updatedAsset)
            }
        };
    };
};

        // Retrieve asset details by ID
        public func getAsset(assetId: AssetId): async Result.Result<Asset, Text> {
            let assetOpt = Array.find(assets, func((id, _): (AssetId, Asset)): Bool {
                id == assetId
            });

            switch (assetOpt) {
                case null {
                    #err("Asset not found.");
                };
                case (?(_, asset)) {
                    #ok(asset)
                };
            };
        };

        // Retrieve all assets
        public func getAllAssets(): async [Asset] {
            Array.map(assets, func((_, asset): (AssetId, Asset)): Asset {
                asset
            })
        };

        // Retrieve assets owned by a specific user
public func getAssetsByOwner(owner: Principal): async [Asset] {
    Array.filter<Asset>(Array.map(assets, func((_, asset): (AssetId, Asset)): Asset { asset }), func(asset: Asset): Bool {
        asset.owner == owner
    })
};

// Retrieve all active assets
public func getActiveAssets(): async [Asset] {
    Array.filter<Asset>(Array.map(assets, func((_, asset): (AssetId, Asset)): Asset { asset }), func(asset: Asset): Bool {
        asset.isActive
    })
};

// Search assets by metadata keyword
public func searchAssetsByMetadata(keyword: Text): async [Asset] {
    Array.filter<Asset>(Array.map(assets, func((_, asset): (AssetId, Asset)): Asset { asset }), func(asset: Asset): Bool {
        Text.contains(asset.metadata, #text keyword)
    })
};

// Batch transfer ownership of assets
public func batchTransferAssets(assetIds: [AssetId], newOwner: Principal): async Result.Result<[Asset], Text> {
    var updatedAssets: [Asset] = [];
    for (assetId in assetIds.vals()) {
        let transferResult = await transferAsset(assetId, newOwner);
        switch (transferResult) {
            case (#ok(asset)) updatedAssets := Array.append(updatedAssets, [asset]);
            case (#err(e)) return #err("Failed to transfer asset with ID: " # Nat.toText(assetId) # ", Error: " # e);
        }
    };
    #ok(updatedAssets)
};
    };
};