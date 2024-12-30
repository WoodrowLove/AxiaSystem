import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import LoggingUtils "../../utils/logging_utils";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    public type Payout = {
        id: Nat;
        recipients: [Principal];
        amounts: [Nat];
        totalAmount: Nat;
        description: ?Text;
        status: Text; // "Pending", "Completed", "Failed"
        createdAt: Int;
    };

    public class PayoutManager(walletProxy: WalletCanisterProxy.WalletCanisterProxy, eventManager: EventManager.EventManager) {
        private var payouts: [Payout] = [];
        private let logStore = LoggingUtils.init();

        // Emit a payout-related event
        private func emitPayoutEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload): async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = eventType;
                payload = payload;
            };
            await eventManager.emit(event);
        };

        // Initiate a payout
        public func initiatePayout(
            recipients: [Principal],
            amounts: [Nat],
            description: ?Text
        ): async Result.Result<Payout, Text> {
            if (Array.size(recipients) != Array.size(amounts)) {
                return #err("Recipients and amounts arrays must have the same size.");
            };

            if (Array.size(recipients) == 0 or Array.size(amounts) == 0) {
    return #err("Recipients and amounts cannot be empty.");
};

            let totalAmount = Array.foldLeft<Nat, Nat>(
                amounts, 
                0, 
                func(acc, amount) { acc + amount }
            );

            let payout: Payout = {
    id = Int.abs(Time.now());
    recipients = recipients;
    amounts = amounts;
    totalAmount = totalAmount;
    description = description;
    status = "Pending";
    createdAt = Time.now();
};

            payouts := Array.append(payouts, [payout]);

            LoggingUtils.logInfo(
                logStore,
                "PayoutModule",
                "Payout initiated. ID: " # Nat.toText(payout.id) # ", Total Amount: " # Nat.toText(totalAmount),
                null
            );

            // Emit event for payout initiation
await emitPayoutEvent(#PayoutInitiated, #PayoutInitiated {
    payoutId = payout.id;
    totalAmount = totalAmount;
    recipients = recipients;
    description = payout.description;
    timestamp = Time.now();
});

            #ok(payout)
        };

        // Execute a payout
public func executePayout(payoutId: Nat): async Result.Result<(), Text> {
    let payoutOpt = Array.find<Payout>(payouts, func(p : Payout) { p.id == payoutId });
    switch (payoutOpt) {
        case null {
            return #err("Payout not found.");
        };
        case (?payout) {
            if (payout.status != "Pending") {
                return #err("Only pending payouts can be executed.");
            };

            for (index in Iter.range(0, Array.size(payout.recipients) - 1)) {
                let recipient = payout.recipients[index];
                let amount = payout.amounts[index];

                let creditResult = await walletProxy.creditWallet(recipient, amount, 0);
                switch (creditResult) {
                    case (#err(e)) {
                        LoggingUtils.logError(
                            logStore,
                            "PayoutModule",
                            "Failed to credit recipient. Recipient: " # Principal.toText(recipient) # ", Error: " # e,
                            ?recipient
                        );

                        // Update payout to failed
                        payouts := Array.map<Payout, Payout>(payouts, func(p : Payout) {
                            if (p.id == payoutId) { { p with status = "Failed" } } else p
                        });

                        return #err("Payout failed for recipient: " # Principal.toText(recipient));
                    };
                    case (#ok(_)) {};
                };
            };

            // Update payout to completed
            payouts := Array.map<Payout, Payout>(payouts, func(p : Payout) {
                if (p.id == payoutId) { { p with status = "Completed" } } else p
            });

            LoggingUtils.logInfo(
                logStore,
                "PayoutModule",
                "Payout executed successfully. ID: " # Nat.toText(payoutId),
                null
            );

            // Emit event for payout completion
            // Emit event for payout completion
await emitPayoutEvent(#PayoutExecuted, #PayoutExecuted {
    payoutId = payoutId;
    totalAmount = payout.totalAmount;
    recipients = Array.mapEntries<Principal, (Principal, Nat)>(
        payout.recipients,
        func(recipient: Principal, i: Nat) : (Principal, Nat) { (recipient, payout.amounts[i]) }
    );
    executionTime = Time.now();
});

            #ok(())
        };
    };
};

        // Get all payouts
        public func getAllPayouts(): [Payout] {
            LoggingUtils.logInfo(
                logStore,
                "PayoutModule",
                "Retrieving all payouts.",
                null
            );

            payouts
        };

  // Get payout details by ID
public func getPayoutDetails(payoutId: Nat): Result.Result<Payout, Text> {
    let payoutOpt = Array.find<Payout>(payouts, func(p : Payout) { p.id == payoutId });

    switch (payoutOpt) {
        case null {
            #err("Payout not found.")
        };
        case (?payout) {
            #ok(payout)
        };
    }
};

        // Cancel a pending payout
public func cancelPayout(payoutId: Nat): async Result.Result<(), Text> {
    let payoutOpt = Array.find<Payout>(payouts, func(p : Payout) { p.id == payoutId });

            switch (payoutOpt) {
                case null {
                    return #err("Payout not found.");
                };
                case (?payout) {
                    if (payout.status != "Pending") {
                        return #err("Only pending payouts can be cancelled.");
                    };

                    payouts := Array.map<Payout, Payout>(payouts, func(p : Payout) {
    if (p.id == payoutId) { { p with status = "Cancelled" } } else p
});

                    LoggingUtils.logInfo(
                        logStore,
                        "PayoutModule",
                        "Payout cancelled successfully. ID: " # Nat.toText(payoutId),
                        null
                    );

                    // Emit event for payout cancellation
await emitPayoutEvent(#PayoutCancelled, #PayoutCancelled {
    payoutId = payoutId;
    status = "Cancelled";
    cancellationTime = Time.now();
});

                    #ok(())
                };
            };
        };

        // Get payouts filtered by status
public func getPayoutsByStatus(status: Text): async [Payout] {
    LoggingUtils.logInfo(
        logStore,
        "PayoutModule",
        "Retrieving payouts with status: " # status,
        null
    );

    Array.filter(payouts, func(p: Payout): Bool { p.status == status })
};
    };
};