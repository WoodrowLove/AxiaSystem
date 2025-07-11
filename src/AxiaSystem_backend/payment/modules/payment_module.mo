import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
import LoggingUtils "../../utils/logging_utils";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import UserCanisterProxy "../../user/utils/user_canister_proxy";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    public type PaymentTransaction = {
        id: Nat;
        sender: Principal;
        receiver: Principal;
        amount: Nat;
        tokenId: ?Nat;
        timestamp: Int;
        status: Text; // "Pending", "Completed", "Failed", "Reversed"
        description: ?Text;
    };

    public class PaymentManager(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        _userProxy: UserCanisterProxy.UserCanisterProxy,
        _tokenProxy: TokenCanisterProxy.TokenCanisterProxy
    ) {
        private var transactions: [PaymentTransaction] = [];
        private var logStore = LoggingUtils.init();
         private let eventManager = EventManager.EventManager();

        // Emit event helper
        private func emitEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload) : async () {
    let event : EventTypes.Event = {
        id = Nat64.fromNat(Int.abs(Time.now()));
        eventType = eventType;
        payload = payload;
    };
    await eventManager.emit(event);
};

// Validate custom payment rules
public func validateCustomRules(
    sender: Principal,
    amount: Nat,
    tokenId: ?Nat
) : Result.Result<(), Text> {
    // Example Rule: Payment amount must not exceed a certain limit
    if (amount > 10_000_000) {
        return #err("Payment amount exceeds the maximum limit of 10,000,000.");
    };

    // Example Rule: Specific users are not allowed to make payments
    let blacklistedUsers: [Principal] = [
        Principal.fromText("2vxsx-fae"),
        Principal.fromText("2vxsx-fae"),
    ];
    if (Array.find<Principal>(blacklistedUsers, func (user : Principal) : Bool { user == sender }) != null) {
    return #err("Sender is not authorized to make payments.");
};

    // Example Rule: Only specific tokens are allowed
let allowedTokenIds: [Nat] = [1, 2, 3]; // Define valid token IDs
if (tokenId != null and Array.find<Nat>(allowedTokenIds, func (id : Nat) : Bool { id == Option.get(tokenId, 0) }) == null) {
    return #err("Token ID is not allowed for this transaction.");
};

    // Add more rules as necessary

    // If all checks pass
    #ok(())
};

        // Initiate a payment
