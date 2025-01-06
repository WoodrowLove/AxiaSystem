import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";

module {
    public type TreasuryTransaction = {
        id: Nat;
        timestamp: Nat;
        sender: Principal;
        receiver: ?Principal;
        amount: Nat;
        tokenId: ?Nat;
        description: Text;
        transactionType: Text;
    };

    public type TreasuryCanisterInterface = actor {
        addFunds: (Principal, Nat, ?Nat, Text) -> async Result.Result<(), Text>;
        withdrawFunds: (Principal, Nat, ?Nat, Text) -> async Result.Result<(), Text>;
        distributeRewards: ([(Principal, Nat)], ?Nat, Text) -> async Result.Result<(), Text>;
        getTreasuryBalance: (?Nat) -> async Nat;
        getTransactionHistory: () -> async [TreasuryTransaction];
        getTreasuryAuditReport: () -> async { totalDeposits: Nat; totalWithdrawals: Nat; totalDistributions: Nat };
        filterTransactions: (Text, ?Nat) -> async [TreasuryTransaction];
        lockTreasury: () -> async Result.Result<(), Text>;
        unlockTreasury: () -> async Result.Result<(), Text>;
        isTreasuryLocked: () -> async Bool;
    };

    // Proxy class for inter-canister calls
    public class TreasuryCanisterProxy(canisterId: Principal) {
        private let treasuryCanister: TreasuryCanisterInterface = actor(Principal.toText(canisterId));

        // Add funds to the treasury
        public func addFunds(
            userId: Principal,
            amount: Nat,
            tokenId: ?Nat,
            description: Text
        ): async Result.Result<(), Text> {
            await treasuryCanister.addFunds(userId, amount, tokenId, description);
        };

        // Withdraw funds from the treasury
        public func withdrawFunds(
            userId: Principal,
            amount: Nat,
            tokenId: ?Nat,
            description: Text
        ): async Result.Result<(), Text> {
            await treasuryCanister.withdrawFunds(userId, amount, tokenId, description);
        };

        // Distribute rewards
        public func distributeRewards(
            recipients: [(Principal, Nat)],
            tokenId: ?Nat,
            description: Text
        ): async Result.Result<(), Text> {
            await treasuryCanister.distributeRewards(recipients, tokenId, description);
        };

        // Retrieve treasury balance
        public func getTreasuryBalance(tokenId: ?Nat): async Nat {
            await treasuryCanister.getTreasuryBalance(tokenId);
        };

        // Get transaction history
        public func getTransactionHistory(): async [TreasuryTransaction] {
            await treasuryCanister.getTransactionHistory();
        };

        // Generate treasury audit report
        public func getTreasuryAuditReport(): async { totalDeposits: Nat; totalWithdrawals: Nat; totalDistributions: Nat } {
            await treasuryCanister.getTreasuryAuditReport();
        };

        // Filter transactions by type and tokenId
        public func filterTransactions(
            transactionType: Text,
            tokenId: ?Nat
        ): async [TreasuryTransaction] {
            await treasuryCanister.filterTransactions(transactionType, tokenId);
        };

        // Lock the treasury
        public func lockTreasury(): async Result.Result<(), Text> {
            await treasuryCanister.lockTreasury();
        };

        // Unlock the treasury
        public func unlockTreasury(): async Result.Result<(), Text> {
            await treasuryCanister.unlockTreasury();
        };

        // Check if the treasury is locked
        public func isTreasuryLocked(): async Bool {
            await treasuryCanister.isTreasuryLocked();
        };
    };
};
