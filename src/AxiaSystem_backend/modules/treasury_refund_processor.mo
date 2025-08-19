import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Array "mo:base/Array";
import _ "mo:base/Option";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import LoggingUtils "../utils/logging_utils";
import EventManager "../heartbeat/event_manager";
import RefundModule "./refund_module";
import TriadShared "../types/triad_shared";
import CorrelationUtils "../utils/correlation";
import EnhancedTriadEventManager "../heartbeat/enhanced_triad_event_manager";

module {
    // Enhanced Treasury interface with triad support
    public type TreasuryInterface = actor {
        withdrawFunds: (userId: Principal, amount: Nat, tokenId: ?Nat, description: Text) -> async Result.Result<Nat, TriadShared.TriadError>;
        getTreasuryBalance: (tokenId: ?Nat) -> async Result.Result<Nat, TriadShared.TriadError>;
        isTreasuryLocked: () -> async Result.Result<Bool, TriadShared.TriadError>;
        estimateWithdrawalTime: (amount: Nat, tokenId: ?Nat) -> async Result.Result<Nat64, TriadShared.TriadError>;
    };

    public type WalletInterface = actor {
        creditWallet: (userId: Principal, amount: Nat) -> async Result.Result<Nat, TriadShared.TriadError>;
        getWalletBalance: (userId: Principal) -> async Result.Result<Nat, TriadShared.TriadError>;
    };

    // Treasury processing states for staged processing
    public type TreasuryProcessingState = {
        #pending;           // Initial state
        #validating;        // Checking treasury capacity and permissions
        #withdrawing;       // Executing treasury withdrawal
        #crediting;         // Crediting user wallet/account
        #compensating;      // Rolling back partial completion
        #completed;         // Successfully finished
        #failed;            // Permanently failed
    };

    // Treasury processing context for correlation
    public type TreasuryProcessingContext = {
        requestId: RefundModule.RefundRequestId;
        processingState: TreasuryProcessingState;
        correlation: TriadShared.CorrelationContext;
        startTime: Int;
        lastStateChange: Int;
        retryCount: Nat;
        priority: TriadShared.Priority;
        compensationActions: [CompensationAction];
    };

    // Compensation actions for rollback scenarios
    public type CompensationAction = {
        #ReverseWithdrawal: { txId: Nat; amount: Nat };
        #CreditTreasury: { amount: Nat; reason: Text };
        #NotifyAdmin: { severity: TriadShared.Priority; message: Text };
        #AuditLog: { action: Text; details: Text };
    };

    // Treasury processing result with detailed information
    public type TreasuryProcessingResult = {
        requestId: RefundModule.RefundRequestId;
        success: Bool;
        finalState: TreasuryProcessingState;
        transactionId: ?Nat;
        processingTime: Nat64;
        compensationsExecuted: Nat;
        error: ?TriadShared.TriadError;
    };

    public class TreasuryRefundProcessor(
        treasuryCanister: TreasuryInterface,
        _walletCanister: WalletInterface,
        eventManager: EventManager.EventManager
    ) {
        private var logStore = LoggingUtils.init();
        
        // Enhanced managers - use the correct factory functions
        private let correlationManager = CorrelationUtils.CorrelationManager();
        private let idempotencyManager = CorrelationUtils.IdempotencyManager();
        private let enhancedEventManager = EnhancedTriadEventManager.EnhancedTriadEventManager(eventManager);
        
        // Active processing contexts
        private var processingContexts = Buffer.Buffer<TreasuryProcessingContext>(10);
        
        // Retry configuration  
        private let _maxRetries: Nat = 3;
        private let baseRetryDelay: Nat64 = 5_000_000_000; // 5 seconds in nanoseconds

        // Enhanced process all approved treasury-funded refunds with staged processing
        public func processApprovedTreasuryRefunds(
            refundManager: RefundModule.RefundManager
        ): async Result.Result<[TreasuryProcessingResult], TriadShared.TriadError> {
            let correlation = correlationManager.createCorrelation(
                "treasury-batch-processing",
                Principal.fromText("2vxsx-fae"), // System principal
                "treasury-processor",
                "process-batch"
            );

            LoggingUtils.logInfo(
                logStore,
                "TreasuryRefundProcessor",
                "Starting enhanced processing of approved treasury refunds",
                null
            );

            // Check treasury operational status
            let statusCheck = await checkTreasuryOperationalStatus();
            switch (statusCheck) {
                case (#err(error)) {
                    // Use existing AlertRaised event for treasury failures
                    let _ = await enhancedEventManager.emitTriadEvent(
                        #AlertRaised,
                        #AlertRaised({
                            alertType = "Treasury Processing Failed";
                            message = "Batch processing failed: " # TriadShared.errorToText(error);
                            timestamp = Nat64.fromIntWrap(Time.now());
                        }),
                        correlation,
                        ?#critical,
                        ["treasury", "processing"],
                        ["treasury", "status", "failure"],
                        [("batchId", Nat64.toText(correlation.correlationId))]
                    );
                    return #err(error);
                };
                case (#ok(_)) {};
            };

            // Get all treasury refunds that need processing
            let refundsToProcess = await refundManager.getTreasuryRefundsToProcess();
            var processingResults: [TreasuryProcessingResult] = [];
            var failedRefunds: [RefundModule.RefundRequestId] = [];

            for (refund in refundsToProcess.vals()) {
                let childCorrelation = correlationManager.deriveChild(
                    correlation,
                    "process-single-refund",
                    "Processing refund ID " # Nat.toText(refund.id)
                );

                let processResult = await processSingleTreasuryRefundEnhanced(refund, refundManager, childCorrelation);
                switch (processResult) {
                    case (#ok(result)) {
                        processingResults := Array.append(processingResults, [result]);
                        if (result.success) {
                            LoggingUtils.logInfo(
                                logStore,
                                "TreasuryRefundProcessor", 
                                "Successfully processed refund ID: " # Nat.toText(result.requestId),
                                null
                            );
                        } else {
                            failedRefunds := Array.append(failedRefunds, [result.requestId]);
                        };
                    };
                    case (#err(error)) {
                        LoggingUtils.logError(
                            logStore,
                            "TreasuryRefundProcessor",
                            "Failed to process refund ID " # Nat.toText(refund.id) # ": " # TriadShared.errorToText(error),
                            null
                        );
                        failedRefunds := Array.append(failedRefunds, [refund.id]);
                        
                        // Create failure result
                        let failureResult: TreasuryProcessingResult = {
                            requestId = refund.id;
                            success = false;
                            finalState = #failed;
                            transactionId = null;
                            processingTime = 0;
                            compensationsExecuted = 0;
                            error = ?error;
                        };
                        processingResults := Array.append(processingResults, [failureResult]);
                    };
                };
            };

            // Emit batch completion using existing SystemMaintenanceCompleted event
            let _ = await enhancedEventManager.emitTriadEvent(
                #SystemMaintenanceCompleted,
                #SystemMaintenanceCompleted({
                    escrowsProcessed = 0;
                    payoutsRetried = Array.size(Array.filter(processingResults, func(r: TreasuryProcessingResult): Bool { r.success }));
                    splitPaymentsRetried = Array.size(failedRefunds);
                    timestamp = Nat64.fromIntWrap(Time.now());
                }),
                correlation,
                ?#high,
                ["treasury", "processing"],
                ["treasury", "batch", "completion"],
                [("batchId", Nat64.toText(correlation.correlationId)), ("processed", Nat.toText(Array.size(processingResults)))]
            );

            LoggingUtils.logInfo(
                logStore,
                "TreasuryRefundProcessor",
                "Batch processing completed: " # Nat.toText(Array.size(processingResults)) # " total, " # 
                Nat.toText(Array.size(failedRefunds)) # " failed",
                null
            );

            #ok(processingResults)
        };

        // Enhanced single treasury refund processing with staged states and compensation
        private func processSingleTreasuryRefundEnhanced(
            refund: RefundModule.RefundRequest,
            refundManager: RefundModule.RefundManager,
            correlation: TriadShared.CorrelationContext
        ): async Result.Result<TreasuryProcessingResult, TriadShared.TriadError> {
            let startTime = Time.now();
            let idempotencyKey = idempotencyManager.generateKey(
                "treasury-refund", 
                refund.requestedBy, 
                "refundId:" # Nat.toText(refund.id) # ",correlationId:" # Nat64.toText(correlation.correlationId)
            );

            // Check for duplicate processing
            switch (idempotencyManager.checkIdempotency(idempotencyKey)) {
                case (#existing(_existing)) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryRefundProcessor",
                        "Duplicate processing attempt detected for refund ID: " # Nat.toText(refund.id),
                        null
                    );
                    return #err(#Conflict({ 
                        reason = "Refund already being processed"; 
                        currentState = "in-progress" 
                    }));
                };
                case (#expired({ key = _ })) {
                    // Key expired, we can reprocess
                    idempotencyManager.storeResult(idempotencyKey, "treasury-refund", refund.requestedBy, "processing", 1);
                };
                case (#new(_stored)) {
                    idempotencyManager.storeResult(idempotencyKey, "treasury-refund", refund.requestedBy, "processing", 1);
                };
            };

            var processingContext: TreasuryProcessingContext = {
                requestId = refund.id;
                processingState = #pending;
                correlation = correlation;
                startTime = startTime;
                lastStateChange = startTime;
                retryCount = 0;
                priority = refund.priority;
                compensationActions = [];
            };

            // Add to active processing contexts
            processingContexts.add(processingContext);

            LoggingUtils.logInfo(
                logStore,
                "TreasuryRefundProcessor",
                "Starting enhanced processing for refund ID: " # Nat.toText(refund.id) # " with correlation: " # Nat64.toText(correlation.correlationId),
                ?refund.requestedBy
            );

            let processResult = await processWithStages(processingContext, refund, refundManager);
            
            // Remove from active contexts
            processingContexts := Buffer.fromArray(Array.filter(
                Buffer.toArray(processingContexts),
                func(ctx: TreasuryProcessingContext): Bool { ctx.requestId != refund.id }
            ));

            processResult
        };

        // Staged processing with compensation logic
        private func processWithStages(
            context: TreasuryProcessingContext,
            refund: RefundModule.RefundRequest,
            refundManager: RefundModule.RefundManager
        ): async Result.Result<TreasuryProcessingResult, TriadShared.TriadError> {
            var currentContext = context;
            var transactionId: ?Nat = null;
            var compensationActions: [CompensationAction] = [];

            // Stage 1: Validation
            let validationResult = await validateStage(currentContext, refund);
            switch (validationResult) {
                case (#err(error)) {
                    return await finalizeProcessing(currentContext, false, transactionId, compensationActions, ?error);
                };
                case (#ok(_)) {
                    currentContext := updateProcessingState(currentContext, #validating);
                };
            };

            // Stage 2: Treasury Withdrawal
            let withdrawalResult = await withdrawalStage(currentContext, refund);
            switch (withdrawalResult) {
                case (#err(error)) {
                    compensationActions := Array.append(compensationActions, [
                        #AuditLog({ action = "withdrawal-failed"; details = TriadShared.errorToText(error) })
                    ]);
                    return await finalizeProcessing(currentContext, false, transactionId, compensationActions, ?error);
                };
                case (#ok(txId)) {
                    transactionId := ?txId;
                    currentContext := updateProcessingState(currentContext, #withdrawing);
                    compensationActions := Array.append(compensationActions, [
                        #ReverseWithdrawal({ txId = txId; amount = getRequiredAmount(refund) })
                    ]);
                };
            };

            // Stage 3: Credit User Account (if needed)
            let creditResult = await creditStage(currentContext, refund, transactionId);
            switch (creditResult) {
                case (#err(error)) {
                    // Execute compensation for withdrawal
                    ignore await executeCompensation(compensationActions, currentContext);
                    return await finalizeProcessing(currentContext, false, transactionId, compensationActions, ?error);
                };
                case (#ok(_)) {
                    currentContext := updateProcessingState(currentContext, #crediting);
                };
            };

            // Stage 4: Mark as processed in refund manager
            let markResult = await refundManager.processTreasuryRefund(
                refund.id,
                switch (transactionId) { case (?id) id; case (null) Int.abs(Time.now()) }
            );
            switch (markResult) {
                case (#err(error)) {
                    // Execute compensation for both withdrawal and credit
                    ignore await executeCompensation(compensationActions, currentContext);
                    return await finalizeProcessing(currentContext, false, transactionId, compensationActions, ?error);
                };
                case (#ok(_)) {
                    currentContext := updateProcessingState(currentContext, #completed);
                };
            };

            // Success - finalize
            await finalizeProcessing(currentContext, true, transactionId, compensationActions, null)
        };

        // Stage processing helper functions
        private func updateProcessingState(
            context: TreasuryProcessingContext, 
            newState: TreasuryProcessingState
        ): TreasuryProcessingContext {
            {
                context with
                processingState = newState;
                lastStateChange = Time.now();
            }
        };

        private func validateStage(
            _context: TreasuryProcessingContext,
            refund: RefundModule.RefundRequest
        ): async Result.Result<(), TriadShared.TriadError> {
            // Check treasury operational status
            let statusCheck = await checkTreasuryOperationalStatus();
            switch (statusCheck) {
                case (#err(error)) return #err(error);
                case (#ok(_)) {};
            };

            // Validate refund source compatibility
            switch (refund.refundSource) {
                case (#UserFunds(_)) {
                    return #err(#Invalid({ 
                        field = "refundSource"; 
                        value = "UserFunds"; 
                        reason = "Cannot process user-funded refund through treasury processor" 
                    }));
                };
                case (#Treasury(_)) {};
                case (#Hybrid(_)) {}; // Supported in this processor
            };

            // Check treasury balance
            let requiredAmount = getRequiredAmount(refund);
            let balanceResult = await treasuryCanister.getTreasuryBalance(null);
            switch (balanceResult) {
                case (#err(error)) return #err(error);
                case (#ok(balance)) {
                    if (balance < requiredAmount) {
                        return #err(#Capacity({ 
                            resource = "treasury-balance"; 
                            current = balance; 
                            limit = requiredAmount 
                        }));
                    };
                };
            };

            #ok(())
        };

        private func withdrawalStage(
            context: TreasuryProcessingContext,
            refund: RefundModule.RefundRequest
        ): async Result.Result<Nat, TriadShared.TriadError> {
            let requiredAmount = getRequiredAmount(refund);
            let description = "Refund processing for " # refund.originType # " ID: " # Nat.toText(refund.originId) # 
                            " (Correlation: " # Nat64.toText(context.correlation.correlationId) # ")";

            let withdrawResult = await treasuryCanister.withdrawFunds(
                refund.requestedBy,
                requiredAmount,
                null, // Default to native tokens
                description
            );

            switch (withdrawResult) {
                case (#ok(txId)) {
                    // Use existing TreasuryTransactionLogged event
                    let _ = await enhancedEventManager.emitTriadEvent(
                        #TreasuryTransactionLogged,
                        #TreasuryTransactionLogged({
                            transactionId = txId;
                            transactionType = "withdrawal";
                            description = "Treasury refund withdrawal for refund ID: " # Nat.toText(refund.id);
                            timestamp = Nat64.fromIntWrap(Time.now());
                        }),
                        context.correlation,
                        ?context.priority,
                        ["treasury", "withdrawal"],
                        ["treasury", "refund", "withdrawal"],
                        [("refundId", Nat.toText(refund.id)), ("txId", Nat.toText(txId))]
                    );
                    #ok(txId)
                };
                case (#err(error)) #err(error);
            }
        };

        private func creditStage(
            _context: TreasuryProcessingContext,
            refund: RefundModule.RefundRequest,
            _transactionId: ?Nat
        ): async Result.Result<(), TriadShared.TriadError> {
            // For treasury refunds, the withdrawal already credits the user
            // This stage is for any additional crediting logic if needed
            #ok(())
        };

        private func executeCompensation(
            actions: [CompensationAction],
            context: TreasuryProcessingContext
        ): async Bool {
            var success = true;
            for (action in actions.vals()) {
                let actionResult = await executeSingleCompensation(action, context);
                if (not actionResult) {
                    success := false;
                };
            };
            success
        };

        private func executeSingleCompensation(
            action: CompensationAction,
            context: TreasuryProcessingContext
        ): async Bool {
            switch (action) {
                case (#ReverseWithdrawal({ txId; amount })) {
                    // In a real implementation, this would call treasury to reverse the withdrawal
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryRefundProcessor",
                        "COMPENSATION: Would reverse withdrawal " # Nat.toText(txId) # " for amount " # Nat.toText(amount),
                        null
                    );
                    true
                };
                case (#CreditTreasury({ amount; reason })) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryRefundProcessor",
                        "COMPENSATION: Would credit treasury " # Nat.toText(amount) # " - " # reason,
                        null
                    );
                    true
                };
                case (#NotifyAdmin({ severity; message })) {
                    // Use existing AlertRaised event for admin notifications
                    let _ = await enhancedEventManager.emitTriadEvent(
                        #AlertRaised,
                        #AlertRaised({
                            alertType = "Treasury Compensation";
                            message = message;
                            timestamp = Nat64.fromIntWrap(Time.now());
                        }),
                        context.correlation,
                        ?severity,
                        ["admin", "notification"],
                        ["compensation", "admin"],
                        [("refundId", Nat.toText(context.requestId))]
                    );
                    true
                };
                case (#AuditLog({ action; details })) {
                    LoggingUtils.logError(
                        logStore,
                        "TreasuryRefundProcessor",
                        "AUDIT: " # action # " - " # details,
                        null
                    );
                    true
                };
            }
        };

        private func finalizeProcessing(
            context: TreasuryProcessingContext,
            success: Bool,
            transactionId: ?Nat,
            compensationActions: [CompensationAction],
            error: ?TriadShared.TriadError
        ): async Result.Result<TreasuryProcessingResult, TriadShared.TriadError> {
            let finalTime = Time.now();
            let processingTime = Int.abs(finalTime - context.startTime);
            
            let result: TreasuryProcessingResult = {
                requestId = context.requestId;
                success = success;
                finalState = if (success) #completed else #failed;
                transactionId = transactionId;
                processingTime = Nat64.fromIntWrap(processingTime);
                compensationsExecuted = Array.size(compensationActions);
                error = error;
            };

            // Use existing RefundProcessed event for processing completion
            let _ = await enhancedEventManager.emitTriadEvent(
                #RefundProcessed,
                #RefundProcessed({
                    refundId = context.requestId;
                    processedAt = finalTime;
                    success = success;
                    errorMsg = switch (error) {
                        case (?err) ?TriadShared.errorToText(err);
                        case (null) null;
                    };
                }),
                context.correlation,
                ?context.priority,
                ["treasury", "processing"],
                ["treasury", "refund", if (success) "success" else "failure"],
                [("refundId", Nat.toText(context.requestId)), ("success", if (success) "true" else "false")]
            );

            #ok(result)
        };

        private func getRequiredAmount(refund: RefundModule.RefundRequest): Nat {
            switch (refund.refundSource) {
                case (#Treasury(_)) refund.amount;
                case (#Hybrid({ treasuryPortion; userPortion = _ })) treasuryPortion;
                case (#UserFunds(_)) 0; // Should not reach here in treasury processor
            }
        };

        private func checkTreasuryOperationalStatus(): async Result.Result<(), TriadShared.TriadError> {
            let lockResult = await treasuryCanister.isTreasuryLocked();
            switch (lockResult) {
                case (#err(error)) #err(error);
                case (#ok(isLocked)) {
                    if (isLocked) {
                        #err(#Transient({ 
                            operationType = "treasury-processing"; 
                            retryAfter = ?baseRetryDelay 
                        }));
                    } else {
                        #ok(())
                    };
                };
            }
        };

        // Enhanced hybrid refund processing with compensation logic
        public func processHybridRefund(
            refund: RefundModule.RefundRequest,
            refundManager: RefundModule.RefundManager,
            userFundsSource: Principal
        ): async Result.Result<TreasuryProcessingResult, TriadShared.TriadError> {
            let correlation = correlationManager.createCorrelation(
                "hybrid-refund-processing",
                userFundsSource,
                "treasury-processor",
                "process-hybrid"
            );

            switch (refund.refundSource) {
                case (#Hybrid({ userPortion; treasuryPortion })) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryRefundProcessor",
                        "Processing enhanced hybrid refund - User portion: " # Nat.toText(userPortion) # 
                        ", Treasury portion: " # Nat.toText(treasuryPortion),
                        ?refund.requestedBy
                    );

                    let processingContext: TreasuryProcessingContext = {
                        requestId = refund.id;
                        processingState = #pending;
                        correlation = correlation;
                        startTime = Time.now();
                        lastStateChange = Time.now();
                        retryCount = 0;
                        priority = refund.priority; // Use refund priority directly
                        compensationActions = [];
                    };

                    // Enhanced hybrid processing with staged validation and compensation
                    let processResult = await processHybridWithStages(processingContext, refund, refundManager, userPortion, treasuryPortion);
                    
                    switch (processResult) {
                        case (#ok(result)) {
                            // Use existing RefundProcessed event for hybrid completion
                            let _ = await enhancedEventManager.emitTriadEvent(
                                #RefundProcessed,
                                #RefundProcessed({
                                    refundId = refund.id;
                                    processedAt = Time.now();
                                    success = result.success;
                                    errorMsg = switch (result.error) {
                                        case (?err) ?TriadShared.errorToText(err);
                                        case (null) null;
                                    };
                                }),
                                correlation,
                                ?#high,
                                ["treasury", "hybrid"],
                                ["refund", "hybrid", if (result.success) "success" else "failure"],
                                [("refundId", Nat.toText(refund.id))]
                            );
                            #ok(result)
                        };
                        case (#err(error)) #err(error);
                    }
                };
                case (_) {
                    #err(#Invalid({ 
                        field = "refundSource"; 
                        value = "non-hybrid"; 
                        reason = "Cannot process non-hybrid refund as hybrid refund" 
                    }));
                };
            }
        };

        // Enhanced auto-processing with triad support
        public func autoProcessEligibleRefunds(
            refundManager: RefundModule.RefundManager
        ): async Result.Result<[TreasuryProcessingResult], TriadShared.TriadError> {
            let correlation = correlationManager.createCorrelation(
                "auto-process-eligible",
                Principal.fromText("2vxsx-fae"), // System principal
                "treasury-processor",
                "auto-process"
            );

            LoggingUtils.logInfo(
                logStore,
                "TreasuryRefundProcessor",
                "Starting enhanced auto-processing of eligible refunds",
                null
            );

            // First, auto-approve eligible refunds
            let autoApprovedIds = await refundManager.autoApproveEligibleRefunds();
            
            // Then process all approved treasury refunds with enhanced processing
            let processResult = await processApprovedTreasuryRefunds(refundManager);
            
            switch (processResult) {
                case (#ok(results)) {
                    let successCount = Array.size(Array.filter(results, func(r: TreasuryProcessingResult): Bool { r.success }));
                    
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryRefundProcessor",
                        "Auto-approved " # Nat.toText(Array.size(autoApprovedIds)) # 
                        " refunds, processed " # Nat.toText(Array.size(results)) # " refunds, " #
                        Nat.toText(successCount) # " successful",
                        null
                    );

                    // Use existing SystemMaintenanceCompleted event for auto-process completion
                    let _ = await enhancedEventManager.emitTriadEvent(
                        #SystemMaintenanceCompleted,
                        #SystemMaintenanceCompleted({
                            escrowsProcessed = Array.size(autoApprovedIds);
                            payoutsRetried = Array.size(results);
                            splitPaymentsRetried = successCount;
                            timestamp = Nat64.fromIntWrap(Time.now());
                        }),
                        correlation,
                        ?#normal,
                        ["treasury", "auto-process"],
                        ["refund", "automation"],
                        [("approved", Nat.toText(Array.size(autoApprovedIds)))]
                    );

                    #ok(results)
                };
                case (#err(error)) {
                    LoggingUtils.logError(
                        logStore,
                        "TreasuryRefundProcessor",
                        "Failed to auto-process refunds: " # TriadShared.errorToText(error),
                        null
                    );
                    #err(error)
                };
            }
        };

        // Enhanced validation with structured error handling
        public func validateRefundRequest(
            amount: Nat,
            refundSource: RefundModule.RefundSource,
            tokenId: ?Nat
        ): async Result.Result<(), TriadShared.TriadError> {
            switch (refundSource) {
                case (#Treasury(_)) {
                    let balanceResult = await treasuryCanister.getTreasuryBalance(tokenId);
                    switch (balanceResult) {
                        case (#err(error)) #err(error);
                        case (#ok(balance)) {
                            if (balance < amount) {
                                #err(#Capacity({ 
                                    resource = "treasury-balance"; 
                                    current = balance; 
                                    limit = amount 
                                }));
                            } else {
                                #ok(())
                            };
                        };
                    };
                };
                case (#Hybrid({ treasuryPortion; userPortion = _ })) {
                    let balanceResult = await treasuryCanister.getTreasuryBalance(tokenId);
                    switch (balanceResult) {
                        case (#err(error)) #err(error);
                        case (#ok(balance)) {
                            if (balance < treasuryPortion) {
                                #err(#Capacity({ 
                                    resource = "treasury-balance-hybrid"; 
                                    current = balance; 
                                    limit = treasuryPortion 
                                }));
                            } else {
                                #ok(())
                            };
                        };
                    };
                };
                case (#UserFunds(_)) {
                    // User funds validation would be handled by the specific canister
                    #ok(())
                };
            }
        };

        // Enhanced treasury stats with structured error handling
        public func getTreasuryRefundStats(): async Result.Result<{ 
            availableBalance: Nat; 
            isLocked: Bool; 
            canProcessRefunds: Bool;
            activeProcessingCount: Nat;
            averageProcessingTime: ?Nat64;
        }, TriadShared.TriadError> {
            let balanceResult = await treasuryCanister.getTreasuryBalance(null);
            let lockedResult = await treasuryCanister.isTreasuryLocked();
            
            switch (balanceResult, lockedResult) {
                case (#ok(balance), #ok(locked)) {
                    #ok({
                        availableBalance = balance;
                        isLocked = locked;
                        canProcessRefunds = not locked and balance > 0;
                        activeProcessingCount = processingContexts.size();
                        averageProcessingTime = null; // Would be calculated from historical data
                    })
                };
                case (#err(error), _) #err(error);
                case (_, #err(error)) #err(error);
            }
        };

        // Helper function for hybrid processing stages
        private func processHybridWithStages(
            context: TreasuryProcessingContext,
            refund: RefundModule.RefundRequest,
            refundManager: RefundModule.RefundManager,
            userPortion: Nat,
            treasuryPortion: Nat
        ): async Result.Result<TreasuryProcessingResult, TriadShared.TriadError> {
            var currentContext = context;
            var transactionId: ?Nat = null;
            var compensationActions: [CompensationAction] = [];

            // Stage 1: Validate both treasury and user portions
            let treasuryValidation = await validateStage(currentContext, refund);
            switch (treasuryValidation) {
                case (#err(error)) {
                    return await finalizeProcessing(currentContext, false, transactionId, compensationActions, ?error);
                };
                case (#ok(_)) {
                    currentContext := updateProcessingState(currentContext, #validating);
                };
            };

            // Stage 2: Process treasury portion
            if (treasuryPortion > 0) {
                let treasuryWithdrawal = await treasuryCanister.withdrawFunds(
                    refund.requestedBy,
                    treasuryPortion,
                    null,
                    "Hybrid refund (treasury portion) for " # refund.originType # " ID: " # Nat.toText(refund.originId)
                );

                switch (treasuryWithdrawal) {
                    case (#err(error)) {
                        compensationActions := Array.append(compensationActions, [
                            #AuditLog({ action = "treasury-withdrawal-failed"; details = TriadShared.errorToText(error) })
                        ]);
                        return await finalizeProcessing(currentContext, false, transactionId, compensationActions, ?error);
                    };
                    case (#ok(txId)) {
                        transactionId := ?txId;
                        currentContext := updateProcessingState(currentContext, #withdrawing);
                        compensationActions := Array.append(compensationActions, [
                            #ReverseWithdrawal({ txId = txId; amount = treasuryPortion })
                        ]);
                    };
                };
            };

            // Stage 3: Process user portion (placeholder - would integrate with user funds canister)
            if (userPortion > 0) {
                // In a real implementation, this would process the user portion
                LoggingUtils.logInfo(
                    logStore,
                    "TreasuryRefundProcessor",
                    "PLACEHOLDER: Would process user portion of " # Nat.toText(userPortion),
                    null
                );
                currentContext := updateProcessingState(currentContext, #crediting);
            };

            // Stage 4: Mark as processed
            let markResult = await refundManager.processTreasuryRefund(
                refund.id,
                switch (transactionId) { case (?id) id; case (null) Int.abs(Time.now()) }
            );
            switch (markResult) {
                case (#err(error)) {
                    ignore await executeCompensation(compensationActions, currentContext);
                    return await finalizeProcessing(currentContext, false, transactionId, compensationActions, ?error);
                };
                case (#ok(_)) {
                    currentContext := updateProcessingState(currentContext, #completed);
                };
            };

            await finalizeProcessing(currentContext, true, transactionId, compensationActions, null)
        };
    };
}
