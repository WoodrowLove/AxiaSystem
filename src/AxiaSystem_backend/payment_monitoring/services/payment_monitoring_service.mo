import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import PaymentMonitoringModule "../modules/payment_monitoring_module";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import PaymentCanisterProxy "../../payment/utils/payment_canister_proxy";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";
import EventManager "../../heartbeat/event_manager";
import _SharedTypes "../../shared_types";

module {
    public func createPaymentMonitoringService(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        paymentProxy: PaymentCanisterProxy.PaymentCanisterProxy,
        tokenProxy: TokenCanisterProxy.TokenCanisterProxy,
        eventManager: EventManager.EventManager,
        subscriptionManagerPrincipal: Principal
    ): PaymentMonitoringModule.PaymentMonitoringManager {
        PaymentMonitoringModule.PaymentMonitoringManager(
            walletProxy,
            paymentProxy,
            tokenProxy,
            eventManager,
            subscriptionManagerPrincipal
        )
    };

    public func monitorPayment(
        paymentMonitoringManager: PaymentMonitoringModule.PaymentMonitoringManager,
        caller: Principal,
        paymentId: Nat
    ): async Result.Result<Text, Text> {
        await paymentMonitoringManager.monitorPayment(caller, paymentId);
    };

    public func monitorPendingPayments(
        paymentMonitoringManager: PaymentMonitoringModule.PaymentMonitoringManager
    ): async Result.Result<Nat, Text> {
        await paymentMonitoringManager.monitorPendingPayments();
    };

    public func validateWalletBalance(
        paymentMonitoringManager: PaymentMonitoringModule.PaymentMonitoringManager,
        userId: Principal,
        tokenId: Nat,
        amount: Nat
    ): async Result.Result<Bool, Text> {
        await paymentMonitoringManager.validateWalletBalance(userId, tokenId, amount);
    };

    public func reconcilePayments(
        paymentMonitoringManager: PaymentMonitoringModule.PaymentMonitoringManager,
        caller: Principal
    ): async Result.Result<Nat, Text> {
        await paymentMonitoringManager.reconcilePayments(caller);
    };

    public func subscribeToPayments(
        paymentMonitoringManager: PaymentMonitoringModule.PaymentMonitoringManager,
        userId: Principal
    ): async Result.Result<Nat, Text> {
        await paymentMonitoringManager.subscribeToPayments(userId);
    };

    public func unsubscribeFromPayments(
        paymentMonitoringManager: PaymentMonitoringModule.PaymentMonitoringManager,
        subscriptionId: Nat
    ): async Result.Result<(), Text> {
        await paymentMonitoringManager.unsubscribeFromPayments(subscriptionId);
    };

    public func broadcastPaymentUpdate(
        paymentMonitoringManager: PaymentMonitoringModule.PaymentMonitoringManager,
        paymentId: Nat,
        status: Text
    ): async Result.Result<(), Text> {
        await paymentMonitoringManager.broadcastPaymentUpdate(paymentId, status);
    };

    public func listSubscriptions(
        paymentMonitoringManager: PaymentMonitoringModule.PaymentMonitoringManager
    ): async [(Nat, Principal)] {
        await paymentMonitoringManager.listSubscriptions();
    };
};