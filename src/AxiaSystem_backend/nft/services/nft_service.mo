import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import NFTModule "../../nft/modules/nft_module";
import EventManager "../../heartbeat/event_manager";

module {
    public func createNFTService(eventManager: EventManager.EventManager): NFTModule.NFTManager {
        NFTModule.NFTManager(eventManager)
    };

    // Create a new NFT
    public func createNFT(
        nftManager: NFTModule.NFTManager,
        creator: Principal,
        metadata: Text
    ): async Result.Result<NFTModule.NFT, Text> {
        await nftManager.createNFT(creator, metadata);
    };

    // Transfer ownership of an NFT
    public func transferNFT(
        nftManager: NFTModule.NFTManager,
        nftId: Nat,
        newOwner: Principal
    ): async Result.Result<NFTModule.NFT, Text> {
        await nftManager.transferNFT(nftId, newOwner);
    };

    // Deactivate an NFT
    public func deactivateNFT(
        nftManager: NFTModule.NFTManager,
        nftId: Nat
    ): async Result.Result<NFTModule.NFT, Text> {
        await nftManager.deactivateNFT(nftId);
    };

    // Reactivate an NFT
    public func reactivateNFT(
        nftManager: NFTModule.NFTManager,
        nftId: Nat
    ): async Result.Result<NFTModule.NFT, Text> {
        await nftManager.reactivateNFT(nftId);
    };

    // Retrieve an NFT by ID
    public func getNFT(
        nftManager: NFTModule.NFTManager,
        nftId: Nat
    ): async Result.Result<NFTModule.NFT, Text> {
        await nftManager.getNFT(nftId);
    };

    // Retrieve all NFTs for a specific owner
    public func getNFTsByOwner(
        nftManager: NFTModule.NFTManager,
        owner: Principal
    ): async [NFTModule.NFT] {
        await nftManager.getNFTsByOwner(owner);
    };

    // Retrieve all NFTs
    public func getAllNFTs(nftManager: NFTModule.NFTManager): async [NFTModule.NFT] {
        await nftManager.getAllNFTs();
    };
};