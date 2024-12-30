import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import EscrowModule "../modules/escrow_module";
import Error "mo:base/Error";

module {
    public type EscrowCanisterInterface = actor {
        createEscrow: (Principal, Principal, Nat, Nat, Text) -> async Result.Result<Nat, Text>;
        releaseEscrow: (Nat) -> async Result.Result<(), Text>;
        cancelEscrow: (Nat) -> async Result.Result<(), Text>;
        getEscrow: (Nat) -> async Result.Result<EscrowModule.EscrowState, Text>;
        listEscrows: () -> async [EscrowModule.EscrowState];
    };

    public class EscrowCanisterProxy(canisterId: Principal) {
        private let escrowCanister: EscrowCanisterInterface = actor(Principal.toText(canisterId));

        public func createEscrow(
            sender: Principal,
            receiver: Principal,
            tokenId: Nat,
            amount: Nat,
            conditions: Text
        ): async Result.Result<Nat, Text> {
            try {
                await escrowCanister.createEscrow(sender, receiver, tokenId, amount, conditions);
            } catch (e) {
                #err("Failed to create escrow: " # Error.message(e))
            }
        };

        public func releaseEscrow(escrowId: Nat): async Result.Result<(), Text> {
            try {
                await escrowCanister.releaseEscrow(escrowId);
            } catch (e) {
                #err("Failed to release escrow: " # Error.message(e))
            }
        };

        public func cancelEscrow(escrowId: Nat): async Result.Result<(), Text> {
            try {
                await escrowCanister.cancelEscrow(escrowId);
            } catch (e) {
                #err("Failed to cancel escrow: " # Error.message(e))
            }
        };

        public func getEscrow(escrowId: Nat): async Result.Result<EscrowModule.EscrowState, Text> {
            try {
                await escrowCanister.getEscrow(escrowId);
            } catch (e) {
                #err("Failed to get escrow details: " # Error.message(e))
            }
        };

        public func listEscrows(): async Result.Result<[EscrowModule.EscrowState], Text> {
            try {
                let escrows = await escrowCanister.listEscrows();
                #ok(escrows)
            } catch (e) {
                #err("Failed to list escrows: " # Error.message(e))
            }
        };
    };
};