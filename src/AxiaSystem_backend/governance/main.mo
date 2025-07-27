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
import GeneralProposals "modules/general_proposals";
import UpgradeEngineModule "modules/upgrade_engine";
import SharedTypes "../shared_types";
import MonitorModule "modules/monitor";

// 🧠 NamoraAI Observability Imports
import Insight "../types/insight";
import Time "mo:base/Time";
import Debug "mo:base/Debug";

persistent actor GovernanceCanister {

    // 🧠 NamoraAI Observability Helper
    private func emitInsight(severity: Text, message: Text) : async () {
        let _insight : Insight.SystemInsight = {
            source = "governance";
            severity = severity;
            message = message;
            timestamp = Time.now();
        };
        Debug.print("🧠 GOVERNANCE INSIGHT [" # severity # "]: " # message);
        // await NamoraAI.pushInsight(insight);
    };

    // Dependencies
    private transient let eventManager = EventManager.EventManager();
    private transient let logStore = LoggingUtils.init();

    // Governance Manager
    private transient let governanceManager = GovernanceModule.GovernanceModule(eventManager);

    transient let upgradeProposals = UpgradeProposals.UpgradeProposalModule(eventManager);
    transient let generalProposalModule = GeneralProposals.GeneralProposalModule(eventManager);

    transient let upgradeEngine = UpgradeEngineModule.UpgradeEngine();

    transient let monitor = MonitorModule.Monitor(eventManager);

    // Public APIs

    system func heartbeat() : async () {
      await emitInsight("info", "Governance heartbeat monitoring cycle initiated");
      await upgradeProposals.monitorPendingUpgradeElections();
      await upgradeProposals.autoFinalizeExecutedProposals ();
      let queueLen = await eventManager.getEventQueueLength();
      
      if (queueLen > 100) {
        await emitInsight("warning", "High event queue length detected: " # Nat.toText(queueLen) # " events pending");
      };
      
      await monitor.runHealthCheck(queueLen);
    };

    // Create a new proposal
    public func propose(
        proposer: Principal,
        description: Text
    ): async Result.Result<GovernanceModule.Proposal, Text> {
        await emitInsight("info", "New governance proposal submitted by: " # Principal.toText(proposer));
        
        try {
            let result = await governanceManager.propose(proposer, description);
            switch result {
                case (#ok(proposal)) {
                    LoggingUtils.logInfo(logStore, "GovernanceCanister", "Proposal created successfully: " # Nat.toText(proposal.id), ?proposer);
                    await emitInsight("info", "Governance proposal #" # Nat.toText(proposal.id) # " successfully created by " # Principal.toText(proposer));
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

public shared({ caller = _ }) func syncUpgradeVoteResult(proposalId: Nat) : async Result.Result<Text, Text> {
    await upgradeProposals.syncUpgradeVoteResult(proposalId);
};

public shared({ caller }) func emergencyExecuteUpgradeProposal(proposalId: Nat): async Result.Result<UpgradeProposals.UpgradeProposal, Text> {
  await upgradeProposals.emergencyExecuteUpgradeProposal(proposalId, caller);
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

  public shared func monitorPendingUpgradeElections() : async () {
  await upgradeProposals.monitorPendingUpgradeElections();
};

public shared ({ caller = _ }) func markProposalAsFinalized(proposalId: Nat) : async Result.Result<Bool, Text> {
  await upgradeProposals.markProposalAsFinalized(proposalId);
};

public shared func listPendingUpgradeElectionSyncs() : async [UpgradeProposals.UpgradeProposal] {
 await upgradeProposals.listPendingUpgradeElectionSyncs();
};

// ✅ Get list of executable proposals
public shared func listExecutableProposals() : async [UpgradeProposals.UpgradeProposal] {
  await upgradeProposals.listExecutableProposals();
};

// ✅ Check if a proposal has been executed
public shared func hasBeenExecuted(proposalId: Nat) : async Bool {
  await upgradeProposals.hasBeenExecuted(proposalId);
};

// ✅ Get current execution status
public shared func getExecutionStatus(proposalId: Nat) : async Text {
  await upgradeProposals.getExecutionStatus(proposalId);
};

public shared({ caller = _ }) func autoFinalizeExecutedProposals() : async () {
  await upgradeProposals.autoFinalizeExecutedProposals();
};

public shared({ caller }) func submitGeneralProposal( title: Text, 
description: Text
): async Result.Result<GeneralProposals.GeneralProposal, Text> {
  await generalProposalModule.submitGeneralProposal(caller, title, description);
};

public shared func getGeneralProposal(proposalId: Nat): async Result.Result<GeneralProposals.GeneralProposal, Text> {
  await generalProposalModule.getGeneralProposal(proposalId);
};

public shared func listGeneralProposals(): async [GeneralProposals.GeneralProposal] {
  await generalProposalModule.listGeneralProposals();
};

public shared({ caller }) func deleteGeneralProposal(proposalId: Nat): async Bool {
  await generalProposalModule.deleteGeneralProposal(proposalId, caller);
};

public shared ({ caller }) func castGeneralVote(proposalId: Nat, choice: Bool): async Bool {
  await generalProposalModule.castGeneralVote(proposalId, caller, choice);
};

public shared func getGeneralVotes(proposalId: Nat) : async [SharedTypes.GeneralVoteRecord] {
  await generalProposalModule.getGeneralVotes(proposalId);
};

public shared func hasVoted(proposalId: Nat, voter: Principal) : async Bool {
  await generalProposalModule.hasVoted(proposalId, voter);
};

public shared func getGeneralProposalStatus(proposalId: Nat): async SharedTypes.GeneralProposalStatus {
  await generalProposalModule.getGeneralProposalStatus(proposalId);
};

public shared func finalizeGeneralProposal(proposalId: Nat): async Result.Result<Text, Text> {
  await generalProposalModule.finalizeGeneralProposal(proposalId);
};

public shared func tallyGeneralProposal(proposalId: Nat): async SharedTypes.GeneralTallyResult {
  await generalProposalModule.tallyGeneralProposal(proposalId);
};

public shared func getGeneralProposalHistory(proposalId: Nat) : async [Text] {
  await generalProposalModule.getGeneralProposalHistory(proposalId);
};

public shared func getGeneralVoteBreakdown(proposalId: Nat) : async (Nat, Nat, Nat) {
  await generalProposalModule.getGeneralVoteBreakdown(proposalId);
};

public shared({ caller = _}) func flagGeneralProposal(proposalId: Nat, reason: Text) : async Bool {
  await generalProposalModule.flagGeneralProposal(proposalId, reason);
};

public shared({ caller }) func resolveFlaggedProposal(proposalId: Nat, resolution: Text) : async Bool {
  await generalProposalModule.resolveFlaggedProposal(proposalId, caller, resolution);
};

public shared({ caller = _ }) func registerCanisterForUpgrade(canisterId: Principal): async Bool {
  await upgradeEngine.registerCanisterForUpgrade(canisterId);
};

public shared func getRegisteredUpgradeTargets(): async [Principal] {
  await upgradeEngine.getRegisteredUpgradeTargets();
};

// Upload Wasm
public shared({ caller = _ }) func uploadUpgradeWasm(canisterId: Principal, version: Text, wasmModule: Blob): async Bool {
  await upgradeEngine.uploadUpgradeWasm(canisterId, version, wasmModule);
};

// Get version of uploaded Wasm
public shared func getWasmVersion(canisterId: Principal): async ?Text {
  await upgradeEngine.getWasmVersion(canisterId);
};

// Get actual Wasm Blob
public shared func getStoredWasm(canisterId: Principal): async ?Blob {
  await upgradeEngine.getStoredWasm(canisterId);
};

public shared({ caller = _ }) func executeUpgrade(canisterId: Principal): async Result.Result<Text, Text> {
  await upgradeEngine.executeUpgrade(canisterId);
};

public shared func verifyUpgradeIntegrity(canisterId: Principal): async Bool {
  await upgradeEngine.verifyUpgradeIntegrity(canisterId);
};

public shared({ caller = _ }) func rollbackUpgrade(canisterId: Principal): async Result.Result<Text, Text> {
  await upgradeEngine.rollbackUpgrade(canisterId);
};

public shared func listUpgradeHistory(canisterId: Principal): async [Text] {
  await upgradeEngine.listUpgradeHistory(canisterId);
};

 public func reportGovernanceError(errorMsg: Text) : async () {
    monitor.logError(errorMsg);
  };

  public func reportVotingAnomaly() : async () {
    monitor.logVotingAnomaly();
  };
};