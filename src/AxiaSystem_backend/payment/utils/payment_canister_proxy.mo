import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";
import LoggingUtils "../../utils/logging_utils";

module {
    public type Payment = {
        id: Nat;
        sender: Principal;
        receiver: Principal;
        amount: Nat;
        tokenId: ?Nat;
        status: Text; // "Pending", "Completed", "Failed", "Reversed"
        timestamp: Nat;
    };

    public type PaymentCanisterInterface = actor {
        initiatePayment: (sender: Principal, receiver: Principal, amount: Nat, tokenId: ?Nat) -> async Result.Result<Payment, Text>;
        completePayment: (paymentId: Nat) -> async Result.Result<(), Text>;
        getPaymentStatus: (paymentId: Nat) -> async Result.Result<Text, Text>;
        getPaymentHistory: (userId: Principal) -> async Result.Result<[Payment], Text>;
        getAllPayments: (user: Principal, filterByStatus: ?Text, fromDate: ?Nat, toDate: ?Nat) -> async Result.Result<[Payment], Text>;
        reversePayment: (paymentId: Nat) -> async Result.Result<(), Text>;
        timeoutPendingPayments: () -> async Result.Result<Nat, Text>;
    };

    public class PaymentCanisterProxy(paymentCanisterId: Principal) {
        private let paymentCanister: PaymentCanisterInterface = actor(Principal.toText(paymentCanisterId));
        private let logStore = LoggingUtils.init();

        // Initiate a payment
        public func initiatePayment(
            sender: Principal,
            receiver: Principal,
            amount: Nat,
            tokenId: ?Nat
        ): async Result.Result<Payment, Text> {
            try {
                await paymentCanister.initiatePayment(sender, receiver, amount, tokenId);
            } catch (e) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentCanisterProxy",
                    "Failed to initiate payment: " # Error.message(e),
                    ?sender
                );
                #err("Failed to initiate payment: " # Error.message(e))
            }
        };

        // Complete a payment
        public func completePayment(paymentId: Nat): async Result.Result<(), Text> {
            try {
                await paymentCanister.completePayment(paymentId);
            } catch (e) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentCanisterProxy",
                    "Failed to complete payment: " # Error.message(e),
                    null
                );
                #err("Failed to complete payment: " # Error.message(e))
            }
        };

        // Get the status of a payment
        public func getPaymentStatus(paymentId: Nat): async Result.Result<Text, Text> {
            try {
                await paymentCanister.getPaymentStatus(paymentId);
            } catch (e) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentCanisterProxy",
                    "Failed to get payment status: " # Error.message(e),
                    null
                );
                #err("Failed to get payment status: " # Error.message(e))
            }
        };

        // Get payment history for a user
        public func getPaymentHistory(userId: Principal): async Result.Result<[Payment], Text> {
            try {
                await paymentCanister.getPaymentHistory(userId);
            } catch (e) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentCanisterProxy",
                    "Failed to fetch payment history: " # Error.message(e),
                    ?userId
                );
                #err("Failed to fetch payment history: " # Error.message(e))
            }
        };

        // Get all payments with optional filters
        public func getAllPayments(
            user: Principal,
            filterByStatus: ?Text,
            fromDate: ?Nat,
            toDate: ?Nat
        ): async Result.Result<[Payment], Text> {
            try {
                await paymentCanister.getAllPayments(user, filterByStatus, fromDate, toDate);
            } catch (e) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentCanisterProxy",
                    "Failed to fetch all payments: " # Error.message(e),
                    ?user
                );
                #err("Failed to fetch all payments: " # Error.message(e))
            }
        };

        // Reverse a payment
        public func reversePayment(paymentId: Nat): async Result.Result<(), Text> {
            try {
                await paymentCanister.reversePayment(paymentId);
            } catch (e) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentCanisterProxy",
                    "Failed to reverse payment: " # Error.message(e),
                    null
                );
                #err("Failed to reverse payment: " # Error.message(e))
            }
        };

        // Timeout pending payments
        public func timeoutPendingPayments(): async Result.Result<Nat, Text> {
            try {
                await paymentCanister.timeoutPendingPayments();
            } catch (e) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentCanisterProxy",
                    "Failed to clean up pending payments: " # Error.message(e),
                    null
                );
                #err("Failed to clean up pending payments: " # Error.message(e))
            }
        };
    };
};