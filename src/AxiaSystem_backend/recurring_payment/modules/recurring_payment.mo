import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";
import LoggingUtils "../../utils/logging_utils";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    public type RecurringPayment = {
        id: Nat;
        sender: Principal;
        receiver: Principal;
        amount: Nat;
        interval: Nat64; // In seconds
        nextPaymentTimestamp: Nat64;
        status: Text; // "Active", "Paused", "Cancelled"
        description: Text;
        createdAt: Int;
    };

    public class RecurringPaymentManager(walletProxy: WalletCanisterProxy.WalletCanisterProxy, eventManager: EventManager.EventManager) {
        private var recurringPayments: [RecurringPayment] = [];
        private let logStore = LoggingUtils.init();

        // Emit a recurring payment-related event
        private func emitRecurringPaymentEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload): async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = eventType;
                payload = payload;
            };
            await eventManager.emit(event);
        };

        // Schedule a new recurring payment
        public func scheduleRecurringPayment(
            sender: Principal,
            receiver: Principal,
            amount: Nat,
            interval: Nat64,
            description: Text
        ): async Result.Result<RecurringPayment, Text> {
            if (amount <= 0) {
                return #err("Recurring payment amount must be greater than zero.");
            };

            if (interval < 60) {
                return #err("Recurring payment interval must be at least 60 seconds.");
            };

            let recurringPayment: RecurringPayment = {
                id = Int.abs(Time.now());
                sender = sender;
                receiver = receiver;
                amount = amount;
                interval = interval;
                nextPaymentTimestamp = Nat64.fromIntWrap(Time.now()) + interval;
                status = "Active";
                description = description;
                createdAt = Time.now();
            };

            recurringPayments := Array.append(recurringPayments, [recurringPayment]);

            // Emit event for new recurring payment
            await emitRecurringPaymentEvent(#PaymentProcessed, #PaymentProcessed {
                userId = sender;
                amount = amount;
                walletId = "recurring_payment_" # Nat.toText(recurringPayment.id);
            });

            LoggingUtils.logInfo(
                logStore,
                "RecurringPaymentModule",
                "Scheduled new recurring payment. Payment ID: " # Nat.toText(recurringPayment.id),
                ?sender
            );

            #ok(recurringPayment)
        };

        // Cancel a recurring payment
        public func cancelRecurringPayment(paymentId: Nat): async Result.Result<(), Text> {
            let paymentOpt: ?RecurringPayment = Array.find<RecurringPayment>(recurringPayments, func(p: RecurringPayment): Bool { p.id == paymentId });

            switch (paymentOpt) {
                case null {
                    return #err("Recurring payment not found.");
                };
                case (?payment) {
                    if (payment.status == "Cancelled") {
                        return #err("Recurring payment is already cancelled.");
                    };

                    recurringPayments := Array.map<RecurringPayment, RecurringPayment>(recurringPayments, func(p: RecurringPayment): RecurringPayment {
                        if (p.id == paymentId) { { p with status = "Cancelled" } } else p
                    });

                    // Emit event for recurring payment cancellation
                    await emitRecurringPaymentEvent(#PaymentUpdated, #PaymentUpdated {
                        userId = Principal.toText(payment.sender);
                        paymentId = Nat.toText(paymentId);
                        status = "Cancelled";
                    });

                    LoggingUtils.logInfo(
                        logStore,
                        "RecurringPaymentModule",
                        "Recurring payment cancelled. Payment ID: " # Nat.toText(paymentId),
                        null
                    );

                    #ok(())
                };
            };
        };

        // Execute all due recurring payments
        public func executeDuePayments(): async Result.Result<Nat, Text> {
            let now = Nat64.fromIntWrap(Time.now());
            var executedCount: Nat = 0;

            for (payment in recurringPayments.vals()) {
                if (payment.status == "Active" and payment.nextPaymentTimestamp <= now) {
                    let debitResult = await walletProxy.debitWallet(payment.sender, payment.amount, 0);
                    switch (debitResult) {
                        case (#err(e)) {
                            LoggingUtils.logError(
                                logStore,
                                "RecurringPaymentModule",
                                "Failed to debit sender for recurring payment. Payment ID: " # Nat.toText(payment.id) # ", Error: " # e,
                                ?payment.sender
                            );
                            // Continue to next payment
                        };
                        case (#ok(_)) {
                            let creditResult = await walletProxy.creditWallet(payment.receiver, payment.amount, 0);
                            switch (creditResult) {
                                case (#err(e)) {
                                    // Rollback debit if credit fails
                                    ignore await walletProxy.creditWallet(payment.sender, payment.amount, 0);
                                    LoggingUtils.logError(
                                        logStore,
                                        "RecurringPaymentModule",
                                        "Failed to credit receiver for recurring payment. Payment ID: " # Nat.toText(payment.id) # ", Error: " # e,
                                        ?payment.receiver
                                    );
                                    // Continue to next payment
                                };
                                case (#ok(_)) {
                                    // Update next payment timestamp
                                    recurringPayments := Array.map<RecurringPayment, RecurringPayment>(recurringPayments, func(p: RecurringPayment): RecurringPayment {
                                        if (p.id == payment.id) {
                                            { p with nextPaymentTimestamp = now + p.interval }
                                        } else p
                                    });

                                    LoggingUtils.logInfo(
                                        logStore,
                                        "RecurringPaymentModule",
                                        "Executed recurring payment. Payment ID: " # Nat.toText(payment.id),
                                        null
                                    );

                                    // Emit event for successful recurring payment execution
                                    await emitRecurringPaymentEvent(#PaymentProcessed, #PaymentProcessed {
                                        userId = payment.sender;
                                        amount = payment.amount;
                                        walletId = "recurring_payment_" # Nat.toText(payment.id);
                                    });

                                    executedCount += 1;
                                };
                            };
                        };
                    };
                };
            };

            LoggingUtils.logInfo(
                logStore,
                "RecurringPaymentModule",
                "Executed " # Nat.toText(executedCount) # " recurring payments.",
                null
            );

            #ok(executedCount)
        };

        // Get all recurring payments
        public func getAllRecurringPayments(): async [RecurringPayment] {
            LoggingUtils.logInfo(
                logStore,
                "RecurringPaymentModule",
                "Retrieving all recurring payments.",
                null
            );

            recurringPayments
        };

        // Pause a recurring payment
        public func pauseRecurringPayment(paymentId: Nat): async Result.Result<(), Text> {
            let paymentOpt: ?RecurringPayment = Array.find<RecurringPayment>(recurringPayments, func(p: RecurringPayment): Bool { p.id == paymentId });

            switch (paymentOpt) {
                case null {
                    return #err("Recurring payment not found.");
                };
                case (?payment) {
                    if (payment.status != "Active") {
                        return #err("Only active recurring payments can be paused.");
                    };

                    recurringPayments := Array.map<RecurringPayment, RecurringPayment>(recurringPayments, func(p: RecurringPayment): RecurringPayment {
                        if (p.id == paymentId) { { p with status = "Paused" } } else p
                    });

                    // Emit event for recurring payment pause
                    await emitRecurringPaymentEvent(#PaymentUpdated, #PaymentUpdated {
                        userId = Principal.toText(payment.sender);
                        paymentId = Nat.toText(paymentId);
                        status = "Paused";
                    });

                    LoggingUtils.logInfo(
                        logStore,
                        "RecurringPaymentModule",
                        "Recurring payment paused. Payment ID: " # Nat.toText(paymentId),
                        null
                    );

                    #ok(())
                };
            };
        };
    };
};