import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Array "mo:base/Array";
import EventTypes "../../heartbeat/event_types";
import EventManager "../../heartbeat/event_manager";
import SharedTypes "../../shared_types";

module {
  public type GeneralProposal = {
    id: Nat;
    title: Text;
    description: Text;
    submittedBy: Principal;
    submittedAt: Nat64;
    approved: Bool;
    rejected: Bool;
    votesFor: Nat;
    votesAgainst: Nat;
    statusMessage: ?Text;
  };

  public type GeneralProposalManager = {
    submitGeneralProposal: (Principal, Text, Text) -> async Result.Result<GeneralProposal, Text>;
    // Additional functions will be added here.
  };

  public class GeneralProposalModule(eventManager: EventManager.EventManager) : GeneralProposalManager {
    private var proposals: [GeneralProposal] = [];
    private var nextId: Nat = 1;
    private var votes: [SharedTypes.GeneralVoteRecord] = [];
    private var proposalHistory: [(Nat, Text)] = [];
    private var flaggedProposals: [(Nat, Text)] = [];

    private func emitEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload): async () {
      let event: EventTypes.Event = {
        id = Nat64.fromNat(nextId);
        eventType = eventType;
        payload = payload;
      };
      await eventManager.emit(event);
    };

    public func submitGeneralProposal(
      submitter: Principal,
      title: Text,
      description: Text
    ): async Result.Result<GeneralProposal, Text> {
      if (title == "" or description == "") {
        return #err("Title and description cannot be empty.");
      };

      let proposal: GeneralProposal = {
        id = nextId;
        title = title;
        description = description;
        submittedBy = submitter;
        submittedAt = Nat64.fromIntWrap(Time.now());
        approved = false;
        rejected = false;
        votesFor = 0;
        votesAgainst = 0;
        statusMessage = null;
      };

      proposals := Array.append(proposals, [proposal]);
      nextId += 1;

      await emitEvent(#GeneralProposalSubmitted, #GeneralProposalSubmitted({
        proposalId = proposal.id;
        title = proposal.title;
        submittedBy = Principal.toText(submitter);
        submittedAt = proposal.submittedAt;
      }));

      return #ok(proposal);
    };

    public func getGeneralProposal(proposalId: Nat): async Result.Result<GeneralProposal, Text> {
  let found = Array.find<GeneralProposal>(proposals, func(p: GeneralProposal) : Bool {
    p.id == proposalId
  });

  switch (found) {
    case null return #err("Proposal not found.");
    case (?p) return #ok(p);
  };
};

public func listGeneralProposals(): async [GeneralProposal] {
  proposals
};

public func deleteGeneralProposal(proposalId: Nat, requestedBy: Principal): async Bool {
  let maybeProposal = Array.find<GeneralProposal>(proposals, func(p) = p.id == proposalId);

  switch (maybeProposal) {
    case null return false;
    case (?proposal) {
      if (proposal.submittedBy != requestedBy) {
        return false; // Only creator can delete
      };

      // Remove the proposal
      proposals := Array.filter<GeneralProposal>(proposals, func(p) = p.id != proposalId);
      return true;
    };
  };
};

public func castGeneralVote(proposalId: Nat, voter: Principal, choice: Bool): async Bool {
  let maybeProposal = Array.find<GeneralProposal>(proposals, func(p: GeneralProposal): Bool {
    p.id == proposalId
  });

  switch (maybeProposal) {
    case null return false;
    case (_) {
      // Prevent duplicate voting
      let alreadyVoted = Array.find<SharedTypes.GeneralVoteRecord>(votes, func(v) = v.proposalId == proposalId and v.voter == voter);
      if (alreadyVoted != null) return false;

      // Create the vote record
      let voteRecord: SharedTypes.GeneralVoteRecord = {
        proposalId = proposalId;
        voter = voter;
        choice = choice;
        timestamp = Nat64.fromIntWrap(Time.now());
      };

      // Store the vote
      votes := Array.append<SharedTypes.GeneralVoteRecord>(votes, [voteRecord]);

      // Update vote counts in proposals array
      proposals := Array.map<GeneralProposal, GeneralProposal>(proposals, func(p) {
        if (p.id == proposalId) {
          if (choice) {
            { p with votesFor = p.votesFor + 1 }
          } else {
            { p with votesAgainst = p.votesAgainst + 1 }
          }
        } else p
      });

      // Emit event
      await eventManager.emit({
        id = Nat64.fromNat(proposalId);
        eventType = #GeneralVoteCast;
        payload = #GeneralVoteCast({
          proposalId = proposalId;
          voter = Principal.toText(voter);
          choice = choice;
          timestamp = Nat64.fromIntWrap(Time.now());
        });
      });

      return true;
    };
  };
};

public func getGeneralVotes(proposalId: Nat) : async [SharedTypes.GeneralVoteRecord] {
  Array.filter<SharedTypes.GeneralVoteRecord>(
    votes,
    func(v: SharedTypes.GeneralVoteRecord): Bool {
      v.proposalId == proposalId
    }
  )
};

