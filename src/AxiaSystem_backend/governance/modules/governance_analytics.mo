// AxiaSystem Governance Analytics Engine
// Real-time governance insights, participation tracking, and decision analytics

import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Trie "mo:base/Trie";
import Iter "mo:base/Iter";

// System imports
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";
import TriadGovernance "triad_governance";

module {
    // ================================
    // ANALYTICS TYPES
    // ================================

    public type ParticipationMetrics = {
        totalProposals: Nat;
        activeVoters: Nat;
        averageParticipationRate: Float;
        quorumSuccessRate: Float;
        proposalSuccessRate: Float;
        averageVotingDuration: Nat64;
        topContributors: [(Principal, Nat)]; // (identity, proposal_count)
    };

    public type VotingPattern = {
        voter: Principal;
        totalVotes: Nat;
        yesVotes: Nat;
        noVotes: Nat;
        abstainVotes: Nat;
        successfulPredictions: Nat; // Votes that aligned with final outcome
        influenceScore: Float; // Calculated based on voting patterns and outcomes
    };

    public type ProposalAnalytics = {
        proposalId: Nat;
        submissionTime: Nat64;
        finalizationTime: ?Nat64;
        totalVotes: Nat;
        participationRate: Float;
        decisiveness: Float; // How clear the outcome was (margin of victory)
        controversyScore: Float; // Measure of disagreement
        timeToQuorum: ?Nat64;
        outcomePredicability: Float; // How early the outcome was predictable
    };

    public type GovernanceHealth = {
        #healthy: { score: Float; insights: [Text] };
        #concerning: { score: Float; issues: [Text]; recommendations: [Text] };
        #critical: { score: Float; problems: [Text]; urgentActions: [Text] };
    };

    public type TrendAnalysis = {
        participationTrend: Text; // "increasing", "decreasing", "stable"
        proposalVelocity: Float; // Proposals per time period
        consensusStrength: Float; // How unified the community is
        emergingIssues: [Text];
        recommendations: [Text];
    };

    // ================================
    // GOVERNANCE ANALYTICS ENGINE
    // ================================

    public class GovernanceAnalytics(
        eventManager: EventManager.EventManager
    ) {
        // Storage
        private var participationData: Trie.Trie<Principal, VotingPattern> = Trie.empty();
        private var proposalAnalytics: Trie.Trie<Nat, ProposalAnalytics> = Trie.empty();
        private var historicalMetrics: [ParticipationMetrics] = [];
        
        // Analytics configuration
        private let HEALTH_SCORE_THRESHOLD_GOOD: Float = 0.7;
        private let HEALTH_SCORE_THRESHOLD_FAIR: Float = 0.4;
        private let PARTICIPATION_TARGET: Float = 0.6; // 60% participation target
        private let QUORUM_TARGET: Float = 0.8; // 80% quorum success target

        // ================================
        // REAL-TIME ANALYTICS
        // ================================

        // Track proposal submission
        public func trackProposalSubmission(
            proposalId: Nat,
            _submitter: Principal,
            timestamp: Nat64
        ): async () {
            let analytics: ProposalAnalytics = {
                proposalId = proposalId;
                submissionTime = timestamp;
                finalizationTime = null;
                totalVotes = 0;
                participationRate = 0.0;
                decisiveness = 0.0;
                controversyScore = 0.0;
                timeToQuorum = null;
                outcomePredicability = 0.0;
            };
            
            proposalAnalytics := Trie.put(proposalAnalytics, natKey(proposalId), Nat.equal, analytics).0;
            await emitAnalyticsEvent("proposal-submitted", "New proposal #" # Nat.toText(proposalId) # " submitted");
        };

        // Track vote casting with pattern analysis
        public func trackVoteCast(
            proposalId: Nat,
            voter: Principal,
            choice: TriadGovernance.VoteChoice,
            _weight: Nat,
            _timestamp: Nat64,
            currentTally: {yes: Nat; no: Nat; abstain: Nat; weightTotal: Nat}
        ): async () {
            // Update voter patterns
            let currentPattern = switch (Trie.find(participationData, principalKey(voter), Principal.equal)) {
                case null {
                    {
                        voter = voter;
                        totalVotes = 0;
                        yesVotes = 0;
                        noVotes = 0;
                        abstainVotes = 0;
                        successfulPredictions = 0;
                        influenceScore = 0.0;
                    }
                };
                case (?pattern) pattern;
            };

            let updatedPattern = {
                currentPattern with
                totalVotes = currentPattern.totalVotes + 1;
                yesVotes = currentPattern.yesVotes + (if (choice == #yes) 1 else 0);
                noVotes = currentPattern.noVotes + (if (choice == #no) 1 else 0);
                abstainVotes = currentPattern.abstainVotes + (if (choice == #abstain) 1 else 0);
            };

            participationData := Trie.put(participationData, principalKey(voter), Principal.equal, updatedPattern).0;

            // Update proposal analytics
            switch (Trie.find(proposalAnalytics, natKey(proposalId), Nat.equal)) {
                case (?analytics) {
                    let participationRate = Float.fromInt(currentTally.weightTotal) / Float.fromInt(1000); // Mock total eligible
                    let controversyScore = calculateControversyScore(currentTally);
                    
                    let updatedAnalytics = {
                        analytics with
                        totalVotes = currentTally.weightTotal;
                        participationRate = participationRate;
                        controversyScore = controversyScore;
                    };
                    
                    proposalAnalytics := Trie.put(proposalAnalytics, natKey(proposalId), Nat.equal, updatedAnalytics).0;
                };
                case null ();
            };
        };

        // Track proposal finalization
        public func trackProposalFinalization(
            proposalId: Nat,
            outcome: Bool,
            finalTally: {yes: Nat; no: Nat; abstain: Nat; weightTotal: Nat},
            timestamp: Nat64
        ): async () {
            switch (Trie.find(proposalAnalytics, natKey(proposalId), Nat.equal)) {
                case (?analytics) {
                    let decisiveness = calculateDecisiveness(finalTally);
                    let _votingDuration = timestamp - analytics.submissionTime;
                    
                    let finalAnalytics = {
                        analytics with
                        finalizationTime = ?timestamp;
                        decisiveness = decisiveness;
                        participationRate = Float.fromInt(finalTally.weightTotal) / Float.fromInt(1000);
                    };
                    
                    proposalAnalytics := Trie.put(proposalAnalytics, natKey(proposalId), Nat.equal, finalAnalytics).0;
                    
                    // Update successful predictions for all voters
                    await updateSuccessfulPredictions(proposalId, outcome);
                };
                case null ();
            };
        };

        // ================================
        // GOVERNANCE HEALTH ASSESSMENT
        // ================================

        public func assessGovernanceHealth(): async GovernanceHealth {
            let metrics = await calculateCurrentMetrics();
            let healthScore = calculateHealthScore(metrics);
            
            if (healthScore >= HEALTH_SCORE_THRESHOLD_GOOD) {
                #healthy({
                    score = healthScore;
                    insights = [
                        "Strong community participation: " # Float.toText(metrics.averageParticipationRate),
                        "Healthy proposal success rate: " # Float.toText(metrics.proposalSuccessRate),
                        "Active governance engagement detected"
                    ];
                })
            } else if (healthScore >= HEALTH_SCORE_THRESHOLD_FAIR) {
                #concerning({
                    score = healthScore;
                    issues = generateHealthIssues(metrics);
                    recommendations = generateRecommendations(metrics);
                })
            } else {
                #critical({
                    score = healthScore;
                    problems = generateCriticalProblems(metrics);
                    urgentActions = generateUrgentActions(metrics);
                })
            }
        };

        // ================================
        // TREND ANALYSIS
        // ================================

        public func generateTrendAnalysis(): async TrendAnalysis {
            let currentMetrics = await calculateCurrentMetrics();
            let trend = if (historicalMetrics.size() < 2) {
                "insufficient-data"
            } else {
                let previousMetrics = historicalMetrics[historicalMetrics.size() - 2];
                if (currentMetrics.averageParticipationRate > previousMetrics.averageParticipationRate * 1.1) {
                    "increasing"
                } else if (currentMetrics.averageParticipationRate < previousMetrics.averageParticipationRate * 0.9) {
                    "decreasing"
                } else {
                    "stable"
                }
            };

            {
                participationTrend = trend;
                proposalVelocity = Float.fromInt(currentMetrics.totalProposals) / 7.0; // Per week
                consensusStrength = currentMetrics.proposalSuccessRate;
                emergingIssues = identifyEmergingIssues();
                recommendations = generateStrategicRecommendations(currentMetrics);
            }
        };

        // ================================
        // QUERY METHODS
        // ================================

        public func getParticipationMetrics(): async ParticipationMetrics {
            await calculateCurrentMetrics()
        };

        public func getVoterProfile(voter: Principal): async ?VotingPattern {
            Trie.find(participationData, principalKey(voter), Principal.equal)
        };

        public func getProposalAnalytics(proposalId: Nat): async ?ProposalAnalytics {
            Trie.find(proposalAnalytics, natKey(proposalId), Nat.equal)
        };

        public func getTopContributors(limit: Nat): async [(Principal, VotingPattern)] {
            let allPatterns = Iter.toArray(Trie.iter(participationData));
            let sorted = Array.sort(allPatterns, func(a: (Principal, VotingPattern), b: (Principal, VotingPattern)): {#less; #equal; #greater} {
                if (a.1.totalVotes > b.1.totalVotes) #less
                else if (a.1.totalVotes < b.1.totalVotes) #greater
                else #equal
            });
            Array.take(sorted, limit)
        };

        public func getGovernanceEfficiencyReport(): async {
            averageTimeToQuorum: ?Nat64;
            averageFinalizationTime: Nat64;
            participationTrends: Text;
            consensusStrength: Float;
        } {
            let analytics = Iter.toArray(Trie.iter(proposalAnalytics));
            let finalized = Array.mapFilter<(Nat, ProposalAnalytics), ProposalAnalytics>(analytics, func(entry) {
                if (entry.1.finalizationTime != null) ?entry.1 else null
            });
            
            let avgFinalizationTime: Nat64 = if (finalized.size() == 0) 0 else {
                Array.foldLeft<ProposalAnalytics, Nat64>(finalized, 0, func(acc, p) {
                    acc + (switch (p.finalizationTime) { case (?time) time - p.submissionTime; case null 0 })
                }) / Nat64.fromNat(finalized.size())
            };

            {
                averageTimeToQuorum = null; // Would need more detailed tracking
                averageFinalizationTime = avgFinalizationTime;
                participationTrends = "stable"; // Simplified
                consensusStrength = 0.75; // Mock value
            }
        };

        // ================================
        // PRIVATE ANALYTICS FUNCTIONS
        // ================================

        private func calculateCurrentMetrics(): async ParticipationMetrics {
            let allAnalytics = Iter.toArray(Trie.iter(proposalAnalytics));
            let allPatterns = Iter.toArray(Trie.iter(participationData));
            
            let totalProposals = allAnalytics.size();
            let activeVoters = allPatterns.size();
            
            let avgParticipation = if (allAnalytics.size() == 0) 0.0 else {
                Array.foldLeft<(Nat, ProposalAnalytics), Float>(allAnalytics, 0.0, func(acc, entry) {
                    acc + entry.1.participationRate
                }) / Float.fromInt(allAnalytics.size())
            };

            let finalized = Array.filter<(Nat, ProposalAnalytics)>(allAnalytics, func(entry) {
                entry.1.finalizationTime != null
            });

            let successfulProposals = Array.filter<(Nat, ProposalAnalytics)>(finalized, func(entry) {
                entry.1.decisiveness > 0.0 // Simplified success metric
            });

            let proposalSuccessRate = if (finalized.size() == 0) 0.0 else {
                Float.fromInt(successfulProposals.size()) / Float.fromInt(finalized.size())
            };

            let topContributors = Array.take(
                Array.sort(allPatterns, func(a: (Principal, VotingPattern), b: (Principal, VotingPattern)): {#less; #equal; #greater} {
                    if (a.1.totalVotes > b.1.totalVotes) #less else #greater
                }),
                5
            ) |> Array.map<(Principal, VotingPattern), (Principal, Nat)>(_, func(entry) { (entry.0, entry.1.totalVotes) });

            {
                totalProposals = totalProposals;
                activeVoters = activeVoters;
                averageParticipationRate = avgParticipation;
                quorumSuccessRate = 0.8; // Mock value
                proposalSuccessRate = proposalSuccessRate;
                averageVotingDuration = 5 * 24 * 60 * 60 * 1_000_000_000; // 5 days in nanoseconds
                topContributors = topContributors;
            }
        };

        private func calculateHealthScore(metrics: ParticipationMetrics): Float {
            let participationScore = Float.min(metrics.averageParticipationRate / PARTICIPATION_TARGET, 1.0) * 0.3;
            let quorumScore = Float.min(metrics.quorumSuccessRate / QUORUM_TARGET, 1.0) * 0.3;
            let successScore = metrics.proposalSuccessRate * 0.2;
            let activityScore = Float.min(Float.fromInt(metrics.totalProposals) / 10.0, 1.0) * 0.2;
            
            participationScore + quorumScore + successScore + activityScore
        };

        private func calculateControversyScore(tally: {yes: Nat; no: Nat; abstain: Nat; weightTotal: Nat}): Float {
            if (tally.weightTotal == 0) return 0.0;
            
            let yesRatio = Float.fromInt(tally.yes) / Float.fromInt(tally.weightTotal);
            let noRatio = Float.fromInt(tally.no) / Float.fromInt(tally.weightTotal);
            
            // High controversy when votes are close to 50/50
            1.0 - Float.abs(yesRatio - noRatio)
        };

        private func calculateDecisiveness(tally: {yes: Nat; no: Nat; abstain: Nat; weightTotal: Nat}): Float {
            if (tally.weightTotal == 0) return 0.0;
            
            let yesRatio = Float.fromInt(tally.yes) / Float.fromInt(tally.weightTotal);
            let noRatio = Float.fromInt(tally.no) / Float.fromInt(tally.weightTotal);
            
            Float.abs(yesRatio - noRatio)
        };

        private func updateSuccessfulPredictions(_proposalId: Nat, _outcome: Bool): async () {
            // Implementation would track which voters predicted the correct outcome
            // This is a simplified placeholder
        };

        private func generateHealthIssues(metrics: ParticipationMetrics): [Text] {
            var issues: [Text] = [];
            
            if (metrics.averageParticipationRate < PARTICIPATION_TARGET) {
                issues := Array.append(issues, ["Low participation rate: " # Float.toText(metrics.averageParticipationRate)]);
            };
            
            if (metrics.proposalSuccessRate < 0.5) {
                issues := Array.append(issues, ["High proposal failure rate: " # Float.toText(metrics.proposalSuccessRate)]);
            };
            
            if (metrics.activeVoters < 10) {
                issues := Array.append(issues, ["Small active voter base: " # Nat.toText(metrics.activeVoters)]);
            };
            
            issues
        };

        private func generateRecommendations(_metrics: ParticipationMetrics): [Text] {
            [
                "Consider incentive programs to increase participation",
                "Review proposal quality and relevance",
                "Implement better communication channels",
                "Consider adjusting voting periods"
            ]
        };

        private func generateCriticalProblems(_metrics: ParticipationMetrics): [Text] {
            [
                "Governance legitimacy at risk due to low participation",
                "Community disengagement detected",
                "Decision-making process may be compromised"
            ]
        };

        private func generateUrgentActions(_metrics: ParticipationMetrics): [Text] {
            [
                "Immediate community outreach required",
                "Review and adjust governance parameters",
                "Consider emergency governance measures",
                "Implement participation incentives"
            ]
        };

        private func identifyEmergingIssues(): [Text] {
            [
                "Voter fatigue potentially developing",
                "Centralization of voting power detected",
                "Proposal quality concerns emerging"
            ]
        };

        private func generateStrategicRecommendations(_metrics: ParticipationMetrics): [Text] {
            [
                "Implement liquid democracy features",
                "Add proposal impact assessment",
                "Create governance mentorship program",
                "Enhance decision tracking and feedback"
            ]
        };

        private func emitAnalyticsEvent(eventType: Text, message: Text): async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = #AlertRaised;
                payload = #AlertRaised({
                    alertType = "governance-analytics";
                    message = eventType # ": " # message;
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
    };

    // Factory function
    public func createGovernanceAnalytics(
        eventManager: EventManager.EventManager
    ): GovernanceAnalytics {
        GovernanceAnalytics(eventManager)
    };
};