public func initiatePayment(
    sender: Principal,
    receiver: Principal,
    amount: Nat,
    tokenId: ?Nat,
    description: ?Text
): async Result.Result<PaymentTransaction, Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Initiating payment from " # Principal.toText(sender) # " to " # Principal.toText(receiver) # 
        " with amount: " # Nat.toText(amount),
        ?sender
    );

    // Validate custom rules
    let rulesValidation = validateCustomRules(sender, amount, tokenId);
    switch (rulesValidation) {
        case (#err(e)) {
            LoggingUtils.logError(logStore, "PaymentModule", "Custom rules validation failed: " # e, ?sender);
            return #err(e);
        };
        case (#ok(())) {
            LoggingUtils.logInfo(logStore, "PaymentModule", "Custom rules validated successfully", null);
        };
    };

    // Check for valid amount
    if (amount <= 0) {
        return #err("Invalid payment amount");
    };

    // Debit sender's wallet
    let debitResult = await walletProxy.debitWallet(sender, amount, Option.get(tokenId, 0));
    switch (debitResult) {
        case (#err(e)) {
            LoggingUtils.logError(logStore, "PaymentModule", "Debit failed for sender: " # e, ?sender);
            return #err("Failed to debit sender: " # e);
        };
        case (#ok(_)) {};
    };

    // Credit receiver's wallet
    let creditResult = await walletProxy.creditWallet(receiver, amount, Option.get(tokenId, 0));
    switch (creditResult) {
        case (#err(e)) {
            // Rollback debit in case of credit failure
            ignore await walletProxy.creditWallet(sender, amount, Option.get(tokenId, 0));
            LoggingUtils.logError(logStore, "PaymentModule", "Credit failed for receiver: " # e, ?receiver);
            return #err("Failed to credit receiver: " # e);
        };
        case (#ok(_)) {};
    };

    // Create transaction
    let transaction: PaymentTransaction = {
        id = Int.abs(Time.now());
        sender = sender;
        receiver = receiver;
        amount = amount;
        tokenId = tokenId;
        timestamp = Time.now();
        status = "Completed";
        description = description;
    };

    // Append transaction
    transactions := Array.append(transactions, [transaction]);

    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Payment completed successfully. Transaction ID: " # Nat.toText(transaction.id),
        null
    );

    // Emit payment processed event
await eventManager.emit({
    id = Nat64.fromNat(transaction.id);
    eventType = #PaymentProcessed;
    payload = #PaymentProcessed {
        userId = sender;
        amount = amount;
        walletId = Principal.toText(sender)
    };
});

    #ok(transaction)
};

        // Complete a payment
        public func completePayment(paymentId: Nat): async Result.Result<(), Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Attempting to complete payment ID: " # Nat.toText(paymentId),
        null
    );

    let paymentOpt = Array.find<PaymentTransaction>(transactions, func(p: PaymentTransaction): Bool {
        p.id == paymentId
    });

    switch (paymentOpt) {
        case null {
            LoggingUtils.logError(
                logStore,
                "PaymentModule",
                "Payment not found for ID: " # Nat.toText(paymentId),
                null
            );
            #err("Payment not found");
        };
        case (?payment) {
            if (payment.status != "Pending") {
                LoggingUtils.logError(
                    logStore,
                    "PaymentModule",
                    "Payment cannot be completed. Current status: " # payment.status,
                    ?payment.sender
                );
                return #err("Payment cannot be completed. Status: " # payment.status);
            };

            // Update payment status to "Completed"
            transactions := Array.map<PaymentTransaction, PaymentTransaction>(transactions, func(p: PaymentTransaction): PaymentTransaction {
                if (p.id == paymentId) { 
                    { p with status = "Completed" } 
                } else p
            });

            LoggingUtils.logInfo(
                logStore,
                "PaymentModule",
                "Payment successfully completed for ID: " # Nat.toText(paymentId),
                null
            );

            // Emit event for payment completion
            // Emit event for payment completion
await emitEvent(#PaymentProcessed, #PaymentProcessed {
    userId = payment.sender;
    amount = payment.amount;
    walletId = Principal.toText(payment.sender)
});

            #ok(());
        };
    };
};

        // Reverse a payment
        public func reversePayment(paymentId: Nat): async Result.Result<(), Text> {
    LoggingUtils.logInfo(logStore, "PaymentModule", "Attempting to reverse payment ID: " # Nat.toText(paymentId), null);

    // Find the payment transaction
    let paymentOpt = Array.find<PaymentTransaction>(transactions, func(t: PaymentTransaction): Bool { t.id == paymentId });
    switch (paymentOpt) {
        case null {
            LoggingUtils.logError(logStore, "PaymentModule", "Payment not found for reversal. ID: " # Nat.toText(paymentId), null);
            #err("Payment not found");
        };
        case (?payment) {
            if (payment.status != "Completed") {
                LoggingUtils.logError(
                    logStore,
                    "PaymentModule",
                    "Only completed payments can be reversed. Payment ID: " # Nat.toText(paymentId),
                    null
                );
                return #err("Only completed payments can be reversed");
            };

            // Debit the receiver's wallet
            let debitResult = await walletProxy.debitWallet(payment.receiver, payment.amount, Option.get(payment.tokenId, 0));
            switch (debitResult) {
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "PaymentModule", "Failed to debit receiver during reversal: " # e, ?payment.receiver);
                    return #err("Failed to debit receiver: " # e);
                };
                case (#ok(_)) {};
            };

            // Credit the sender's wallet
            let creditResult = await walletProxy.creditWallet(payment.sender, payment.amount, Option.get(payment.tokenId, 0));
            switch (creditResult) {
                case (#err(e)) {
                    // Rollback receiver's debit in case credit fails
                    ignore await walletProxy.creditWallet(payment.receiver, payment.amount, Option.get(payment.tokenId, 0));
                    LoggingUtils.logError(logStore, "PaymentModule", "Failed to credit sender during reversal: " # e, ?payment.sender);
                    return #err("Failed to credit sender: " # e);
                };
                case (#ok(_)) {};
            };

            // Update the payment status to "Reversed"
            transactions := Array.map<PaymentTransaction, PaymentTransaction>(transactions, func(t: PaymentTransaction): PaymentTransaction {
                if (t.id == paymentId) { { t with status = "Reversed" } } else t
            });

            LoggingUtils.logInfo(logStore, "PaymentModule", "Payment reversed successfully for ID: " # Nat.toText(paymentId), null);

            // Emit a "PaymentReversed" event
            await emitEvent(
                #PaymentReversed,
                #PaymentReversed {
                    userId = payment.sender;
                    amount = payment.amount;
                    walletId = Principal.toText(payment.sender)
                }
            );

            #ok(())
        };
    };
};

        // Get payment history for a user
        public func getPaymentHistory(userId: Principal): async [PaymentTransaction] {
    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Retrieving payment history for user ID: " # Principal.toText(userId),
        ?userId
    );

    let userTransactions = Array.filter<PaymentTransaction>(transactions, func(tx: PaymentTransaction): Bool {
        tx.sender == userId or tx.receiver == userId
    });

    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Found " # Nat.toText(Array.size(userTransactions)) # " transactions for user ID: " # Principal.toText(userId),
        ?userId
    );

    // Emit event for payment history retrieval (optional)
await emitEvent(#PaymentHistoryRetrieved, #PaymentHistoryRetrieved {
    userId = userId;
    transactionCount = Array.size(userTransactions)
});
    userTransactions
};

        // Get all payments
        public func getAllPayments(): async [PaymentTransaction] {
    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Retrieving all payment transactions",
        null
    );

    // Log the number of transactions retrieved
    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Total transactions found: " # Nat.toText(Array.size(transactions)),
        null
    );

    // Emit event for all payments retrieval (optional)
