import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Time "mo:base/Time";
import AdminModule "../../admin/modules/admin_module";
import LoggingUtils "../../utils/logging_utils";

module {
    public class AdminService(adminManager: AdminModule.AdminManager) {
        private let logStore = LoggingUtils.init();

       // Log an admin action
private func _logAdminAction(admin: Principal, action: Text, details: ?Text): async () {
    let adminAction: AdminModule.AdminAction = {
        id = Int.abs(Time.now()) : Nat;
        admin = admin;
        action = action;
        details = details;
        timestamp = Time.now();
    };

            // Fetch current actions and update (if update logic exists in AdminManager)
            var currentActions = await adminManager.getAllAdminActions();
            currentActions := Array.append(currentActions, [adminAction]);

            LoggingUtils.logInfo(
                logStore,
                "AdminService",
                "Admin action logged: " # action # " by " # Principal.toText(admin),
                ?admin
            );
        };

        // Verify if the admin has proper access
        public func verifyAdminAccess(admin: Principal): Result.Result<(), Text> {
            let allowedAdmins: [Principal] = [
                Principal.fromText("aaaaa-aa"), // Example authorized admin
                Principal.fromText("bbbbb-bb")
            ];

           if (Array.find<Principal>(allowedAdmins, func(a : Principal) : Bool { a == admin }) != null) {
    LoggingUtils.logInfo(
        logStore,
        "AdminService",
        "Admin access verified for: " # Principal.toText(admin),
        ?admin
    );
                return #ok(());
            } else {
                LoggingUtils.logError(
                    logStore,
                    "AdminService",
                    "Unauthorized access attempt by: " # Principal.toText(admin),
                    ?admin
                );
                return #err("Unauthorized admin.");
            };
        };

        // Retrieve all admin actions
        public func getAllAdminActions(): async [AdminModule.AdminAction] {
            LoggingUtils.logInfo(logStore, "AdminService", "Fetching all admin actions", null);
            await adminManager.getAllAdminActions();
        };

        // Retrieve actions filtered by a specific admin
        public func getAdminActionsByAdmin(admin: Principal): async [AdminModule.AdminAction] {
            LoggingUtils.logInfo(
                logStore,
                "AdminService",
                "Fetching actions for admin: " # Principal.toText(admin),
                ?admin
            );
            await adminManager.getAdminActionsByAdmin(admin);
        };

        // Retrieve filtered admin actions
        public func getFilteredAdminActions(
            admin: ?Principal,
            action: ?Text,
            since: ?Int
        ): async [AdminModule.AdminAction] {
            LoggingUtils.logInfo(logStore, "AdminService", "Fetching filtered admin actions", null);
            await adminManager.getFilteredAdminActions(admin, action, since);
        };
    };
};