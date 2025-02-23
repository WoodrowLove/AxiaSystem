import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import _Time "mo:base/Time";
import Result "mo:base/Result";
import _LoggingUtils "../utils/logging_utils";
import EventManager "../heartbeat/event_manager";
import EscrowManager "../escrow/modules/escrow_module";
import PayoutManager "../payout/modules/payout_module";
import SplitPaymentManager "../split_payment/modules/split_payment_module";
import PaymentManager "../payment/modules/payment_module";
import AdminModule "../admin/modules/admin_module";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import UserCanisterProxy "../user/utils/user_canister_proxy";
import TokenCanisterProxy "../token/utils/token_canister_proxy";

actor {
    // Dependencies
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(Principal.fromText("c2lt4-zmaaa-aaaaa-qaaiq-cai"));
    private let eventManager = EventManager.EventManager();
    private let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("c5kvi-uuaaa-aaaaa-qaaia-cai"));
    private let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("ahw5u-keaaa-aaaaa-qaaha-cai"));

    // Managers
    private let escrowManager = EscrowManager.EscrowManager(walletProxy, eventManager);
    private let payoutManager = PayoutManager.PayoutManager(walletProxy, eventManager);
    private let splitPaymentManager = SplitPaymentManager.PaymentSplitManager(walletProxy, eventManager);
    private let paymentManager = PaymentManager.PaymentManager(walletProxy, userProxy, tokenProxy);

    // AdminManager instance
    private let adminManager = AdminModule.AdminManager(
        eventManager,
        escrowManager,
        payoutManager,
        splitPaymentManager,
        paymentManager
    );

    // Public API
    public func getAllAdminActions(): async [AdminModule.AdminAction] {
        await adminManager.getAllAdminActions();
    };

    public func getAdminActionsByAdmin(admin: Principal): async [AdminModule.AdminAction] {
        await adminManager.getAdminActionsByAdmin(admin);
    };

    public func processEscrowTimeouts(admin: Principal): async Result.Result<Nat, Text> {
        await adminManager.processEscrowTimeouts(admin);
    };

    public func retryFailedSplitPayments(admin: Principal): async Result.Result<Nat, Text> {
        await adminManager.retryFailedSplitPayments(admin);
    };

    public func retryFailedPayouts(admin: Principal): async Result.Result<Nat, Text> {
        await adminManager.retryFailedPayouts(admin);
    };

    public func performSystemMaintenance(admin: Principal): async Result.Result<(), Text> {
        await adminManager.performSystemMaintenance(admin);
    };

    public func getFilteredAdminActions(
        admin: ?Principal,
        action: ?Text,
        since: ?Int
    ): async [AdminModule.AdminAction] {
        await adminManager.getFilteredAdminActions(admin, action, since);
    };
}