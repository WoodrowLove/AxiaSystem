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
import SharedTypes "../shared_types";

actor {
    // Dependencies
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(
        Principal.fromText("cuj6u-c4aaa-aaaaa-qaajq-cai"), // Wallet Canister ID
        Principal.fromText("ctiya-peaaa-aaaaa-qaaja-cai")  // User Canister ID
    );
    private let eventManager = EventManager.EventManager();
    private let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("ctiya-peaaa-aaaaa-qaaja-cai"));
    private let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("c5kvi-uuaaa-aaaaa-qaaia-cai"));

    // Aegis canisters
    private let aegisCanister : actor {
  logSecureAdminAction : (Principal, Text, ?Text) -> async Bool;
  validateSecureCaller : (Principal) -> async Bool;
  logSecureAction : (Principal, Text, ?Text) -> async ();
  cloakPrincipal : (Principal) -> async Principal;
  cloakActionRecord : (record: SharedTypes.AdminAction) -> async SharedTypes.CloakedRecord;
  verifyActionIntegrity : (Nat) -> async Bool;
} = actor("uxrrr-q7777-77774-qaaaq-cai");
    

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
        paymentManager,
        aegisCanister
    );

    // ✅ **Public API - Create Admin**
    public func createAdmin(creator: Principal, newAdmin: Principal): async Result.Result<(), Text> {
        await adminManager.createAdmin(creator, newAdmin);
    };

    // ✅ **Public API - Remove Admin**
    public func removeAdmin(existingAdmin: Principal, targetAdmin: Principal): async Result.Result<(), Text> {
        await adminManager.removeAdmin(existingAdmin, targetAdmin);
    };

    // ✅ **Public API - Verify Admin**
    public func verifyAdmin(admin: Principal): async Result.Result<(), Text> {
        adminManager.verifyAdmin(admin);
    };

    // ✅ **Public API - Check Admin Status**
    public func isAdmin(admin: Principal): async Bool {
        adminManager.isAdmin(admin);
    };

    // ✅ **Public API - Log Admin Action** (Fixed)
public func logAdminAction(admin: Principal, action: Text, details: ?Text): async Result.Result<(), Text> {
    await adminManager.logAdminAction(admin, action, details);
    return #ok(());
};

    // ✅ **Public API - Retrieve All Admin Actions**
    public func getAllAdminActions(): async [AdminModule.AdminAction] {
        await adminManager.getAllAdminActions();
    };

    // ✅ **Public API - Retrieve Actions by Admin**
    public func getAdminActionsByAdmin(admin: Principal): async [AdminModule.AdminAction] {
        await adminManager.getAdminActionsByAdmin(admin);
    };

    // ✅ **Public API - Filtered Admin Actions**
    public func getFilteredAdminActions(
        admin: ?Principal,
        action: ?Text,
        since: ?Int
    ): async [AdminModule.AdminAction] {
        await adminManager.getFilteredAdminActions(admin, action, since);
    };

    // ✅ **Public API - Process Escrow Timeouts**
    public func processEscrowTimeouts(admin: Principal): async Result.Result<Nat, Text> {
        await adminManager.processEscrowTimeouts(admin);
    };

    // ✅ **Public API - Retry Failed Split Payments**
    public func retryFailedSplitPayments(admin: Principal): async Result.Result<Nat, Text> {
        await adminManager.retryFailedSplitPayments(admin);
    };

    // ✅ **Public API - Retry Failed Payouts**
    public func retryFailedPayouts(admin: Principal): async Result.Result<Nat, Text> {
        await adminManager.retryFailedPayouts(admin);
    };

    // ✅ **Public API - Perform System Maintenance**
    public func performSystemMaintenance(admin: Principal): async Result.Result<(), Text> {
        await adminManager.performSystemMaintenance(admin);
    };

    // ✅ **Public API - Multi-Signature Approval Check** (NEWLY ADDED)
    public func isMultiSigApprovalComplete(electionId: Nat): async Bool {
        await adminManager.isMultiSigApprovalComplete(electionId);
    };

    public func forceAddAdmin(newAdmin: Principal): async () {
    await adminManager.forceAddAdmin(newAdmin);
    };

    public func getAllAdmins(): async [Principal] {
    await adminManager.getAllAdmins();
    };

    public func enableMultiSigApproval(admin: Principal, electionId: Nat): async Result.Result<(), Text> {
    await adminManager.enableMultiSigApproval(admin, electionId);
    };

    public shared func getMultiSigApprovalDetails(electionId: Nat): async Result.Result<[AdminModule.AdminAction], Text> {
    await adminManager.getMultiSigApprovalDetails(electionId);
    };

};
