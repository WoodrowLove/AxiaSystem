import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import EscrowModule "../modules/escrow_module";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import EventManager "../../heartbeat/event_manager";

module {
    public func createEscrowService(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        eventManager: EventManager.EventManager
    ): EscrowModule.EscrowManager {
        EscrowModule.EscrowManager(walletProxy, eventManager)
    };

    public func createEscrow(
        escrowManager: EscrowModule.EscrowManager,
        sender: Principal,
        receiver: Principal,
        tokenId: Nat,
        amount: Nat,
        conditions: Text
    ): async Result.Result<Nat, Text> {
        await escrowManager.createEscrow(sender, receiver, tokenId, amount, conditions);
    };

    public func releaseEscrow(
        escrowManager: EscrowModule.EscrowManager,
        escrowId: Nat
    ): async Result.Result<(), Text> {
        await escrowManager.releaseEscrow(escrowId);
    };

    public func cancelEscrow(
        escrowManager: EscrowModule.EscrowManager,
        escrowId: Nat
    ): async Result.Result<(), Text> {
        await escrowManager.cancelEscrow(escrowId);
    };

    public func getEscrow(
        escrowManager: EscrowModule.EscrowManager,
        escrowId: Nat
    ): async Result.Result<EscrowModule.EscrowState, Text> {
        await escrowManager.getEscrow(escrowId);
    };

    public func listEscrows(
        escrowManager: EscrowModule.EscrowManager
    ): async [EscrowModule.EscrowState] {
        await escrowManager.listEscrows();
    };
};