public func hasVoted(proposalId: Nat, voter: Principal) : async Bool {
  let existing = Array.find<SharedTypes.GeneralVoteRecord>(
    votes,
    func(v: SharedTypes.GeneralVoteRecord): Bool {
      v.proposalId == proposalId and v.voter == voter
    }
  );

  switch (existing) {
    case null return false;
    case (?_) return true;
  };
};

public func tallyGeneralProposal(proposalId: Nat): async SharedTypes.GeneralTallyResult {
  let voteRecords = Array.filter<SharedTypes.GeneralVoteRecord>(
    votes,
    func(v: SharedTypes.GeneralVoteRecord) = v.proposalId == proposalId
  );

  let yesVotes = Array.foldLeft<SharedTypes.GeneralVoteRecord, Nat>(
    voteRecords,
    0,
    func(accum, vote) {
      if (vote.choice) accum + 1 else accum
    }
  );

  let noVotes = Array.foldLeft<SharedTypes.GeneralVoteRecord, Nat>(
    voteRecords,
    0,
    func(accum, vote) {
      if (not vote.choice) accum + 1 else accum
    }
  );

  {
    yes = yesVotes;
    no = noVotes;
    total = yesVotes + noVotes;
  };
};

public func finalizeGeneralProposal(proposalId: Nat): async Result.Result<Text, Text> {
  let maybeProposal = Array.find<GeneralProposal>(proposals, func(p: GeneralProposal) = p.id == proposalId);

  switch (maybeProposal) {
    case null return #err("Proposal not found.");
    case (?proposal) {
      if (proposal.approved or proposal.rejected) {
        return #err("Proposal already finalized.");
      };

      let result = await tallyGeneralProposal(proposalId);

      let updatedProposal = if (result.yes > result.no) {
        {
          proposal with
          approved = true;
          statusMessage = ?"Proposal approved by majority vote.";
        };
      } else {
        {
          proposal with
          rejected = true;
          statusMessage = ?"Proposal rejected by majority vote.";
        };
      };

      switch (updatedProposal.statusMessage) {
  case (?msg) return #ok(msg);
  case null return #ok("Finalization complete.");
};
    };
  };
};

public func getGeneralProposalStatus(proposalId: Nat): async SharedTypes.GeneralProposalStatus {
  let maybeProposal = Array.find<GeneralProposal>(proposals, func(p: GeneralProposal) = p.id == proposalId);

  switch (maybeProposal) {
    case null return #NotFound;
    case (?p) {
      if (p.approved) return #Approved;
      if (p.rejected) return #Rejected;
      return #Pending;
    };
  };
};

public func getGeneralProposalHistory(proposalId: Nat): async [Text] {
  let history = Array.filter<(Nat, Text)>(
    proposalHistory,
    func(entry: (Nat, Text)) : Bool {
      entry.0 == proposalId
    }
  );
  Array.map<(Nat, Text), Text>(history, func(entry) = entry.1)
};

public func getGeneralVoteBreakdown(proposalId: Nat): async (Nat, Nat, Nat) {
  let yesVotes = Array.filter<SharedTypes.GeneralVoteRecord>(votes, func(v) = v.proposalId == proposalId and v.choice == true);
  let noVotes = Array.filter<SharedTypes.GeneralVoteRecord>(votes, func(v) = v.proposalId == proposalId and v.choice == false);
  let total = yesVotes.size() + noVotes.size();
  (yesVotes.size(), noVotes.size(), total)
};

public func flagGeneralProposal(proposalId: Nat, reason: Text): async Bool {
  if (Array.indexOf<(Nat, Text)>(
    (proposalId, reason),
    flaggedProposals,
    func(a, b) = a.0 == b.0
  ) != null) {
    return false;
  };

  flaggedProposals := Array.append(flaggedProposals, [(proposalId, reason)]);
  proposalHistory := Array.append(proposalHistory, [(proposalId, "Flagged - " # reason)]);

  await eventManager.emit({
    id = Nat64.fromNat(proposalId);
    eventType = #GeneralProposalFlagged;
    payload = #GeneralProposalFlagged({
      proposalId = proposalId;
      reason = reason;
      flaggedAt = Nat64.fromIntWrap(Time.now());
    })
  });

  true
};

public func resolveFlaggedProposal(proposalId: Nat, admin: Principal, resolution: Text): async Bool {
  let isFlagged = Array.indexOf<(Nat, Text)>(
    (proposalId, ""),
    flaggedProposals,
    func(a, b) = a.0 == b.0
  );

  switch (isFlagged) {
    case null return false;
    case (?_) {
      flaggedProposals := Array.filter<(Nat, Text)>(
        flaggedProposals,
        func(p) = p.0 != proposalId
      );

      proposalHistory := Array.append(proposalHistory, [(proposalId, "Resolved by " # Principal.toText(admin) # " - " # resolution)]);

      await eventManager.emit({
        id = Nat64.fromNat(proposalId);
        eventType = #GeneralProposalResolved;
        payload = #GeneralProposalResolved({
          proposalId = proposalId;
          resolvedBy = Principal.toText(admin);
          resolution = resolution;
          resolvedAt = Nat64.fromIntWrap(Time.now());
        })
      });

      return true;
    }
  }
};
  };
};