await emitEvent(#AllPaymentsRetrieved, #AllPaymentsRetrieved {
    totalTransactions = Array.size(transactions)
});

    transactions
};

        // Get payment status
        public func getPaymentStatus(paymentId: Nat): async Result.Result<Text, Text> {
            let paymentOpt = Array.find<PaymentTransaction>(transactions, func(t: PaymentTransaction): Bool { t.id == paymentId });
            switch (paymentOpt) {
                case (?payment) #ok(payment.status);
                case (null) #err("Payment not found");
            }
        };

        // Check for timed-out payments
public func processTimeouts(timeoutThreshold: Nat): async Result.Result<(), Text> {
    LoggingUtils.logInfo(logStore, "PaymentModule", "Processing timed-out payments", null);

    let now = Nat64.fromIntWrap(Time.now());
let updatedTransactions = Array.map<PaymentTransaction, PaymentTransaction>(transactions, func(tx: PaymentTransaction): PaymentTransaction {
    if (tx.status == "Pending" and now > Nat64.fromIntWrap(tx.timestamp) and (now - Nat64.fromIntWrap(tx.timestamp) > Nat64.fromNat(timeoutThreshold))) {
        LoggingUtils.logInfo(logStore, "PaymentModule", "Marking payment as failed due to timeout: ID = " # Nat.toText(tx.id), null);
        { tx with status = "Failed" }
    } else tx
});

    transactions := updatedTransactions;
    #ok(())
};


// Retry a failed payment
public func retryPayment(paymentId: Nat): async Result.Result<(), Text> {
    let paymentOpt = Array.find<PaymentTransaction>(transactions, func(t: PaymentTransaction): Bool { t.id == paymentId });
    switch (paymentOpt) {
        case null #err("Payment not found");
        case (?payment) {
            if (payment.status != "Failed") {
                return #err("Only failed payments can be retried");
            };

            LoggingUtils.logInfo(logStore, "PaymentModule", "Retrying payment ID: " # Nat.toText(paymentId), null);

            // Debit sender again
            let debitResult = await walletProxy.debitWallet(payment.sender, payment.amount, Option.get(payment.tokenId, 0));
            switch (debitResult) {
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "PaymentModule", "Retry failed to debit sender: " # e, ?payment.sender);
                    return #err("Retry failed to debit sender: " # e);
                };
                case (#ok(_)) {};
            };

            // Credit receiver again
            let creditResult = await walletProxy.creditWallet(payment.receiver, payment.amount, Option.get(payment.tokenId, 0));
            switch (creditResult) {
                case (#err(e)) {
                    // Rollback debit if credit fails
                    ignore await walletProxy.creditWallet(payment.sender, payment.amount, Option.get(payment.tokenId, 0));
                    LoggingUtils.logError(logStore, "PaymentModule", "Retry failed to credit receiver: " # e, ?payment.receiver);
                    return #err("Retry failed to credit receiver: " # e);
                };
                case (#ok(_)) {};
            };

            // Update payment status
            transactions := Array.map<PaymentTransaction, PaymentTransaction>(transactions, func(t: PaymentTransaction): PaymentTransaction {
                if (t.id == paymentId) { { t with status = "Completed" } } else t
            });

            LoggingUtils.logInfo(logStore, "PaymentModule", "Payment retried successfully for ID: " # Nat.toText(paymentId), null);

            #ok(())
        };
    }
};

public func timeoutPendingPayments(): async Result.Result<Nat, Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Running timeout cleanup for pending payments.",
        null
    );

    let currentTime = Time.now();
    let timeoutDuration: Int = 10_000_000_000; // Example: 10 seconds in nanoseconds

    var removedCount: Nat = 0;
    var timedOutTransactions: [PaymentTransaction] = [];

    transactions := Array.filter<PaymentTransaction>(transactions, func(tx: PaymentTransaction): Bool {
        if (tx.status == "Pending" and (currentTime - tx.timestamp) > timeoutDuration) {
            LoggingUtils.logInfo(
                logStore,
                "PaymentModule",
                "Timeout detected for Payment ID: " # Nat.toText(tx.id),
                null
            );

            removedCount += 1;
            timedOutTransactions := Array.append(timedOutTransactions, [tx]);
            false; // Remove this transaction from the list
        } else {
            true; // Retain this transaction
        }
    });

    // Emit events for timed-out payments after filtering
    for (tx in timedOutTransactions.vals()) {
        await emitEvent(#PaymentTimedOut, #PaymentTimedOut {
            userId = tx.sender;
            amount = tx.amount;
            walletId = Principal.toText(tx.sender)
        });
    };

    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Timeout cleanup complete. Total removed: " # Nat.toText(removedCount),
        null
    );

    #ok(removedCount)
};

// Synchronize balances for a user
public func synchronizeBalances(
    sender: Principal,
    receiver: Principal,
    tokenId: Nat,
    amount: Nat
): async Result.Result<(), Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentModule",
        "Attempting to synchronize balances. Sender: " # Principal.toText(sender) # ", Receiver: " # Principal.toText(receiver) # ", Amount: " # Nat.toText(amount),
        ?sender
    );

    try {
        // Verify sender's balance
        let senderBalanceResult = await walletProxy.getBalance(sender, tokenId);
        switch (senderBalanceResult) {
            case (#ok(senderBalance)) {
                if (senderBalance < amount) {
                    LoggingUtils.logError(
                        logStore,
                        "PaymentModule",
                        "Insufficient balance for sender: " # Principal.toText(sender),
                        ?sender
                    );
                    return #err("Insufficient balance for sender");
                };
            };
            case (#err(e)) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentModule",
                    "Failed to get sender balance: " # e,
                    ?sender
                );
                return #err("Failed to get sender balance: " # e);
            };
        };

        // Deduct from sender
        let deductResult = await walletProxy.deductBalance(sender, tokenId, amount);
        switch (deductResult) {
            case (#err(e)) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentModule",
                    "Failed to deduct balance from sender: " # e,
                    ?sender
                );
                return #err("Failed to deduct balance from sender: " # e);
            };
            case (#ok(_)) {};
        };

        // Add to receiver
        let addResult = await walletProxy.addBalance(receiver, tokenId, amount);
        switch (addResult) {
            case (#err(e)) {
                // If adding to receiver fails, refund the sender
                ignore await walletProxy.addBalance(sender, tokenId, amount);
                LoggingUtils.logError(
                    logStore,
                    "PaymentModule",
                    "Failed to add balance to receiver: " # e,
                    ?receiver
                );
                return #err("Failed to add balance to receiver: " # e);
            };
            case (#ok(_)) {};
        };

        LoggingUtils.logInfo(
            logStore,
            "PaymentModule",
            "Balances synchronized successfully",
            ?sender
        );

        // Emit event for balance synchronization
        await emitEvent(#BalancesSynchronized, #BalancesSynchronized {
            senderId = sender;
            receiverId = receiver;
            amount = amount;
            tokenId = tokenId
        });

        #ok(())
    } catch (error) {
        LoggingUtils.logError(
            logStore,
            "PaymentModule",
            "Unexpected error while synchronizing balances: " # Error.message(error),
            ?sender
        );
        #err("Failed to synchronize balances: " # Error.message(error))
    }
};

    };
};