import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import EventManager "../heartbeat/event_manager";
import _EventTypes "../heartbeat/event_types";
import NFTModule "./modules/nft_module"; // Your provided NFTManager module

actor NFTCanister {
    // Initialize the Event Manager
    private let eventManager = EventManager.EventManager();

    // Initialize the NFT Manager
    private let nftManager = NFTModule.NFTManager(eventManager);

    // Public APIs

    // Create a new NFT
    public func createNFT(creator: Principal, metadata: Text): async Result.Result<NFTModule.NFT, Text> {
        let result = await nftManager.createNFT(creator, metadata);
        switch (result) {
            case (#ok(nft)) #ok(nft);
            case (#err(error)) #err(error);
        }
    };

    // Transfer NFT ownership
    public func transferNFT(nftId: Nat, newOwner: Principal): async Result.Result<NFTModule.NFT, Text> {
        let result = await nftManager.transferNFT(nftId, newOwner);
        switch (result) {
            case (#ok(updatedNFT)) #ok(updatedNFT);
            case (#err(error)) #err(error);
        }
    };

    // Deactivate an NFT
    public func deactivateNFT(nftId: Nat): async Result.Result<NFTModule.NFT, Text> {
        let result = await nftManager.deactivateNFT(nftId);
        switch (result) {
            case (#ok(updatedNFT)) #ok(updatedNFT);
            case (#err(error)) #err(error);
        }
    };

    // Reactivate an NFT
    public func reactivateNFT(nftId: Nat): async Result.Result<NFTModule.NFT, Text> {
        let result = await nftManager.reactivateNFT(nftId);
        switch (result) {
            case (#ok(updatedNFT)) #ok(updatedNFT);
            case (#err(error)) #err(error);
        }
    };

    // Get an NFT by ID
    public func getNFT(nftId: Nat): async Result.Result<NFTModule.NFT, Text> {
        let result = await nftManager.getNFT(nftId);
        switch (result) {
            case (#ok(nft)) #ok(nft);
            case (#err(error)) #err(error);
        }
    };

    // Get all NFTs owned by a specific Principal
    public func getNFTsByOwner(owner: Principal): async [NFTModule.NFT] {
        await nftManager.getNFTsByOwner(owner);
    };

    // Get all NFTs
    public func getAllNFTs(): async [NFTModule.NFT] {
        await nftManager.getAllNFTs();
    };

    // System Health Check
    public shared func healthCheck(): async Text {
        try {
            let allNFTs = await nftManager.getAllNFTs();
            if (allNFTs.size() > 0) {
                "NFT canister is operational. Total NFTs: " # Nat.toText(allNFTs.size())
            } else {
                "NFT canister is operational. No NFTs found."
            }
        } catch (e) {
            "NFT health check failed: " # Error.message(e);
        }
    };

    // Optional: Heartbeat integration
    public shared func runHeartbeat(): async () {
        Debug.print("NFT canister heartbeat executed.");
        // Add any periodic tasks here, such as cleanup or status updates
    };
};