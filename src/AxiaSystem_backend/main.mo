import TokenCanisterProxy "./token/utils/token_canister_proxy";
import UserCanisterProxy "./user/utils/user_canister_proxy";
import WalletCanisterProxy "./wallet/utils/wallet_canister_proxy";
import PaymentCanisterProxy "./payment/utils/payment_canister_proxy";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import _List "mo:base/List";
import Int "mo:base/Int";
import EventManager "./heartbeat/event_manager";
import EventTypes "./heartbeat/event_types";
import _Time "mo:base/Time";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Error "mo:base/Error";

actor AxiaSystem_backend {
    // Initialize proxies for all canisters
    private let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("YOUR_TOKEN_CANISTER_ID"));
    private let _userProxy = UserCanisterProxy.UserCanisterProxyManager(Principal.fromText("YOUR_USER_CANISTER_ID"));
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(Principal.fromText("YOUR_WALLET_CANISTER_ID"));
    private let paymentProxy = PaymentCanisterProxy.PaymentCanisterProxy(Principal.fromText("YOUR_PAYMENT_CANISTER_ID"));

    // Initialize event manager for the heartbeat
    private let eventManager = EventManager.EventManager();

    // Exposed APIs to connect with frontend or other services

    // Create a user wallet
    public func createUserWallet(userId: Principal, initialBalance: Nat): async Result.Result<Text, Text> {
        let result = await walletProxy.createWallet(userId, initialBalance);
        switch (result) {
            case (#ok(wallet)) #ok("Wallet created with ID: " # Int.toText(wallet.id));
            case (#err(error)) #err(error);
        }
    };

    // Credit a user wallet
    public func creditUserWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
        await walletProxy.creditWallet(userId, amount, tokenId)
    };

    // Debit a user wallet
    public func debitUserWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
        await walletProxy.debitWallet(userId, amount, tokenId)
    };

    // Get transaction history for a wallet
    public func getWalletTransactionHistory(userId: Principal): async Result.Result<[WalletCanisterProxy.Transaction], Text> {
        let result = await walletProxy.getTransactionHistory(userId);
        switch (result) {
            case (#ok(transactions)) #ok(transactions);
            case (#err(e)) #err(e);
        }
    };

    // Create a token
    public func createToken(
        name: Text,
        symbol: Text,
        totalSupply: Nat,
        decimals: Nat,
        owner: Principal
    ): async Result.Result<Text, Text> {
        let result = await tokenProxy.createToken(name, symbol, totalSupply, decimals, owner);
        switch (result) {
            case (#ok(token)) #ok("Token created with ID: " # Nat.toText(token.id));
            case (#err(error)) #err(error);
        }
    };

    // Mint tokens for a user
    public func mintTokens(_tokenId: Nat, amount: Nat, userId: Principal): async Result.Result<(), Text> {
        await tokenProxy.mintTokens(userId, amount)
    };

    // Handle token-related events
    public func initializeEventListeners() : async () {
        // Example: Handle TokenCreated event
        let onTokenCreated = func(event: EventTypes.Event) : async () {
            switch (event.payload) {
                case (#TokenCreated { tokenId; name; owner }) {
                    Debug.print("Token created: " # name # ", ID: " # Nat.toText(tokenId) # ", Owner: " # Principal.toText(owner));
                };
                case (_) {}; // Ignore other events
            };
        };
        await eventManager.subscribe(#TokenCreated, onTokenCreated);

        // Add other event subscriptions as needed (e.g., #TokenMinted, #TokenBurned)
    };

    // System health check
    public func healthCheck(): async Text {
        try {
            let tokenStatus = await tokenProxy.getAllTokens();
           let walletStatus = await walletProxy.getTransactionHistory(Principal.fromText("2vxsx-fae"));
if (tokenStatus.size() > 0 and (switch walletStatus { case (#ok(_)) true; case (#err(_)) false })) {
    "System is operational"
} else {
    "System has issues"
}
        } catch (e) {
            "System health check failed: " # Error.message(e);
        }
    };

    // Heartbeat integration (periodic tasks)
    public func runHeartbeat(): async () {
        Debug.print("Running heartbeat tasks...");

        // Example: Handle timed-out payments
        let timeoutResult = await paymentProxy.timeoutPendingPayments();
        switch (timeoutResult) {
            case (#ok(count)) Debug.print("Timed-out payments processed: " # Nat.toText(count));
            case (#err(error)) Debug.print("Error processing timed-out payments: " # error);
        };

        // Add more periodic tasks (e.g., releasing locked tokens, processing token events)
    };
};

