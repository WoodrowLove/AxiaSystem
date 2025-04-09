import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
  public type UpgradeProposal = {
    id: Nat;
    canisterId: Principal;
    proposedVersion: Text;
    submitter: Principal;
    submittedAt: Nat64;
    approved: Bool;
    rejected: Bool;
    statusMessage: ?Text;
  };

  public type UpgradeProposalManager = {
    proposeCanisterUpgrade: (Principal, Principal, Text) -> async Result.Result<UpgradeProposal, Text>;
    getUpgradeProposal: (Nat) -> async Result.Result<UpgradeProposal, Text>;
    listUpgradeProposals: () -> async [UpgradeProposal];
  };

  public class UpgradeProposalModule(eventManager: EventManager.EventManager) : UpgradeProposalManager {
    private var proposals: [UpgradeProposal] = [];
    private var nextId: Nat = 1;

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
  };
};