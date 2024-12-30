import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Error "mo:base/Error";

module {
    public type PayoutCanisterInterface = actor {
        initiatePayout: ([Principal], [Nat], ?Text) -> async Result.Result<Nat, Text>;
        executePayout: (Nat) -> async Result.Result<(), Text>;
        cancelPayout: (Nat) -> async Result.Result<(), Text>;
        getAllPayouts: () -> async [Payout];
        getPayoutDetails: (Nat) -> async Result.Result<Payout, Text>;
    };

    public type Payout = {
        id: Nat;
        recipients: [Principal];
        amounts: [Nat];
        totalAmount: Nat;
        description: ?Text;
        status: Text; // "Pending", "Completed", "Failed", etc.
        createdAt: Int;
    };

    // Proxy class for interacting with the Payout Canister
    public class PayoutProxy(canisterId: Principal) {
        private let payoutCanister: PayoutCanisterInterface = actor(Principal.toText(canisterId));

        // Initiate a new payout
        public func initiatePayout(
            recipients: [Principal],
            amounts: [Nat],
            description: ?Text
        ): async Result.Result<Nat, Text> {
            try {
                await payoutCanister.initiatePayout(recipients, amounts, description);
            } catch (e) {
                #err("Failed to initiate payout: " # Error.message(e))
            }
        };

        // Execute an existing payout by ID
        public func executePayout(payoutId: Nat): async Result.Result<(), Text> {
            try {
                await payoutCanister.executePayout(payoutId);
            } catch (e) {
                #err("Failed to execute payout: " # Error.message(e))
            }
        };

        // Cancel a pending payout by ID
        public func cancelPayout(payoutId: Nat): async Result.Result<(), Text> {
            try {
                await payoutCanister.cancelPayout(payoutId);
            } catch (e) {
                #err("Failed to cancel payout: " # Error.message(e))
            }
        };

        // Retrieve all payouts
        public func getAllPayouts(): async [Payout] {
            try {
                await payoutCanister.getAllPayouts();
            } catch (_e) {
                [];
            }
        };

        // Retrieve payout details by ID
        public func getPayoutDetails(payoutId: Nat): async Result.Result<Payout, Text> {
            try {
                await payoutCanister.getPayoutDetails(payoutId);
            } catch (e) {
                #err("Failed to get payout details: " # Error.message(e))
            }
        };
    };
};