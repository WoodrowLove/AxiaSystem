import WalletModule "./modules/wallet_module";
import WalletService "./services/wallet_service";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import _List "mo:base/List";
import UserCanisterProxy "../user/utils/user_canister_proxy";
import TokenCanisterProxy "../token/utils/token_canister_proxy";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import EventManager "../heartbeat/event_manager";

actor WalletCanister {
    private let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("c2lt4-zmaaa-aaaaa-qaaiq-cai"));
    private let tokenCanisterProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("aax3a-h4aaa-aaaaa-qaahq-cai"));

    private let tokenProxy = {
        getAllTokens = tokenCanisterProxy.getAllTokens;
        getToken = tokenCanisterProxy.getToken;
        updateToken = tokenCanisterProxy.updateToken;
        mintTokens = tokenCanisterProxy.mintTokens;
        attachTokensToUser = tokenCanisterProxy.attachTokensToUser;
    };

    private let walletManager = WalletModule.WalletManager(userProxy, tokenProxy);
    private let walletService = WalletService.WalletService(walletManager, EventManager.EventManager());

    
    // Create a wallet for a user
    public func createWallet(userId: Principal, initialBalance: Nat): async Result.Result<WalletModule.Wallet, Text> {
        await walletService.createWallet(userId, initialBalance);
    };

    // Get a wallet by the owner's Principal
    public func getWalletByOwner(ownerId: Principal): async Result.Result<WalletModule.Wallet, Text> {
        let walletResult = await walletService.getWalletByOwner(ownerId);
        switch (walletResult) {
            case (#ok(wallet)) {
                #ok(wallet);
            };
            case (#err(error)) {
                #err("Failed to retrieve wallet: " # error);
            };
        }
    };

    // Update the wallet balance
    public func updateBalance(ownerId: Principal, amount: Int): async Result.Result<Nat, Text> {
        await walletService.updateBalance(ownerId, amount);
    };

    // Get transaction history for a wallet
    public func getTransactionHistory(ownerId: Principal): async Result.Result<[WalletModule.WalletTransaction], Text> {
        await walletService.getTransactionHistory(ownerId);
    };

    // Delete a wallet
    public func deleteWallet(ownerId: Principal): async Result.Result<(), Text> {
        await walletService.deleteWallet(ownerId);
    };

    // Credit a wallet (add funds)
    public func creditWallet(userId: Principal, amount: Nat): async Result.Result<Nat, Text> {
        await walletService.creditWallet(userId, amount);
    };

    // Debit a wallet (withdraw funds)
    public func debitWallet(userId: Principal, amount: Nat): async Result.Result<Nat, Text> {
        await walletService.debitWallet(userId, amount);
    };

    // Attach token balances to a wallet
    public func attachTokenBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
        await walletService.attachTokenBalance(userId, tokenId, amount);
    };

    // Get wallet balance
    public func getWalletBalance(userId: Principal): async Result.Result<Nat, Text> {
        await walletService.getWalletBalance(userId);
    };
};