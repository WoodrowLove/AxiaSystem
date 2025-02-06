import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import PaymentCanisterProxy "../../payment/utils/payment_canister_proxy";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";
import LoggingUtils "../../utils/logging_utils";
import Time "mo:base/Time";
import Option "mo:base/Option";
import Array "mo:base/Array";
import SharedTypes "../../shared_types";

module {
    public class PaymentMonitoringManager(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        paymentProxy: PaymentCanisterProxy.PaymentCanisterProxy,
        _tokenProxy: TokenCanisterProxy.TokenCanisterProxy,
        _eventManager: EventManager.EventManager,
        subscriptionManagerPrincipal: Principal
    )
     {
        private let subscriptionManager = actor(Principal.toText(subscriptionManagerPrincipal)) : SharedTypes.SubscriptionCanisterInterface;
         private let logStore = LoggingUtils.init();
         let eventManager = EventManager.EventManager();
         
        // Monitor a specific payment
        public func monitorPayment(caller: Principal, paymentId: Nat): async Result.Result<Text, Text> {
    let paymentResult = await paymentProxy.getPaymentStatus(paymentId);
    switch (paymentResult) {
        case (#ok(status)) {
            let eventType : EventTypes.EventType = switch (status) {
                case ("Completed") #PaymentProcessed;
                case ("Failed") #PaymentStatusRetrieved;
                case ("Reversed") #PaymentReversed;
                case (_) #PaymentUpdated;
            };
            
            let userId = Principal.toText(caller);
            let paymentIdText = Nat64.toText(Nat64.fromNat(paymentId));
            
            let payload : EventTypes.EventPayload = switch (eventType) {
                case (#PaymentProcessed) #PaymentProcessed({ userId = caller; amount = 0; walletId = "" });
                case (#PaymentReversed) #PaymentReversed({ userId = caller; amount = 0; walletId = "" });
                case (#PaymentStatusRetrieved) #PaymentStatusRetrieved({ paymentId = paymentIdText; status = status });
                case (#PaymentUpdated) #PaymentUpdated({ userId = userId; paymentId = paymentIdText; status = status });
                case (_) return #err("Unexpected event type");
            };

            let event : EventTypes.Event = {
                id = Nat64.fromNat(paymentId);
                eventType = eventType;
                payload = payload;
            };

            await eventManager.emit(event);

            #ok(status)
        };
        case (#err(e)) {
            #err("Failed to monitor payment status: " # e)
        };
    }
};

        // Monitor all pending payments
        public func monitorPendingPayments(): async Result.Result<Nat, Text> {
    let timeoutResult = await paymentProxy.timeoutPendingPayments();
    switch timeoutResult {
        case (#ok(timeoutCount)) {
            let event : EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = #PendingPaymentsMonitored;
                payload = #PendingPaymentsMonitored({
                    timeoutCount = timeoutCount;
                });
            };
            await eventManager.emit(event);
            #ok(timeoutCount)
        };
        case (#err(e)) {
            #err("Failed to process pending payments: " # e)
        };
    }
};
        // Validate wallet balance during payment monitoring
        public func validateWalletBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<Bool, Text> {
    let walletBalanceResult = await walletProxy.getBalance(userId, tokenId);
    switch walletBalanceResult {
        case (#ok(balance)) {
            if (balance >= amount) {
                #ok(true)
            } else {
                let event : EventTypes.Event = {
                    id = Nat64.fromIntWrap(Time.now());
                    eventType = #InsufficientFunds;
                    payload = #InsufficientFunds({
                        userId = Principal.toText(userId);
                        tokenId = Nat64.fromNat(tokenId);
                        requiredAmount = Nat64.fromNat(amount);
                        currentBalance = Nat64.fromNat(balance);
                    });
                };
                await eventManager.emit(event);
                #ok(false)
            }
        };
        case (#err(e)) {
            #err("Failed to validate wallet balance: " # e)
        };
    }
};

        // Cross-check payment records for discrepancies
        public func reconcilePayments(caller: Principal): async Result.Result<Nat, Text> {
    let allPayments = await paymentProxy.getAllPayments(caller, null, null, null);
    switch allPayments {
        case (#ok(payments)) {
            var discrepancyCount: Nat = 0;
            for (payment in payments.vals()) {
                let balanceCheck = await validateWalletBalance(payment.sender, Option.get(payment.tokenId, 0), payment.amount);
                switch balanceCheck {
                    case (#ok(true)) {};
                    case (#ok(false)) {
                        discrepancyCount += 1;
                    };
                    case (#err(_)) {};
                }
            };
            let event : EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = #PaymentsReconciled;
                payload = #PaymentsReconciled({
                    discrepancyCount = discrepancyCount;
                });
            };
            await eventManager.emit(event);
            #ok(discrepancyCount)
        };
        case (#err(e)) {
            #err("Failed to reconcile payments: " # e)
        };
    }
};

