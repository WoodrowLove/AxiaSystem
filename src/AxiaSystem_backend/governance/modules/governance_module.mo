import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import _Option "mo:base/Option";
import _Int "mo:base/Int";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    public type Proposal = {
        id: Nat;
        proposer: Principal;
        description: Text;
        createdAt: Nat64;
        votesYes: Nat;
        votesNo: Nat;
        executed: Bool;
        rejected: Bool;
        expired: Bool;
        executionOutcome: ?Text;
    };

    public type GovernanceManager = {
        propose: (Principal, Text) -> async Result.Result<Proposal, Text>;
        vote: (Principal, Nat, Bool, Nat) -> async Result.Result<(), Text>;
        executeProposal: (Nat) -> async Result.Result<Text, Text>;
        rejectProposal: (Nat, Text) -> async Result.Result<(), Text>;
        checkProposalExpiry: (Nat) -> async Result.Result<(), Text>;
        getProposal: (Nat) -> async Result.Result<Proposal, Text>;
        getAllProposals: () -> async [Proposal];
    };

    public class GovernanceModule(eventManager: EventManager.EventManager) : GovernanceManager {
        private var proposals: [Proposal] = [];
        private var nextProposalId: Nat = 1;

        // Emit a governance-related event
        private func emitGovernanceEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload) : async () {
            let event: EventTypes.Event = {
                id = Nat64.fromNat(nextProposalId);
                eventType = eventType;
                payload = payload;
            };
            await eventManager.emit(event);
        };

        // Create a new proposal
        public func propose(proposer: Principal, description: Text) : async Result.Result<Proposal, Text> {
            if (description.size() == 0) {
                return #err("Proposal description cannot be empty.");
            };

            let proposal: Proposal = {
                id = nextProposalId;
                proposer = proposer;
                description = description;
                createdAt = Nat64.fromIntWrap(Time.now());
                votesYes = 0;
                votesNo = 0;
                executed = false;
                rejected = false;
                expired = false;
                executionOutcome = null;
            };
            proposals := Array.append(proposals, [proposal]);
            nextProposalId += 1;

            // Emit ProposalCreated event
            await emitGovernanceEvent(#ProposalCreated, #ProposalCreated({
                proposalId = proposal.id;
                proposer = Principal.toText(proposer);
                description = description;
                createdAt = proposal.createdAt;
            }));

            #ok(proposal)
        };

       public func vote(voter: Principal, proposalId: Nat, isYes: Bool, weight: Nat) : async Result.Result<(), Text> {
    let proposalOpt = Array.find<Proposal>(proposals, func(p: Proposal): Bool { p.id == proposalId });
    switch (proposalOpt) {
        case null {
            return #err("Proposal not found.");
        };
        case (?proposal) {
            if (proposal.executed or proposal.rejected or proposal.expired) {
                return #err("Cannot vote on finalized or expired proposals.");
            };

            let updatedProposal = if (isYes) {
                { proposal with votesYes = proposal.votesYes + weight }
            } else {
                { proposal with votesNo = proposal.votesNo + weight }
            };

            // Update the proposal in the proposals array
            proposals := Array.map<Proposal, Proposal>(proposals, func (p: Proposal): Proposal {
                if (p.id == proposalId) { updatedProposal } else { p }
            });

            // Emit ProposalVoted event
            await emitGovernanceEvent(#ProposalVoted, #ProposalVoted({
                proposalId = proposalId;
                voter = Principal.toText(voter);
                vote = if (isYes) "Yes" else "No";
                weight = weight;
                votedAt = Nat64.fromIntWrap(Time.now());
            }));

            #ok(())
        };
    };
};

        // Execute a proposal
        public func executeProposal(proposalId: Nat) : async Result.Result<Text, Text> {
    let proposalOpt = Array.find<Proposal>(proposals, func(p: Proposal): Bool { p.id == proposalId });
    switch (proposalOpt) {
        case null {
            return #err("Proposal not found.");
        };
        case (?proposal) {
            if (proposal.executed or proposal.rejected or proposal.expired) {
                return #err("Cannot execute a finalized or expired proposal.");
            };

            // Example logic for execution: pass if more "Yes" than "No" votes
            let (executed, executionOutcome, outcome) = if (proposal.votesYes > proposal.votesNo) {
                (true, ?("Success"), "Success")
            } else {
                (true, ?("Failure"), "Failure")
            };

            let updatedProposal = {
                proposal with
                executed = executed;
                executionOutcome = executionOutcome;
            };

            // Update the proposal in the proposals array
            proposals := Array.map<Proposal, Proposal>(proposals, func (p: Proposal): Proposal {
                if (p.id == proposalId) { updatedProposal } else { p }
            });

            // Emit ProposalExecuted event
            await emitGovernanceEvent(#ProposalExecuted, #ProposalExecuted({
                proposalId = proposalId;
                executedAt = Nat64.fromIntWrap(Time.now());
                outcome = outcome;
            }));

            if (outcome == "Success") {
                #ok("Proposal executed successfully.")
            } else {
                #err("Proposal execution failed due to insufficient support.")
            }
        };
    };
};

        public func rejectProposal(proposalId: Nat, reason: Text) : async Result.Result<(), Text> {
    let proposalOpt = Array.find<Proposal>(proposals, func(p: Proposal): Bool { p.id == proposalId });
    switch (proposalOpt) {
        case null {
            return #err("Proposal not found.");
        };
        case (?proposal) {
            if (proposal.executed or proposal.rejected or proposal.expired) {
                return #err("Cannot reject a finalized or expired proposal.");
            };

            let updatedProposal = {
                proposal with
                rejected = true;
            };

            // Update the proposal in the proposals array
            proposals := Array.map<Proposal, Proposal>(proposals, func (p: Proposal): Proposal {
                if (p.id == proposalId) { updatedProposal } else { p }
            });

            // Emit ProposalRejected event
            await emitGovernanceEvent(#ProposalRejected, #ProposalRejected({
                proposalId = proposalId;
                rejectedAt = Nat64.fromIntWrap(Time.now());
                reason = reason;
            }));

            #ok(())
        };
    };
};

        public func checkProposalExpiry(proposalId: Nat) : async Result.Result<(), Text> {
    let proposalOpt = Array.find(proposals, func(p: Proposal): Bool { p.id == proposalId });
    switch (proposalOpt) {
        case null {
            return #err("Proposal not found.");
        };
        case (?proposal) {
            let currentTime = Time.now();
            let expirationTime = Nat64.toNat(proposal.createdAt) + 7 * 24 * 60 * 60 * 1_000_000_000; // 7 days in nanoseconds

            if (currentTime > expirationTime) {
                let updatedProposal = {
                    proposal with
                    expired = true;
                };
                
                // Update the proposal in the proposals array
                proposals := Array.map<Proposal, Proposal>(proposals, func (p: Proposal): Proposal {
                    if (p.id == proposal.id) { updatedProposal } else { p }
                });

                // Emit ProposalExpired event
                await emitGovernanceEvent(#ProposalExpired, #ProposalExpired({
                    proposalId = proposalId;
                    expiredAt = Nat64.fromIntWrap(Time.now());
                }));

                #ok(())
            } else {
                #err("Proposal has not yet expired.")
            };
        };
    };
};

        // Retrieve a specific proposal
        public func getProposal(proposalId: Nat) : async Result.Result<Proposal, Text> {
            let proposalOpt = Array.find(proposals, func(p: Proposal): Bool { p.id == proposalId });
            switch (proposalOpt) {
                case null #err("Proposal not found.");
                case (?proposal) #ok(proposal);
            };
        };

        // Retrieve all proposals
        public func getAllProposals() : async [Proposal] {
            proposals
        };
    };
};