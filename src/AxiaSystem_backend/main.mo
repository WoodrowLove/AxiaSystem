import TokenCanisterProxy "./token/utils/token_canister_proxy";
import UserCanisterProxy "./user/utils/user_canister_proxy";
import WalletCanisterProxy "./wallet/utils/wallet_canister_proxy";
import PaymentCanisterProxy "./payment/utils/payment_canister_proxy";
import SubscriptionCanisterProxy "./subscriptions/utils/subscription_canister_proxy";
import PaymentMonitoringProxy "payment_monitoring/utils/payment_monitoring_proxy";
import EscrowCanisterProxy "./escrow/utils/escrow_canister_proxy";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import _List "mo:base/List";
import Int "mo:base/Int";
import EventManager "./heartbeat/event_manager";
import EventTypes "./heartbeat/event_types";
import _Time "mo:base/Time";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Trie "mo:base/Trie";
import Bool "mo:base/Bool";
import _EscrowService "escrow/services/escrow_service";
import EscrowModule "escrow/modules/escrow_module";
import SplitPaymentProxy "./split_payment/utils/split_payment_proxy";
import PayoutProxy "./payout/utils/payout_proxy";
import PayoutModule "./payout/modules/payout_module";
import PayoutService "./payout/services/payout_service";
import AssetRegistryProxy "./asset_registry/utils/asset_registry_proxy";
import AssetRegistryService "./asset_registry/services/asset_registry_service";
import AssetRegistryModule "./asset_registry/modules/asset_registry_module";
import AssetProxy "asset/utils/asset_proxy";
import IdentityModule "./identity/modules/identity_module";
import GovernanceModule "./governance/modules/governance_module";
import GovernanceProxy "./governance/utils/governance_proxy";
import GovernanceService "./governance/services/governance_service";
import UserModule "user/modules/user_module";
import UserService "user/service/user_service";



