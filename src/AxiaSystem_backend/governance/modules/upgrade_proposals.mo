import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";
import SharedTypes "../../shared_types";

module {

    private let electionCanister : actor {
  createElection: (SharedTypes.ElectionConfig) -> async Nat;
  getElectionResults : shared Nat -> async ?SharedTypes.ElectionResult
} = actor("cgpjn-omaaa-aaaaa-qaakq-cai");

  public type UpgradeProposal = {
    id: Nat;
    canisterId: Principal;
    proposedVersion: Text;
    submitter: Principal;
    submittedAt: Nat64;
    approved: Bool;
    rejected: Bool;
    statusMessage: ?Text;
    electionId: ?Nat;
    emergencyOverride: Bool;
    executed: Bool;
  };

  public type UpgradeProposalManager = {
    proposeCanisterUpgrade: (Principal, Principal, Text) -> async Result.Result<UpgradeProposal, Text>;
    getUpgradeProposal: (Nat) -> async Result.Result<UpgradeProposal, Text>;
    listUpgradeProposals: () -> async [UpgradeProposal];
  };

  public class UpgradeProposalModule(eventManager: EventManager.EventManager) : UpgradeProposalManager {
    private var proposals: [UpgradeProposal] = [];
    private var nextId: Nat = 1;
    
    let adminCanisterId : Principal = Principal.fromText("u6s2n-gx777-77774-qaaba-cai");
    // Finalized proposal tracking
    var finalizedProposals: [Nat] = [];

    


    private func emitUpgradeEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload): async () {
      let event: EventTypes.Event = {
        id = Nat64.fromNat(nextId);
        eventType = eventType;
        payload = payload;
      };
      await eventManager.emit(event);
    };

    public func proposeCanisterUpgrade(
      submitter: Principal,
      canisterId: Principal,
      proposedVersion: Text
    ): async Result.Result<UpgradeProposal, Text> {
      if (proposedVersion == "") {
        return #err("Version cannot be empty.");
      };

      let proposal: UpgradeProposal = {
        id = nextId;
        canisterId = canisterId;
        proposedVersion = proposedVersion;
        submitter = submitter;
        submittedAt = Nat64.fromIntWrap(Time.now());
        approved = false;
        rejected = false;
        statusMessage = null;
        electionId = null;
        emergencyOverride = false;
        executed = false;
      };

      proposals := Array.append(proposals, [proposal]);
      nextId += 1;

      await emitUpgradeEvent(#UpgradeProposalCreated, #UpgradeProposalCreated({
        proposalId = proposal.id;
        canisterId = Principal.toText(canisterId);
        proposedVersion = proposedVersion;
        submitter = Principal.toText(submitter);
        submittedAt = proposal.submittedAt;
      }));

      #ok(proposal)
    };

    public func getUpgradeProposal(id: Nat): async Result.Result<UpgradeProposal, Text> {
 let found = Array.find<UpgradeProposal>(proposals, func(p: UpgradeProposal): Bool { p.id == id });
 switch (found) {
 case null #err("Upgrade proposal not found.");
 case (?p) #ok(p);
 }
};

    public func listUpgradeProposals(): async [UpgradeProposal] {
      proposals
    };

    public func approveUpgradeProposal(proposalId: Nat, approver: Principal): async Result.Result<UpgradeProposal, Text> {
    let found = Array.find(proposals, func(p: UpgradeProposal): Bool {
        p.id == proposalId
    });

    switch (found) {
        case null {
            #err("Upgrade proposal not found.")
        };
        case (?proposal) {
            if (proposal.approved or proposal.rejected) {
                return #err("Proposal already finalized.");
            };

            let updated = {
                proposal with
                approved = true;
                statusMessage = ?("Approved by " # Principal.toText(approver));
            };

            proposals := Array.map<UpgradeProposal, UpgradeProposal>(proposals, func(p) {
                if (p.id == proposalId) { updated } else { p }
            });

            await emitUpgradeEvent(#UpgradeProposalApproved, #UpgradeProposalApproved({
                proposalId = proposalId;
                approver = Principal.toText(approver);
                approvedAt = Nat64.fromIntWrap(Time.now());
                reason = "Upgrade approved via vote";
            }));

            #ok(updated)
        }
    }
};

