import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import GovernanceModule "../modules/governance_module";
import Error "mo:base/Error";

module {
    public type GovernanceCanisterInterface = actor {
        propose: (Principal, Text) -> async Result.Result<GovernanceModule.Proposal, Text>;
        vote: (Principal, Nat, Bool, Nat) -> async Result.Result<(), Text>;
        executeProposal: (Nat) -> async Result.Result<Text, Text>;
        rejectProposal: (Nat, Text) -> async Result.Result<(), Text>;
        checkProposalExpiry: (Nat) -> async Result.Result<(), Text>;
        getProposal: (Nat) -> async Result.Result<GovernanceModule.Proposal, Text>;
        getAllProposals: () -> async [GovernanceModule.Proposal];
    };

    public class GovernanceProxy(canisterId: Principal) {
        private let governanceCanister: GovernanceCanisterInterface = actor(Principal.toText(canisterId));

        // Propose a new governance action
        public func propose(
            proposer: Principal,
            description: Text
        ): async Result.Result<GovernanceModule.Proposal, Text> {
            try {
                await governanceCanister.propose(proposer, description);
            } catch (e) {
                #err("Failed to create proposal: " # Error.message(e))
            }
        };

        // Vote on a governance proposal
        public func vote(
            voter: Principal,
            proposalId: Nat,
            isYes: Bool,
            weight: Nat
        ): async Result.Result<(), Text> {
            try {
                await governanceCanister.vote(voter, proposalId, isYes, weight);
            } catch (e) {
                #err("Failed to vote on proposal: " # Error.message(e))
            }
        };

        // Execute a governance proposal
        public func executeProposal(proposalId: Nat): async Result.Result<Text, Text> {
            try {
                await governanceCanister.executeProposal(proposalId);
            } catch (e) {
                #err("Failed to execute proposal: " # Error.message(e))
            }
        };

        // Reject a governance proposal
        public func rejectProposal(proposalId: Nat, reason: Text): async Result.Result<(), Text> {
            try {
                await governanceCanister.rejectProposal(proposalId, reason);
            } catch (e) {
                #err("Failed to reject proposal: " # Error.message(e))
            }
        };

        // Check if a proposal has expired
        public func checkProposalExpiry(proposalId: Nat): async Result.Result<(), Text> {
            try {
                await governanceCanister.checkProposalExpiry(proposalId);
            } catch (e) {
                #err("Failed to check proposal expiry: " # Error.message(e))
            }
        };

        // Retrieve a specific proposal by ID
        public func getProposal(proposalId: Nat): async Result.Result<GovernanceModule.Proposal, Text> {
            try {
                await governanceCanister.getProposal(proposalId);
            } catch (e) {
                #err("Failed to fetch proposal: " # Error.message(e))
            }
        };

        // Retrieve all proposals
        public func getAllProposals(): async Result.Result<[GovernanceModule.Proposal], Text> {
            try {
                let proposals = await governanceCanister.getAllProposals();
                #ok(proposals);
            } catch (e) {
                #err("Failed to fetch all proposals: " # Error.message(e))
            }
        };
    };
};