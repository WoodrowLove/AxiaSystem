import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import AssetRegistryModule "./modules/asset_registry_module";
import AssetRegistryService "./services/asset_registry_service";
import TriadAssetRegistryService "./services/triad_asset_registry_service";

persistent actor AssetRegistryCanister {

    // Initialize the Asset Registry Manager
    private transient let assetRegistryManager = AssetRegistryService.createAssetRegistryService();

    // Initialize the Triad Asset Registry Service (with placeholder canister references)
    private transient let triadAssetRegistryService = TriadAssetRegistryService.TriadAssetRegistryService(
        assetRegistryManager,
        null, // identityCanister: ?IdentityService - to be connected
        null, // userCanister: ?UserService - to be connected  
        null, // walletCanister: ?WalletService - to be connected
        null  // eventHub: ?EventHub - to be connected
    );

    // 🔥 TRIAD-COMPLIANT ENDPOINTS (New, Recommended)

    // Register Asset with Full Triad Validation
    public shared ({ caller = _ }) func registerAssetTriad(
        identityId: Principal,
        nftId: Nat,
        metadata: Text,
        proof: TriadAssetRegistryService.LinkProof,
        userId: ?Principal,
        walletId: ?Principal
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        await triadAssetRegistryService.registerAssetTriad(identityId, nftId, metadata, proof, userId, walletId)
    };

    // Transfer Asset Ownership with Triad Validation
    public shared ({ caller = _ }) func transferAssetTriad(
        identityId: Principal,
        assetId: Nat,
        newOwnerIdentity: Principal,
        proof: TriadAssetRegistryService.LinkProof,
        userId: ?Principal
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        await triadAssetRegistryService.transferAssetTriad(identityId, assetId, newOwnerIdentity, proof, userId)
    };

    // Deactivate Asset with Triad Validation
    public shared ({ caller = _ }) func deactivateAssetTriad(
        identityId: Principal, 
        assetId: Nat, 
        proof: TriadAssetRegistryService.LinkProof
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        await triadAssetRegistryService.deactivateAssetTriad(identityId, assetId, proof)
    };

    // Reactivate Asset with Triad Validation
    public shared ({ caller = _ }) func reactivateAssetTriad(
        identityId: Principal, 
        assetId: Nat, 
        proof: TriadAssetRegistryService.LinkProof
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        await triadAssetRegistryService.reactivateAssetTriad(identityId, assetId, proof)
    };

    // 🔄 LEGACY ENDPOINTS (Backward Compatibility - Deprecated)
    // Note: These maintain backward compatibility but mark triadVerified=false
    // New integrations should use the *Triad endpoints above

    // Register a new asset (Legacy)
    public shared ({ caller = _ }) func registerAsset(
        owner: Principal,
        nftId: Nat,
        metadata: Text
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        AssetRegistryService.registerAssetLegacy(assetRegistryManager, owner, nftId, metadata)
    };

    // Transfer ownership of an asset (Legacy)
    public shared ({ caller = _ }) func transferAsset(
        assetId: Nat,
        newOwner: Principal
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        AssetRegistryService.transferAssetLegacy(assetRegistryManager, assetId, newOwner)
    };

    // Deactivate an asset (Legacy)
    public shared ({ caller = _ }) func deactivateAsset(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
        AssetRegistryService.deactivateAssetLegacy(assetRegistryManager, assetId)
    };

    // Reactivate an asset (Legacy)
    public shared ({ caller = _ }) func reactivateAsset(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
        AssetRegistryService.reactivateAssetLegacy(assetRegistryManager, assetId)
    };

    // 🔍 QUERY ENDPOINTS (Backward Compatible)
    // These work for both Triad and Legacy assets

    // Retrieve asset details by ID
    public query func getAsset(
        assetId: Nat
    ): async Result.Result<AssetRegistryModule.Asset, Text> {
        AssetRegistryService.getAsset(assetRegistryManager, assetId)
    };

    // Retrieve all assets owned by a specific user (supports both legacy owner and Identity)
    public query func getAssetsByOwner(owner: Principal): async [AssetRegistryModule.Asset] {
        AssetRegistryService.getAssetsByOwner(assetRegistryManager, owner)
    };

    // Retrieve all assets linked to a specific NFT
    public query func getAssetsByNFT(nftId: Nat): async [AssetRegistryModule.Asset] {
        AssetRegistryService.getAssetsByNFT(assetRegistryManager, nftId)
    };

    // Retrieve all assets in the registry
    public query func getAllAssets(): async [AssetRegistryModule.Asset] {
        AssetRegistryService.getAllAssets(assetRegistryManager)
    };

    // Retrieve ownership history of an asset
    public query func getAssetOwnershipHistory(assetId: Nat): async [Principal] {
        AssetRegistryService.getAssetOwnershipHistory(assetRegistryManager, assetId)
    };

    // 📊 SYSTEM INFORMATION

    // Get system statistics
    public query func getSystemStats(): async {
        totalAssets: Nat;
        activeAssets: Nat;
        triadVerifiedAssets: Nat;
        nftLinkedAssets: Nat;
    } {
        let allAssets = AssetRegistryService.getAllAssets(assetRegistryManager);
        let activeAssets = Array.filter(allAssets, func(a: AssetRegistryModule.Asset): Bool { a.isActive });
        let triadVerified = Array.filter(allAssets, func(a: AssetRegistryModule.Asset): Bool { a.triadVerified });
        let nftLinked = Array.filter(allAssets, func(a: AssetRegistryModule.Asset): Bool { a.nftId > 0 });
        
        {
            totalAssets = allAssets.size();
            activeAssets = activeAssets.size();
            triadVerifiedAssets = triadVerified.size();
            nftLinkedAssets = nftLinked.size();
        }
    };

    // System Health Check
    public query func healthCheck(): async Bool {
        true
    };
};