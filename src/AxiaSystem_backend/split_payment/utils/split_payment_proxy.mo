import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Error "mo:base/Error";

module {
    public type SplitPaymentCanisterInterface = actor {
        initiateSplitPayment: (Principal, [Principal], [Nat], Nat, ?Text) -> async Result.Result<Nat, Text>;
        executeSplitPayment: (Nat) -> async Result.Result<(), Text>;
        cancelSplitPayment: (Nat) -> async Result.Result<(), Text>;
        getAllSplitPayments: () -> async [Nat];
        getSplitPaymentDetails: (Nat) -> async Result.Result<{
            id: Nat;
            sender: Principal;
            recipients: [Principal];
            shares: [Nat];
            totalAmount: Nat;
            description: ?Text;
            status: Text;
            createdAt: Int;
        }, Text>;
        listSplitPaymentsByStatus: (Text) -> async [Nat];
        retrySplitPayment: (Nat) -> async Result.Result<(), Text>;
        calculateDistributedAmount: (Nat) -> async Result.Result<Nat, Text>;
        validateSplitPayment: (Nat) -> async Result.Result<(), Text>;
    };

    public class SplitPaymentProxy(canisterId: Principal) {
        private let splitPaymentCanister: SplitPaymentCanisterInterface = actor(Principal.toText(canisterId));

        // Initiate a split payment
        public func initiateSplitPayment(
            sender: Principal,
            recipients: [Principal],
            shares: [Nat],
            totalAmount: Nat,
            description: ?Text
        ): async Result.Result<Nat, Text> {
            try {
                await splitPaymentCanister.initiateSplitPayment(sender, recipients, shares, totalAmount, description);
            } catch (e) {
                #err("Failed to initiate split payment: " # Error.message(e));
            }
        };

        // Execute a split payment
        public func executeSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
            try {
                await splitPaymentCanister.executeSplitPayment(paymentId);
            } catch (e) {
                #err("Failed to execute split payment: " # Error.message(e));
            }
        };

        // Cancel a split payment
        public func cancelSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
            try {
                await splitPaymentCanister.cancelSplitPayment(paymentId);
            } catch (e) {
                #err("Failed to cancel split payment: " # Error.message(e));
            }
        };

        // Retrieve all split payments
        public func getAllSplitPayments(): async [Nat] {
            try {
                await splitPaymentCanister.getAllSplitPayments();
            } catch (_e) {
                [];
            }
        };

        // Get details of a specific split payment
        public func getSplitPaymentDetails(paymentId: Nat): async Result.Result<{
            id: Nat;
            sender: Principal;
            recipients: [Principal];
            shares: [Nat];
            totalAmount: Nat;
            description: ?Text;
            status: Text;
            createdAt: Int;
        }, Text> {
            try {
                await splitPaymentCanister.getSplitPaymentDetails(paymentId);
            } catch (e) {
                #err("Failed to fetch split payment details: " # Error.message(e));
            }
        };

        // List split payments by status
        public func listSplitPaymentsByStatus(status: Text): async [Nat] {
            try {
                await splitPaymentCanister.listSplitPaymentsByStatus(status);
            } catch (_e) {
                [];
            }
        };

        // Retry a failed split payment
        public func retrySplitPayment(paymentId: Nat): async Result.Result<(), Text> {
            try {
                await splitPaymentCanister.retrySplitPayment(paymentId);
            } catch (e) {
                #err("Failed to retry split payment: " # Error.message(e));
            }
        };

        // Calculate distributed amount
        public func calculateDistributedAmount(paymentId: Nat): async Result.Result<Nat, Text> {
            try {
                await splitPaymentCanister.calculateDistributedAmount(paymentId);
            } catch (e) {
                #err("Failed to calculate distributed amount: " # Error.message(e));
            }
        };

        // Validate a split payment
        public func validateSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
            try {
                await splitPaymentCanister.validateSplitPayment(paymentId);
            } catch (e) {
                #err("Failed to validate split payment: " # Error.message(e));
            }
        };
    };
};