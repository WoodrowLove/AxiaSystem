import GovernanceModule "./modules/governance_module";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import LoggingUtils "../utils/logging_utils";
import UpgradeProposals "modules/upgrade_proposals";

actor GovernanceCanister {
    // Dependencies
    private let eventManager = EventManager.EventManager();
    private let logStore = LoggingUtils.init();

    // Governance Manager
    private let governanceManager = GovernanceModule.GovernanceModule(eventManager);

    let upgradeProposals = UpgradeProposals.UpgradeProposalModule(eventManager);

    // Public APIs

    // Create a new proposal
    public func propose(
        proposer: Principal,
        description: Text
    ): async Result.Result<GovernanceModule.Proposal, Text> {
        try {
            let result = await governanceManager.propose(proposer, description);
            switch result {
                case (#ok(proposal)) {
                    LoggingUtils.logInfo(logStore, "GovernanceCanister", "Proposal created successfully: " # Nat.toText(proposal.id), ?proposer);
                    #ok(proposal)
                };
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "GovernanceCanister", "Failed to create proposal: " # e, ?proposer);
                    #err(e)
                };
            }
        } catch (error) {
            let errorMessage = Error.message(error);
            LoggingUtils.logError(logStore, "GovernanceCanister", "Unexpected error while creating proposal: " # errorMessage, ?proposer);
            #err("Unexpected error: " # errorMessage)
        };
    };

    // Vote on a proposal
    public func vote(
        voter: Principal,
        proposalId: Nat,
        isYes: Bool,
        weight: Nat
    ): async Result.Result<(), Text> {
        try {
            let result = await governanceManager.vote(voter, proposalId, isYes, weight);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(logStore, "GovernanceCanister", "Vote registered successfully for proposal: " # Nat.toText(proposalId), ?voter);
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "GovernanceCanister", "Failed to register vote: " # e, ?voter);
                    #err(e)
                };
            }
        } catch (error) {
            let errorMessage = Error.message(error);
            LoggingUtils.logError(logStore, "GovernanceCanister", "Unexpected error while voting: " # errorMessage, ?voter);
            #err("Unexpected error: " # errorMessage)
        };
    };

    // Execute a proposal
    public func executeProposal(proposalId: Nat): async Result.Result<Text, Text> {
        try {
            let result = await governanceManager.executeProposal(proposalId);
            switch result {
                case (#ok(outcome)) {
                    LoggingUtils.logInfo(logStore, "GovernanceCanister", "Proposal executed successfully: " # outcome, null);
                    #ok(outcome)
                };
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "GovernanceCanister", "Failed to execute proposal: " # e, null);
                    #err(e)
                };
            }
        } catch (error) {
            let errorMessage = Error.message(error);
            LoggingUtils.logError(logStore, "GovernanceCanister", "Unexpected error while executing proposal: " # errorMessage, null);
            #err("Unexpected error: " # errorMessage)
        };
    };

    // Reject a proposal
    public func rejectProposal(proposalId: Nat, reason: Text): async Result.Result<(), Text> {
        try {
            let result = await governanceManager.rejectProposal(proposalId, reason);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(logStore, "GovernanceCanister", "Proposal rejected successfully: " # Nat.toText(proposalId), null);
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "GovernanceCanister", "Failed to reject proposal: " # e, null);
                    #err(e)
                };
            }
        } catch (error) {
            let errorMessage = Error.message(error);
            LoggingUtils.logError(logStore, "GovernanceCanister", "Unexpected error while rejecting proposal: " # errorMessage, null);
            #err("Unexpected error: " # errorMessage)
        };
    };

    // Check if a proposal has expired
    public func checkProposalExpiry(proposalId: Nat): async Result.Result<(), Text> {
        try {
            let result = await governanceManager.checkProposalExpiry(proposalId);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(logStore, "GovernanceCanister", "Proposal expiry checked: " # Nat.toText(proposalId), null);
                    #ok(())
                };
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "GovernanceCanister", "Failed to check proposal expiry: " # e, null);
                    #err(e)
                };
            }
        } catch (error) {
            let errorMessage = Error.message(error);
            LoggingUtils.logError(logStore, "GovernanceCanister", "Unexpected error while checking proposal expiry: " # errorMessage, null);
            #err("Unexpected error: " # errorMessage)
        };
    };

    public query func getProposal(proposalId: Nat): async Result.Result<GovernanceModule.Proposal, Text> {
    governanceManager.getProposalSync(proposalId)
};

public query func getAllProposals(): async [GovernanceModule.Proposal] {
    governanceManager.getAllProposalsSync()
};

public shared ({ caller }) func proposeCanisterUpgrade(
  canisterId: Principal,
  proposedVersion: Text
): async Result.Result<UpgradeProposals.UpgradeProposal, Text> {
  await upgradeProposals.proposeCanisterUpgrade(caller, canisterId, proposedVersion);
};

 public shared({ caller }) func approveUpgradeProposal(proposalId: Nat): async Result.Result<UpgradeProposals.UpgradeProposal, Text> {
   await upgradeProposals.approveUpgradeProposal(proposalId, caller);
  };

  public shared ({ caller }) func rejectUpgradeProposal(proposalId: Nat, reason: Text): async Result.Result<UpgradeProposals.UpgradeProposal, Text> {
    await upgradeProposals.rejectUpgradeProposal(proposalId, caller, reason);
};

public shared({ caller = _ }) func executeUpgradeProposal(
  proposalId: Nat
): async Result.Result<UpgradeProposals.UpgradeProposal, Text> {
  await upgradeProposals.executeUpgradeProposal(proposalId);
};

public shared({ caller =_ }) func createUpgradeElection(proposalId: Nat) : async Result.Result<Nat, Text> {
  let result = await upgradeProposals.createUpgradeElection(proposalId);
  switch (result) {
    case (#ok(proposal)) {
      switch (proposal.electionId) {
        case (?id) #ok(id);
        case null #err("Election was created but no ID was returned.");
      }
    };
    case (#err(msg)) #err(msg);
  }
};


     public shared func onProposalEvent(event: EventTypes.Event): async () {
    switch (event.payload) {
      case (#ProposalCreated { proposalId; proposer; description; createdAt }) {
        LoggingUtils.logInfo(
          logStore,
          "GovernanceCanister",
          "Proposal Created: ID=" # Nat.toText(proposalId) # 
          ", Proposer=" # proposer # 
          ", Description=" # description # 
          ", CreatedAt=" # Nat64.toText(createdAt),
          null
        );
      };
      case (#ProposalVoted { proposalId; voter; vote; weight; votedAt }) {
        LoggingUtils.logInfo(
          logStore,
          "GovernanceCanister",
          "Vote Cast: Proposal=" # Nat.toText(proposalId) # 
          ", Voter=" # voter # 
          ", Vote=" # vote # 
          ", Weight=" # Nat.toText(weight) # 
          ", VotedAt=" # Nat64.toText(votedAt),
          null
        );
      };
      case (#ProposalExecuted { proposalId; executedAt; outcome }) {
        LoggingUtils.logInfo(
          logStore,
          "GovernanceCanister",
          "Proposal Executed: ID=" # Nat.toText(proposalId) # 
          ", ExecutedAt=" # Nat64.toText(executedAt) # 
          ", Outcome=" # outcome,
          null
        );
      };
      case (#ProposalRejected { proposalId; rejectedAt; reason }) {
        LoggingUtils.logInfo(
          logStore,
          "GovernanceCanister",
          "Proposal Rejected: ID=" # Nat.toText(proposalId) # 
          ", RejectedAt=" # Nat64.toText(rejectedAt) # 
          ", Reason=" # reason,
          null
        );
      };
      case (#ProposalExpired { proposalId; expiredAt }) {
        LoggingUtils.logInfo(
          logStore,
          "GovernanceCanister",
          "Proposal Expired: ID=" # Nat.toText(proposalId) # 
          ", ExpiredAt=" # Nat64.toText(expiredAt),
          null
        );
      };
      case (_) {};
    };
  };

  public func initializeEventListeners(): async () {
    // Use the public shared function to subscribe to events
    await eventManager.subscribe(#ProposalCreated, onProposalEvent);
    await eventManager.subscribe(#ProposalVoted, onProposalEvent);
    await eventManager.subscribe(#ProposalExecuted, onProposalEvent);
    await eventManager.subscribe(#ProposalRejected, onProposalEvent);
    await eventManager.subscribe(#ProposalExpired, onProposalEvent);
  };
};