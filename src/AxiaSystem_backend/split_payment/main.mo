import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import SplitPaymentService "services/split_payment_service";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import EventManager "../heartbeat/event_manager";
import SplitPaymentModule "modules/split_payment_module";

actor {

    // Initialize dependencies
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(Principal.fromText("ahw5u-keaaa-aaaaa-qaaha-cai"));
    private let eventManager = EventManager.EventManager();

    // Initialize the Split Payment Service
    private let splitPaymentService = SplitPaymentService.createSplitPaymentService(walletProxy, eventManager);

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
};