public func rejectUpgradeProposal(
    proposalId: Nat,
    rejectedBy: Principal,
    reason: Text
) : async Result.Result<UpgradeProposal, Text> {
    let maybeProposal = Array.find<UpgradeProposal>(
        proposals,
        func(p: UpgradeProposal): Bool {
            p.id == proposalId
        }
    );

    switch (maybeProposal) {
        case null {
            return #err("Upgrade proposal not found.");
        };
        case (?proposal) {
            if (proposal.approved or proposal.rejected) {
                return #err("Proposal has already been finalized.");
            };

            let updated = {
                proposal with
                rejected = true;
                statusMessage = ?reason;
            };

            proposals := Array.map<UpgradeProposal, UpgradeProposal>(
                proposals,
                func(p: UpgradeProposal): UpgradeProposal {
                    if (p.id == proposalId) { updated } else { p }
                }
            );

            await emitUpgradeEvent(
                #UpgradeProposalRejected,
                #UpgradeProposalRejected({
                    proposalId = proposalId;
                    rejectedBy = Principal.toText(rejectedBy);
                    rejectedAt = Nat64.fromIntWrap(Time.now());
                    reason = reason;
                })
            );

            return #ok(updated);
        }
    }
};

public func executeUpgradeProposal(proposalId: Nat) : async Result.Result<UpgradeProposal, Text> {
    let maybeProposal = Array.find<UpgradeProposal>(proposals, func(p: UpgradeProposal): Bool {
        p.id == proposalId
    });

    switch (maybeProposal) {
        case null {
            return #err("Upgrade proposal not found.");
        };
        case (?proposal) {
            if (proposal.approved == false or proposal.rejected) {
                return #err("Proposal must be approved and not rejected to be executed.");
            };

            // Simulate success execution
            let outcome: Text = "Upgrade executed successfully.";

            let updated = {
                proposal with
                statusMessage = ?outcome
            };

            // Update the proposal list
            proposals := Array.map<UpgradeProposal, UpgradeProposal>(proposals, func(p: UpgradeProposal): UpgradeProposal {
                if (p.id == proposalId) { updated } else { p }
            });

            await emitUpgradeEvent(#UpgradeProposalExecuted, #UpgradeProposalExecuted({
                proposalId = proposalId;
                executedAt = Nat64.fromIntWrap(Time.now());
                outcome = outcome;
            }));

            return #ok(updated);
        }
    }
};

public func createUpgradeElection(proposalId: Nat) : async Result.Result<UpgradeProposal, Text> {
    let found = Array.find<UpgradeProposal>(proposals, func(p: UpgradeProposal) = p.id == proposalId);

    switch (found) {
        case null {
            return #err("Proposal not found.");
        };
        case (?proposal) {
            if (proposal.rejected or proposal.approved) {
                return #err("Proposal has already been finalized.");
            };

            // Build election config using AxiaVote-compatible fields
            let config: SharedTypes.ElectionConfig = {
                name = "Upgrade Approval - " # Principal.toText(proposal.canisterId);
                startTime = Nat64.toNat(Nat64.fromIntWrap(Time.now()));
                endTime = Nat64.toNat(Nat64.fromIntWrap(Time.now() + 3 * 24 * 60 * 60 * 1_000_000_000)); // 3 days from now
                candidates = ["Approve Upgrade", "Reject Upgrade"];
                creator = proposal.submitter;
                electionType = #Government;
                voteWeighting = null;
                encryption = #BasicEncryption;
            };

            // Cross-canister call to create the election in AxiaVote
            let electionId = await electionCanister.createElection(config);

            // Update the local proposal with the electionId
            proposals := Array.map<UpgradeProposal, UpgradeProposal>(proposals, func(p: UpgradeProposal) {
                if (p.id == proposalId) {
                    { p with electionId = ?electionId }
                } else {
                    p
                }
            });

            // Emit UpgradeElectionCreated event
            await emitUpgradeEvent(#UpgradeElectionCreated, #UpgradeElectionCreated({
                proposalId = proposalId;
                electionId = electionId;
                triggeredAt = Nat64.fromIntWrap(Time.now());
            }));

            // Return the updated proposal
            let updatedProposal = Array.find<UpgradeProposal>(proposals, func(p: UpgradeProposal) = p.id == proposalId);
            switch (updatedProposal) {
                case (?p) #ok(p);
                case null #err("Proposal linked to election but could not be retrieved.");
            };
        };
    };
};

