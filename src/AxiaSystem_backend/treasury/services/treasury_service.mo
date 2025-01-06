import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import LoggingUtils "../../utils/logging_utils";
import EventManager "../../heartbeat/event_manager";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";
import TreasuryModule "../../treasury/modules/treasury_module";

module {
    public class TreasuryService(
        treasuryManager: TreasuryModule.TreasuryManager,
        _walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        _tokenProxy: TokenCanisterProxy.TokenCanisterProxy,
        _eventManager: EventManager.EventManager
    ) {
        private let logStore = LoggingUtils.init();

        // Add funds to the treasury
        public func addFunds(
            userId: Principal,
            amount: Nat,
            tokenId: ?Nat,
            description: Text
        ): async Result.Result<(), Text> {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Adding funds for user: " # Principal.toText(userId) # ", Amount: " # Nat.toText(amount),
                ?userId
            );

            if (amount == 0) {
                return #err("Amount must be greater than zero.");
            };

            let result = await treasuryManager.addFunds(userId, amount, tokenId, description);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryService",
                        "Funds added successfully for user: " # Principal.toText(userId),
                        ?userId
                    );
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "TreasuryService",
                        "Failed to add funds: " # e,
                        ?userId
                    );
                    #err(e)
                };
            };
        };

        // Withdraw funds from the treasury
        public func withdrawFunds(
            userId: Principal,
            amount: Nat,
            tokenId: ?Nat,
            description: Text
        ): async Result.Result<(), Text> {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Withdrawing funds for user: " # Principal.toText(userId) # ", Amount: " # Nat.toText(amount),
                ?userId
            );

            if (amount == 0) {
                return #err("Amount must be greater than zero.");
            };

            let result = await treasuryManager.withdrawFunds(userId, amount, tokenId, description);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryService",
                        "Funds withdrawn successfully for user: " # Principal.toText(userId),
                        ?userId
                    );
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "TreasuryService",
                        "Failed to withdraw funds: " # e,
                        ?userId
                    );
                    #err(e)
                };
            };
        };

        // Distribute rewards to recipients
        public func distributeRewards(
            recipients: [(Principal, Nat)],
            tokenId: ?Nat,
            description: Text
        ): async Result.Result<(), Text> {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Distributing rewards. Total recipients: " # Nat.toText(Array.size(recipients)),
                null
            );

            let result = await treasuryManager.distributeRewards(recipients, tokenId, description);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryService",
                        "Rewards distributed successfully.",
                        null
                    );
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "TreasuryService",
                        "Failed to distribute rewards: " # e,
                        null
                    );
                    #err(e)
                };
            };
        };

        // Get treasury balance for a specific token
        public func getTreasuryBalance(tokenId: ?Nat): Nat {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Fetching treasury balance for tokenId: " # (switch tokenId { case (null) "Native ICP"; case (?id) Nat.toText(id) }),
                null
            );

            treasuryManager.getTreasuryBalance(tokenId);
        };

        // Retrieve transaction history
        public func getTransactionHistory(): [TreasuryModule.TreasuryTransaction] {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Fetching transaction history",
                null
            );

            treasuryManager.getTransactionHistory();
        };

        // Generate treasury audit report
        public func getTreasuryAuditReport(): { totalDeposits: Nat; totalWithdrawals: Nat; totalDistributions: Nat } {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Generating treasury audit report",
                null
            );

            treasuryManager.getTreasuryAuditReport();
        };

        // Filter transactions
        public func filterTransactions(transactionType: Text, tokenId: ?Nat): [TreasuryModule.TreasuryTransaction] {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Filtering transactions by type: " # transactionType,
                null
            );

            treasuryManager.filterTransactions(transactionType, tokenId);
        };

        // Lock the treasury
        public func lockTreasury(): async Result.Result<(), Text> {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Locking the treasury",
                null
            );

            let result = await treasuryManager.lockTreasury();
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryService",
                        "Treasury locked successfully",
                        null
                    );
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "TreasuryService",
                        "Failed to lock the treasury: " # e,
                        null
                    );
                    #err(e)
                };
            };
        };

        // Unlock the treasury
        public func unlockTreasury(): async Result.Result<(), Text> {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Unlocking the treasury",
                null
            );

            let result = await treasuryManager.unlockTreasury();
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryService",
                        "Treasury unlocked successfully",
                        null
                    );
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "TreasuryService",
                        "Failed to unlock the treasury: " # e,
                        null
                    );
                    #err(e)
                };
            };
        };

        // Check if the treasury is locked
        public func isTreasuryLocked(): Bool {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryService",
                "Checking if the treasury is locked",
                null
            );

            treasuryManager.isTreasuryLocked();
        };
    };
};