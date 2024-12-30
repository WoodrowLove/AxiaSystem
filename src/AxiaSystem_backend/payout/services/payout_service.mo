import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import PayoutModule "../modules/payout_module";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import EventManager "../../heartbeat/event_manager";

module {
    public func createPayoutService(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        eventManager: EventManager.EventManager
    ): PayoutModule.PayoutManager {
        PayoutModule.PayoutManager(walletProxy, eventManager)
    };

    // Initiate a new payout
    public func initiatePayout(
        payoutManager: PayoutModule.PayoutManager,
        recipients: [Principal],
        amounts: [Nat],
        description: ?Text
    ): async Result.Result<PayoutModule.Payout, Text> {
        await payoutManager.initiatePayout(recipients, amounts, description);
    };

    // Execute an existing payout by ID
    public func executePayout(
        payoutManager: PayoutModule.PayoutManager,
        payoutId: Nat
    ): async Result.Result<(), Text> {
        await payoutManager.executePayout(payoutId);
    };

    // Cancel a pending payout
    public func cancelPayout(
        payoutManager: PayoutModule.PayoutManager,
        payoutId: Nat
    ): async Result.Result<(), Text> {
        await payoutManager.cancelPayout(payoutId);
    };

    // Retrieve all payouts
    public func getAllPayouts(
        payoutManager: PayoutModule.PayoutManager
    ): [PayoutModule.Payout] {
         payoutManager.getAllPayouts();
    };

   // Retrieve payout details by ID
public func getPayoutDetails(
    payoutManager: PayoutModule.PayoutManager,
    payoutId: Nat
): Result.Result<PayoutModule.Payout, Text> {
    payoutManager.getPayoutDetails(payoutId)
};

    // Retrieve payouts filtered by status
    public func getPayoutsByStatus(
        payoutManager: PayoutModule.PayoutManager,
        status: Text
    ): async [PayoutModule.Payout] {
        await payoutManager.getPayoutsByStatus(status);
    };
};