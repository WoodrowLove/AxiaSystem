import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";
import LoggingUtils "../../utils/logging_utils";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    public type SplitPayment = {
        id: Nat;
        sender: Principal;
        recipients: [Principal];
        shares: [Nat];
        totalAmount: Nat;
        description: ?Text;
        status: Text; // "Pending", "Completed", "Failed"
        createdAt: Int;
    };

    public class PaymentSplitManager(walletProxy: WalletCanisterProxy.WalletCanisterProxy, eventManager: EventManager.EventManager) {
        private var splitPayments: [SplitPayment] = [];
        private let logStore = LoggingUtils.init();

        // Emit a split payment-related event
        private func emitSplitPaymentEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload): async () {
            let event: EventTypes.Event = {
        id = Nat64.fromNat(Int.abs(Time.now()));
        eventType = eventType;
        payload = payload;
    };
            await eventManager.emit(event);
        };

        // Validate shares
        private func validateShares(shares: [Nat]): Bool {
            let totalShares = Array.foldLeft<Nat, Nat>(shares, 0, func(acc, share) { acc + share });
            totalShares == 100 // Ensure shares add up to 100%
        };

        // Initiate a split payment
        public func initiateSplitPayment(
            sender: Principal,
            recipients: [Principal],
            shares: [Nat],
            totalAmount: Nat,
            description: ?Text
        ): async Result.Result<SplitPayment, Text> {
            if (Array.size(recipients) != Array.size(shares)) {
                return #err("Recipients and shares arrays must have the same size.");
            };

            if (Array.size(recipients) == 0 or Array.size(shares) == 0) {
    return #err("Recipients and shares cannot be empty.");
};
            if (not validateShares(shares)) {
                return #err("Shares must add up to 100%.");
            };

            let splitPayment: SplitPayment = {
            id = Nat64.toNat(Nat64.fromNat(Int.abs(Time.now())));
            sender = sender;
            recipients = recipients;
            shares = shares;
            totalAmount = totalAmount;
            description = description;
            status = "Pending";
            createdAt = Time.now();
};
            splitPayments := Array.append(splitPayments, [splitPayment]);

            LoggingUtils.logInfo(
                logStore,
                "PaymentSplitsModule",
                "Split payment initiated. ID: " # Nat.toText(splitPayment.id) # ", Total Amount: " # Nat.toText(totalAmount),
                ?sender
            );

// Emit event for split payment initiation
await emitSplitPaymentEvent(#SplitPaymentInitiated, #SplitPaymentInitiated({
    splitId = splitPayment.id;
    initiator = sender;
    recipients = Array.mapEntries<Principal, (Principal, Nat)>(
        recipients,
        func(p: Principal, i: Nat) : (Principal, Nat) { (p, shares[i]) }
    );
    totalAmount = totalAmount;
    tokenId = 0; // Replace this with the correct tokenId if you're using a token system
}));
            #ok(splitPayment)
        };

       public func executeSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
    let paymentOpt = Array.find<SplitPayment>(splitPayments, func(p : SplitPayment) { p.id == paymentId });

    switch (paymentOpt) {
        case null {
            return #err("Split payment not found.");
        };
        case (?payment) {
            if (payment.status != "Pending") {
                return #err("Only pending split payments can be executed.");
            };

            let amounts = Array.map<Nat, Nat>(payment.shares, func(share) {
                Nat.div(Nat.mul(payment.totalAmount, share), 100)
            });

            for (index in Iter.range(0, Array.size(payment.recipients) - 1)) {
                let recipient = payment.recipients[index];
                let amount = amounts[index];

                let creditResult = await walletProxy.creditWallet(recipient, amount, 0);
                switch (creditResult) {
                    case (#err(e)) {
                        LoggingUtils.logError(
                            logStore,
                            "PaymentSplitsModule",
                            "Failed to credit recipient. Recipient: " # Principal.toText(recipient) # ", Error: " # e,
                            ?recipient
                        );

                        splitPayments := Array.map<SplitPayment, SplitPayment>(splitPayments, func(p : SplitPayment) {
                            if (p.id == paymentId) { { p with status = "Failed" } } else p
                        });

                        return #err("Split payment failed for recipient: " # Principal.toText(recipient));
                    };
                    case (#ok(_)) {};
                };
            };

            splitPayments := Array.map<SplitPayment, SplitPayment>(splitPayments, func(p : SplitPayment) {
                if (p.id == paymentId) { { p with status = "Completed" } } else p
            });

            LoggingUtils.logInfo(
                logStore,
                "PaymentSplitsModule",
                "Split payment executed successfully. ID: " # Nat.toText(paymentId),
                null
            );

            await emitSplitPaymentEvent(#SplitPaymentExecuted, #SplitPaymentExecuted {
                splitId = paymentId;
                executor = payment.sender;
                recipients = Array.mapEntries<Principal, (Principal, Nat)>(
                    payment.recipients,
                    func(recipient: Principal, i: Nat) : (Principal, Nat) { (recipient, payment.shares[i]) }
                );
                totalAmount = payment.totalAmount;
                tokenId = 0; // Replace with the correct token ID if you're using a token system
                executionTime = Nat64.fromNat(Int.abs(Time.now()));
            });

            #ok(())
        };
    };
};

        // Get all split payments
        public func getAllSplitPayments(): async [SplitPayment] {
            LoggingUtils.logInfo(
                logStore,
                "PaymentSplitsModule",
                "Retrieving all split payments.",
                null
            );

            splitPayments
        };

        // Get split payment details by ID