actor AxiaSystem_backend {
    // Initialize proxies for all canisters
    private let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("ajuq4-ruaaa-aaaaa-qaaga-cai"));
    private let _userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("aovwi-4maaa-aaaaa-qaagq-cai"));
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(Principal.fromText("ahw5u-keaaa-aaaaa-qaaha-cai"));
    private let _paymentProxy = PaymentCanisterProxy.PaymentCanisterProxy(Principal.fromText("by6od-j4aaa-aaaaa-qaadq-cai"));
    private let paymentMonitoringProxy = PaymentMonitoringProxy.PaymentMonitoringProxy(Principal.fromText("avqkn-guaaa-aaaaa-qaaea-cai"));
    private var localSubscriptions: [(Principal, SubscriptionCanisterProxy.Subscription)] = [];
    private let escrowCanisterProxy = EscrowCanisterProxy.EscrowCanisterProxy(Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai"));
    // Initialize proxies for all canisters
    private let splitPaymentProxy = SplitPaymentProxy.SplitPaymentProxy(Principal.fromText("a3shf-5eaaa-aaaaa-qaafa-cai"));
    // Initialize event manager for the heartbeat
    private let eventManager = EventManager.EventManager();
    // Initialize Payout Proxy
    private let _payoutProxy = PayoutProxy.PayoutProxy(Principal.fromText("asrmz-lmaaa-aaaaa-qaaeq-cai"));
    // Initialize Payout Manager and Service
    private let _payoutManager = PayoutModule.PayoutManager(walletProxy, eventManager);
    private let payoutService = PayoutService.createPayoutService(walletProxy, eventManager);
    // Initialize Asset Registry Proxy
    private let _assetRegistryProxy = AssetRegistryProxy.AssetRegistryProxy(Principal.fromText("br5f7-7uaaa-aaaaa-qaaca-cai"));
    // Initialize Asset Registry Service
    private let assetRegistryService = AssetRegistryService.createAssetRegistryService(eventManager);
    // Asset Canister Proxy
    private let assetProxy = AssetProxy.AssetProxy(Principal.fromText("be2us-64aaa-aaaaa-qaabq-cai"));
     // Initialize Identity Manager
    private let identityManager : IdentityModule.IdentityManager = IdentityModule.IdentityManager(eventManager);
    // Initialize Governance Proxy
    private let _governanceProxy = GovernanceProxy.GovernanceProxy(Principal.fromText("c2lt4-zmaaa-aaaaa-qaaiq-cai"));

    // Initialize Governance Manager and Service
    private let governanceManager = GovernanceModule.GovernanceModule(eventManager);
    private let governanceService = GovernanceService.GovernanceService(governanceManager, eventManager);

    // State initialization

    let userModule = UserModule.UserManager(eventManager);
    let userService = UserService.UserService(userModule, eventManager);

    // Exposed APIs to connect with frontend or other services

    // Create a user wallet
    public func createUserWallet(userId: Principal, initialBalance: Nat): async Result.Result<Text, Text> {
        let result = await walletProxy.createWallet(userId, initialBalance);
        switch (result) {
            case (#ok(wallet)) #ok("Wallet created with ID: " # Int.toText(wallet.id));
            case (#err(error)) #err(error);
        }
    };

    // Credit a user wallet
    public func creditUserWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
        await walletProxy.creditWallet(userId, amount, tokenId)
    };

    // Debit a user wallet
    public func debitUserWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
        await walletProxy.debitWallet(userId, amount, tokenId)
    };

    // Get transaction history for a wallet
    public func getWalletTransactionHistory(userId: Principal): async Result.Result<[WalletCanisterProxy.Transaction], Text> {
        let result = await walletProxy.getTransactionHistory(userId);
        switch (result) {
            case (#ok(transactions)) #ok(transactions);
            case (#err(e)) #err(e);
        }
    };

    // Create a token
    public func createToken(
        name: Text,
        symbol: Text,
        totalSupply: Nat,
        decimals: Nat,
        owner: Principal
    ): async Result.Result<Text, Text> {
        let result = await tokenProxy.createToken(name, symbol, totalSupply, decimals, owner);
        switch (result) {
            case (#ok(token)) #ok("Token created with ID: " # Nat.toText(token.id));
            case (#err(error)) #err(error);
        }
    };

    // Mint tokens for a user
    public func mintTokens(_tokenId: Nat, amount: Nat, userId: Principal): async Result.Result<(), Text> {
        await tokenProxy.mintTokens(userId, amount)
    };

    // Define this outside of any function, as a private function of the actor
private func handleTokenCreated(event: EventTypes.Event) {
    switch (event.payload) {
        case (#TokenCreated { tokenId; name; owner }) {
            Debug.print("Token created: " # name # ", ID: " # Nat.toText(tokenId) # ", Owner: " # Principal.toText(owner));
        };
        case (_) {}; // Ignore other events
    };
};

// Define this as a public field of the actor
public shared func onTokenCreated(event: EventTypes.Event) : async () {
    handleTokenCreated(event);
};

public func initializeEventListeners() : async () {
    // Subscribe using the public shared function
    await eventManager.subscribe(#TokenCreated, onTokenCreated);

    // Add other event subscriptions as needed
};
    // System health check
    public func healthCheck(): async Text {
        try {
            let tokenStatus = await tokenProxy.getAllTokens();
           let walletStatus = await walletProxy.getTransactionHistory(Principal.fromText("2vxsx-fae"));
if (tokenStatus.size() > 0 and (switch walletStatus { case (#ok(_)) true; case (#err(_)) false })) {
    "System is operational"
} else {
    "System has issues"
}
        } catch (e) {
            "System health check failed: " # Error.message(e);
        }
    };

    /* Heartbeat integration (periodic tasks)
    public func runHeartbeat(): async () {
        Debug.print("Running heartbeat tasks...");

        // Example: Handle timed-out payments
        let timeoutResult = await paymentProxy.timeoutPendingPayments();
        switch (timeoutResult) {
            case (#ok(count)) Debug.print("Timed-out payments processed: " # Nat.toText(count));
            case (#err(error)) Debug.print("Error processing timed-out payments: " # error);
        };
    }; */

    

// Expose Payment Monitoring APIs
public func monitorPayment(caller: Principal, paymentId: Nat): async Result.Result<Text, Text> {
    await paymentMonitoringProxy.monitorPayment(caller, paymentId);
};

public func monitorPendingPayments(): async Result.Result<Nat, Text> {
    await paymentMonitoringProxy.monitorPendingPayments();
};

public func validateWalletBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<Bool, Text> {
    await paymentMonitoringProxy.validateWalletBalance(userId, tokenId, amount);
};

public func reconcilePayments(caller: Principal): async Result.Result<Nat, Text> {
    await paymentMonitoringProxy.reconcilePayments(caller);
};

public func subscribeToPayments(userId: Principal): async Result.Result<Nat, Text> {
    await paymentMonitoringProxy.subscribeToPayments(userId);
};

public func unsubscribeFromPayments(subscriptionId: Nat): async Result.Result<(), Text> {
    await paymentMonitoringProxy.unsubscribeFromPayments(subscriptionId);
};

public func broadcastPaymentUpdate(paymentId: Nat, status: Text): async Result.Result<(), Text> {
    await paymentMonitoringProxy.broadcastPaymentUpdate(paymentId, status);
};

public func listSubscriptions(): async Result.Result<[(Nat, Principal)], Text> {
    await paymentMonitoringProxy.listSubscriptions();
};

// Extend Heartbeat to handle subscription expiry
public func runHeartbeat(): async () {
    Debug.print("Running heartbeat tasks...");

    // Handle payment monitoring-specific tasks
    try {
        let expiredCountResult = await paymentMonitoringProxy.monitorPendingPayments();
        switch expiredCountResult {
            case (#ok(count)) Debug.print("Expired subscriptions processed: " # Nat.toText(count));
            case (#err(error)) Debug.print("Error processing expired subscriptions: " # error);
        };
    } catch (e) {
        Debug.print("Error in heartbeat task: " # Error.message(e));
    };

    // Call the existing runHeartbeat tasks
    await runHeartbeat();
};

// Initialize the Subscription Proxy
private let subscriptionProxy = SubscriptionCanisterProxy.SubscriptionProxy(
    Principal.fromText("a4tbr-q4aaa-aaaaa-qaafq-cai")
);

// Subscription APIs

// Subscription APIs

// Create a subscription for a user
// Create a subscription for a user
public func createSubscription(userId: Principal, duration: Int): async Result.Result<SubscriptionCanisterProxy.Subscription, Text> {
    try {
        let result = await subscriptionProxy.createSubscription(userId, duration);
        result
    } catch (e) {
        #err("Failed to create subscription: " # Error.message(e))
    }
};

// Check if a user is subscribed
public func isSubscribed(userId: Principal): async Result.Result<Bool, Text> {
    try {
        let result = await subscriptionProxy.isSubscribed(userId);
        result
    } catch (e) {
        #err("Failed to check subscription status: " # Error.message(e));
    }
};

// Update an existing subscription
public func updateSubscription(userId: Principal, newEndDate: Int): async Result.Result<(), Text> {
    try {
        let result = await subscriptionProxy.updateSubscription(userId, newEndDate);
        result
    } catch (e) {
        #err("Failed to update subscription: " # Error.message(e));
    }
};



public query func getAllSubscriptions(): async [(Principal, SubscriptionCanisterProxy.Subscription)] {
    localSubscriptions
};

// You would need to update localSubscriptions whenever changes occur

// Validate a user's subscription
public func validateSubscription(userId: Principal): async Result.Result<(), Text> {
    try {
        let result = await subscriptionProxy.validateSubscription(userId);
        result
    } catch (e) {
        #err("Failed to validate subscription: " # Error.message(e));
    }
};

// Expire outdated subscriptions
public func expireSubscriptions(): async Result.Result<Nat, Text> {
    try {
        let result = await subscriptionProxy.expireSubscriptions();
        result
    } catch (e) {
        #err("Failed to expire subscriptions: " # Error.message(e));
    }
};

// Attach a subscription to a user
public func attachSubscriptionToUser(
    userId: Principal,
    subscription: SubscriptionCanisterProxy.Subscription
): async Result.Result<(), Text> {
    try {
        let result = await subscriptionProxy.attachSubscriptionToUser(userId, subscription);
        result
    } catch (e) {
        #err("Failed to attach subscription: " # Error.message(e));
    }
};

// Get subscription details for a user
public func getSubscriptionDetails(userId: Principal): async Result.Result<SubscriptionCanisterProxy.Subscription, Text> {
    try {
        let result = await subscriptionProxy.getSubscriptionDetails(userId);
        result
    } catch (e) {
        #err("Failed to retrieve subscription details: " # Error.message(e));
    }
};

// Global Escrow APIs

// Create a new escrow
public shared func createEscrow(
    sender: Principal,
    receiver: Principal,
    tokenId: Nat,
    amount: Nat,
    conditions: Text
): async Result.Result<Nat, Text> {
    try {
        await escrowCanisterProxy.createEscrow(sender, receiver, tokenId, amount, conditions);
    } catch (e) {
        #err("Failed to create escrow: " # Error.message(e))
    }
};

// Release an escrow
public shared func releaseEscrow(escrowId: Nat): async Result.Result<(), Text> {
    try {
        await escrowCanisterProxy.releaseEscrow(escrowId);
    } catch (e) {
        #err("Failed to release escrow: " # Error.message(e))
    }
};

// Cancel an escrow
public shared func cancelEscrow(escrowId: Nat): async Result.Result<(), Text> {
    try {
        await escrowCanisterProxy.cancelEscrow(escrowId);
    } catch (e) {
        #err("Failed to cancel escrow: " # Error.message(e))
    }
};

// Get details of a specific escrow
public shared func getEscrow(escrowId: Nat): async Result.Result<EscrowModule.EscrowState, Text> {
    try {
        await escrowCanisterProxy.getEscrow(escrowId);
    } catch (e) {
        #err("Failed to get escrow details: " # Error.message(e))
    }
};

// List all escrows
// List all escrows
public shared func listEscrows(): async [EscrowModule.EscrowState] {
    try {
        let result = await escrowCanisterProxy.listEscrows();
        switch (result) {
            case (#ok(escrows)) { escrows };
            case (#err(_)) { [] };
        }
    } catch (_e) {
        []; // Return empty list in case of an error
    }
};

// Split Payment APIs

    // Initiate a split payment
    public shared func initiateSplitPayment(
        sender: Principal,
        recipients: [Principal],
        shares: [Nat],
        totalAmount: Nat,
        description: ?Text
    ): async Result.Result<Nat, Text> {
        await splitPaymentProxy.initiateSplitPayment(sender, recipients, shares, totalAmount, description);
    };

    // Execute a split payment
    public shared func executeSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
        await splitPaymentProxy.executeSplitPayment(paymentId);
    };

    // Cancel a split payment
    public shared func cancelSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
        await splitPaymentProxy.cancelSplitPayment(paymentId);
    };

    // Get details of a split payment
    public shared func getSplitPaymentDetails(paymentId: Nat): async Result.Result<{
        id: Nat;
        sender: Principal;
        recipients: [Principal];
        shares: [Nat];
        totalAmount: Nat;
        description: ?Text;
        status: Text;
        createdAt: Int;
    }, Text> {
        await splitPaymentProxy.getSplitPaymentDetails(paymentId);
    };

    // Retrieve all split payments
    public shared func getAllSplitPayments(): async [Nat] {
        await splitPaymentProxy.getAllSplitPayments();
    };

    // List split payments by status
    public shared func listSplitPaymentsByStatus(status: Text): async [Nat] {
        await splitPaymentProxy.listSplitPaymentsByStatus(status);
    };

    // Retry a failed split payment
    public shared func retrySplitPayment(paymentId: Nat): async Result.Result<(), Text> {
        await splitPaymentProxy.retrySplitPayment(paymentId);
    };

    // Calculate distributed amount
    public shared func calculateDistributedAmount(paymentId: Nat): async Result.Result<Nat, Text> {
        await splitPaymentProxy.calculateDistributedAmount(paymentId);
    };

    // Validate a split payment
    public shared func validateSplitPayment(paymentId: Nat): async Result.Result<(), Text> {
        await splitPaymentProxy.validateSplitPayment(paymentId);
    };

    // Global Exposed APIs for Payout Canister

// Initiate a Payout
public shared func initiatePayout(
    recipients: [Principal],
    amounts: [Nat],
    description: ?Text
): async Result.Result<Text, Text> {
    let result = await payoutService.initiatePayout(recipients, amounts, description);
    switch (result) {
        case (#ok(payout)) {
            #ok("Payout initiated successfully. ID: " # Nat.toText(payout.id))
        };
        case (#err(error)) {
            #err("Failed to initiate payout: " # error)
        };
    };
};

// Execute a Payout
public shared func executePayout(payoutId: Nat): async Result.Result<(), Text> {
    await payoutService.executePayout(payoutId)
};

public shared func getPayoutDetails(payoutId: Nat): async Result.Result<PayoutModule.Payout, Text> {
    await async {
        payoutService.getPayoutDetails(payoutId)
    }
};

// Get All Payouts
public query func getAllPayouts(): async [PayoutModule.Payout] {
    payoutService.getAllPayouts()
};

// Cancel a Payout
public shared func cancelPayout(payoutId: Nat): async Result.Result<(), Text> {
    await payoutService.cancelPayout(payoutId);
};

// Asset Registry APIs

// Register a new asset
public func registerAssetInRegistry(
    owner: Principal,
    nftId: Nat,
    metadata: Text
): async Result.Result<AssetRegistryModule.Asset, Text> {
    await assetRegistryService.registerAssetInRegistry(owner, nftId, metadata)
};

// Transfer ownership of an asset
public func transferAssetInRegistry(
    assetId: Nat,
    newOwner: Principal
): async Result.Result<AssetRegistryModule.Asset, Text> {
    await assetRegistryService.transferAssetInRegistry(assetId, newOwner);
};

// Deactivate an asset
public func deactivateAssetInRegistry(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
    await assetRegistryService.deactivateAssetInRegistry(assetId);
};

// Reactivate an asset
public func reactivateAssetInRegistry(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
    await assetRegistryService.reactivateAssetInRegistry(assetId);
};

// Retrieve asset details by ID
public func getAssetInRegistry(assetId: Nat): async Result.Result<AssetRegistryModule.Asset, Text> {
    await assetRegistryService.getAssetInRegistry(assetId);
};

// Retrieve all assets owned by a specific user
public func getAssetsByOwnerInRegistry(owner: Principal): async [AssetRegistryModule.Asset] {
    await assetRegistryService.getAssetsByOwnerInRegistry(owner);
};

// Retrieve all assets linked to a specific NFT
public func getAssetsByNFTInRegistry(nftId: Nat): async [AssetRegistryModule.Asset] {
    await assetRegistryService.getAssetsByNFTInRegistry(nftId);
};

// Retrieve all assets in the registry
public func getAllAssetsInRegistry(): async [AssetRegistryModule.Asset] {
    await assetRegistryService.getAllAssetsInRegistry();
};

// Retrieve ownership history of an asset
public func getAssetOwnershipHistoryInRegistry(assetId: Nat): async Result.Result<[Principal], Text> {
    await assetRegistryService.getAssetOwnershipHistoryInRegistry(assetId);
};

// Asset Canister APIs

// Register a new asset
public shared func registerAsset(owner: Principal, metadata: Text): async Result.Result<Nat, Text> {
    try {
        let result = await assetProxy.registerAsset(owner, metadata);
        result
    } catch (e) {
        #err("Failed to register asset: " # Error.message(e))
    }
};

// Transfer ownership of an asset
public shared func transferAsset(assetId: Nat, newOwner: Principal): async Result.Result<(), Text> {
    try {
        let result = await assetProxy.transferAsset(assetId, newOwner);
        result
    } catch (e) {
        #err("Failed to transfer asset: " # Error.message(e))
    }
}; 

// Deactivate an asset
public shared func deactivateAsset(assetId: Nat): async Result.Result<(), Text> {
    try {
        let result = await assetProxy.deactivateAsset(assetId);
        result
    } catch (e) {
        #err("Failed to deactivate asset: " # Error.message(e))
    }
}; 

// Reactivate an asset
public shared func reactivateAsset(assetId: Nat): async Result.Result<(), Text> {
    try {
        let result = await assetProxy.reactivateAsset(assetId);
        result
    } catch (e) {
        #err("Failed to reactivate asset: " # Error.message(e))
    }
}; 

// Retrieve asset details by ID
public shared func getAsset(assetId: Nat): async Result.Result<{ id: Nat; owner: Principal; metadata: Text }, Text> {
    try {
        let result = await assetProxy.getAsset(assetId);
        result
    } catch (e) {
        #err("Failed to get asset details: " # Error.message(e))
    }
}; 

// Retrieve all assets
public shared func getAllAssets(): async [Nat] {
    try {
        await assetProxy.getAllAssets();
    } catch (_) {
        []; // Return an empty list in case of error
    }
}; 

// Retrieve assets owned by a specific user
public shared func getAssetsByOwner(owner: Principal): async [Nat] {
    try {
        await assetProxy.getAssetsByOwner(owner);
    } catch (_) {
        []; // Return an empty list in case of error
    }
}; 

// Retrieve all active assets
public shared func getActiveAssets(): async [Nat] {
    try {
        await assetProxy.getActiveAssets();
    } catch (_) {
        []; // Return an empty list in case of error
    }
};

// Search assets by metadata keyword
public shared func searchAssetsByMetadata(keyword: Text): async [Nat] {
    try {
        await assetProxy.searchAssetsByMetadata(keyword);
    } catch (_) {
        []; // Return an empty list in case of error
    }
};

// Batch transfer ownership of assets
public shared func batchTransferAssets(assetIds: [Nat], newOwner: Principal): async Result.Result<[Nat], Text> {
    try {
        let result = await assetProxy.batchTransferAssets(assetIds, newOwner);
        result
    } catch (e) {
        #err("Failed to batch transfer assets: " # Error.message(e))
    }
};

// Public API for identity canister
public func createIdentity(userId: Principal, details: Trie.Trie<Text, Text>): async Result.Result<Text, Text> {
    let result = await identityManager.createIdentity(userId, details);
    switch (result) {
        case (#ok(identity)) {
            #ok("Identity created successfully for user: " # Principal.toText(identity.id))
        };
        case (#err(error)) {
            #err(error)
        };
    }
};

public func updateIdentity(userId: Principal, details: Trie.Trie<Text, Text>): async Result.Result<Text, Text> {
    let result = await identityManager.updateIdentity(userId, details);
    switch (result) {
        case (#ok(identity)) {
            #ok("Identity updated successfully for user: " # Principal.toText(identity.id))
        };
        case (#err(error)) {
            #err(error)
        };
    }
};

public func deleteIdentity(userId: Principal): async Result.Result<Text, Text> {
    let result = await identityManager.deleteIdentity(userId);
    switch (result) {
        case (#ok(())) {
            #ok("Identity deleted successfully for user: " # Principal.toText(userId))
        };
        case (#err(error)) {
            #err(error)
        };
    }
};

public func getIdentity(userId: Principal): async ?IdentityModule.Identity {
    await identityManager.getIdentity(userId);
};

public func getAllIdentities(): async [IdentityModule.Identity] {
    identityManager.getAllIdentities();
};

public func getStaleIdentities(): async [IdentityModule.Identity] {
    await identityManager.getStaleIdentities();
};

public func searchIdentitiesByMetadata(key: Text, value: Text): async [IdentityModule.Identity] {
    await identityManager.searchIdentitiesByMetadata(key, value);
};

public func batchUpdateMetadata(updates: [(Principal, Text, Text)]): async Result.Result<Text, Text> {
    let result = await identityManager.batchUpdateMetadata(updates);
    switch (result) {
        case (#ok(())) {
            #ok("Batch metadata update completed successfully.")
        };
        case (#err(error)) {
            #err(error)
        };
    }
};

public func exportAllIdentities(): async Result.Result<Text, Text> {
    let result = await identityManager.exportAllIdentities();
    #ok("All identities exported successfully: " # result)
};

public func subscribeToIdentityEvents(eventType: EventTypes.EventType, listener: shared EventTypes.Event -> async ()): async Text {
    await eventManager.subscribe(eventType, listener);
    "Subscribed to events of type: " # debug_show(eventType);
};

public func listSubscribedEventTypes(): async [EventTypes.EventType] {
    await eventManager.listSubscribedEventTypes();
};

// Public API: Trigger the heartbeat for stale identity cleanup
public func runIdentityHeartbeat(): async Text {
    await identityManager.runHeartbeat();
    "Heartbeat executed successfully for stale identity cleanup.";
};

// Governance APIs

// Create a new proposal
public func createProposal(proposer: Principal, description: Text): async Result.Result<GovernanceModule.Proposal, Text> {
    let result = await governanceService.propose(proposer, description);
    switch (result) {
        case (#ok(proposal)) {
            #ok(proposal);
        };
        case (#err(error)) {
            #err("Failed to create proposal: " # error);
        };
    }
};

// Vote on a proposal
public func voteOnProposal(voter: Principal, proposalId: Nat, isYes: Bool, weight: Nat): async Result.Result<(), Text> {
    let result = await governanceService.vote(voter, proposalId, isYes, weight);
    switch (result) {
        case (#ok(())) {
            #ok(());
        };
        case (#err(error)) {
            #err("Failed to vote on proposal: " # error);
        };
    }
};

// Execute a proposal
public func executeProposal(proposalId: Nat): async Result.Result<Text, Text> {
    let result = await governanceService.executeProposal(proposalId);
    switch (result) {
        case (#ok(outcome)) {
            #ok(outcome);
        };
        case (#err(error)) {
            #err("Failed to execute proposal: " # error);
        };
    }
};

// Reject a proposal
public func rejectProposal(proposalId: Nat, reason: Text): async Result.Result<(), Text> {
    let result = await governanceService.rejectProposal(proposalId, reason);
    switch (result) {
        case (#ok(())) {
            #ok(());
        };
        case (#err(error)) {
            #err("Failed to reject proposal: " # error);
        };
    }
};

// Check if a proposal has expired
public func checkProposalExpiry(proposalId: Nat): async Result.Result<(), Text> {
    let result = await governanceService.checkProposalExpiry(proposalId);
    switch (result) {
        case (#ok(())) {
            #ok(());
        };
        case (#err(error)) {
            #err("Failed to check proposal expiry: " # error);
        };
    }
};

public query func getProposal(proposalId: Nat): async Result.Result<GovernanceModule.Proposal, Text> {
    governanceService.getProposalSync(proposalId)
};

public query func getAllProposals(): async [GovernanceModule.Proposal] {
    governanceService.getAllProposalsSync()
};

  // Public API: Create a new user
public shared func createUser(username: Text, email: Text, password: Text): async Result.Result<UserModule.User, Text> {
    Debug.print("Global main received createUser request.");
    return await userService.createUser(username, email, password);
};

// Public API: Retrieve user by ID
public shared func getUserById(userId: Principal): async Result.Result<UserModule.User, Text> {
    Debug.print("Global main received getUserById request.");
    return await userService.getUserById(userId);
};

// Public API: Update user details
public shared func updateUser(
    userId: Principal,
    newUsername: ?Text,
    newEmail: ?Text,
    newPassword: ?Text
): async Result.Result<UserModule.User, Text> {
    Debug.print("Global main received updateUser request for: " # Principal.toText(userId));
    return await userService.updateUser(userId, newUsername, newEmail, newPassword);
};

// Public API: Deactivate a user
public shared func deactivateUser(userId: Principal): async Result.Result<(), Text> {
    Debug.print("Global main received deactivateUser request for: " # Principal.toText(userId));
    return await userService.deactivateUser(userId);
};

// Public API: List all users
public shared func listAllUsers(includeInactive: Bool): async Result.Result<[UserModule.User], Text> {
    Debug.print("Global main received listAllUsers request. Include inactive: " # Bool.toText(includeInactive));
    return await userService.listAllUsers(includeInactive);
};

// Public API: Reset user password
public shared func resetPassword(userId: Principal, newPassword: Text): async Result.Result<(), Text> {
    Debug.print("Global main received resetPassword request for: " # Principal.toText(userId));

    // Call the service and map the result to match the expected return type
    let resetResult = await userService.resetPassword(userId, newPassword);

    // Map the user result to ()
    switch resetResult {
        case (#ok(_user)) {
            return #ok(()); // Ignore the user object and return success
        };
        case (#err(errMsg)) {
            return #err(errMsg); // Propagate the error message
        };
    };
};

// Public API: Delete a user
public shared func deleteUser(userId: Principal): async Result.Result<(), Text> {
    Debug.print("Global main received deleteUser request for: " # Principal.toText(userId));
    return await userService.deleteUser(userId);
};

// Heartbeat function to process queued events
system func heartbeat(): async () {
    Debug.print("Processing queued events in heartbeat.");
    await eventManager.processQueuedEvents();
};
    
};