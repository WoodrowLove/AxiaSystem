import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";
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
                id = Nat.fromIntWrap(Time.now());
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

            if (Array.isEmpty(recipients) or Array.isEmpty(shares)) {
                return #err("Recipients and shares cannot be empty.");
            };

            if (not validateShares(shares)) {
                return #err("Shares must add up to 100%.");
            };

            let splitPayment: SplitPayment = {
                id = Nat.fromIntWrap(Time.now());
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
            await emitSplitPaymentEvent(#SplitPaymentInitiated, #SplitPaymentInitiated {
                paymentId = Nat.toText(splitPayment.id);
                senderId = Principal.toText(sender);
                totalAmount = totalAmount;
                recipients = Array.map(recipients, Principal.toText);
            });

            #ok(splitPayment)
        };

        // Execute a split payment
        public func executeSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
            let paymentOpt = Array.find(splitPayments, func(p) { p.id == paymentId });

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

                    for (index in 0 to Array.size(payment.recipients) - 1) {
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

                                // Update payment to failed
                                splitPayments := Array.map(splitPayments, func(p) {
                                    if (p.id == paymentId) { { p with status = "Failed" } } else p
                                });

                                return #err("Split payment failed for recipient: " # Principal.toText(recipient));
                            };
                            case (#ok(_)) {};
                        };
                    };

                    // Update payment to completed
                    splitPayments := Array.map(splitPayments, func(p) {
                        if (p.id == paymentId) { { p with status = "Completed" } } else p
                    });

                    LoggingUtils.logInfo(
                        logStore,
                        "PaymentSplitsModule",
                        "Split payment executed successfully. ID: " # Nat.toText(paymentId),
                        null
                    );

                    // Emit event for split payment completion
                    await emitSplitPaymentEvent(#SplitPaymentExecuted, #SplitPaymentExecuted {
                        paymentId = Nat.toText(paymentId);
                        senderId = Principal.toText(payment.sender);
                        totalAmount = payment.totalAmount;
                        recipients = Array.map(payment.recipients, Principal.toText);
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
            let paymentOpt = Array.find(splitPayments, func(p) { p.id == paymentId });

            switch (paymentOpt) {
                case null {
                    return #err("Split payment not found.");
                };
                case (?payment) #ok(payment);
            };
        };

        // Cancel a pending split payment
        public func cancelSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
            let paymentOpt = Array.find(splitPayments, func(p) { p.id == paymentId });

            switch (paymentOpt) {
                case null {
                    return #err("Split payment not found.");
                };
                case (?payment) {
                    if (payment.status != "Pending") {
                        return #err("Only pending split payments can be cancelled.");
                    };

                    splitPayments := Array.map(splitPayments, func(p) {
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
                        paymentId = Nat.toText(paymentId);
                        senderId = Principal.toText(payment.sender);
                        status = "Cancelled";
                    });

                    #ok(())
                };
            };
        };
    };
};