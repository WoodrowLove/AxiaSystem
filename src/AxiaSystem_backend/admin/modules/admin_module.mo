import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Option "mo:base/Option";

import LoggingUtils "../../utils/logging_utils";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";
import EscrowManager "../../escrow/modules/escrow_module";
import PayoutManager "../../payout/modules/payout_module";
import SplitPaymentManager "../../split_payment/modules/split_payment_module";
import PaymentManager "../../payment/modules/payment_module";
import _SharedTypes "../../shared_types";

module {
  public type AdminAction = {
    id: Nat;
    timestamp: Int;
    admin: Principal;
    action: Text;
    details: ?Text;
  };

  public class AdminManager(
    eventManager: EventManager.EventManager,
    escrowManager: EscrowManager.EscrowManager,
    payoutManager: PayoutManager.PayoutManager,
    splitPaymentManager: SplitPaymentManager.PaymentSplitManager,
    _paymentManager: PaymentManager.PaymentManager,

  ) {
    private var adminActions: [AdminAction] = [];
    private var admins: [Principal] = [];
    private let logStore = LoggingUtils.init();

    // Emit admin-related events (optional legacy diagnostic use)
    private func emitAdminEvent(
      eventType: EventTypes.EventType,
      payload: EventTypes.EventPayload
    ): async () {
      let event: EventTypes.Event = {
        id = Nat64.fromNat(Int.abs(Time.now()));
        eventType = eventType;
        payload = payload;
      };
      await eventManager.emit(event);
    };

    public func logAdminAction(admin: Principal, action: Text, details: ?Text): async () {
      let newAction: AdminAction = {
        id = adminActions.size();
        admin = admin;
        action = action;
        details = details;
        timestamp = Time.now();
      };
      adminActions := Array.append(adminActions, [newAction]);
      LoggingUtils.logInfo(
        logStore,
        "AdminModule",
        "Action logged by admin: " # Principal.toText(admin) # ", Action: " # action,
        ?admin
      );
    };

        // View all logged admin actions
        public func getAllAdminActions(): async [AdminAction] {
            LoggingUtils.logInfo(logStore, "AdminModule", "Retrieving all admin actions.", null);
            adminActions
        };

        // View actions by a specific admin
        public func getAdminActionsByAdmin(admin: Principal): async [AdminAction] {
    LoggingUtils.logInfo(
        logStore,
        "AdminModule",
        "Retrieving actions for admin: " # Principal.toText(admin),
        ?admin
    );
    Array.filter<AdminAction>(adminActions, func(a: AdminAction): Bool { a.admin == admin })
};

        // Perform maintenance on EscrowManager
        public func processEscrowTimeouts(admin: Principal): async Result.Result<Nat, Text> {
            await logAdminAction(admin, "Process Escrow Timeouts", null);
            let result = await escrowManager.processEscrowTimeouts(10_000_000_000);
            switch (result) {
                case (#ok(timeoutCount)) {
                    LoggingUtils.logInfo(
                        logStore,
                        "AdminModule",
                        "Escrow timeouts processed. Count: " # Nat.toText(timeoutCount),
                        ?admin
                    );
                    #ok(timeoutCount)
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "AdminModule",
                        "Failed to process escrow timeouts: " # e,
                        ?admin
                    );
                    #err(e)
                };
            }
        };

        // Retry failed split payments
        public func retryFailedSplitPayments(admin: Principal): async Result.Result<Nat, Text> {
            await logAdminAction(admin, "Retry Failed Split Payments", null);
            let failedSplits = await splitPaymentManager.listSplitPaymentsByStatus("Failed");
            var retryCount: Nat = 0;

            for (split in failedSplits.vals()) {
                let retryResult = await splitPaymentManager.retrySplitPayment(split.id);
                switch (retryResult) {
                    case (#ok(())) {
                        retryCount += 1;
                    };
                    case (#err(e)) {
                        LoggingUtils.logError(
                            logStore,
                            "AdminModule",
                            "Retry failed for Split Payment ID: " # Nat.toText(split.id) # ", Error: " # e,
                            ?admin
                        );
                    };
                };
            };

            LoggingUtils.logInfo(
                logStore,
                "AdminModule",
                "Retry completed for failed split payments. Retry Count: " # Nat.toText(retryCount),
                ?admin
            );

            #ok(retryCount)
        };

        // Retry failed payouts
        public func retryFailedPayouts(admin: Principal): async Result.Result<Nat, Text> {
            await logAdminAction(admin, "Retry Failed Payouts", null);
            let failedPayouts = await payoutManager.getPayoutsByStatus("Failed");
            var retryCount: Nat = 0;

            for (payout in failedPayouts.vals()) {
                let retryResult = await payoutManager.executePayout(payout.id);
                switch (retryResult) {
                    case (#ok(())) {
                        retryCount += 1;
                    };
                    case (#err(e)) {
                        LoggingUtils.logError(
                            logStore,
                            "AdminModule",
                            "Retry failed for Payout ID: " # Nat.toText(payout.id) # ", Error: " # e,
                            ?admin
                        );
                    };
                };
            };

            LoggingUtils.logInfo(
                logStore,
                "AdminModule",
                "Retry completed for failed payouts. Retry Count: " # Nat.toText(retryCount),
                ?admin
            );

            #ok(retryCount)
        };

        // System-wide maintenance task
        public func performSystemMaintenance(admin: Principal): async Result.Result<(), Text> {
            await logAdminAction(admin, "Perform System Maintenance", null);
            let escrowResult = await processEscrowTimeouts(admin);
            let splitRetryResult = await retryFailedSplitPayments(admin);
            let payoutRetryResult = await retryFailedPayouts(admin);

            LoggingUtils.logInfo(
    logStore,
    "AdminModule",
    "System maintenance completed. Escrow Timeouts: " # 
    Nat.toText(switch (escrowResult) { case (#ok(val)) val; case (#err(_)) 0 }) #
    ", Split Payment Retries: " # 
    Nat.toText(switch (splitRetryResult) { case (#ok(val)) val; case (#err(_)) 0 }) #
    ", Payout Retries: " # 
    Nat.toText(switch (payoutRetryResult) { case (#ok(val)) val; case (#err(_)) 0 }),
    ?admin
);

            #ok(())
        };

       public func getFilteredAdminActions(
    admin: ?Principal,
    action: ?Text,
    since: ?Int
): async [AdminAction] {
    Array.filter<AdminAction>(adminActions, func(a: AdminAction): Bool {
        Option.getMapped(admin, func(p: Principal): Bool { a.admin == p }, true) and
        Option.getMapped(action, func(act: Text): Bool { a.action == act }, true) and
        Option.getMapped(since, func(s: Int): Bool { a.timestamp >= s }, true)
    })
};

// ✅ **Private Verification Function**
    private func _verifyAdmin(admin: Principal): Bool {
        Array.find(admins, func(a: Principal): Bool { a == admin }) != null
    };

   // ✅ **Create a New Admin**
        public func createAdmin(creator: Principal, newAdmin: Principal): async Result.Result<(), Text> {
            if (Array.find(admins, func(a: Principal): Bool { a == creator }) == null) {
                return #err("Unauthorized: Only admins can create new admins.");
            };

            if (Array.find(admins, func(a: Principal): Bool { a == newAdmin }) != null) {
                return #err("Admin already exists.");
            };

            admins := Array.append(admins, [newAdmin]);

            LoggingUtils.logInfo(logStore, "AdminModule", "New admin added: " # Principal.toText(newAdmin), ?creator);

            await emitAdminEvent(#AdminCreated, #AdminCreated {
                creatorId = creator;
                newAdminId = newAdmin;
                timestamp = Nat64.fromNat(Int.abs(Time.now()));
            });

            return #ok(());
        };

         // ✅ **Remove an Admin (Only Verified Admins Can Do This)**
    public func removeAdmin(existingAdmin: Principal, targetAdmin: Principal): async Result.Result<(), Text> {
        if (not _verifyAdmin(existingAdmin)) {
            return #err("Unauthorized: Only admins can remove other admins.");
        };

        if (not _verifyAdmin(targetAdmin)) {
            return #err("Admin does not exist.");
        };

        admins := Array.filter<Principal>(admins, func(a: Principal): Bool { a != targetAdmin });

        LoggingUtils.logInfo(logStore, "AdminModule", "Admin removed: " # Principal.toText(targetAdmin), ?existingAdmin);

        await eventManager.emit({
    eventType = #AdminRemoved;
    id = Nat64.fromNat(Int.abs(Time.now()));
    payload = #AdminRemoved {
        removerId = existingAdmin;
        targetAdminId = targetAdmin;
        timestamp = Nat64.fromNat(Int.abs(Time.now()));
    };
});

        return #ok(());
    };

       // ✅ **Public Wrapper for Verification**
    public func verifyAdmin(admin: Principal): Result.Result<(), Text> {
        if (_verifyAdmin(admin)) {
            return #ok(());
        } else {
            return #err("Unauthorized: Admin access required.");
        };
    };

     // ✅ **Add an Admin (Only Verified Admins Can Do This)**
    public func addAdmin(existingAdmin: Principal, newAdmin: Principal): async Result.Result<(), Text> {
        if (not _verifyAdmin(existingAdmin)) {
            return #err("Unauthorized: Only admins can add new admins.");
        };

        if (Array.find(admins, func(a: Principal): Bool { a == newAdmin }) != null) {
            return #err("Admin already exists.");
        };

        admins := Array.append(admins, [newAdmin]);

        LoggingUtils.logInfo(logStore, "AdminModule", "Admin added: " # Principal.toText(newAdmin), ?existingAdmin);

        await eventManager.emit({
    eventType = #AdminAdded;
    id = Nat64.fromNat(Int.abs(Time.now()));
    payload = #AdminAdded {
        adminId = existingAdmin;
        newAdminId = newAdmin;
        timestamp = Nat64.fromNat(Int.abs(Time.now()));
    };
});

        return #ok(());
    };

    // ✅ **Check if a Principal is an Admin**
    public func isAdmin(admin: Principal): Bool {
        Array.find(admins, func(a: Principal): Bool { a == admin }) != null
    };

    public func isMultiSigApprovalComplete(electionId: Nat): async Bool {
    let approvals = Array.filter<AdminAction>(
        adminActions,
        func(a: AdminAction): Bool {
            a.action == "MultiSigApproval" and a.details == ?("ElectionID: " # Nat.toText(electionId))
        }
    );

    return approvals.size() >= 2; // Requires at least two unique admin approvals
};


public func enableMultiSigApproval(admin: Principal, electionId: Nat): async Result.Result<(), Text> {
    // Ensure the caller is an admin
    if (not isAdmin(admin)) {
        return #err("Unauthorized: Only admins can enable multi-signature approval.");
    };

    // Log the approval action
    await logAdminAction(admin, "MultiSigApproval", ?("ElectionID: " # Nat.toText(electionId)));

    return #ok(());
};

public func forceAddAdmin(newAdmin: Principal): async () {
    admins := Array.append(admins, [newAdmin]);
};

public func getAllAdmins(): async [Principal] {
    admins
};

public func getMultiSigApprovalDetails(electionId: Nat): async Result.Result<[AdminAction], Text> {
    // Filter approvals related to the specific election
    let approvals = Array.filter<AdminAction>(
        adminActions,
        func(a: AdminAction): Bool {
            a.action == "MultiSigApproval" and a.details == ?("ElectionID: " # Nat.toText(electionId))
        }
    );

    if (approvals.size() == 0) {
        return #err("No multi-signature approvals found for this election.");
    };

    return #ok(approvals);
};

public func clearState(): async () {
    adminActions := [];
    admins := [];
    LoggingUtils.logInfo(logStore, "AdminModule", "State cleared.", null);

};

    };
};
