import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";

module {
    public type Payment = {
        id: Nat;
        sender: Principal;
        receiver: Principal;
        amount: Nat;
        tokenId: ?Nat;
        status: Text; // "Pending", "Completed", "Failed"
        timestamp: Nat;
    };

    public type PaymentCanisterInterface = actor {
        initiatePayment: (sender: Principal, receiver: Principal, amount: Nat, tokenId: ?Nat) -> async Result.Result<Payment, Text>;
        getPaymentStatus: (paymentId: Nat) -> async Result.Result<Text, Text>;
        getPaymentHistory: (userId: Principal) -> async Result.Result<[Payment], Text>;
    };

    public class PaymentCanisterProxy(paymentCanisterId: Principal) {
        private let paymentCanister: PaymentCanisterInterface = actor(Principal.toText(paymentCanisterId));

        // Initiate a payment
        public func initiatePayment(sender: Principal, receiver: Principal, amount: Nat, tokenId: ?Nat): async Result.Result<Payment, Text> {
            try {
                await paymentCanister.initiatePayment(sender, receiver, amount, tokenId)
            } catch (e) {
                #err("Failed to initiate payment: " # Error.message(e))
            }
        };

        // Get the status of a payment
        public func getPaymentStatus(paymentId: Nat): async Result.Result<Text, Text> {
            try {
                await paymentCanister.getPaymentStatus(paymentId)
            } catch (e) {
                #err("Failed to get payment status: " # Error.message(e))
            }
        };

        // Get payment history for a user
        public func getPaymentHistory(userId: Principal): async Result.Result<[Payment], Text> {
            try {
                await paymentCanister.getPaymentHistory(userId)
            } catch (e) {
                #err("Failed to fetch payment history: " # Error.message(e))
            }
        };
    };
};