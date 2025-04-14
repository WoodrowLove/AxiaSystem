
    import Principal "mo:base/Principal";
    import Text "mo:base/Text";
    import Trie "mo:base/Trie";
    import Int "mo:base/Int";
    import Bool "mo:base/Bool";
    import Result "mo:base/Result";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";

    module {

    // Shared User Type
    public type User = {
        id: Principal;
        username: Text;
        email: Text;
        hashedPassword: Text;
        createdAt: Int;
        updatedAt: Int;
        icpWallet: ?Text; // Optional ICP Wallet
        tokens: Trie.Trie<Nat, Nat>;
        isActive: Bool;
    };

    // Shared Identity Type
    public type Identity = {
        id: Principal;
        metadata: Trie.Trie<Text, Text>;
        createdAt: Int;
        updatedAt: Int;
    };

    public type Subscription = {
        id: Nat;
        startDate: Int;
        endDate: Int;
        status: Text; // "Active", "Expired"
    };

    // Shared UserCanisterInterface
    public type UserCanisterInterface = actor {
        createUser: (Text, Text, Text) -> async Result.Result<User, Text>;
        getUserById: (Principal) -> async Result.Result<User, Text>;
        updateUser: (Principal, ?Text, ?Text, ?Text) -> async Result.Result<User, Text>;
        deactivateUser: (Principal) -> async Result.Result<(), Text>;
        reactivateUser: (Principal) -> async Result.Result<(), Text>;
        deleteUser: (Principal) -> async Result.Result<(), Text>;
        listAllUsers: Bool -> async Result.Result<[User], Text>;
        resetPassword: (Principal, Text) -> async Result.Result<User, Text>;
    };

    // Shared IdentityCanisterInterface
    public type IdentityCanisterInterface = actor {
        createIdentity: (Principal, Trie.Trie<Text, Text>) -> async Result.Result<Identity, Text>;
        updateIdentity: (Principal, Trie.Trie<Text, Text>) -> async Result.Result<Identity, Text>;
        getIdentity: (Principal) -> async ?Identity;
        getAllIdentities: () -> async [Identity];
        deleteIdentity: (Principal) -> async Result.Result<(), Text>;
        findIdentityByMetadata: (Text, Text) -> async ?Identity;
    };

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

      public type ElectionConfig = {
        name: Text;
        creator: Principal;
        startTime: Nat;
        endTime: Nat;
        candidates: [Text];
        electionType: ElectionType;
        voteWeighting: ?VoteWeightingRules;
        encryption: EncryptionType; 
    };

    public type ElectionType = {
        #Basic;
        #Government;
    };

    public type Election = {
        id: Nat;
        name: Text;
        creator: Principal;
        startTime: Nat;
        endTime: Nat;
        candidates: [Text];
        voters: [Principal];
        status: ElectionStatus;
        electionType: ElectionType; 
        voteWeighting: ?VoteWeightingRules;  //this is optional
        encryption: EncryptionType;
        accessControlRules: AccessControlRules;
        visibilityRules: VisibilitySettings; 
        escrowSettings: ?EscrowSettings;
    };

    public type ElectionStatus = {
        #Pending;
        #Active;
        #Closed;
        #Finalized;
    };

    // ✅ Election result structure
    public type ElectionResult = {
        winner: ?Text;
        totalVotes: Nat;
        candidateVotes: [(Text, Nat)];
    };
    


// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    public type VoterId = Principal;

    public type VoteWeightingRules = {
        #StakeBased : { tokenCanisterId : Principal };
        #DelegateBased : {governanceCanisterId : Principal };
        //#Custom: Text;
    };


     // ✅ Vote record to store votes with weight
    public type VoteRecord = {
        voter: Principal;
        candidate: Text;
        weight: Nat;
    };

    public type GeneralVoteRecord = {
  proposalId: Nat;
  voter: Principal;
  choice: Bool;
  timestamp: Nat64;
};

    public type AdminAction = {
        id: Nat;
        timestamp: Int;
        admin: Principal;
        action: Text;
        details: ?Text;
    }; 

    public type AuditReport = {
    electionId: Nat;
    electionName: Text;
    totalVotes: Nat;
    candidateVoteCounts: [(Text, Nat)];
    voterParticipationRate: Nat;
    auditTimestamp: Nat;
    };

 // Multi-signature approval tracking
    public type MultiSigApproval = {
        requiredAdmins: [Principal];  // List of admins required to approve
        approvedAdmins: [Principal];  // List of admins who have approved
    };
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

     public type EncryptionType = {
        #None;
        #BasicEncryption;
        #AdvancedEncryption;
        #Homomorphic;
        #ZeroKnowledge;
    };

    public type AccessControlRules = {
    #Open;  // Anyone can vote
    #Restricted: { allowedVoters: [Principal] };  // Specific voter list
    #AdminOnly: { adminList: [Principal] };  // Only admins can access
    };


    public type PublicLedgerEntry = {
    electionId: Nat;
    timestamp: Nat;
    resultHash: Text;
    };

    // ✅ Convert Text → [Nat8]
public func textToUtf8Bytes(input: Text) : [Nat8] {
    let blob: Blob = Text.encodeUtf8(input);
    return Blob.toArray(blob);
};

// ✅ Custom Hash Function for Election Results (FNV-1a)
public func customHash(input: Text) : Nat {
    let utf8Bytes: [Nat8] = textToUtf8Bytes(input);
    var hash: Nat32 = 2166136261; // ✅ FNV-1a 32-bit offset basis
    let prime: Nat32 = 16777619;

    for (byte in utf8Bytes.vals()) {
        let byteAsNat32 = Nat32.fromNat(Nat8.toNat(byte));
        hash := (hash ^ byteAsNat32) * prime;
    };

    return Nat32.toNat(hash); // ✅ Convert Nat32 → Nat
};

     // ✅ Hash function for election results
    public func hashElectionResult(electionId: Nat, resultData: Text) : Text {
        let rawData = Nat.toText(electionId) # ":" # resultData;
        let hashValue: Nat = customHash(rawData);
        return Nat.toText(hashValue);
    };

    public type VisibilitySettings = {
  #Disabled;
  #Enabled: {
    authorizedViewers: ?[Principal];
    liveTracking: Bool;
  };
};

// ✅ Challenge Record
public type ElectionChallenge = {
  submittedBy: Principal;
  reason: Text;
  timestamp: Nat;
};

public type TokenId = Text;

public type EscrowSettings = {
    token: TokenId;
    minStake: Nat;
};

public type GeneralTallyResult = {
  yes: Nat;
  no: Nat;
  total: Nat;
};

public type GeneralProposalStatus = {
  #Pending;
  #Approved;
  #Rejected;
  #NotFound;
};
};