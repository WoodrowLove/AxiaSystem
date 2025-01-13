import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Trie "mo:base/Trie";

module {
    public type EventType = {
        #PaymentProcessed;
        #PaymentReversed;
        #WalletCreated;
        #WalletUpdated;
        #WalletDeleted;
        #PaymentHistoryRetrieved;
        #AllPaymentsRetrieved;
        #PaymentTimedOut;
        #BalancesSynchronized;
        #TokenCreated;
        #TokenMetadataUpdated;
        #TokenDeactivated;
        #TokenReactivated;
        #TokensLocked;
        #TokensUnlocked;
        #TokensBurned;
        #WalletEventGeneric;
        #EscrowCreated;
        #EscrowReleased;
        #EscrowCanceled;
        #SubscriptionCreated;  // Emitted when a subscription is created
        #SubscriptionRemoved;  // Emitted when a subscription is removed
        #PaymentStatusRetrieved; // Emitted when payment status is retrieved
        #PaymentUpdated;  // Emitted when a payment update is broadcasted
        #PendingPaymentsMonitored;
        #PaymentsReconciled;
        #InsufficientFunds;
        #SplitPaymentInitiated;
        #SplitPaymentExecuted;
        #SplitPaymentCancelled;
        #PayoutInitiated;
        #PayoutExecuted;
        #PayoutCancelled;
        #AssetRegistered;
        #AssetTransferred;
        #AssetDeactivated;
        #AssetReactivated;
         #IdentityCreated;
        #IdentityUpdated;
        #IdentityStaleRemoved;
        #IdentityDeleted;
        #FundsDeposited;
        #FundsWithdrawn;
        #RewardsDistributed;
        #TreasuryBalanceChecked;
        #TreasuryTransactionLogged;
        #ProposalCreated;
        #ProposalVoted;
        #ProposalExecuted;
        #ProposalRejected;
        #ProposalExpired;
        #GovernanceBalanceUpdated;
        #AdminActionLogged;   
        #EscrowTimeoutProcessed;          
        #SplitPaymentRetryCompleted;  
        #PayoutRetryCompleted;            
        #SystemMaintenanceCompleted;
        #UserCreated;

    };

    public type Event = {
        id: Nat64; // Changed from Nat to Nat64
        eventType: EventType;
        payload: EventPayload;
    };

    public type EventPayload = {
        #PaymentProcessed : { userId: Principal; amount: Nat; walletId: Text };
        #PaymentReversed : { userId: Principal; amount: Nat; walletId: Text };
        #WalletCreated : { walletId: Text; ownerId: Principal; initialBalance: Nat };
        #WalletUpdated : { walletId: Text; balance: Nat };
        #WalletDeleted : { walletId: Text; ownerId: Principal };
        #PaymentHistoryRetrieved : { userId: Principal; transactionCount: Nat };
        #AllPaymentsRetrieved : { totalTransactions: Nat };
        #PaymentTimedOut : { userId: Principal; amount: Nat; walletId: Text };
        #BalancesSynchronized : { senderId: Principal; receiverId: Principal; amount: Nat; tokenId: Nat };
        #TokenCreated : { tokenId: Nat; name: Text; symbol: Text; owner: Principal };
        #TokenMetadataUpdated : { tokenId: Nat; name: Text; symbol: Text; owner: Principal };
        #TokenDeactivated : { tokenId: Nat; owner: Principal };
        #TokenReactivated : { tokenId: Nat; owner: Principal };
        #TokensLocked : { tokenId: Nat; amount: Nat; owner: Principal};
        #TokensUnlocked : { tokenId: Nat; amount: Nat; owner: Principal };
        #TokensBurned : { tokenId: Nat; amount: Nat };
        #WalletEventGeneric : { walletId: Text; details: Text }; // Added this new variant
        #EscrowCreated : { escrowId: Nat; sender: Principal; receiver: Principal; tokenId: Nat; amount: Nat };
        #EscrowReleased : {};
        #EscrowCanceled : {};
        #SubscriptionCreated : { userId: Text; subscriptionId: Text };
        #SubscriptionRemoved : { subscriptionId: Text };
        #PaymentStatusRetrieved : { paymentId: Text; status: Text };
        #PaymentUpdated : { userId: Text; paymentId: Text; status: Text };
        #PendingPaymentsMonitored : { timeoutCount : Nat };
        #PaymentsReconciled : { discrepancyCount : Nat };
        #InsufficientFunds : { userId : Text; tokenId : Nat64; requiredAmount : Nat64; currentBalance : Nat64 };
        #SplitPaymentInitiated : { splitId: Nat; initiator: Principal;  recipients: [(Principal, Nat)]; totalAmount: Nat; tokenId: Nat; };
        #SplitPaymentExecuted : { splitId: Nat; executor: Principal; recipients: [(Principal, Nat)]; totalAmount: Nat; tokenId: Nat; executionTime: Nat64; };
        #SplitPaymentCancelled : { splitId: Nat; initiator: Principal; cancellationReason: Text; cancellationTime: Nat64; };
        #PayoutInitiated : { payoutId: Nat; totalAmount: Nat; recipients: [Principal]; description: ?Text; timestamp: Int };
        #PayoutExecuted : { payoutId: Nat; totalAmount: Nat; recipients: [(Principal, Nat)]; executionTime: Int };
        #PayoutCancelled : { payoutId: Nat; status: Text; cancellationTime: Int };
        #AssetRegistered : { assetId: Nat; owner: Principal; metadata: Text; registeredAt: Int };
        #AssetTransferred : { assetId: Nat; previousOwner: Principal; newOwner: Principal; transferTime: Int };
        #AssetDeactivated : { assetId: Nat; owner: Principal; deactivatedAt: Int };
        #AssetReactivated : { assetId: Nat; owner: Principal; reactivatedAt: Int };
        #IdentityCreated : { id: Principal; metadata: Trie.Trie<Text, Text>; createdAt: Int; };
        #IdentityUpdated : { id: Principal; metadata: Trie.Trie<Text, Text>; updatedAt: Int; };
        #IdentityStaleRemoved : { id: Principal; removedAt: Int; };
        #IdentityDeleted : { id: Principal; deletedAt: Int; };
        #FundsDeposited : { userId: Text; amount: Nat; tokenId: ?Nat; timestamp: Nat64 };
        #FundsWithdrawn : { userId: Text; amount: Nat; tokenId: ?Nat; timestamp: Nat64 };
        #RewardsDistributed : { recipients: [(Text, Nat)]; tokenId: ?Nat; totalAmount: Nat; timestamp: Nat64 };
        #TreasuryBalanceChecked : { tokenId: ?Nat; balance: Nat; timestamp: Nat64 };
        #TreasuryTransactionLogged : { transactionId: Nat; description: Text; transactionType: Text; timestamp: Nat64 };
        #ProposalCreated : { proposalId: Nat; proposer: Text; description: Text; createdAt: Nat64; }; 
        #ProposalVoted : { proposalId: Nat; voter: Text; vote: Text; /* "Yes" or "No" */ weight: Nat; /* Voting power used */ votedAt: Nat64; };
        #ProposalExecuted : { proposalId: Nat; executedAt: Nat64; outcome: Text; /* "Success" or "Failure" */ };
        #ProposalRejected : { proposalId: Nat; rejectedAt: Nat64; reason: Text; };
        #ProposalExpired : { proposalId: Nat;expiredAt: Nat64; };
        #GovernanceBalanceUpdated : { tokenId: ?Nat; newBalance: Nat; updatedAt: Nat64; };
        #AdminActionLogged : { adminId: Principal; actionId: Nat; action: Text;  timestamp: Nat64; };
        #EscrowTimeoutProcessed : { timeoutCount: Nat; timestamp: Nat64; };
        #SplitPaymentRetryCompleted : { retryCount: Nat; timestamp: Nat64; };
        #PayoutRetryCompleted : { retryCount: Nat; timestamp: Nat64; };
        #SystemMaintenanceCompleted : { escrowsProcessed: Nat; splitPaymentsRetried: Nat; payoutsRetried: Nat; timestamp: Nat64; };
         #UserCreated : { UserId: Text; username: Text; email: Text; };
    };

    public func equal(x: EventType, y: EventType): Bool {
        x == y
    };

    public func hash(x: EventType): Hash.Hash {
        switch(x) {
            case (#PaymentProcessed) { 0 };
            case (#PaymentReversed) { 1 };
            case (#WalletCreated) { 2 };
            case (#WalletUpdated) { 3 };
            case (#WalletDeleted) { 4 };
            case (#PaymentHistoryRetrieved) { 5 };
            case (#AllPaymentsRetrieved) { 6 };
            case (#PaymentTimedOut) { 7 };
            case (#BalancesSynchronized) { 8 };
            case (#TokenCreated) { 9 };
            case (#TokenMetadataUpdated) { 10 };
            case (#TokenDeactivated) { 11 };
            case (#TokenReactivated) { 12 };
            case (#TokensLocked) { 13 };
            case (#TokensUnlocked) { 14 };
            case (#TokensBurned) { 15 }; 
            case (#WalletEventGeneric) { 16 }; 
            case (#EscrowCreated) { 17 };
            case (#EscrowReleased) { 18 };
            case (#EscrowCanceled) { 19 };
            case (#SubscriptionCreated) { 20 };
            case (#SubscriptionRemoved) { 21 };
            case (#PaymentStatusRetrieved) { 22 };
            case (#PaymentUpdated) { 23 };
            case (#PendingPaymentsMonitored) { 24 };
            case (#PaymentsReconciled) { 25 };
            case (#InsufficientFunds) { 26 };
            case (#SplitPaymentInitiated) { 27 };
            case (#SplitPaymentExecuted) { 28 };
            case (#SplitPaymentCancelled) { 29 };
            case (#PayoutInitiated) { 30 };
            case (#PayoutExecuted) { 31 };
            case (#PayoutCancelled) { 32 };
            case (#AssetRegistered) { 33 };
            case (#AssetTransferred) { 34 };
            case (#AssetDeactivated) { 35 };
            case (#AssetReactivated) { 36 };
            case (#IdentityCreated) { 37 };
            case (#IdentityUpdated) { 38 };
            case (#IdentityStaleRemoved) { 39 };
            case (#IdentityDeleted) { 40 };
            case (#FundsDeposited) { 41 };
            case (#FundsWithdrawn) { 42 };
            case (#RewardsDistributed) { 43 };
            case (#TreasuryBalanceChecked) { 44 };
            case (#TreasuryTransactionLogged) { 45 };
            case (#ProposalCreated) { 46 }; 
            case (#ProposalVoted) { 47 };
            case (#ProposalExecuted) { 48 };
            case (#ProposalRejected) { 49 };
            case (#ProposalExpired) { 50 };
            case (#GovernanceBalanceUpdated) { 51 };
            case (#AdminActionLogged) { 52 };   
            case (#EscrowTimeoutProcessed) { 53 };          
            case (#SplitPaymentRetryCompleted) { 54 };  
            case (#PayoutRetryCompleted) { 55 };            
            case (#SystemMaintenanceCompleted) { 56 }; 
            case (#UserCreated) { 57 };

        }
    };
}