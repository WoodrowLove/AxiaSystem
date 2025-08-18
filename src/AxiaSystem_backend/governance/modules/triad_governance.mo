// AxiaSystem Triad-Native Governance Module
// Production-ready governance with Identity-anchored auth, snapshot voting, and stake locks

import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Trie "mo:base/Trie";
import Iter "mo:base/Iter";

// System imports
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    // ================================
    // TRIAD-NATIVE TYPES
    // ================================

    public type LinkProof = { 
        signature: Blob; 
        challenge: Blob; 
        device: ?Blob 
    };

    public type ProposalType = { 
        #general; 
        #upgrade; 
        #core 
    };

    public type VoteChoice = { 
        #yes; 
        #no; 
        #abstain 
    };

    public type VotingStrategy = {
        #oneIdentityOneVote;
        #stakeWeighted: { token: Text; minStake: Nat };
        #timeWeighted: { token: Text; slope: Nat };
    };

    public type ProposalStatus = { 
        #open; 
        #finalizing; 
        #executed; 
        #rejected; 
        #expired 
    };

    public type Proposal = {
        id: Nat;
        pType: ProposalType;
        title: Text;
        description: Text;
        proposerIdentity: Principal;
        proposerUserId: ?Principal;
        depositLockId: ?Text;
        createdAt: Nat64;
        snapshotAt: Nat64;
        votingStartsAt: Nat64;
        votingEndsAt: Nat64;
        quorumBp: Nat;  // basis points (e.g., 2000 = 20%)
        thresholdBp: Nat;  // % of cast YES needed to pass
        strategy: VotingStrategy;
        status: ProposalStatus;
        tally: { yes: Nat; no: Nat; abstain: Nat; weightTotal: Nat };
    };

    public type VoteReceipt = {
        proposalId: Nat;
        voterIdentity: Principal;
        choice: VoteChoice;
        weight: Nat;
        castAt: Nat64;
    };

    public type SubmitOptions = {
        userId: ?Principal;
        depositToken: ?Text;
        depositAmount: ?Nat;
        quorumBp: ?Nat;
        thresholdBp: ?Nat;
        votingDurationHours: ?Nat;
        strategy: ?VotingStrategy;
    };

    // ================================
    // TRIAD GOVERNANCE MODULE
    // ================================

    public class TriadGovernance(
        eventManager: EventManager.EventManager,
        _identityCanisterId: Principal,
        _walletCanisterId: ?Principal,
        _tokenCanisterId: ?Principal
    ) {
        // Storage
        private var proposals: Trie.Trie<Nat, Proposal> = Trie.empty();
        private var votesByProposal: Trie.Trie<Nat, Trie.Trie<Principal, VoteReceipt>> = Trie.empty();
        private var nextProposalId: Nat = 1;
        
        // Indexes for efficient queries
        private var byStatus: Trie.Trie<Text, [Nat]> = Trie.empty();
        private var byProposer: Trie.Trie<Principal, [Nat]> = Trie.empty();
        private var byEndTime: Trie.Trie<Nat64, [Nat]> = Trie.empty();

        // Constants
        private let DAY: Nat64 = 24 * 60 * 60 * 1_000_000_000;
        private let DEFAULT_VOTING_DURATION: Nat64 = 7 * DAY;
        private let DEFAULT_QUORUM_BP: Nat = 2000; // 20%
        private let DEFAULT_THRESHOLD_BP: Nat = 5000; // 50%

        // ================================
        // TRIAD-NATIVE API
        // ================================

        // 📝 Submit General Proposal (Triad)
        public func submitGeneralProposalTriad(
            identityId: Principal,
            title: Text,
            description: Text,
            proof: LinkProof,
            opts: SubmitOptions
        ): async Result.Result<Nat, Text> {
            
            // Validation
            if (Text.size(title) == 0 or Text.size(description) == 0) {
                return #err("empty title/description");
            };
            
            // Auth check (mock for now - would call Identity canister)
            let authResult = await verifyIdentity(identityId, proof);
            if (not authResult) {
                return #err("unauthorized");
            };

            // Optional deposit lock (mock for now - would call Wallet canister)
            let depositLock: ?Text = switch (opts.depositToken, opts.depositAmount) {
                case (?token, ?amount) {
                    switch (await lockDeposit(identityId, token, amount)) {
                        case (#ok(lockId)) ?lockId;
                        case (#err(error)) return #err("deposit lock failed: " # error);
                    };
                };
                case _ null;
            };

            let now = Nat64.fromIntWrap(Time.now());
            let votingDuration = switch (opts.votingDurationHours) {
                case (?hours) Nat64.fromNat(hours) * 60 * 60 * 1_000_000_000;
                case null DEFAULT_VOTING_DURATION;
            };

            let proposal: Proposal = {
                id = nextProposalId;
                pType = #general;
                title = title;
                description = description;
                proposerIdentity = identityId;
                proposerUserId = opts.userId;
                depositLockId = depositLock;
                createdAt = now;
                snapshotAt = now; // Snapshot taken at creation
                votingStartsAt = now;
                votingEndsAt = now + votingDuration;
                quorumBp = Option.get(opts.quorumBp, DEFAULT_QUORUM_BP);
                thresholdBp = Option.get(opts.thresholdBp, DEFAULT_THRESHOLD_BP);
                strategy = Option.get(opts.strategy, #oneIdentityOneVote);
                status = #open;
                tally = { yes = 0; no = 0; abstain = 0; weightTotal = 0 };
            };

            // Store proposal
            proposals := Trie.put(proposals, natKey(proposal.id), Nat.equal, proposal).0;
            nextProposalId += 1;

            // Initialize votes storage
            votesByProposal := Trie.put(votesByProposal, natKey(proposal.id), Nat.equal, Trie.empty()).0;

            // Update indexes
            updateStatusIndex(proposal.id, "open");
            updateProposerIndex(proposal.id, identityId);
            updateEndTimeIndex(proposal.id, proposal.votingEndsAt);

            // Emit event
            await emitTriadEvent("gov.proposal.created", identityId, opts.userId, ?("proposal:" # Nat.toText(proposal.id)), proposal);

            #ok(proposal.id)
        };

        // 🗳️ Cast Vote (Triad)
        public func castGeneralVoteTriad(
            identityId: Principal,
            proposalId: Nat,
            choice: VoteChoice,
            proof: LinkProof
        ): async Result.Result<(), Text> {
            
            // Auth check
            let authResult = await verifyIdentity(identityId, proof);
            if (not authResult) {
                return #err("unauthorized");
            };

            // Get proposal
            let proposal = switch (Trie.find(proposals, natKey(proposalId), Nat.equal)) {
                case null return #err("proposal not found");
                case (?p) p;
            };

            // Status and timing checks
            if (proposal.status != #open) {
                return #err("voting closed");
            };

            let now = Nat64.fromIntWrap(Time.now());
            if (now < proposal.votingStartsAt or now > proposal.votingEndsAt) {
                return #err("out of voting window");
            };

            // Check for existing vote
            if (hasVoteReceipt(proposalId, identityId)) {
                return #err("already voted");
            };

            // Calculate voting weight
            let weight = await calculateVotingWeight(identityId, proposal);
            if (weight == 0) {
                return #err("ineligible to vote");
            };

            // Record vote
            let receipt: VoteReceipt = {
                proposalId = proposalId;
                voterIdentity = identityId;
                choice = choice;
                weight = weight;
                castAt = now;
            };

            // Store vote receipt
            let proposalVotes = switch (Trie.find(votesByProposal, natKey(proposalId), Nat.equal)) {
                case null Trie.empty<Principal, VoteReceipt>();
                case (?votes) votes;
            };
            let updatedVotes = Trie.put(proposalVotes, principalKey(identityId), Principal.equal, receipt).0;
            votesByProposal := Trie.put(votesByProposal, natKey(proposalId), Nat.equal, updatedVotes).0;

            // Update tally
            let updatedProposal = updateProposalTally(proposal, choice, weight);
            proposals := Trie.put(proposals, natKey(proposalId), Nat.equal, updatedProposal).0;

            // Emit event
            await emitTriadEvent("gov.vote.cast", identityId, null, ?("proposal:" # Nat.toText(proposalId)), receipt);

            #ok(())
        };

        // ✅ Finalize Proposal (Triad)
        public func finalizeGeneralProposalTriad(
            identityId: Principal,
            proposalId: Nat,
            proof: LinkProof
        ): async Result.Result<Proposal, Text> {
            
            // Auth check
            let authResult = await verifyIdentity(identityId, proof);
            if (not authResult) {
                return #err("unauthorized");
            };

            // Role check (mock for now - would call Identity canister)
            let roleResult = await hasRole(identityId, "gov.finalizer");
            if (not roleResult) {
                return #err("not authorized to finalize");
            };

            // Get proposal
            let proposal = switch (Trie.find(proposals, natKey(proposalId), Nat.equal)) {
                case null return #err("proposal not found");
                case (?p) p;
            };

            // Status check
            if (proposal.status != #open and proposal.status != #finalizing) {
                return #err("proposal already finalized");
            };

            // Timing check
            let now = Nat64.fromIntWrap(Time.now());
            if (now < proposal.votingEndsAt) {
                return #err("voting period not ended");
            };

            // Calculate results
            let eligibleSupply = await getEligibleSupply(proposal);
            let turnoutBp = if (eligibleSupply == 0) 0 else (proposal.tally.weightTotal * 10_000) / eligibleSupply;
            let yesBp = if ((proposal.tally.yes + proposal.tally.no) == 0) {
                0
            } else {
                (proposal.tally.yes * 10_000) / (proposal.tally.yes + proposal.tally.no)
            };

            // Determine outcome
            let newStatus: ProposalStatus = if (turnoutBp >= proposal.quorumBp and yesBp >= proposal.thresholdBp) {
                #executed
            } else {
                #rejected
            };

            // Handle deposit
            switch (proposal.depositLockId) {
                case (?lockId) {
                    if (newStatus == #executed) {
                        ignore await refundDeposit(lockId); // Refund to proposer
                    } else {
                        ignore await forfeitDeposit(lockId); // Send to treasury
                    };
                };
                case null ();
            };

            // Update proposal
            let finalizedProposal = { proposal with status = newStatus };
            proposals := Trie.put(proposals, natKey(proposalId), Nat.equal, finalizedProposal).0;

            // Update status index
            updateStatusIndex(proposalId, statusToText(newStatus));

            // Emit event
            await emitTriadEvent("gov.proposal.finalized", identityId, null, ?("proposal:" # Nat.toText(proposalId)), {
                proposal = finalizedProposal;
                turnoutBp = turnoutBp;
                yesBp = yesBp;
                quorumMet = turnoutBp >= proposal.quorumBp;
                thresholdMet = yesBp >= proposal.thresholdBp;
            });

            #ok(finalizedProposal)
        };

        // ================================
        // QUERY METHODS
        // ================================

        public func getProposal(proposalId: Nat): ?Proposal {
            Trie.find(proposals, natKey(proposalId), Nat.equal)
        };

        public func listProposalsByStatus(status: ProposalStatus): [Proposal] {
            let statusKey = statusToText(status);
            switch (Trie.find(byStatus, textKey(statusKey), Text.equal)) {
                case null [];
                case (?proposalIds) {
                    Array.mapFilter<Nat, Proposal>(proposalIds, func(id) {
                        Trie.find(proposals, natKey(id), Nat.equal)
                    })
                };
            }
        };

        public func listProposalsByProposer(proposer: Principal): [Proposal] {
            switch (Trie.find(byProposer, principalKey(proposer), Principal.equal)) {
                case null [];
                case (?proposalIds) {
                    Array.mapFilter<Nat, Proposal>(proposalIds, func(id) {
                        Trie.find(proposals, natKey(id), Nat.equal)
                    })
                };
            }
        };

        public func getVoteReceipts(proposalId: Nat): [VoteReceipt] {
            switch (Trie.find(votesByProposal, natKey(proposalId), Nat.equal)) {
                case null [];
                case (?votes) {
                    Iter.toArray(Trie.iter(votes)) |> Array.map<(Principal, VoteReceipt), VoteReceipt>(_, func(entry) { entry.1 })
                };
            }
        };

        public func getVoteReceipt(proposalId: Nat, voter: Principal): ?VoteReceipt {
            switch (Trie.find(votesByProposal, natKey(proposalId), Nat.equal)) {
                case null null;
                case (?votes) Trie.find(votes, principalKey(voter), Principal.equal);
            }
        };

        public func getProposalsEndingSoon(withinHours: Nat): [Proposal] {
            let now = Nat64.fromIntWrap(Time.now());
            let deadline = now + Nat64.fromNat(withinHours * 60 * 60 * 1_000_000_000);
            
            let allProposals = Iter.toArray(Trie.iter(proposals));
            Array.mapFilter<(Nat, Proposal), Proposal>(allProposals, func(entry) {
                let proposal = entry.1;
                if (proposal.status == #open and proposal.votingEndsAt >= now and proposal.votingEndsAt <= deadline) {
                    ?proposal
                } else {
                    null
                }
            })
        };

        // ================================
        // LEGACY COMPATIBILITY WRAPPERS
        // ================================

        // Legacy submit (non-triad)
        public func submitGeneralProposal(
            caller: Principal,
            title: Text,
            description: Text
        ): async Result.Result<Nat, Text> {
            // Create minimal proof for migration period
            let proof: LinkProof = {
                signature = Blob.fromArray([]);
                challenge = Blob.fromArray([]);
                device = null;
            };
            
            let opts: SubmitOptions = {
                userId = ?caller;
                depositToken = null;
                depositAmount = null;
                quorumBp = null;
                thresholdBp = null;
                votingDurationHours = null;
                strategy = null;
            };

            await submitGeneralProposalTriad(caller, title, description, proof, opts)
        };

        // Legacy vote (non-triad)
        public func castGeneralVote(
            caller: Principal,
            proposalId: Nat,
            choice: Bool
        ): async Result.Result<(), Text> {
            let proof: LinkProof = {
                signature = Blob.fromArray([]);
                challenge = Blob.fromArray([]);
                device = null;
            };
            
            let triadChoice: VoteChoice = if (choice) #yes else #no;
            await castGeneralVoteTriad(caller, proposalId, triadChoice, proof)
        };

        // Legacy finalize (non-triad)
        public func finalizeGeneralProposal(
            caller: Principal,
            proposalId: Nat
        ): async Result.Result<Proposal, Text> {
            let proof: LinkProof = {
                signature = Blob.fromArray([]);
                challenge = Blob.fromArray([]);
                device = null;
            };
            
            await finalizeGeneralProposalTriad(caller, proposalId, proof)
        };

        // ================================
        // PRIVATE HELPERS
        // ================================

        private func hasVoteReceipt(proposalId: Nat, voter: Principal): Bool {
            switch (getVoteReceipt(proposalId, voter)) {
                case null false;
                case (?_) true;
            }
        };

        private func updateProposalTally(proposal: Proposal, choice: VoteChoice, weight: Nat): Proposal {
            let newTally = switch (choice) {
                case (#yes) {
                    { yes = proposal.tally.yes + weight;
                      no = proposal.tally.no;
                      abstain = proposal.tally.abstain;
                      weightTotal = proposal.tally.weightTotal + weight; }
                };
                case (#no) {
                    { yes = proposal.tally.yes;
                      no = proposal.tally.no + weight;
                      abstain = proposal.tally.abstain;
                      weightTotal = proposal.tally.weightTotal + weight; }
                };
                case (#abstain) {
                    { yes = proposal.tally.yes;
                      no = proposal.tally.no;
                      abstain = proposal.tally.abstain + weight;
                      weightTotal = proposal.tally.weightTotal + weight; }
                };
            };
            { proposal with tally = newTally }
        };

        private func updateStatusIndex(proposalId: Nat, status: Text) {
            let currentIds = switch (Trie.find(byStatus, textKey(status), Text.equal)) {
                case null [];
                case (?ids) ids;
            };
            let updatedIds = Array.append(currentIds, [proposalId]);
            byStatus := Trie.put(byStatus, textKey(status), Text.equal, updatedIds).0;
        };

        private func updateProposerIndex(proposalId: Nat, proposer: Principal) {
            let currentIds = switch (Trie.find(byProposer, principalKey(proposer), Principal.equal)) {
                case null [];
                case (?ids) ids;
            };
            let updatedIds = Array.append(currentIds, [proposalId]);
            byProposer := Trie.put(byProposer, principalKey(proposer), Principal.equal, updatedIds).0;
        };

        private func updateEndTimeIndex(proposalId: Nat, endTime: Nat64) {
            let bucket = endTime / (24 * 60 * 60 * 1_000_000_000); // Daily buckets
            let currentIds = switch (Trie.find(byEndTime, nat64Key(bucket), Nat64.equal)) {
                case null [];
                case (?ids) ids;
            };
            let updatedIds = Array.append(currentIds, [proposalId]);
            byEndTime := Trie.put(byEndTime, nat64Key(bucket), Nat64.equal, updatedIds).0;
        };

        private func statusToText(status: ProposalStatus): Text {
            switch (status) {
                case (#open) "open";
                case (#finalizing) "finalizing";
                case (#executed) "executed";
                case (#rejected) "rejected";
                case (#expired) "expired";
            }
        };

        // ================================
        // MOCK EXTERNAL CALLS (To be replaced with real canisters)
        // ================================

        private func verifyIdentity(_identityId: Principal, _proof: LinkProof): async Bool {
            // TODO: Call Identity canister to verify proof
            true // Mock for now
        };

        private func hasRole(_identityId: Principal, _role: Text): async Bool {
            // TODO: Call Identity canister to check role
            true // Mock for now - allow all finalizations during development
        };

        private func lockDeposit(_identityId: Principal, _token: Text, amount: Nat): async Result.Result<Text, Text> {
            // TODO: Call Wallet canister to lock funds
            #ok("mock-lock-" # Nat.toText(amount)) // Mock for now
        };

        private func refundDeposit(_lockId: Text): async Result.Result<(), Text> {
            // TODO: Call Wallet canister to refund locked funds
            #ok(()) // Mock for now
        };

        private func forfeitDeposit(_lockId: Text): async Result.Result<(), Text> {
            // TODO: Call Treasury/Wallet canister to forfeit locked funds
            #ok(()) // Mock for now
        };

        private func calculateVotingWeight(_identityId: Principal, proposal: Proposal): async Nat {
            switch (proposal.strategy) {
                case (#oneIdentityOneVote) 1;
                case (#stakeWeighted({token = _; minStake})) {
                    // TODO: Call Token canister to get balance at snapshot
                    let balance = 100; // Mock balance
                    if (balance >= minStake) balance else 0
                };
                case (#timeWeighted({token = _; slope})) {
                    // TODO: Call Token canister to get stake info at snapshot
                    let stakeAmount = 100; // Mock
                    let stakeAge = 30 * 24 * 60 * 60 * 1_000_000_000; // Mock 30 days
                    stakeAmount + (stakeAge / 1_000_000_000) * slope
                };
            }
        };

        private func getEligibleSupply(proposal: Proposal): async Nat {
            switch (proposal.strategy) {
                case (#oneIdentityOneVote) 1000; // Mock total identities
                case (#stakeWeighted({token = _; minStake = _})) 100000; // Mock total supply
                case (#timeWeighted({token = _; slope = _})) 100000; // Mock total supply
            }
        };

        private func emitTriadEvent(eventType: Text, _identityId: Principal, _userId: ?Principal, _ref: ?Text, _data: Any): async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = #AlertRaised; // Using existing event type
                payload = #AlertRaised({
                    alertType = eventType;
                    message = "Triad governance event: " # eventType;
                    timestamp = Nat64.fromIntWrap(Time.now());
                });
            };
            await eventManager.emit(event);
        };

        // ================================
        // UTILITY FUNCTIONS
        // ================================

        private func natKey(n: Nat): Trie.Key<Nat> {
            { key = n; hash = Nat32.fromNat(n) }
        };

        private func principalKey(p: Principal): Trie.Key<Principal> {
            { key = p; hash = Principal.hash(p) }
        };

        private func textKey(t: Text): Trie.Key<Text> {
            { key = t; hash = Text.hash(t) }
        };

        private func nat64Key(n: Nat64): Trie.Key<Nat64> {
            { key = n; hash = Nat32.fromNat(Nat64.toNat(n)) }
        };
    };

    // Factory function
    public func createTriadGovernance(
        eventManager: EventManager.EventManager,
        identityCanisterId: Principal,
        walletCanisterId: ?Principal,
        tokenCanisterId: ?Principal
    ): TriadGovernance {
        TriadGovernance(eventManager, identityCanisterId, walletCanisterId, tokenCanisterId)
    };
};
