import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Int "mo:base/Int";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";

module {
    public type EscrowState = {
        id: Nat;
        sender: Principal;
        receiver: Principal;
        tokenId: Nat;
        amount: Nat;
        conditions: Text;
        isReleased: Bool;
        isCanceled: Bool;
        createdAt: Nat;
    };

    public type EscrowId = Nat;

    public class EscrowManager(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        eventManager: EventManager.EventManager
    ) {
        private var escrows: [EscrowState] = [];

        // Emit an escrow-related event
        private func emitEscrowEvent(
            eventType: EventTypes.EventType,
            payload: EventTypes.EventPayload
        ): async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = eventType;
                payload = payload;
            };
            await eventManager.emit(event);
        };

        // Create a new escrow
        public func createEscrow(
    sender: Principal,
    receiver: Principal,
    tokenId: Nat,
    amount: Nat,
    conditions: Text
): async Result.Result<EscrowId, Text> {
    // Verify sender balance
    let senderBalance = await walletProxy.getWalletBalance(sender);
    switch (senderBalance) {
        case (#err(e)) return #err("Failed to validate sender balance: " # e);
        case (#ok(balance)) {
            if (balance < amount) {
                return #err("Insufficient balance to create escrow.");
            };
        };
    };

    // Deduct funds from the sender's wallet
    let debitResult = await walletProxy.debitWallet(sender, amount, tokenId);
    switch (debitResult) {
        case (#err(e)) return #err("Failed to deduct funds: " # e);
        case (#ok(_)) {};
    };

    // Create an escrow record
let currentTime = Time.now();
let escrowId = Int.abs(currentTime);
let escrow: EscrowState = {
    id = escrowId;
    sender = sender;
    receiver = receiver;
    tokenId = tokenId;
    amount = amount;
    conditions = conditions;
    isReleased = false;
    isCanceled = false;
    createdAt = Int.abs(currentTime);
};
    escrows := Array.append(escrows, [escrow]);

    // Emit escrow created event
await emitEscrowEvent(
    #EscrowCreated,
    #EscrowCreated {
        escrowId = escrowId;
        sender = sender;
        receiver = receiver;
        tokenId = tokenId;
        amount = amount
    }
);
    #ok(escrowId)
};

       public func releaseEscrow(escrowId: EscrowId): async Result.Result<(), Text> {
    let escrowOpt = Array.find(escrows, func(e: EscrowState): Bool { e.id == escrowId });
    switch (escrowOpt) {
        case null return #err("Escrow not found.");
        case (?escrow) {
            if (escrow.isReleased or escrow.isCanceled) {
                return #err("Escrow already finalized.");
            };

            // Add funds to the receiver's wallet
            let creditResult = await walletProxy.creditWallet(escrow.receiver, escrow.amount, escrow.tokenId);
            switch (creditResult) {
                case (#err(e)) return #err("Failed to credit funds: " # e);
                case (#ok(_)) {};
            };

            // Update escrow state
            escrows := Array.map<EscrowState, EscrowState>(
                escrows, 
                func(e: EscrowState): EscrowState {
                    if (e.id == escrowId) { { e with isReleased = true } } else e
                }
            );

            // Emit escrow released event
            await emitEscrowEvent(
                #EscrowReleased,
                #EscrowReleased {
                    escrowId = Nat.toText(escrowId);
                    sender = Principal.toText(escrow.sender);
                    receiver = Principal.toText(escrow.receiver);
                    amount = escrow.amount;
                    tokenId = escrow.tokenId;
                }
            );

            #ok(())
        };
    };
};

        public func cancelEscrow(escrowId: EscrowId): async Result.Result<(), Text> {
    let escrowOpt = Array.find<EscrowState>(escrows, func(e: EscrowState): Bool { e.id == escrowId });
    switch (escrowOpt) {
        case null return #err("Escrow not found.");
        case (?escrow) {
            if (escrow.isReleased or escrow.isCanceled) {
                return #err("Escrow already finalized.");
            };

            // Refund funds to the sender's wallet
            let refundResult = await walletProxy.creditWallet(escrow.sender, escrow.amount, escrow.tokenId);
            switch (refundResult) {
                case (#err(e)) return #err("Failed to refund funds: " # e);
                case (#ok(_)) {};
            };

            // Update escrow state
            escrows := Array.map<EscrowState, EscrowState>(
                escrows, 
                func(e: EscrowState): EscrowState {
                    if (e.id == escrowId) { { e with isCanceled = true } } else e
                }
            );

            // Emit escrow canceled event
            await emitEscrowEvent(
                #EscrowCanceled,
                #EscrowCanceled {
                    escrowId = Nat.toText(escrowId);
                    sender = Principal.toText(escrow.sender);
                    amount = escrow.amount;
                    tokenId = escrow.tokenId;
                }
            );

            #ok(())
        };
    };
};

        public func getEscrow(escrowId: EscrowId): async Result.Result<EscrowState, Text> {
    let escrowOpt = Array.find<EscrowState>(escrows, func(e: EscrowState): Bool { e.id == escrowId });
    switch (escrowOpt) {
        case null #err("Escrow not found.");
        case (?escrow) #ok(escrow);
    };
};

        // List all escrows
        public func listEscrows(): async [EscrowState] {
            escrows
        };
    };
};