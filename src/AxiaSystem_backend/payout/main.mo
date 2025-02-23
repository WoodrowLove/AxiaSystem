import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Error "mo:base/Error";
import PayoutService "../payout/services/payout_service";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import EventManager "../heartbeat/event_manager";
import PayoutModule "modules/payout_module";

actor {
    // Initialize dependencies
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(Principal.fromText("c2lt4-zmaaa-aaaaa-qaaiq-cai"));
    private let eventManager = EventManager.EventManager();

    // Initialize the Payout Service
    private let payoutService = PayoutService.createPayoutService(walletProxy, eventManager);

    // Public APIs

    // Initiate a new payout
public shared func initiatePayout(
    recipients: [Principal],
    amounts: [Nat],
    description: ?Text
): async Result.Result<Nat, Text> {
    let result = await payoutService.initiatePayout(recipients, amounts, description);
    switch (result) {
        case (#ok(payout)) {
            #ok(payout.id)
        };
        case (#err(error)) {
            #err(error)
        };
    };
};

    // Execute an existing payout by ID
    public shared func executePayout(payoutId: Nat): async Result.Result<(), Text> {
        await payoutService.executePayout(payoutId);
    };

    // Cancel a pending payout by ID
    public shared func cancelPayout(payoutId: Nat): async Result.Result<(), Text> {
        await payoutService.cancelPayout(payoutId);
    };

    // Retrieve all payouts
public shared query func getAllPayouts(): async [PayoutModule.Payout] {
    payoutService.getAllPayouts()
};

    // Retrieve payout details by ID
public shared query func getPayoutDetails(payoutId: Nat): async Result.Result<PayoutModule.Payout, Text> {
    payoutService.getPayoutDetails(payoutId)
};

    // Health check for the Payout Canister
public shared func healthCheck(): async Text {
    try {
        let payouts = payoutService.getAllPayouts();
        if (payouts.size() > 0) {
            "Payout canister is operational with " # Nat.toText(payouts.size()) # " payouts."
        } else {
            "Payout canister is operational but no payouts exist."
        }
    } catch (e) {
        "Payout canister health check failed: " # Error.message(e);
    }
};
};