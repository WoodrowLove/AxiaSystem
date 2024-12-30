import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import _PaymentMonitoringModule "../modules/payment_monitoring_module";
import _SharedTypes "../../shared_types";
import Error "mo:base/Error";

module {
    public type PaymentMonitoringCanisterInterface = actor {
        monitorPayment: (Principal, Nat) -> async Result.Result<Text, Text>;
        monitorPendingPayments: () -> async Result.Result<Nat, Text>;
        validateWalletBalance: (Principal, Nat, Nat) -> async Result.Result<Bool, Text>;
        reconcilePayments: (Principal) -> async Result.Result<Nat, Text>;
        subscribeToPayments: (Principal) -> async Result.Result<Nat, Text>;
        unsubscribeFromPayments: (Nat) -> async Result.Result<(), Text>;
        broadcastPaymentUpdate: (Nat, Text) -> async Result.Result<(), Text>;
        listSubscriptions: () -> async [(Nat, Principal)];
    };

    // Proxy class for Payment Monitoring Canister
    public class PaymentMonitoringProxy(canisterId: Principal) {
        private let paymentMonitoringCanister: PaymentMonitoringCanisterInterface = actor(Principal.toText(canisterId));

        public func monitorPayment(caller: Principal, paymentId: Nat): async Result.Result<Text, Text> {
            try {
                await paymentMonitoringCanister.monitorPayment(caller, paymentId);
            } catch (e) {
                #err("Failed to monitor payment: " # Error.message(e))
            }
        };

        public func monitorPendingPayments(): async Result.Result<Nat, Text> {
            try {
                await paymentMonitoringCanister.monitorPendingPayments();
            } catch (e) {
                #err("Failed to monitor pending payments: " # Error.message(e))
            }
        };

        public func validateWalletBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<Bool, Text> {
            try {
                await paymentMonitoringCanister.validateWalletBalance(userId, tokenId, amount);
            } catch (e) {
                #err("Failed to validate wallet balance: " # Error.message(e))
            }
        };

        public func reconcilePayments(caller: Principal): async Result.Result<Nat, Text> {
            try {
                await paymentMonitoringCanister.reconcilePayments(caller);
            } catch (e) {
                #err("Failed to reconcile payments: " # Error.message(e))
            }
        };

        public func subscribeToPayments(userId: Principal): async Result.Result<Nat, Text> {
            try {
                await paymentMonitoringCanister.subscribeToPayments(userId);
            } catch (e) {
                #err("Failed to subscribe to payments: " # Error.message(e))
            }
        };

        public func unsubscribeFromPayments(subscriptionId: Nat): async Result.Result<(), Text> {
            try {
                await paymentMonitoringCanister.unsubscribeFromPayments(subscriptionId);
            } catch (e) {
                #err("Failed to unsubscribe from payments: " # Error.message(e))
            }
        };

        public func broadcastPaymentUpdate(paymentId: Nat, status: Text): async Result.Result<(), Text> {
            try {
                await paymentMonitoringCanister.broadcastPaymentUpdate(paymentId, status);
            } catch (e) {
                #err("Failed to broadcast payment update: " # Error.message(e))
            }
        };

        public func listSubscriptions(): async Result.Result<[(Nat, Principal)], Text> {
    try {
        let subscriptions = await paymentMonitoringCanister.listSubscriptions();
        #ok(subscriptions)
    } catch (e) {
        #err("Failed to list subscriptions: " # Error.message(e))
    }
};
    };
};