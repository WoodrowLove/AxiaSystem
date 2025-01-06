import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Trie "mo:base/Trie";
import Option "mo:base/Option";
import _Hash "mo:base/Hash";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";

module {
    public type TreasuryTransaction = {
        id: Nat;
        timestamp: Nat;
        sender: Principal;
        receiver: ?Principal;
        amount: Nat;
        tokenId: ?Nat;
        description: Text;
        transactionType: Text; // e.g., "Deposit", "Withdrawal", "Reward Distribution"
    };

    public class TreasuryManager(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        _tokenProxy: TokenCanisterProxy.TokenCanisterProxy,
        eventManager: EventManager.EventManager
    ) {
        private var treasuryBalance: Trie.Trie<Nat, Nat> = Trie.empty(); // Balances keyed by tokenId (null for native ICP)
        private var transactions: [TreasuryTransaction] = [];
        private var nextTransactionId: Nat = 1;

        // Add this function to your module
private func natHash(n: Nat) : Nat32 {
    var x = n;
    var h : Nat32 = 0;
    while (x > 0) {
        h := h +% Nat32.fromNat(x % 256);
        h := h *% 0x01000193;
        x := x / 256;
    };
    return h;
};

        private func emitTreasuryEvent(eventType: EventTypes.EventType, details: Text): async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now());
        eventType = eventType;
        payload = switch (eventType) {
            case (#TreasuryTransactionLogged) {
                #TreasuryTransactionLogged({
                    transactionId = 0; // You may want to generate or pass this
                    description = details;
                    transactionType = "Generic"; // Or pass this as a parameter
                    timestamp = Nat64.fromIntWrap(Time.now());
                })
            };
            case (_) {
                #WalletEventGeneric({ walletId = "Treasury"; details = details })
            };
        };
    };
    await eventManager.emit(event);
};

       public func addFunds(
    userId: Principal,
    amount: Nat,
    tokenId: ?Nat,
    description: Text
): async Result.Result<(), Text> {
    if (amount == 0) {
        return #err("Amount must be greater than zero.");
    };

    // Transfer funds from the user's wallet
let debitResult = await walletProxy.debitWallet(
    userId,
    amount,
    switch (tokenId) {
        case (null) { 0 }; // Or another default value that makes sense for your system
        case (?id) { id };
    }
);
switch debitResult {
    case (#err(e)) return #err("Failed to debit user's wallet: " # e);
    case (#ok(_)) {};
};

 // Update treasury balance
let key = switch (tokenId) {
    case (null) { { hash = 0 : Nat32; key = 0 } };
    case (?id) { { hash = natHash(id); key = id } };
};
let currentBalance = switch (Trie.find(treasuryBalance, key, Nat.equal)) {
    case (?balance) balance;
    case null 0;
};
let newBalance = currentBalance + amount;
treasuryBalance := Trie.put(treasuryBalance, key, Nat.equal, newBalance).0;

// Record transaction
let transaction: TreasuryTransaction = {
    id = nextTransactionId;
    timestamp = Int.abs(Time.now());
    sender = userId;
    receiver = null;
    amount = amount;
    tokenId = tokenId;  // Keep it as ?Nat
    description = description;
    transactionType = "Deposit";
};
    nextTransactionId += 1;
    transactions := Array.append(transactions, [transaction]);

    // Emit event
    await eventManager.emit({
        id = Nat64.fromIntWrap(Time.now());
        eventType = #FundsDeposited;
        payload = #FundsDeposited({
            userId = Principal.toText(userId);
            amount = amount;
            tokenId = tokenId;
            timestamp = Nat64.fromNat(Int.abs(Time.now()));
        });
    });

    #ok(())
};

        // Withdraw funds from the treasury
        public func withdrawFunds(
            userId: Principal,
            amount: Nat,
            tokenId: ?Nat,
            description: Text
        ): async Result.Result<(), Text> {
            if (amount == 0) {
                return #err("Amount must be greater than zero.");
            };

           // Check treasury balance
let key = switch (tokenId) {
    case (null) { { hash = 0 : Nat32; key = 0 } };
    case (?id) { { hash = Nat32.fromNat(id); key = id } };
};
let currentBalance = switch (Trie.find(treasuryBalance, key, Nat.equal)) {
    case (?balance) balance;
    case null 0;
};
if (currentBalance < amount) {
    return #err("Insufficient treasury balance.");
};
// Deduct funds from treasury balance
if (currentBalance >= amount) {
    let newBalance = Nat.sub(currentBalance, amount);
    treasuryBalance := Trie.put(treasuryBalance, key, Nat.equal, newBalance).0;
} else {
    return #err("Insufficient treasury balance.");
};

            // Transfer funds to the user's wallet
let creditResult = await walletProxy.creditWallet(
    userId,
    amount,
    switch (tokenId) {
        case (null) { 0 }; // Or another default value that makes sense for your system
        case (?id) { id };
    }
);
switch creditResult {
    case (#err(e)) return #err("Failed to credit user's wallet: " # e);
    case (#ok(_)) {};
};

            // Record transaction
let transaction: TreasuryTransaction = {
    id = nextTransactionId;
    timestamp = Int.abs(Time.now()); // Convert Time to Nat
    sender = Principal.fromText("aaaaa-aa"); // Use the null Principal or another appropriate value
    receiver = ?userId;
    amount = amount;
    tokenId = tokenId;
    description = description;
    transactionType = "Withdrawal";
};
nextTransactionId += 1;
transactions := Array.append(transactions, [transaction]);

            // Emit event
            await emitTreasuryEvent(#FundsWithdrawn, "Funds withdrawn by user: " # Principal.toText(userId));

            #ok(())
        };

        // Distribute rewards
public func distributeRewards(
    recipients: [(Principal, Nat)],
    tokenId: ?Nat,
    description: Text
): async Result.Result<(), Text> {
    // Calculate total rewards
    let totalRewards = Array.foldLeft<(Principal, Nat), Nat>(
        recipients,
        0,
        func(sum, current) { sum + current.1 }
    );

            // Check treasury balance
let key = switch (tokenId) {
    case (null) { { hash = 0 : Nat32; key = 0 } };
    case (?id) { { hash = Nat32.fromNat(id); key = id } };
};
let currentBalance = switch (Trie.find(treasuryBalance, key, Nat.equal)) {
    case (?balance) balance;
    case null 0;
};
            if (currentBalance < totalRewards) {
                return #err("Insufficient treasury balance for rewards.");
            };

          // Deduct funds from treasury balance
if (currentBalance >= totalRewards) {
    let newBalance = Nat.sub(currentBalance, totalRewards);
    treasuryBalance := Trie.put(treasuryBalance, key, Nat.equal, newBalance).0;

    // Transfer funds to recipients
    for ((recipient, amount) in recipients.vals()) {
        let creditResult = await walletProxy.creditWallet(
            recipient,
            amount,
            Option.get(tokenId, 0) // Use 0 as default if tokenId is null
        );
        switch creditResult {
            case (#err(e)) return #err("Failed to credit recipient's wallet: " # e);
            case (#ok(_)) {};
        };
    };

    // Record transaction
    let transaction: TreasuryTransaction = {
    id = nextTransactionId;
    timestamp = Int.abs(Time.now()); // Convert Time to Nat
    sender = Principal.fromText("aaaaa-aa"); // Wrap in Some()
    receiver = ?Principal.fromText("aaaaa-aa"); // Wrap in Some()
    amount = totalRewards;
    tokenId = tokenId;
    description = description;
    transactionType = "Reward Distribution";
};
nextTransactionId += 1;
transactions := Array.append(transactions, [transaction]);
    // Emit event
    await eventManager.emit({
    id = Nat64.fromIntWrap(Time.now());
    eventType = #RewardsDistributed;
    payload = #RewardsDistributed({
        recipients = Array.map<(Principal, Nat), (Text, Nat)>(
            recipients,
            func((principal, amount)) {
                (Principal.toText(principal), amount)
            }
        );
        tokenId = tokenId;
        totalAmount = totalRewards;
        timestamp = Nat64.fromNat(Int.abs(Time.now()));
    });
});

    #ok(())
} else {
    #err("Insufficient treasury balance for reward distribution.")
};
};

       public func getTreasuryBalance(tokenId: ?Nat): Nat {
    let key = switch (tokenId) {
        case (null) { { hash = 0 : Nat32; key = 0 } };
        case (?id) { { hash = Nat32.fromNat(id); key = id } };
    };
    switch (Trie.find(treasuryBalance, key, Nat.equal)) {
        case (?balance) balance;
        case null 0;
    }
};

        // Get transaction history
        public func getTransactionHistory(): [TreasuryTransaction] {
            transactions
        };

        public func getTreasuryAuditReport(): { totalDeposits: Nat; totalWithdrawals: Nat; totalDistributions: Nat } {
    let deposits = Array.foldLeft<TreasuryTransaction, Nat>(
        transactions,
        0,
        func (sum, tx) { if (tx.transactionType == "Deposit") sum + tx.amount else sum }
    );
    let withdrawals = Array.foldLeft<TreasuryTransaction, Nat>(
        transactions,
        0,
        func (sum, tx) { if (tx.transactionType == "Withdrawal") sum + tx.amount else sum }
    );
    let distributions = Array.foldLeft<TreasuryTransaction, Nat>(
        transactions,
        0,
        func (sum, tx) { if (tx.transactionType == "Reward Distribution") sum + tx.amount else sum }
    );
    { totalDeposits = deposits; totalWithdrawals = withdrawals; totalDistributions = distributions }
};


public func filterTransactions(transactionType: Text, tokenId: ?Nat): [TreasuryTransaction] {
    Array.filter<TreasuryTransaction>(
        transactions,
        func (tx) { tx.transactionType == transactionType and (tokenId == null or tx.tokenId == tokenId) }
    )
};

private var isLocked: Bool = false;

public func lockTreasury(): async Result.Result<(), Text> {
    if (isLocked) return #err("Treasury is already locked.");
    isLocked := true;
    #ok(())
};

public func unlockTreasury(): async Result.Result<(), Text> {
    if (not isLocked) return #err("Treasury is not locked.");
    isLocked := false;
    #ok(())
};

public func isTreasuryLocked(): Bool {
    isLocked
};

    };
};