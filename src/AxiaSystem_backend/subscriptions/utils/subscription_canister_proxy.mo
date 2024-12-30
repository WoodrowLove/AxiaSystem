import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import SubscriptionModule "../modules/subscription_module";
import Error "mo:base/Error";

module {
    public type Subscription = SubscriptionModule.Subscription;

    // Define the interface for the Subscription Canister
    public type SubscriptionCanisterInterface = actor {
        createSubscription: (Principal, Int) -> async Result.Result<Subscription, Text>;
        isSubscribed: (Principal) -> async Result.Result<Bool, Text>;
        updateSubscription: (Principal, Int) -> async Result.Result<(), Text>;
        validateSubscription: (Principal) -> async Result.Result<(), Text>;
        expireSubscriptions: () -> async Result.Result<Nat, Text>;
        attachSubscriptionToUser: (Principal, Subscription) -> async Result.Result<(), Text>;
        getSubscriptionDetails: (Principal) -> async Result.Result<Subscription, Text>;
        cancelSubscription: (Principal) -> async Result.Result<(), Text>;
        getActiveSubscriptions: () -> async [(Principal, Subscription)];
        getAllSubscriptions: () -> async [(Principal, Subscription)];
    };

    // Proxy class for the Subscription Canister
    public class SubscriptionProxy(canisterId: Principal) {
        private let subscriptionCanister: SubscriptionCanisterInterface = actor(Principal.toText(canisterId));

        // Create a new subscription
        public func createSubscription(userId: Principal, duration: Int): async Result.Result<Subscription, Text> {
            try {
                await subscriptionCanister.createSubscription(userId, duration);
            } catch (e) {
                #err("Failed to create subscription: " # Error.message(e))
            }
        };

        // Check if a user has an active subscription
        public func isSubscribed(userId: Principal): async Result.Result<Bool, Text> {
            try {
                await subscriptionCanister.isSubscribed(userId);
            } catch (e) {
                #err("Failed to check subscription status: " # Error.message(e))
            }
        };

        // Update an existing subscription
        public func updateSubscription(userId: Principal, newEndDate: Int): async Result.Result<(), Text> {
            try {
                await subscriptionCanister.updateSubscription(userId, newEndDate);
            } catch (e) {
                #err("Failed to update subscription: " # Error.message(e))
            }
        };

        // Validate if a user's subscription is active
        public func validateSubscription(userId: Principal): async Result.Result<(), Text> {
            try {
                await subscriptionCanister.validateSubscription(userId);
            } catch (e) {
                #err("Failed to validate subscription: " # Error.message(e))
            }
        };

        // Expire all outdated subscriptions
        public func expireSubscriptions(): async Result.Result<Nat, Text> {
            try {
                await subscriptionCanister.expireSubscriptions();
            } catch (e) {
                #err("Failed to expire subscriptions: " # Error.message(e))
            }
        };

        // Attach a subscription to a user
        public func attachSubscriptionToUser(userId: Principal, subscription: Subscription): async Result.Result<(), Text> {
            try {
                await subscriptionCanister.attachSubscriptionToUser(userId, subscription);
            } catch (e) {
                #err("Failed to attach subscription to user: " # Error.message(e))
            }
        };

        // Get subscription details for a user
        public func getSubscriptionDetails(userId: Principal): async Result.Result<Subscription, Text> {
            try {
                await subscriptionCanister.getSubscriptionDetails(userId);
            } catch (e) {
                #err("Failed to get subscription details: " # Error.message(e))
            }
        };

        // Cancel a subscription for a user
        public func cancelSubscription(userId: Principal): async Result.Result<(), Text> {
            try {
                await subscriptionCanister.cancelSubscription(userId);
            } catch (e) {
                #err("Failed to cancel subscription: " # Error.message(e))
            }
        };

        // Get all active subscriptions
        public func getActiveSubscriptions(): async Result.Result<[(Principal, Subscription)], Text> {
            try {
                let subscriptions = await subscriptionCanister.getActiveSubscriptions();
                #ok(subscriptions);
            } catch (e) {
                #err("Failed to fetch active subscriptions: " # Error.message(e))
            }
        };

        // Get all subscriptions (active and expired)
        public func getAllSubscriptions(): async Result.Result<[(Principal, Subscription)], Text> {
            try {
                let subscriptions = await subscriptionCanister.getAllSubscriptions();
                #ok(subscriptions);
            } catch (e) {
                #err("Failed to fetch all subscriptions: " # Error.message(e))
            }
        };
    };
};