public func syncUpgradeVoteResult(proposalId: Nat) : async Result.Result<Text, Text> {
    let maybeProposal = Array.find<UpgradeProposal>(proposals, func(p) = p.id == proposalId);
    switch (maybeProposal) {
        case null return #err("Upgrade proposal not found.");
        case (?proposal) {
            let maybeElectionId = proposal.electionId;
            switch (maybeElectionId) {
                case null return #err("No election linked to this proposal.");
                case (?electionId) {
                    let resultOpt = await electionCanister.getElectionResults(electionId);
                    switch (resultOpt) {
                        case null return #err("Election results not yet available.");
                        case (?result) {
                            switch (result.winner) {
                                case null return #err("Election has no declared winner.");
                                case (?winner) {
                                    if (winner == "Approve Upgrade") {
                                        let updated = {
                                            proposal with
                                            approved = true;
                                            statusMessage = ?"Upgrade approved via election."
                                        };
                                        proposals := Array.map<UpgradeProposal, UpgradeProposal>(proposals, func(p: UpgradeProposal): UpgradeProposal {
    if (p.id == proposalId) { updated } else { p }
});

                                        await emitUpgradeEvent(#UpgradeProposalApproved, #UpgradeProposalApproved({
                                            proposalId = proposalId;
                                            approver = "Election"; // System flag
                                            approvedAt = Nat64.fromIntWrap(Time.now());
                                            reason = "Upgrade approved via vote";
                                        }));

                                        return #ok("Upgrade approved based on vote.");
                                    } else {
                                        let updated = {
                                            proposal with
                                            rejected = true;
                                            statusMessage = ?"Upgrade rejected via election."
                                        };
                                        proposals := Array.map<UpgradeProposal, UpgradeProposal>(proposals, func(p: UpgradeProposal): UpgradeProposal {
    if (p.id == proposalId) { updated } else { p }
});

                                        await emitUpgradeEvent(#UpgradeProposalRejected, #UpgradeProposalRejected({
                                            proposalId = proposalId;
                                            rejectedBy = "Election";
                                            rejectedAt = Nat64.fromIntWrap(Time.now());
                                            reason = "Upgrade rejected via vote";
                                        }));

                                        return #ok("Upgrade rejected based on vote.");
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    };
};

public func emergencyExecuteUpgradeProposal(proposalId: Nat, caller: Principal): async Result.Result<UpgradeProposal, Text> {
  if (Principal.toText(caller) != Principal.toText(adminCanisterId)) {
    return #err("Unauthorized: Only Admin Canister may perform emergency execution.");
  };

  let maybeProposal = Array.find<UpgradeProposal>(proposals, func(p: UpgradeProposal) = p.id == proposalId);
  switch (maybeProposal) {
    case null return #err("Upgrade proposal not found.");
    case (?proposal) {
      let updated = {
        proposal with
        emergencyOverride = true;
        statusMessage = ?"Emergency override triggered";
      };

      proposals := Array.map<UpgradeProposal, UpgradeProposal>(proposals, func(p: UpgradeProposal): UpgradeProposal {
        if (p.id == proposalId) { updated } else { p }
      });

      return await executeUpgradeProposal(proposalId);
    };
  };
};




public func markProposalAsFinalized(proposalId: Nat) : async Result.Result<Bool, Text> {
  let alreadyFinalized: ?Nat = Array.indexOf<Nat>(
    proposalId,
    finalizedProposals,
    func(a: Nat, b: Nat) : Bool { a == b }
  );

  switch (alreadyFinalized) {
    case (?_) return #err("Proposal already finalized.");
    case null {
      finalizedProposals := Array.append<Nat>(finalizedProposals, [proposalId]);
      return #ok(true);
    };
  };
};

public func listPendingUpgradeElectionSyncs() : async [UpgradeProposal] {
  Array.filter<UpgradeProposal>(proposals, func(p: UpgradeProposal) : Bool {
    let alreadyFinalized: ?Nat = Array.indexOf<Nat>(
    p.id,
    finalizedProposals,
      
      func(a: Nat, b: Nat) : Bool { a == b }
    );

    p.electionId != null and
    not p.approved and
    not p.rejected and
    alreadyFinalized == null
  })
};

public func monitorPendingUpgradeElections() : async () {
  let pending = await listPendingUpgradeElectionSyncs();
  for (p in pending.vals()) {
    let _ = await syncUpgradeVoteResult(p.id); // Ignore individual errors
  }
};

public func listExecutableProposals() : async [UpgradeProposal] {
  Array.filter<UpgradeProposal>(proposals, func(p) {
    p.approved and not p.rejected and not p.executed
  });
};


public func hasBeenExecuted(proposalId: Nat) : async Bool {
  let found = Array.find<UpgradeProposal>(proposals, func(p) {
    p.id == proposalId
  });

  switch (found) {
    case (?p) return p.executed;
    case null return false;
  };
};

public func getExecutionStatus(proposalId: Nat) : async Text {
  let found = Array.find<UpgradeProposal>(proposals, func(p) {
    p.id == proposalId
  });

  switch (found) {
    case (?p) {
      if (p.executed) return "executed";
      if (p.approved) return "approved";
      if (p.rejected) return "rejected";
      return "pending";
    };
    case null return "not_found";
  };
};

public func autoFinalizeExecutedProposals() : async () {
  let toFinalize = Array.filter<UpgradeProposal>(proposals, func(p: UpgradeProposal) : Bool {
    p.executed and Array.indexOf<Nat>(
      p.id,
      finalizedProposals,
      func(a: Nat, b: Nat) : Bool { a == b }
    ) == null
  });

  for (p in toFinalize.vals()) {
    finalizedProposals := Array.append<Nat>(finalizedProposals, [p.id]);

    await emitUpgradeEvent(
      #UpgradeProposalFinalized,
      #UpgradeProposalFinalized({
        proposalId = p.id;
        finalizedAt = Nat64.fromIntWrap(Time.now());
      })
    );
  };
};

public func enableEmergencyOverride(proposalId: Nat, caller: Principal): async Result.Result<UpgradeProposal, Text> {
  if (Principal.toText(caller) != Principal.toText(adminCanisterId)) {
    return #err("Unauthorized: Only Admin Canister may enable emergency override.");
  };

  let maybeProposal = Array.find<UpgradeProposal>(proposals, func(p: UpgradeProposal) = p.id == proposalId);
  switch (maybeProposal) {
    case null return #err("Upgrade proposal not found.");
    case (?proposal) {
      if (proposal.emergencyOverride) {
        return #err("Emergency override already enabled.");
      };

      let updated = {
        proposal with
        emergencyOverride = true;
        statusMessage = ?"Emergency override enabled manually"
      };

      proposals := Array.map<UpgradeProposal, UpgradeProposal>(proposals, func(p: UpgradeProposal): UpgradeProposal {
  if (p.id == proposalId) { updated } else { p }
});

      await emitUpgradeEvent(
        #EmergencyOverrideEnabled,
        #EmergencyOverrideEnabled({
          proposalId = proposalId;
          enabledBy = Principal.toText(caller);
          timestamp = Nat64.fromIntWrap(Time.now());
        })
      );

      #ok(updated)
    }
  }
};
};
};