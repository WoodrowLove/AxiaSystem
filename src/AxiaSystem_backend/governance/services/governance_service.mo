import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import LoggingUtils "../../utils/logging_utils";
import EventManager "../../heartbeat/event_manager";
import GovernanceModule "../../governance/modules/governance_module";

module {
    public class GovernanceService(
        governanceManager: GovernanceModule.GovernanceManager,
        _eventManager: EventManager.EventManager
    ) {
        private let logStore = LoggingUtils.init();

        // Propose a new governance action
        public func propose(
            proposer: Principal,
            description: Text
        ): async Result.Result<GovernanceModule.Proposal, Text> {
            LoggingUtils.logInfo(
                logStore,
                "GovernanceService",
                "Proposing a new action by: " # Principal.toText(proposer),
                ?proposer
            );

            if (description.size() == 0) {
                return #err("Proposal description cannot be empty.");
            };

            let result = await governanceManager.propose(proposer, description);
            switch result {
                case (#ok(proposal)) {
                    LoggingUtils.logInfo(
                        logStore,
                        "GovernanceService",
                        "Proposal created successfully with ID: " # Nat.toText(proposal.id),
                        ?proposer
                    );
                    #ok(proposal);
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "GovernanceService",
                        "Failed to create proposal: " # e,
                        ?proposer
                    );
                    #err(e);
                };
            };
        };

        // Cast a vote on a proposal
        public func vote(
            voter: Principal,
            proposalId: Nat,
            isYes: Bool,
            weight: Nat
        ): async Result.Result<(), Text> {
            LoggingUtils.logInfo(
    logStore,
    "GovernanceService",
    "Casting vote on proposal ID: " # Nat.toText(proposalId) #
        " by: " # Principal.toText(voter) #
        ", Vote: " # (if isYes "Yes" else "No"),
    ?voter
);

            let result = await governanceManager.vote(voter, proposalId, isYes, weight);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(
                        logStore,
                        "GovernanceService",
                        "Vote cast successfully on proposal ID: " # Nat.toText(proposalId),
                        ?voter
                    );
                    #ok(());
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "GovernanceService",
                        "Failed to cast vote: " # e,
                        ?voter
                    );
                    #err(e);
                };
            };
        };

        // Execute a proposal
        public func executeProposal(proposalId: Nat): async Result.Result<Text, Text> {
            LoggingUtils.logInfo(
                logStore,
                "GovernanceService",
                "Attempting to execute proposal ID: " # Nat.toText(proposalId),
                null
            );

            let result = await governanceManager.executeProposal(proposalId);
            switch result {
                case (#ok(message)) {
                    LoggingUtils.logInfo(
                        logStore,
                        "GovernanceService",
                        "Proposal executed successfully. ID: " # Nat.toText(proposalId) #
                            ", Message: " # message,
                        null
                    );
                    #ok(message);
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "GovernanceService",
                        "Failed to execute proposal: " # e,
                        null
                    );
                    #err(e);
                };
            };
        };

        // Reject a proposal
        public func rejectProposal(proposalId: Nat, reason: Text): async Result.Result<(), Text> {
            LoggingUtils.logInfo(
                logStore,
                "GovernanceService",
                "Rejecting proposal ID: " # Nat.toText(proposalId) #
                    ", Reason: " # reason,
                null
            );

            let result = await governanceManager.rejectProposal(proposalId, reason);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(
                        logStore,
                        "GovernanceService",
                        "Proposal rejected successfully. ID: " # Nat.toText(proposalId),
                        null
                    );
                    #ok(());
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "GovernanceService",
                        "Failed to reject proposal: " # e,
                        null
                    );
                    #err(e);
                };
            };
        };

        // Check if a proposal has expired
        public func checkProposalExpiry(proposalId: Nat): async Result.Result<(), Text> {
            LoggingUtils.logInfo(
                logStore,
                "GovernanceService",
                "Checking expiry for proposal ID: " # Nat.toText(proposalId),
                null
            );

            let result = await governanceManager.checkProposalExpiry(proposalId);
            switch result {
                case (#ok(())) {
                    LoggingUtils.logInfo(
                        logStore,
                        "GovernanceService",
                        "Proposal expiry checked successfully for ID: " # Nat.toText(proposalId),
                        null
                    );
                    #ok(());
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "GovernanceService",
                        "Failed to check proposal expiry: " # e,
                        null
                    );
                    #err(e);
                };
            };
        };

        // Retrieve a specific proposal by ID
        public func getProposal(proposalId: Nat): async Result.Result<GovernanceModule.Proposal, Text> {
            LoggingUtils.logInfo(
                logStore,
                "GovernanceService",
                "Fetching proposal by ID: " # Nat.toText(proposalId),
                null
            );

            await governanceManager.getProposal(proposalId);
        };

        // Retrieve all proposals
        public func getAllProposals(): async [GovernanceModule.Proposal] {
            LoggingUtils.logInfo(
                logStore,
                "GovernanceService",
                "Fetching all proposals",
                null
            );

            await governanceManager.getAllProposals();
        };

        // Synchronous function to get a specific proposal
    public func getProposalSync(proposalId: Nat): Result.Result<GovernanceModule.Proposal, Text> {
        LoggingUtils.logInfo(
            logStore,
            "GovernanceService",
            "Getting proposal with ID: " # Nat.toText(proposalId),
            null
        );

        let result = governanceManager.getProposalSync(proposalId);
        switch result {
            case (#ok(proposal)) {
                LoggingUtils.logInfo(
                    logStore,
                    "GovernanceService",
                    "Successfully retrieved proposal with ID: " # Nat.toText(proposalId),
                    null
                );
                #ok(proposal);
            };
            case (#err(e)) {
                LoggingUtils.logError(
                    logStore,
                    "GovernanceService",
                    "Failed to retrieve proposal: " # e,
                    null
                );
                #err(e);
            };
        };
    };

    // Synchronous function to get all proposals
    public func getAllProposalsSync(): [GovernanceModule.Proposal] {
        LoggingUtils.logInfo(
            logStore,
            "GovernanceService",
            "Getting all proposals",
            null
        );

        let proposals = governanceManager.getAllProposalsSync();
        LoggingUtils.logInfo(
            logStore,
            "GovernanceService",
            "Successfully retrieved " # Nat.toText(proposals.size()) # " proposals",
            null
        );
        proposals;
    };

    };
};