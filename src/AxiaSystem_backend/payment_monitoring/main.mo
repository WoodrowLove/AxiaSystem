import Principal "mo:base/Principal";
import Result "mo:base/Result";
import PaymentMonitoringService "./services/payment_monitoring_service";
import _PaymentMonitoringModule "./modules/payment_monitoring_module";
import _PaymentMonitoringProxy "./utils/payment_monitoring_proxy";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import PaymentCanisterProxy "../payment/utils/payment_canister_proxy";
import TokenCanisterProxy "../token/utils/token_canister_proxy";
import EventManager "../heartbeat/event_manager";

actor {
    // Instantiate proxies and dependencies
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(Principal.fromText("c2lt4-zmaaa-aaaaa-qaaiq-cai"));
    private let paymentProxy = PaymentCanisterProxy.PaymentCanisterProxy(Principal.fromText("asrmz-lmaaa-aaaaa-qaaeq-cai"));
    private let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("ahw5u-keaaa-aaaaa-qaaha-cai"));
    private let eventManager = EventManager.EventManager();
    private let subscriptionManagerPrincipal = (Principal.fromText("aovwi-4maaa-aaaaa-qaagq-cai"));

    // Initialize the Payment Monitoring Manager
    private let paymentMonitoringManager = PaymentMonitoringService.createPaymentMonitoringService(
        walletProxy,
        paymentProxy,
        tokenProxy,
        eventManager,
        subscriptionManagerPrincipal
    );

    // Expose public APIs
    public shared func monitorPayment(caller: Principal, paymentId: Nat): async Result.Result<Text, Text> {
        await PaymentMonitoringService.monitorPayment(paymentMonitoringManager, caller, paymentId);
    };

    public shared func monitorPendingPayments(): async Result.Result<Nat, Text> {
        await PaymentMonitoringService.monitorPendingPayments(paymentMonitoringManager);
    };

    public shared func validateWalletBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<Bool, Text> {
        await PaymentMonitoringService.validateWalletBalance(paymentMonitoringManager, userId, tokenId, amount);
    };

    public shared func reconcilePayments(caller: Principal): async Result.Result<Nat, Text> {
        await PaymentMonitoringService.reconcilePayments(paymentMonitoringManager, caller);
    };

    public shared func subscribeToPayments(userId: Principal): async Result.Result<Nat, Text> {
        await PaymentMonitoringService.subscribeToPayments(paymentMonitoringManager, userId);
    };

    public shared func unsubscribeFromPayments(userId: Principal): async Result.Result<(), Text> {
    await PaymentMonitoringService.unsubscribeFromPayments(paymentMonitoringManager, userId);
};

    public shared func broadcastPaymentUpdate(paymentId: Nat, status: Text): async Result.Result<(), Text> {
        await PaymentMonitoringService.broadcastPaymentUpdate(paymentMonitoringManager, paymentId, status);
    };

    public shared func listSubscriptions(): async [(Nat, Principal)] {
        await PaymentMonitoringService.listSubscriptions(paymentMonitoringManager);
    };
};