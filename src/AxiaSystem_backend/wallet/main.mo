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

    private transient let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("uzt4z-lp777-77774-qaabq-cai"));
    private transient let tokenCanisterProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("xad5d-bh777-77774-qaaia-cai"));

    // Identity canister for session validation
    private transient let IDENTITY_CANISTER_ID = "uxrrr-q7777-77774-qaaaq-cai";
    
    public type SessionScope = {
        #wallet_read;
        #wallet_transfer;
        #wallet_admin;
        #user_profile;
        #user_admin;
        #admin_security;
        #admin_roles;
        #ai_submit;
        #ai_deliver;
        #notify_send;
        #notify_admin;
        #gov_approve;
        #system_admin;
    };

    public type SessionValidation = {
        valid: Bool;
        session: ?{ sessionId: Text; identityId: Principal; deviceId: Principal; riskScore: Nat8 };
        reason: ?Text;
        remaining: Nat64;
        riskAssessment: { score: Nat8; factors: [Text]; action: { #allow; #challenge; #deny } };
    };

    // Validate session with identity canister
    private func validateSessionInternal(sessionId: Text, requiredScopes: [SessionScope]): async SessionValidation {
        let identityCanister = actor(IDENTITY_CANISTER_ID) : actor {
            validateSession: (Text, [SessionScope]) -> async SessionValidation;
        };
        
        try {
            await identityCanister.validateSession(sessionId, requiredScopes)
        } catch (_error) {
            {
                valid = false;
                session = null;
                reason = ?"Session validation service unavailable";
                remaining = 0;
                riskAssessment = { score = 10; factors = ["validation_error"]; action = #deny };
            }
        }
    };

    private transient let tokenProxy = {
        getAllTokens = tokenCanisterProxy.getAllTokens;
        getToken = tokenCanisterProxy.getToken;
        updateToken = tokenCanisterProxy.updateToken;
        mintTokens = tokenCanisterProxy.mintTokens;
        mintToUser = tokenCanisterProxy.mintToUser;
        attachTokensToUser = tokenCanisterProxy.attachTokensToUser;
        getBalanceOf = tokenCanisterProxy.getBalanceOf;
        getBalancesForUser = tokenCanisterProxy.getBalancesForUser;
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

    // Session-validated credit wallet
    public shared func creditWalletWithSession(userId: Principal, amount: Nat, sessionId: Text): async Result.Result<Nat, Text> {
        await emitInsight("info", "Session-validated credit request for user: " # Principal.toText(userId) # " amount: " # Nat.toText(amount));
        
        // Validate session with required scope
        let validation = await validateSessionInternal(sessionId, [#wallet_transfer]);
        
        if (not validation.valid) {
            let reason = switch (validation.reason) { case (?r) r; case null "Invalid session" };
            await emitInsight("error", "Credit denied due to session validation: " # reason);
            return #err("Session validation failed: " # reason);
        };
        
        // Check if session belongs to the user
        switch (validation.session) {
            case null {
                await emitInsight("error", "Credit denied: No session information");
                return #err("Session validation failed: No session information");
            };
            case (?session) {
                if (session.identityId != userId) {
                    await emitInsight("error", "Credit denied: Session identity mismatch");
                    return #err("Session validation failed: Identity mismatch");
                };
                
                // Check risk assessment
                if (validation.riskAssessment.action == #deny) {
                    await emitInsight("warning", "Credit denied due to high risk assessment");
                    return #err("Operation denied due to security risk");
                };
                
                // Proceed with credit
                await emitInsight("info", "Session validated, proceeding with credit operation");
                await walletService.creditWallet(userId, amount);
            };
        }
    };

    // Debit a wallet (withdraw funds)
    public func debitWallet(userId: Principal, amount: Nat): async Result.Result<Nat, Text> {
        await walletService.debitWallet(userId, amount);
    };

    // Attach token balances to a wallet
    public func attachTokenBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
        await walletService.attachTokenBalance(userId, tokenId, amount);
    };

    // Retrieve wallet balance
    public shared func getWalletBalance(userId: Principal): async Result.Result<Nat, Text> {
        await walletManager.getWalletBalance(userId);
    };

    // NEW: Ensure wallet exists, create if it doesn't
    public shared func ensureWallet(userId: Principal): async Result.Result<WalletModule.Wallet, Text> {
        await emitInsight("info", "Ensuring wallet for user: " # Principal.toText(userId));
        
        let result = await walletManager.ensureWallet(userId);
        
        switch (result) {
            case (#ok(wallet)) {
                await emitInsight("info", "Wallet ensured for user with balance: " # Nat.toText(wallet.balance));
            };
            case (#err(error)) {
                await emitInsight("error", "Wallet ensure failed: " # error);
            };
        };
        
        result
    };

    // NEW: Get comprehensive wallet overview
    public shared func getWalletOverview(userId: Principal): async Result.Result<{nativeBalance: Nat; tokenBalances: [(Nat, Nat)]}, Text> {
        await walletManager.getWalletOverview(userId);
    };
};