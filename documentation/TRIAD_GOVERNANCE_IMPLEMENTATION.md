# Triad-Native Governance Implementation

## 🎯 Overview

The AxiaSystem governance has been enhanced with a production-ready **Triad-Native Governance** system that provides:

- **Identity-anchored authentication** with LinkProof verification
- **Snapshot-based voting** to prevent flash governance attacks
- **Flexible voting strategies** (one-identity-one-vote, stake-weighted, time-weighted)
- **Optional anti-spam deposit locks** via Wallet integration
- **Comprehensive event system** for monitoring and analytics
- **Legacy compatibility** for seamless migration

## 🔧 Key Components

### 1. TriadGovernance Module (`modules/triad_governance.mo`)
- **Proposal Management**: Create, vote, finalize proposals with full triad integration
- **Voting Strategies**: Multiple voting power calculation methods
- **Snapshot System**: Voting power calculated at proposal creation time
- **Event Integration**: Real-time governance events for monitoring
- **Query System**: Efficient indexed queries by status, proposer, timing

### 2. Main Governance Canister (`main.mo`)
- **Triad-Native APIs**: Full identity-anchored governance endpoints
- **Legacy Compatibility**: Wrapper functions for migration support
- **Monitoring Integration**: NamoraAI observability for governance activities

## 🚀 API Reference

### Triad-Native Endpoints

#### Submit Proposal
```motoko
submitGeneralProposalTriad(
  identityId: Principal,
  title: Text,
  description: Text,
  proof: LinkProof,
  opts: SubmitOptions
): async Result.Result<Nat, Text>
```

#### Cast Vote
```motoko
castGeneralVoteTriad(
  identityId: Principal,
  proposalId: Nat,
  choice: VoteChoice, // #yes | #no | #abstain
  proof: LinkProof
): async Result.Result<(), Text>
```

#### Finalize Proposal
```motoko
finalizeGeneralProposalTriad(
  identityId: Principal,
  proposalId: Nat,
  proof: LinkProof
): async Result.Result<Proposal, Text>
```

### Query Methods
- `getTriadProposal(proposalId: Nat)`: Get proposal details
- `listTriadProposalsByStatus(status: ProposalStatus)`: Filter by status
- `listTriadProposalsByProposer(proposer: Principal)`: Filter by proposer
- `getTriadVoteReceipts(proposalId: Nat)`: Get all votes for proposal
- `getTriadProposalsEndingSoon(withinHours: Nat)`: Get proposals ending soon

### Legacy Compatibility
- `submitGeneralProposalLegacy()`: Legacy proposal submission
- `castGeneralVoteLegacy()`: Legacy voting
- `finalizeGeneralProposalLegacy()`: Legacy finalization

## 🔐 Security Features

### Identity Verification
- All write operations require `LinkProof` verification
- Device attestation support for enhanced security
- Role-based access control integration

### Anti-Spam Protection
- Optional deposit locks via Wallet integration
- Deposit refund on proposal success, forfeit on failure
- Configurable deposit amounts per proposal type

### Snapshot-Based Voting
- Voting power calculated at proposal creation time
- Prevents flash governance attacks
- Supports multiple voting strategies

## 📊 Voting Strategies

### 1. One Identity One Vote
```motoko
#oneIdentityOneVote
```
- Each verified identity gets 1 vote
- Simple democratic approach
- Relies on Identity system for Sybil resistance

### 2. Stake-Weighted Voting
```motoko
#stakeWeighted({ token: "GOV"; minStake: 100 })
```
- Voting power proportional to token stake
- Minimum stake threshold for participation
- Snapshot prevents flash staking

### 3. Time-Weighted Voting (Advanced)
```motoko
#timeWeighted({ token: "GOV"; slope: 10 })
```
- Voting power increases with stake age
- Rewards long-term participants
- Incentivizes governance participation

## 🎛️ Configuration Options

### SubmitOptions
```motoko
{
  userId: ?Principal;           // Optional UX context
  depositToken: ?Text;          // Token for anti-spam deposit
  depositAmount: ?Nat;          // Deposit amount
  quorumBp: ?Nat;              // Quorum in basis points (default: 20%)
  thresholdBp: ?Nat;           // Threshold in basis points (default: 50%)
  votingDurationHours: ?Nat;   // Voting duration (default: 168 hours)
  strategy: ?VotingStrategy;   // Voting strategy (default: oneIdentityOneVote)
}
```

## 📈 Monitoring & Events

### Event Types
- `gov.proposal.created`: New proposal submitted
- `gov.vote.cast`: Vote recorded
- `gov.proposal.finalized`: Proposal finalized with results
- `gov.proposal.flagged`: Proposal flagged for moderation

### Indexes
- **By Status**: Efficient status-based queries
- **By Proposer**: Track proposer activity
- **By End Time**: Auto-finalization and monitoring

## 🔄 Migration Strategy

### Phase 1: Parallel Operation
- Deploy triad-native APIs alongside legacy APIs
- Monitor usage patterns and system performance
- Gradual client migration to triad endpoints

### Phase 2: Feature Enhancement
- Enable deposit locks for spam prevention
- Implement stake-weighted voting strategies
- Add governance delegation features

### Phase 3: Legacy Deprecation
- Deprecate legacy endpoints
- Full triad-native governance operation
- Advanced voting strategies deployment

## 🛠️ Integration Points

### Identity Canister
- LinkProof verification
- Role-based access control
- Anti-Sybil protection

### Wallet Canister
- Deposit lock management
- Stake tracking for voting power
- Fund management for treasury

### Token Canister
- Balance snapshots for voting power
- Stake age tracking for time-weighted voting
- Token economics integration

### Event System
- Real-time governance monitoring
- Analytics data collection
- Alert generation for anomalies

## 🚀 Future Enhancements

1. **Quadratic Voting**: Implement quadratic voting mechanisms
2. **Liquid Democracy**: Add delegation and proxy voting
3. **Multi-Sig Integration**: Require multi-signature for high-impact proposals
4. **Governance Tokens**: Native governance token integration
5. **Cross-Canister Proposals**: Proposals affecting multiple canisters
6. **Automated Execution**: Smart contract execution of passed proposals

## 📋 Example Usage

```motoko
// Submit a proposal with anti-spam deposit
let proof = { signature = ...; challenge = ...; device = null };
let opts = {
  userId = ?caller;
  depositToken = ?"GOV";
  depositAmount = ?1000;
  quorumBp = ?2500;  // 25% quorum
  thresholdBp = ?6000; // 60% threshold
  votingDurationHours = ?72; // 3 days
  strategy = ?#stakeWeighted({ token = "GOV"; minStake = 100 });
};

let result = await submitGeneralProposalTriad(
  identityId,
  "Increase transaction fees",
  "Proposal to increase transaction fees by 10% to fund development",
  proof,
  opts
);

// Cast a vote
let voteResult = await castGeneralVoteTriad(
  identityId,
  proposalId,
  #yes,
  proof
);

// Finalize proposal
let finalResult = await finalizeGeneralProposalTriad(
  identityId,
  proposalId,
  proof
);
```

---

This implementation provides enterprise-grade governance capabilities with robust security, flexibility, and monitoring suitable for production decentralized systems.
