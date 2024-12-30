import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import SplitPaymentModule "../modules/split_payment_module";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import EventManager "../../heartbeat/event_manager";

module {
    public func createSplitPaymentService(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        eventManager: EventManager.EventManager
    ): SplitPaymentModule.PaymentSplitManager {
        SplitPaymentModule.PaymentSplitManager(walletProxy, eventManager)
    };

    // Initiate a split payment
    public func initiateSplitPayment(
        splitManager: SplitPaymentModule.PaymentSplitManager,
        sender: Principal,
        recipients: [Principal],
        shares: [Nat],
        totalAmount: Nat,
        description: ?Text
    ): async Result.Result<SplitPaymentModule.SplitPayment, Text> {
        await splitManager.initiateSplitPayment(sender, recipients, shares, totalAmount, description);
    };

    // Execute a split payment by ID
    public func executeSplitPayment(
        splitManager: SplitPaymentModule.PaymentSplitManager,
        paymentId: Nat
    ): async Result.Result<(), Text> {
        await splitManager.executeSplitPayment(paymentId);
    };

    // Cancel a pending split payment by ID
    public func cancelSplitPayment(
        splitManager: SplitPaymentModule.PaymentSplitManager,
        paymentId: Nat
    ): async Result.Result<(), Text> {
        await splitManager.cancelSplitPayment(paymentId);
    };

    // Get all split payments
    public func getAllSplitPayments(
        splitManager: SplitPaymentModule.PaymentSplitManager
    ): async [SplitPaymentModule.SplitPayment] {
        await splitManager.getAllSplitPayments();
    };

    // Get details of a specific split payment by ID
    public func getSplitPaymentDetails(
        splitManager: SplitPaymentModule.PaymentSplitManager,
        paymentId: Nat
    ): async Result.Result<SplitPaymentModule.SplitPayment, Text> {
        await splitManager.getSplitPaymentDetails(paymentId);
    };

    // List split payments filtered by status
    public func listSplitPaymentsByStatus(
        splitManager: SplitPaymentModule.PaymentSplitManager,
        status: Text
    ): async [SplitPaymentModule.SplitPayment] {
        await splitManager.listSplitPaymentsByStatus(status);
    };

    // Retry a failed split payment
    public func retrySplitPayment(
        splitManager: SplitPaymentModule.PaymentSplitManager,
        paymentId: Nat
    ): async Result.Result<(), Text> {
        await splitManager.retrySplitPayment(paymentId);
    };

    // Calculate the total distributed amount for a split payment
    public func calculateDistributedAmount(
        splitManager: SplitPaymentModule.PaymentSplitManager,
        paymentId: Nat
    ): async Result.Result<Nat, Text> {
        await splitManager.calculateDistributedAmount(paymentId);
    };

    // Validate the integrity of a split payment
    public func validateSplitPayment(
        splitManager: SplitPaymentModule.PaymentSplitManager,
        paymentId: Nat
    ): async Result.Result<(), Text> {
        await splitManager.validateSplitPayment(paymentId);
    };
};