public func getSplitPaymentDetails(paymentId: Nat): async Result.Result<SplitPayment, Text> {
    let paymentOpt = Array.find<SplitPayment>(splitPayments, func(p : SplitPayment) { p.id == paymentId });

    switch (paymentOpt) {
        case null {
            return #err("Split payment not found.");
        };
        case (?payment) #ok(payment);
    };
};

        // Cancel a pending split payment
public func cancelSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
    let paymentOpt = Array.find<SplitPayment>(splitPayments, func(p : SplitPayment) { p.id == paymentId });

            switch (paymentOpt) {
                case null {
                    return #err("Split payment not found.");
                };
                case (?payment) {
                    if (payment.status != "Pending") {
                        return #err("Only pending split payments can be cancelled.");
                    };

                    splitPayments := Array.map<SplitPayment, SplitPayment>(splitPayments, func(p : SplitPayment) {
    if (p.id == paymentId) { { p with status = "Cancelled" } } else p
});

                    LoggingUtils.logInfo(
                        logStore,
                        "PaymentSplitsModule",
                        "Split payment cancelled successfully. ID: " # Nat.toText(paymentId),
                        null
                    );

                    // Emit event for split payment cancellation
await emitSplitPaymentEvent(#SplitPaymentCancelled, #SplitPaymentCancelled {
    splitId = paymentId;
    initiator = payment.sender;
    cancellationReason = "Payment cancelled by user"; // You may want to pass this as a parameter
    cancellationTime = Nat64.fromNat(Int.abs(Time.now()));
});

                    #ok(())
                };
            };
        };

        // Validate the integrity of a specific split payment
public func validateSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
    let paymentOpt = Array.find<SplitPayment>(splitPayments, func(p: SplitPayment) { p.id == paymentId });

    switch (paymentOpt) {
        case null {
            return #err("Split payment not found.");
        };
        case (?payment) {
            if (Array.size(payment.recipients) != Array.size(payment.shares)) {
                return #err("Recipients and shares mismatch.");
            };
            if (not validateShares(payment.shares)) {
                return #err("Shares do not add up to 100%.");
            };
            #ok(())
        };
    };
};

// Get split payments by status
public func listSplitPaymentsByStatus(status: Text): async [SplitPayment] {
    Array.filter<SplitPayment>(splitPayments, func(p: SplitPayment) { p.status == status })
};

// Retry a failed split payment
public func retrySplitPayment(paymentId: Nat): async Result.Result<(), Text> {
    let paymentOpt = Array.find<SplitPayment>(splitPayments, func(p: SplitPayment) { p.id == paymentId });

    switch (paymentOpt) {
        case null {
            return #err("Split payment not found.");
        };
        case (?payment) {
            if (payment.status != "Failed") {
                return #err("Only failed split payments can be retried.");
            };

            // Reset status to "Pending" for retry
            splitPayments := Array.map<SplitPayment, SplitPayment>(splitPayments, func(p: SplitPayment) {
                if (p.id == paymentId) { { p with status = "Pending" } } else p
            });

            LoggingUtils.logInfo(
                logStore,
                "PaymentSplitsModule",
                "Retrying split payment. ID: " # Nat.toText(paymentId),
                null
            );

            #ok(())
        };
    };
};

// Calculate the total amount distributed for a split payment
public func calculateDistributedAmount(paymentId: Nat): async Result.Result<Nat, Text> {
    let paymentOpt = Array.find<SplitPayment>(splitPayments, func(p: SplitPayment) { p.id == paymentId });

    switch (paymentOpt) {
        case null {
            return #err("Split payment not found.");
        };
        case (?payment) {
            let amounts = Array.map<Nat, Nat>(payment.shares, func(share) {
                Nat.div(Nat.mul(payment.totalAmount, share), 100)
            });
            let totalDistributed = Array.foldLeft<Nat, Nat>(amounts, 0, func(acc, amount) { acc + amount });
            #ok(totalDistributed)
        };
    };
};

    };
};