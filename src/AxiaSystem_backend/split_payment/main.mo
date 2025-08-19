import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import SplitPaymentService "services/split_payment_service";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import EventManager "../heartbeat/event_manager";
import SplitPaymentModule "modules/split_payment_module";
import RefundModule "../modules/refund_module";
import TriadShared "../types/triad_shared";

persistent actor {

    // Initialize dependencies
    private transient let walletProxy = WalletCanisterProxy.WalletCanisterProxy(
    Principal.fromText("xhc3x-m7777-77774-qaaiq-cai"), // Wallet Canister ID
    Principal.fromText("xad5d-bh777-77774-qaaia-cai")  // User Canister ID
);
    private transient let eventManager = EventManager.EventManager();

    // Initialize the Refund Manager for split payment-specific refunds
    private transient let refundManager = RefundModule.RefundManager("SplitPayment", eventManager);

    // Initialize the Split Payment Service
    private transient let splitPaymentService = SplitPaymentService.createSplitPaymentService(walletProxy, eventManager);

    // Helper function to convert TriadError to Text for legacy API compatibility
    private func triadErrorToText(error: TriadShared.TriadError): Text {
        switch (error) {
            case (#NotFound(details)) "Not found: " # details.resource # " with ID " # details.id;
            case (#Unauthorized(details)) "Unauthorized: " # details.operationType # " for principal " # Principal.toText(details.principal);
            case (#Conflict(details)) "Conflict: " # details.reason # " (current state: " # details.currentState # ")";
            case (#Invalid(details)) "Invalid " # details.field # ": " # details.reason # " (value: " # details.value # ")";
            case (#Upstream(details)) "Upstream error from " # details.systemName # ": " # details.error;
            case (#Transient(details)) "Transient error in " # details.operationType # " operation" # (switch (details.retryAfter) { case (?after) " (retry after " # Nat64.toText(after) # "ms)"; case (null) "" });
            case (#Internal(details)) "Internal error [" # details.code # "]: " # details.message;
            case (#Capacity(details)) "Capacity exceeded: " # details.resource # " (" # Nat.toText(details.current) # "/" # Nat.toText(details.limit) # ")";
            case (#Timeout(details)) "Timeout in " # details.operationType # " operation (" # Nat64.toText(details.duration) # "ms)";
        }
    };

    // Public methods for Split Payment functionality

   // Initiate a split payment
public shared func initiateSplitPayment(
    sender: Principal,
    recipients: [Principal],
    shares: [Nat],
    totalAmount: Nat,
    description: ?Text
): async Result.Result<Nat, Text> {
    let result = await splitPaymentService.initiateSplitPayment(sender, recipients, shares, totalAmount, description);
    switch (result) {
        case (#ok(splitPayment)) {
            #ok(splitPayment.id)
        };
        case (#err(error)) {
            #err(error)
        };
    };
};

    // Execute a split payment
    public shared func executeSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
        await splitPaymentService.executeSplitPayment(paymentId);
    };

    // Cancel a split payment
    public shared func cancelSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
        await splitPaymentService.cancelSplitPayment(paymentId);
    };

    // Get details of a split payment
    public shared func getSplitPaymentDetails(paymentId: Nat): async Result.Result<{
        id: Nat;
        sender: Principal;
        recipients: [Principal];
        shares: [Nat];
        totalAmount: Nat;
        description: ?Text;
        status: Text;
        createdAt: Int;
    }, Text> {
        await splitPaymentService.getSplitPaymentDetails(paymentId);
    };

    // Retrieve all split payments
    // Retrieve all split payments
public shared func getAllSplitPayments(): async [Nat] {
    let splitPayments = await splitPaymentService.getAllSplitPayments();
    Array.map<SplitPaymentModule.SplitPayment, Nat>(splitPayments, func (payment : SplitPaymentModule.SplitPayment) : Nat {
        payment.id
    })
};

    // List split payments by status
public shared func listSplitPaymentsByStatus(status: Text): async [Nat] {
    let splitPayments = await splitPaymentService.listSplitPaymentsByStatus(status);
    Array.map<SplitPaymentModule.SplitPayment, Nat>(splitPayments, func (payment : SplitPaymentModule.SplitPayment) : Nat {
        payment.id
    })
};

    // Retry a failed split payment
    public shared func retrySplitPayment(paymentId: Nat): async Result.Result<(), Text> {
        await splitPaymentService.retrySplitPayment(paymentId);
    };

    // Calculate distributed amount
    public shared func calculateDistributedAmount(paymentId: Nat): async Result.Result<Nat, Text> {
        await splitPaymentService.calculateDistributedAmount(paymentId);
    };

    // Validate a split payment
    public shared func validateSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
        await splitPaymentService.validateSplitPayment(paymentId);
    };

    // ======= REFUND MANAGEMENT API =======

    // API: Create a split payment refund request
    public shared func createSplitPaymentRefundRequest(
        paymentId: Nat,
        requestedBy: Principal,
        amount: Nat,
        reason: ?Text
    ): async Result.Result<Nat, Text> {
        let refundSource = #UserFunds({ 
            fromUser = requestedBy; 
            context = null 
        });
        let result = await refundManager.createRefundRequest(paymentId, requestedBy, amount, refundSource, reason);
        switch (result) {
            case (#ok(refundId)) #ok(refundId);
            case (#err(e)) {
                let errorText = triadErrorToText(e);
                #err(errorText)
            };
        }
    };

    // API: List split payment refund requests
    public shared func listSplitPaymentRefundRequests(
        status: ?Text,
        requestedBy: ?Principal,
        fromTime: ?Int,
        toTime: ?Int,
        offset: Nat,
        limit: Nat
    ): async Result.Result<[RefundModule.RefundRequest], Text> {
        await refundManager.listRefundRequests(status, requestedBy, fromTime, toTime, offset, limit)
    };

    // API: Get specific split payment refund request
    public shared func getSplitPaymentRefundRequest(refundId: Nat): async Result.Result<RefundModule.RefundRequest, Text> {
        await refundManager.getRefundRequest(refundId)
    };

    // API: Approve split payment refund request (Admin only)
    public shared func approveSplitPaymentRefundRequest(
        refundId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        let result = await refundManager.approveRefundRequest(refundId, adminPrincipal, adminNote);
        switch (result) {
            case (#ok(())) #ok(());
            case (#err(e)) {
                let errorText = triadErrorToText(e);
                #err(errorText)
            };
        }
    };

    // API: Deny split payment refund request (Admin only)
    public shared func denySplitPaymentRefundRequest(
        refundId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        let result = await refundManager.denyRefundRequest(refundId, adminPrincipal, adminNote);
        switch (result) {
            case (#ok(())) #ok(());
            case (#err(e)) {
                let errorText = triadErrorToText(e);
                #err(errorText)
            };
        }
    };

    // API: Mark split payment refund as processed
    public shared func markSplitPaymentRefundProcessed(
        refundId: Nat,
        success: Bool,
        errorMsg: ?Text
    ): async Result.Result<(), Text> {
        let result = await refundManager.markRefundProcessed(refundId, success, errorMsg);
        switch (result) {
            case (#ok(())) #ok(());
            case (#err(e)) {
                let errorText = triadErrorToText(e);
                #err(errorText)
            };
        }
    };

    // API: Get split payment refund statistics
    public shared func getSplitPaymentRefundStats(): async RefundModule.RefundStats {
        await refundManager.getRefundStats()
    };
};