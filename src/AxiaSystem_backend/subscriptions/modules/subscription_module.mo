import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import LoggingUtils "../../utils/logging_utils";
import UserCanisterProxy "../../user/utils/user_canister_proxy";
import Iter "mo:base/Iter";

module {
    public type Subscription = {
        id: Nat;
        startDate: Int;
        endDate: Int;
        status: Text; // "Active", "Expired"
    };

    public class SubscriptionManager(userProxy: UserCanisterProxy.UserCanisterProxy) {
        private var subscriptions = HashMap.HashMap<Principal, Subscription>(10, Principal.equal, Principal.hash);
        private let logStore = LoggingUtils.init();

        // Create a new subscription for a user
public func createSubscription(userId: Principal, duration: Int): async Result.Result<Subscription, Text> {
    let startDate = Time.now();
    let endDate = startDate + duration;

    let subscription: Subscription = {
        id = Nat64.toNat(Nat64.fromIntWrap(startDate)); // Generate a unique ID
        //userId = Principal; // Include the userId in the subscription
        startDate = startDate;
        endDate = endDate;
        status = "Active";
    };

    subscriptions.put(userId, subscription); // Store the full subscription object

    LoggingUtils.logInfo(
        logStore,
        "SubscriptionManager",
        "Created subscription for user: " # Principal.toText(userId),
        ?userId
    );

    #ok(subscription) // Return the full subscription object
};

        // Check if a user has an active subscription
        public func isSubscribed(userId: Principal): async Result.Result<Bool, Text> {
            switch (subscriptions.get(userId)) {
                case (?_) #ok(true);
                case null #ok(false);
            };
        };

        // Update an existing subscription for a user
        public func updateSubscription(userId: Principal, newEndDate: Int): async Result.Result<(), Text> {
            switch (subscriptions.get(userId)) {
                case null #err("Subscription not found for user.");
                case (?subscription) {
                    let updatedSubscription = {
                        subscription with endDate = newEndDate;
                    };
                    subscriptions.put(userId, updatedSubscription);
                    LoggingUtils.logInfo(
                        logStore,
                        "SubscriptionManager",
                        "Updated subscription for user: " # Principal.toText(userId),
                        ?userId
                    );
                    #ok(())
                };
            };
        };

        // Get all active subscriptions
        public func getAllSubscriptions(): async [(Principal, Subscription)] {
            Iter.toArray(subscriptions.entries());
        };

        // Validate if a user's subscription is still active
        public func validateSubscription(userId: Principal): async Result.Result<(), Text> {
            switch (subscriptions.get(userId)) {
                case null #err("Subscription not found for user.");
                case (?subscription) {
                    if (subscription.endDate < Time.now()) {
                        LoggingUtils.logInfo(
                            logStore,
                            "SubscriptionManager",
                            "Subscription expired for user: " # Principal.toText(userId),
                            ?userId
                        );
                        #err("Subscription expired.");
                    } else {
                        LoggingUtils.logInfo(
                            logStore,
                            "SubscriptionManager",
                            "Subscription validated for user: " # Principal.toText(userId),
                            ?userId
                        );
                        #ok(());
                    }
                };
            };
        };

       public func expireSubscriptions(): async Result.Result<Nat, Text> {
    let expiredCount = Iter.toArray(
        Iter.filter(
            subscriptions.entries(),
            func ((_userId: Principal, subscription: Subscription)): Bool {
                subscription.endDate < Time.now()
            }
        )
    ).size();

    let newSubscriptions = HashMap.HashMap<Principal, Subscription>(10, Principal.equal, Principal.hash);
    for ((userId: Principal, subscription: Subscription) in subscriptions.entries()) {
        if (subscription.endDate >= Time.now()) {
            newSubscriptions.put(userId, subscription);
        }
    };
    subscriptions := newSubscriptions;

    LoggingUtils.logInfo(
        logStore,
        "SubscriptionManager",
        "Expired subscriptions removed: " # Nat.toText(expiredCount),
        null
    );

    #ok(expiredCount);
};
        // Attach a subscription to a user
        public func attachSubscriptionToUser(userId: Principal, subscription: Subscription): async Result.Result<(), Text> {
            let userOpt = await userProxy.getUserById(userId);
            switch (userOpt) {
                case (#err(e)) #err("Failed to validate user: " # e);
                case (#ok(_user)) {
                    subscriptions.put(userId, subscription);
                    LoggingUtils.logInfo(
                        logStore,
                        "SubscriptionManager",
                        "Attached subscription to user: " # Principal.toText(userId),
                        ?userId
                    );
                    #ok(());
                };
            };
        };

        // Get subscription details for a user
        public func getSubscriptionDetails(userId: Principal): async Result.Result<Subscription, Text> {
            switch (subscriptions.get(userId)) {
                case null #err("No subscription found for user.");
                case (?subscription) #ok(subscription);
            };
        };

        // Prevent overlapping subscriptions for the same user
public func canCreateSubscription(userId: Principal): async Result.Result<Bool, Text> {
    switch (subscriptions.get(userId)) {
        case null #ok(true); // No existing subscription
        case (?subscription) {
            if (subscription.endDate < Time.now()) {
                #ok(true); // Existing subscription expired
            } else {
                #err("User already has an active subscription.");
            }
        };
    }
};

// Retrieve all active subscriptions
public func getActiveSubscriptions(): async [(Principal, Subscription)] {
    let activeSubscriptions = Iter.toArray(
        Iter.filter(
            subscriptions.entries(),
            func ((_userId: Principal, subscription: Subscription)): Bool {
                subscription.status == "Active" and subscription.endDate >= Time.now()
            }
        )
    );
    activeSubscriptions;
};

// Cancel a subscription
public func cancelSubscription(userId: Principal): async Result.Result<(), Text> {
    switch (subscriptions.remove(userId)) {
        case null #err("No subscription found for user.");
        case (?subscription) {
            LoggingUtils.logInfo(
                logStore,
                "SubscriptionManager",
                "Cancelled subscription for user: " # Principal.toText(userId),
                ?userId
            );
            #ok(())
        };
    }
};

    };
}


