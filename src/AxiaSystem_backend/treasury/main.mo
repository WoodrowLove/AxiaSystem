import TreasuryModule "../treasury/modules/treasury_module";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import TokenCanisterProxy "../token/utils/token_canister_proxy";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import _Array "mo:base/Array";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import LoggingUtils "../utils/logging_utils";

actor TreasuryCanister {
    // Dependencies
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(
    Principal.fromText("c2lt4-zmaaa-aaaaa-qaaiq-cai"), // Wallet Canister ID
    Principal.fromText("c5kvi-uuaaa-aaaaa-qaaia-cai")  // User Canister ID
);
    private let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("ahw5u-keaaa-aaaaa-qaaha-cai"));
    private let eventManager = EventManager.EventManager();
    private let logStore = LoggingUtils.init();

    // Treasury Manager
    private let treasuryManager = TreasuryModule.TreasuryManager(walletProxy, tokenProxy, eventManager);

    // Add funds to the treasury
    public func addFunds(
        userId: Principal,
        amount: Nat,
        tokenId: ?Nat,
        description: Text
    ): async Result.Result<(), Text> {
        try {
            let result = await treasuryManager.addFunds(userId, amount, tokenId, description);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(logStore, "TreasuryCanister", "Funds added successfully: " # Nat.toText(amount), ?userId);
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "TreasuryCanister", "Failed to add funds: " # e, ?userId);
                    #err(e)
                };
            }
        } catch (error) {
    let errorMessage = Error.message(error);
    LoggingUtils.logError(logStore, "TreasuryCanister", "Unexpected error while adding funds: " # errorMessage, ?userId);
    #err("Unexpected error: " # errorMessage)
};
    };

    // Withdraw funds from the treasury
    public func withdrawFunds(
        userId: Principal,
        amount: Nat,
        tokenId: ?Nat,
        description: Text
    ): async Result.Result<(), Text> {
        try {
            let result = await treasuryManager.withdrawFunds(userId, amount, tokenId, description);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(logStore, "TreasuryCanister", "Funds withdrawn successfully: " # Nat.toText(amount), ?userId);
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "TreasuryCanister", "Failed to withdraw funds: " # e, ?userId);
                    #err(e)
                };
            }
        } catch (error) {
    let errorMessage = Error.message(error);
    LoggingUtils.logError(logStore, "TreasuryCanister", "Unexpected error while withdrawing funds: " # errorMessage, ?userId);
    #err("Unexpected error: " # errorMessage)
};
    };

    // Distribute rewards
    public func distributeRewards(
        recipients: [(Principal, Nat)],
        tokenId: ?Nat,
        description: Text
    ): async Result.Result<(), Text> {
        try {
            let result = await treasuryManager.distributeRewards(recipients, tokenId, description);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(logStore, "TreasuryCanister", "Rewards distributed successfully", null);
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "TreasuryCanister", "Failed to distribute rewards: " # e, null);
                    #err(e)
                };
            }
        } catch (error) {
    let errorMessage = Error.message(error);
    LoggingUtils.logError(logStore, "TreasuryCanister", "Unexpected error while distributing rewards: " # errorMessage, null);
    #err("Unexpected error: " # errorMessage)
};
    };

    // Get treasury balance
public query func getTreasuryBalance(tokenId: ?Nat): async Nat {
    treasuryManager.getTreasuryBalance(tokenId)
};

    // Get transaction history
    public query func getTransactionHistory(): async [TreasuryModule.TreasuryTransaction] {
        treasuryManager.getTransactionHistory();
    };

    // Get treasury audit report
    public query func getTreasuryAuditReport(): async { totalDeposits: Nat; totalWithdrawals: Nat; totalDistributions: Nat } {
        treasuryManager.getTreasuryAuditReport();
    };

    // Filter transactions
    public query func filterTransactions(transactionType: Text, tokenId: ?Nat): async [TreasuryModule.TreasuryTransaction] {
        treasuryManager.filterTransactions(transactionType, tokenId);
    };

    // Lock the treasury
    public func lockTreasury(): async Result.Result<(), Text> {
        await treasuryManager.lockTreasury();
    };

    // Unlock the treasury
    public func unlockTreasury(): async Result.Result<(), Text> {
        await treasuryManager.unlockTreasury();
    };

    // Check if the treasury is locked
    public query func isTreasuryLocked(): async Bool {
        treasuryManager.isTreasuryLocked();
    };

    // Initialize event listeners
public shared func onTreasuryEvent(event: EventTypes.Event): async () {
    switch (event.payload) {
      case (#FundsDeposited { userId; amount; tokenId; timestamp }) {
        let tokenInfo = switch (tokenId) {
          case (null) "Native Token";
          case (?id) "Token ID: " # Nat.toText(id);
        };
        LoggingUtils.logInfo(
          logStore,
          "TreasuryCanister",
          "Funds Deposited: User=" # userId # 
          ", Amount=" # Nat.toText(amount) # 
          ", " # tokenInfo # 
          ", Timestamp=" # Nat64.toText(timestamp),
          null
        );
      };
      case (#FundsWithdrawn { userId; amount; tokenId; timestamp }) {
        let tokenInfo = switch (tokenId) {
          case (null) "Native Token";
          case (?id) "Token ID: " # Nat.toText(id);
        };
        LoggingUtils.logInfo(
          logStore,
          "TreasuryCanister",
          "Funds Withdrawn: User=" # userId # 
          ", Amount=" # Nat.toText(amount) # 
          ", " # tokenInfo # 
          ", Timestamp=" # Nat64.toText(timestamp),
          null
        );
      };
      case (_) {};
    }
  };

  public func initializeEventListeners(): async () {
    await eventManager.subscribe(#FundsDeposited, onTreasuryEvent);
    await eventManager.subscribe(#FundsWithdrawn, onTreasuryEvent);
  };
};
