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

// 🧠 NamoraAI Observability Imports
import Insight "../types/insight";
import Time "mo:base/Time";
import Debug "mo:base/Debug";

persistent actor WalletCanister {

    // 🧠 NamoraAI Observability Helper
    private func emitInsight(severity: Text, message: Text) : async () {
        let _insight : Insight.SystemInsight = {
            source = "wallet";
            severity = severity;
            message = message;
            timestamp = Time.now();
        };
        Debug.print("🧠 WALLET INSIGHT [" # severity # "]: " # message);
        // await NamoraAI.pushInsight(insight);
    };

    private transient let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("xad5d-bh777-77774-qaaia-cai"));
    private transient let tokenCanisterProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("v27v7-7x777-77774-qaaha-cai"));

    private transient let tokenProxy = {
        getAllTokens = tokenCanisterProxy.getAllTokens;
        getToken = tokenCanisterProxy.getToken;
        updateToken = tokenCanisterProxy.updateToken;
        mintTokens = tokenCanisterProxy.mintTokens;
        attachTokensToUser = tokenCanisterProxy.attachTokensToUser;
    };

    private transient let walletManager = WalletModule.WalletManager(userProxy, tokenProxy);
    private transient let walletService = WalletService.WalletService(walletManager, EventManager.EventManager());

    
    // Create a wallet for a user
    public func createWallet(userId: Principal, initialBalance: Nat): async Result.Result<WalletModule.Wallet, Text> {
        await emitInsight("info", "Wallet creation initiated for user: " # Principal.toText(userId) # " with balance: " # Nat.toText(initialBalance));
        
        let result = await walletService.createWallet(userId, initialBalance);
        
        switch (result) {
            case (#ok(_wallet)) {
                await emitInsight("info", "Wallet successfully created for user: " # Principal.toText(userId));
            };
            case (#err(error)) {
                await emitInsight("error", "Wallet creation failed for user: " # Principal.toText(userId) # " - " # error);
            };
        };
        
        result
    };

    // Get a wallet by the owner's Principal
    public func getWalletByOwner(ownerId: Principal): async Result.Result<WalletModule.Wallet, Text> {
        let walletResult = await walletService.getWalletByOwner(ownerId);
        switch (walletResult) {
            case (#ok(wallet)) {
                await emitInsight("info", "Wallet lookup successful for owner: " # Principal.toText(ownerId));
                #ok(wallet);
            };
            case (#err(error)) {
                await emitInsight("warning", "Wallet lookup failed for owner: " # Principal.toText(ownerId) # " - " # error);
                #err("Failed to retrieve wallet: " # error);
            };
        }
    };

    // Update the wallet balance
    public func updateBalance(ownerId: Principal, amount: Int): async Result.Result<Nat, Text> {
        let amountStr = if (amount >= 0) { "+" # Int.toText(amount) } else { Int.toText(amount) };
        await emitInsight("info", "Balance update initiated for owner: " # Principal.toText(ownerId) # ", amount: " # amountStr);
        
        let result = await walletService.updateBalance(ownerId, amount);
        
        switch (result) {
            case (#ok(newBalance)) {
                await emitInsight("info", "Balance successfully updated for owner: " # Principal.toText(ownerId) # ", new balance: " # Nat.toText(newBalance));
                if (newBalance < 100) { // Warning for low balance
                    await emitInsight("warning", "Low balance detected for owner: " # Principal.toText(ownerId) # " - current balance: " # Nat.toText(newBalance));
                };
            };
            case (#err(error)) {
                await emitInsight("error", "Balance update failed for owner: " # Principal.toText(ownerId) # " - " # error);
            };
        };
        
        result
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