public func subscribeToPayments(userId: Principal): async Result.Result<Nat, Text> {
    let subscriptionResult = await subscriptionManager.createSubscription(userId, 86400000000000); // Example: 1 day in nanoseconds
    switch subscriptionResult {
        case (#err(e)) #err("Failed to create subscription: " # e);
        case (#ok(subscription)) {
            let subscriptionId = subscription.id; // Access the ID from the Subscription object
            // Emit subscription event
            await eventManager.emit({
                id = Nat64.fromNat(subscriptionId);
                eventType = #SubscriptionCreated;
                payload = #SubscriptionCreated {
                    userId = Principal.toText(userId);
                    subscriptionId = Nat.toText(subscriptionId);
                };
            });
            LoggingUtils.logInfo(
                logStore,
                "PaymentMonitoring",
                "Subscription created for user: " # Principal.toText(userId) # ", Subscription ID: " # Nat.toText(subscriptionId),
                ?userId
            );
            #ok(subscriptionId)
        };
    };
};

// Unsubscribe from payment updates
public func unsubscribeFromPayments(userId: Principal): async Result.Result<(), Text> {
    let unsubscribeResult = await subscriptionManager.cancelSubscription(userId);
    switch unsubscribeResult {
        case (#err(e)) #err("Failed to unsubscribe: " # e);
        case (#ok(_)) {
            // Get subscription details to retrieve the subscriptionId
            let subscriptionDetails = await subscriptionManager.getSubscriptionDetails(userId);
            switch (subscriptionDetails) {
                case (#err(e)) #err("Failed to get subscription details: " # e);
                case (#ok(subscription)) {
                    // Emit unsubscription event
                    await eventManager.emitPaymentEvent(#SubscriptionRemoved, #SubscriptionRemoved {
                        subscriptionId = Nat.toText(subscription.id);
                    });
                    LoggingUtils.logInfo(
                        logStore,
                        "PaymentMonitoring",
                        "Subscription removed for User: " # Principal.toText(userId) # ", Subscription ID: " # Nat.toText(subscription.id),
                        ?userId
                    );
                    #ok(())
                };
            };
        };
    };
};

public func broadcastPaymentUpdate(paymentId: Nat, status: Text): async Result.Result<(), Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentMonitoring",
        "Broadcasting payment update to subscribers. Payment ID: " # Nat.toText(paymentId) # ", Status: " # status,
        null
    );

    let allSubscriptions = await subscriptionManager.getAllSubscriptions();
    for ((userId, subscription) in allSubscriptions.vals()) {
        await eventManager.emitPaymentEvent(#PaymentUpdated, #PaymentUpdated {
            userId = Principal.toText(userId);
            paymentId = Nat.toText(paymentId);
            status = status;
        });
    };

    #ok(())
};

public func listSubscriptions(): async [(Nat, Principal)] {
    let allSubscriptions = await subscriptionManager.getAllSubscriptions();
    Array.map<(Principal, SharedTypes.Subscription), (Nat, Principal)>(
        allSubscriptions,
        func((principal, subscription): (Principal, SharedTypes.Subscription)): (Nat, Principal) {
            (subscription.id, principal)
        }
    )
};
    };
};