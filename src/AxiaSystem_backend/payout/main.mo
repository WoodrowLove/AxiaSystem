import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Error "mo:base/Error";
import PayoutService "../payout/services/payout_service";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import EventManager "../heartbeat/event_manager";
import PayoutModule "modules/payout_module";
import RefundModule "../modules/refund_module";

persistent actor {
    // Initialize dependencies
    private transient let walletProxy = WalletCanisterProxy.WalletCanisterProxy(
    Principal.fromText("xhc3x-m7777-77774-qaaiq-cai"), // Wallet Canister ID
    Principal.fromText("xad5d-bh777-77774-qaaia-cai")  // User Canister ID
);
    private transient let eventManager = EventManager.EventManager();

    // Initialize the Refund Manager for payout-specific refunds
    private transient let refundManager = RefundModule.RefundManager("Payout", eventManager);

    // Initialize the Payout Service
    private transient let payoutService = PayoutService.createPayoutService(walletProxy, eventManager);

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

    // ======= REFUND MANAGEMENT API =======

    // API: Create a payout refund request
    public shared func createPayoutRefundRequest(
        payoutId: Nat,
        requestedBy: Principal,
        amount: Nat,
        reason: ?Text
    ): async Result.Result<Nat, Text> {
        // Default to user funds for payout refunds
        let refundSource = #UserFunds({ fromUser = requestedBy });
        await refundManager.createRefundRequest(payoutId, requestedBy, amount, refundSource, reason)
    };

    // API: List payout refund requests
    public shared func listPayoutRefundRequests(
        status: ?Text,
        requestedBy: ?Principal,
        fromTime: ?Int,
        toTime: ?Int,
        offset: Nat,
        limit: Nat
    ): async Result.Result<[RefundModule.RefundRequest], Text> {
        await refundManager.listRefundRequests(status, requestedBy, fromTime, toTime, offset, limit)
    };

    // API: Get specific payout refund request
    public shared func getPayoutRefundRequest(refundId: Nat): async Result.Result<RefundModule.RefundRequest, Text> {
        await refundManager.getRefundRequest(refundId)
    };

    // API: Approve payout refund request (Admin only)
    public shared func approvePayoutRefundRequest(
        refundId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        await refundManager.approveRefundRequest(refundId, adminPrincipal, adminNote)
    };

    // API: Deny payout refund request (Admin only)
    public shared func denyPayoutRefundRequest(
        refundId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        await refundManager.denyRefundRequest(refundId, adminPrincipal, adminNote)
    };

    // API: Mark payout refund as processed
    public shared func markPayoutRefundProcessed(
        refundId: Nat,
        success: Bool,
        errorMsg: ?Text
    ): async Result.Result<(), Text> {
        await refundManager.markRefundProcessed(refundId, success, errorMsg)
    };

    // API: Get payout refund statistics
    public shared func getPayoutRefundStats(): async RefundModule.RefundStats {
        await refundManager.getRefundStats()
    };
};