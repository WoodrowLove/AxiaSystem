import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import EventManager "../heartbeat/event_manager";
import EscrowModule "./modules/escrow_module";
import EscrowService "./services/escrow_service";

actor {
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(
    Principal.fromText("c2lt4-zmaaa-aaaaa-qaaiq-cai"), // Wallet Canister ID
    Principal.fromText("c5kvi-uuaaa-aaaaa-qaaia-cai")  // User Canister ID
);
    private let eventManager = EventManager.EventManager();

    // Initialize the Escrow Service
    private let escrowService = EscrowService.createEscrowService(walletProxy, eventManager);

    // API: Create a new escrow
    public shared func createEscrow(
        sender: Principal,
        receiver: Principal,
        tokenId: Nat,
        amount: Nat,
        conditions: Text
    ): async Result.Result<Nat, Text> {
        await escrowService.createEscrow(sender, receiver, tokenId, amount, conditions);
    };

    // API: Release an escrow
    public shared func releaseEscrow(escrowId: Nat): async Result.Result<(), Text> {
        await escrowService.releaseEscrow(escrowId);
    };

    // API: Cancel an escrow
    public shared func cancelEscrow(escrowId: Nat): async Result.Result<(), Text> {
        await escrowService.cancelEscrow(escrowId);
    };

    // API: Get details of a specific escrow
    public shared func getEscrow(escrowId: Nat): async Result.Result<EscrowModule.EscrowState, Text> {
        try {
            await escrowService.getEscrow(escrowId);
        } catch (e) {
            #err("Failed to get escrow details: " # Error.message(e))
        }
    };

    // API: List all escrows
    public shared func listEscrows(): async [EscrowModule.EscrowState] {
        await escrowService.listEscrows();
    };

    // System Health Check
    public shared func healthCheck(): async Text {
        try {
            let allEscrows = await escrowService.listEscrows();
            if (allEscrows.size() > 0) {
                "Escrow service is operational. Total escrows: " # Nat.toText(allEscrows.size())
            } else {
                "Escrow service is operational. No escrows found."
            }
        } catch (e) {
            "Escrow health check failed: " # Error.message(e);
        }
    };

    // Heartbeat Integration (Optional)
    public shared func runHeartbeat(): async () {
        Debug.print("Escrow canister heartbeat executed.");
        // Example: Clean up stale or inactive escrows (optional implementation)
    };
};