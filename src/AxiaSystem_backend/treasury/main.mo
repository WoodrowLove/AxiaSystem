import TreasuryModule "../treasury/modules/treasury_module";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import TokenCanisterProxy "../token/utils/token_canister_proxy";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";
import RefundModule "../modules/refund_module";
import TreasuryRefundProcessor "../modules/treasury_refund_processor";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import _Array "mo:base/Array";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import LoggingUtils "../utils/logging_utils";

persistent actor TreasuryCanister {
    // Dependencies
    private transient let walletProxy = WalletCanisterProxy.WalletCanisterProxy(
    Principal.fromText("xjaw7-xp777-77774-qaajq-cai"), // Wallet Canister ID
    Principal.fromText("xobql-2x777-77774-qaaja-cai")  // User Canister ID
);
    private transient let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("xad5d-bh777-77774-qaaia-cai"));
    private transient let eventManager = EventManager.EventManager();
    private transient let logStore = LoggingUtils.init();

    // Treasury Manager
    private transient let treasuryManager = TreasuryModule.TreasuryManager(walletProxy, tokenProxy, eventManager);

    // Refund Manager for treasury-funded refunds
    private transient let refundManager = RefundModule.RefundManager("Treasury", eventManager);

    // Wallet interface for refund processor
    private transient let walletCanister: TreasuryRefundProcessor.WalletInterface = 
        actor (Principal.toText(Principal.fromText("xjaw7-xp777-77774-qaajq-cai")));

    // Self-reference for refund processor
    private transient let treasuryCanister: TreasuryRefundProcessor.TreasuryInterface = 
        actor (Principal.toText(Principal.fromText("xhc3x-m7777-77774-qaaiq-cai")));

    // Treasury Refund Processor
    private transient let refundProcessor = TreasuryRefundProcessor.TreasuryRefundProcessor(
        treasuryCanister,
        walletCanister,
        eventManager
    );

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

  // TREASURY REFUND PROCESSING FUNCTIONS

  // Create a treasury-funded refund request
  public func createTreasuryRefund(
    originId: Nat,
    _originType: Text,
    userId: Principal,
    amount: Nat,
    requiresApproval: Bool,
    reason: ?Text
  ): async Result.Result<Nat, Text> {
    try {
      let refundSource = #Treasury({ requiresApproval = requiresApproval });
      let result = await refundManager.createRefundRequest(originId, userId, amount, refundSource, reason);
      
      switch (result) {
        case (#ok(refundId)) {
          LoggingUtils.logInfo(
            logStore,
            "TreasuryCanister",
            "Treasury refund request created with ID: " # Nat.toText(refundId) # 
            " for amount: " # Nat.toText(amount),
            ?userId
          );
          #ok(refundId)
        };
        case (#err(e)) {
          LoggingUtils.logError(logStore, "TreasuryCanister", "Failed to create treasury refund: " # e, ?userId);
          #err(e)
        };
      }
    } catch (error) {
      let errorMessage = Error.message(error);
      LoggingUtils.logError(logStore, "TreasuryCanister", "Treasury refund creation error: " # errorMessage, ?userId);
      #err("Treasury refund creation error: " # errorMessage)
    }
  };

  // Process all approved treasury refunds
  public func processApprovedRefunds(): async Result.Result<[Nat], Text> {
    try {
      let result = await refundProcessor.processApprovedTreasuryRefunds(refundManager);
      switch (result) {
        case (#ok(processedIds)) {
          LoggingUtils.logInfo(
            logStore,
            "TreasuryCanister",
            "Processed " # Nat.toText(processedIds.size()) # " treasury refunds",
            null
          );
          #ok(processedIds)
        };
        case (#err(e)) {
          LoggingUtils.logError(logStore, "TreasuryCanister", "Failed to process refunds: " # e, null);
          #err(e)
        };
      }
    } catch (error) {
      let errorMessage = Error.message(error);
      LoggingUtils.logError(logStore, "TreasuryCanister", "Refund processing error: " # errorMessage, null);
      #err("Refund processing error: " # errorMessage)
    }
  };

  // Auto-process eligible refunds
  public func autoProcessRefunds(): async Result.Result<[Nat], Text> {
    try {
      await refundProcessor.autoProcessEligibleRefunds(refundManager)
    } catch (error) {
      let errorMessage = Error.message(error);
      LoggingUtils.logError(logStore, "TreasuryCanister", "Auto-refund processing error: " # errorMessage, null);
      #err("Auto-refund processing error: " # errorMessage)
    }
  };

  // Validate refund request against treasury capacity
  public func validateRefundRequest(
    amount: Nat,
    refundSource: RefundModule.RefundSource,
    tokenId: ?Nat
  ): async Result.Result<(), Text> {
    try {
      await refundProcessor.validateRefundRequest(amount, refundSource, tokenId)
    } catch (error) {
      #err("Refund validation error: " # Error.message(error))
    }
  };

  // List treasury refund requests
  public func listTreasuryRefunds(
    status: ?Text,
    requestedBy: ?Principal,
    fromDate: ?Int,
    toDate: ?Int,
    offset: Nat,
    limit: Nat
  ): async Result.Result<[RefundModule.RefundRequest], Text> {
    await refundManager.listRefundRequests(status, requestedBy, fromDate, toDate, offset, limit)
  };

  // Approve a treasury refund
  public func approveTreasuryRefund(
    refundId: Nat,
    adminPrincipal: Principal,
    adminNote: ?Text
  ): async Result.Result<(), Text> {
    await refundManager.approveRefundRequest(refundId, adminPrincipal, adminNote)
  };

  // Deny a treasury refund
  public func denyTreasuryRefund(
    refundId: Nat,
    adminPrincipal: Principal,
    adminNote: ?Text
  ): async Result.Result<(), Text> {
    await refundManager.denyRefundRequest(refundId, adminPrincipal, adminNote)
  };

  // Get treasury refund statistics
  public func getTreasuryRefundStats(): async RefundModule.RefundStats {
    await refundManager.getRefundStats()
  };

  // Get treasury refund processing status
  public func getTreasuryRefundProcessingStats(): async { 
    availableBalance: Nat; 
    isLocked: Bool; 
    canProcessRefunds: Bool 
  } {
    await refundProcessor.getTreasuryRefundStats()
  };
};
