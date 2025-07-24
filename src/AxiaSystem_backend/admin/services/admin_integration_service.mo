import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Error "mo:base/Error";

// Import existing admin functionality
import AdminModule "../modules/admin_module";

// Import canister proxies (using existing ones from admin/main.mo)
import UserCanisterProxy "../../user/utils/user_canister_proxy";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";

// Import data types
import _UserModule "../../user/modules/user_module";
import _WalletModule "../../wallet/modules/wallet_module";
import IdentityModule "../../identity/modules/identity_module";
import ProjectRegistryModule "../../modules/project_registry";
import AxiaState "../../state/axia_state";

// Import event system
import EventManager "../../heartbeat/event_manager";
import _EventTypes "../../heartbeat/event_types";

module {
    // Admin Dashboard API Response Types
    public type DashboardStats = {
        totalUsers: Nat;
        totalProjects: Nat;
        totalAdminActions: Nat;
        totalAdmins: Nat;
        recentSystemMaintenance: ?Int;
        systemHealth: SystemHealthStatus;
        lastUpdated: Int;
    };

    public type SystemHealthStatus = {
        overall: Text; // "Healthy", "Warning", "Critical"
        userSystem: Bool;
        walletSystem: Bool;
        paymentSystem: Bool;
        adminSystem: Bool;
        details: [Text];
    };

    public type UserActivitySummary = {
        userId: Principal;
        username: ?Text;
        email: ?Text;
        isActive: Bool;
        hasIdentity: Bool;
        hasWallet: Bool;
        walletBalance: Nat;
        lastActivity: Int;
        registeredProjects: [Text];
        adminNotes: [AdminModule.AdminAction]; // Any admin actions related to this user
    };

    public type ProjectDetails = {
        project: AxiaState.Project;
        ownerSummary: UserActivitySummary;
        adminOversight: [AdminModule.AdminAction]; // Admin actions related to this project
        healthStatus: Text;
    };

    public type AdminActivityDashboard = {
        totalActions: Nat;
        recentActions: [AdminModule.AdminAction];
        adminBreakdown: [(Principal, Nat)]; // Admin Principal -> Action Count
        commonActions: [Text];
        systemMaintenanceHistory: [AdminModule.AdminAction];
    };

    public type IdentityInsights = {
        totalIdentities: Nat;
        recentIdentities: [IdentityModule.Identity];
        identitiesWithProjects: Nat;
        orphanedIdentities: Nat; // Identities without user accounts
        crossAppUsage: [(Text, Nat)]; // Project ID -> Identity Count
    };

    // Admin Integration Service Class that builds on existing AdminManager
    public class AdminIntegrationService(
        adminManager: AdminModule.AdminManager,
        userProxy: UserCanisterProxy.UserCanisterProxy,
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        _tokenProxy: TokenCanisterProxy.TokenCanisterProxy,
        projectRegistry: ProjectRegistryModule.ProjectRegistry,
        _eventManager: EventManager.EventManager
    ) {

        // Get comprehensive dashboard statistics
        public func getDashboardStats(requestingAdmin: Principal): async Result.Result<DashboardStats, Text> {
            // Verify admin access
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    let totalUsers = await getUserCount();
                    let totalProjects = await getProjectCount();
                    let adminActions = await adminManager.getAllAdminActions();
                    let allAdmins = await adminManager.getAllAdmins();
                    let lastMaintenance = getLastMaintenanceTimestamp(adminActions);
                    let systemHealth = await getSystemHealthStatus();

                    let stats: DashboardStats = {
                        totalUsers = totalUsers;
                        totalProjects = totalProjects;
                        totalAdminActions = adminActions.size();
                        totalAdmins = allAdmins.size();
                        recentSystemMaintenance = lastMaintenance;
                        systemHealth = systemHealth;
                        lastUpdated = Time.now();
                    };

                    // Log admin access
                    await adminManager.logAdminAction(requestingAdmin, "View Dashboard Stats", null);
                    
                    #ok(stats)
                };
            }
        };

        // Get detailed user activity with admin oversight context
        public func getUserActivitySummary(requestingAdmin: Principal, userId: Principal): async Result.Result<UserActivitySummary, Text> {
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    try {
                        let userResult = await userProxy.getUserById(userId);
                        let user = switch (userResult) {
                            case (#ok(u)) u;
                            case (#err(e)) return #err("User not found: " # e);
                        };

                        let hasWallet = await checkUserHasWallet(userId);
                        let walletBalance = await getUserWalletBalance(userId);
                        let projects = projectRegistry.getProjectsByCaller(userId);
                        let projectIds = Array.map<AxiaState.Project, Text>(projects, func(p) { p.id });
                        
                        // Get admin actions related to this user
                        let allActions = await adminManager.getAllAdminActions();
                        let userAdminNotes = Array.filter<AdminModule.AdminAction>(allActions, func(action) {
                            switch (action.details) {
                                case (?details) Text.contains(details, #text(Principal.toText(userId)));
                                case null false;
                            }
                        });

                        let summary: UserActivitySummary = {
                            userId = userId;
                            username = ?user.username;
                            email = ?user.email;
                            isActive = user.isActive;
                            hasIdentity = true; // User creation automatically creates identity
                            hasWallet = hasWallet;
                            walletBalance = walletBalance;
                            lastActivity = user.updatedAt;
                            registeredProjects = projectIds;
                            adminNotes = userAdminNotes;
                        };

                        // Log admin access
                        await adminManager.logAdminAction(requestingAdmin, "View User Activity", ?("User: " # Principal.toText(userId)));

                        #ok(summary)
                    } catch (e) {
                        #err("Failed to get user activity: " # Error.message(e))
                    }
                };
            }
        };

        // Get detailed project information with admin oversight
        public func getProjectDetails(requestingAdmin: Principal, _projectId: Text): async Result.Result<ProjectDetails, Text> {
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    // Note: getProjectById is not available, we need owner context
                    // For admin access, we'll need a different approach
                    return #err("Project access requires owner context - admin-level project access needs to be implemented in project registry");
                };
            }
        };

        // Get comprehensive admin activity insights
        public func getAdminActivityDashboard(requestingAdmin: Principal): async Result.Result<AdminActivityDashboard, Text> {
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    let allActions = await adminManager.getAllAdminActions();
                    let recentActions = Array.take<AdminModule.AdminAction>(
                        Array.sort<AdminModule.AdminAction>(allActions, func(a, b) { 
                            Int.compare(b.timestamp, a.timestamp) 
                        }), 20
                    );

                    // Create admin breakdown
                    let allAdmins = await adminManager.getAllAdmins();
                    let adminBreakdown = Array.map<Principal, (Principal, Nat)>(allAdmins, func(admin) {
                        let adminActions = Array.filter<AdminModule.AdminAction>(allActions, func(action) {
                            action.admin == admin
                        });
                        (admin, adminActions.size())
                    });

                    // Get common actions
                    let commonActions = getCommonActions(allActions);

                    // Get maintenance history
                    let maintenanceActions = Array.filter<AdminModule.AdminAction>(allActions, func(action) {
                        action.action == "Perform System Maintenance" or
                        action.action == "Process Escrow Timeouts" or
                        action.action == "Retry Failed Split Payments" or
                        action.action == "Retry Failed Payouts"
                    });

                    let dashboard: AdminActivityDashboard = {
                        totalActions = allActions.size();
                        recentActions = recentActions;
                        adminBreakdown = adminBreakdown;
                        commonActions = commonActions;
                        systemMaintenanceHistory = maintenanceActions;
                    };

                    // Log admin access
                    await adminManager.logAdminAction(requestingAdmin, "View Admin Dashboard", null);

                    #ok(dashboard)
                };
            }
        };

        // System maintenance operations (delegates to existing AdminManager)
        public func performSystemMaintenance(requestingAdmin: Principal): async Result.Result<(), Text> {
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    await adminManager.performSystemMaintenance(requestingAdmin)
                };
            }
        };

        public func processEscrowTimeouts(requestingAdmin: Principal): async Result.Result<Nat, Text> {
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    await adminManager.processEscrowTimeouts(requestingAdmin)
                };
            }
        };

        public func retryFailedSplitPayments(requestingAdmin: Principal): async Result.Result<Nat, Text> {
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    await adminManager.retryFailedSplitPayments(requestingAdmin)
                };
            }
        };

        public func retryFailedPayouts(requestingAdmin: Principal): async Result.Result<Nat, Text> {
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    await adminManager.retryFailedPayouts(requestingAdmin)
                };
            }
        };

        // Emergency user management (Note: Direct deactivation not available via proxy)
        public func emergencyUserSuspension(requestingAdmin: Principal, userId: Principal, reason: Text): async Result.Result<(), Text> {
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    // Log the action - actual suspension would need to be implemented differently
                    await adminManager.logAdminAction(requestingAdmin, "Emergency User Suspension Request", ?("User: " # Principal.toText(userId) # ", Reason: " # reason));
                    #ok(())
                };
            }
        };

        public func reactivateUser(requestingAdmin: Principal, userId: Principal, reason: Text): async Result.Result<(), Text> {
            switch (adminManager.verifyAdmin(requestingAdmin)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {
                    // Log the action - actual reactivation would need to be implemented differently
                    await adminManager.logAdminAction(requestingAdmin, "User Reactivation Request", ?("User: " # Principal.toText(userId) # ", Reason: " # reason));
                    #ok(())
                };
            }
        };

        // Helper functions (private)
        private func getUserCount(): async Nat {
            // User count would need to be implemented differently
            // Since listAllUsers is not available via proxy
            0 // Placeholder - would need admin-level user access
        };

        private func getProjectCount(): async Nat {
            // This would count all projects across all users
            // For now, we'll return 0 as placeholder
            0
        };

        private func getLastMaintenanceTimestamp(actions: [AdminModule.AdminAction]): ?Int {
            let maintenanceActions = Array.filter<AdminModule.AdminAction>(actions, func(action) {
                action.action == "Perform System Maintenance"
            });
            
            if (maintenanceActions.size() > 0) {
                let sorted = Array.sort<AdminModule.AdminAction>(maintenanceActions, func(a, b) {
                    Int.compare(b.timestamp, a.timestamp)
                });
                ?sorted[0].timestamp
            } else {
                null
            }
        };

        private func getSystemHealthStatus(): async SystemHealthStatus {
            // Check various system components
            let userHealth = await checkUserSystemHealth();
            let walletHealth = await checkWalletSystemHealth();
            let paymentHealth = true; // Placeholder
            let adminHealth = true; // Admin system is always healthy if we can call this

            let details: [Text] = [];
            var overall = "Healthy";

            if (not userHealth) {
                overall := "Warning";
            };
            if (not walletHealth) {
                overall := "Critical";
            };

            {
                overall = overall;
                userSystem = userHealth;
                walletSystem = walletHealth;
                paymentSystem = paymentHealth;
                adminSystem = adminHealth;
                details = details;
            }
        };

        private func checkUserSystemHealth(): async Bool {
            try {
                // Try to get a user by ID to test system health
                let _ = await userProxy.getUserById(Principal.fromText("2vxsx-fae"));
                true // If no exception, system is responsive
            } catch (_) { 
                false // System not responsive
            }
        };

        private func checkWalletSystemHealth(): async Bool {
            // This would need implementation once we know wallet health check methods
            true // Placeholder
        };

        private func checkUserHasWallet(userId: Principal): async Bool {
            try {
                let result = await walletProxy.getWalletByOwner(userId);
                switch (result) {
                    case (#ok(_)) true;
                    case (#err(_)) false;
                }
            } catch (_) { false }
        };

        private func getUserWalletBalance(userId: Principal): async Nat {
            try {
                let result = await walletProxy.getWalletBalance(userId);
                switch (result) {
                    case (#ok(balance)) balance;
                    case (#err(_)) 0;
                }
            } catch (_) { 0 }
        };

        private func getCommonActions(actions: [AdminModule.AdminAction]): [Text] {
            // Count action types and return most common ones
            // This is a simplified implementation
            let uniqueActions = Array.map<AdminModule.AdminAction, Text>(actions, func(action) { action.action });
            Array.take<Text>(uniqueActions, 5) // Return first 5 unique actions as placeholder
        };
    };
};
