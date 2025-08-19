import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Text "mo:base/Text";
import _ "mo:base/Option";
import Buffer "mo:base/Buffer";
import LoggingUtils "../utils/logging_utils";
import EventManager "../heartbeat/event_manager";
import TriadShared "../types/triad_shared";
import CorrelationUtils "../utils/correlation";
import EnhancedTriadEventManager "../heartbeat/enhanced_triad_event_manager";

module {
    // Core types for refund management
    public type RefundRequestId = Nat;

    // Enhanced refund source with triad identity context
    public type TriadRefundContext = {
        identity: TriadShared.TriadIdentity;
        userPrincipal: ?Principal;
        walletPrincipal: ?Principal;
        deviceContext: ?Text;
    };

    public type RefundSource = {
        #UserFunds: { fromUser: Principal; context: ?TriadRefundContext };
        #Treasury: { requiresApproval: Bool; context: ?TriadRefundContext };
        #Hybrid: { 
            userPortion: Nat; 
            treasuryPortion: Nat; 
            context: ?TriadRefundContext 
        };
    };

    // Enhanced refund processing states
    public type RefundProcessingState = {
        #pending;
        #withdrawing;        // Treasury withdrawal in progress
        #credited;          // Funds credited to user
        #finalized;         // Process complete
        #failedCompensated; // Failed but compensated
        #retrying;          // Retry in progress
    };

    public type RefundRequest = {
        id: RefundRequestId;
        originId: Nat;                    // paymentId | escrowId | payoutId | splitId | subscriptionId
        originType: Text;                 // "Payment" | "Escrow" | "Payout" | "SplitPayment" | "Subscription"
        requestedBy: Principal;           // User/system that requested refund
        requestedAt: Int;                 // Timestamp
        amount: Nat;                      // Amount to refund
        refundSource: RefundSource;       // Where funds come from with triad context
        reason: ?Text;                    // User-provided reason
        status: Text;                     // "Requested" | "PendingReview" | "Approved" | "Denied" | "Processing" | "Completed" | "Failed"
        processingState: ?RefundProcessingState; // Detailed processing state
        adminPrincipal: ?Principal;       // Admin who approved/denied
        adminNote: ?Text;                 // Admin reasoning
        processedAt: ?Int;                // When processed
        treasuryTransactionId: ?Nat;      // If funded by treasury, reference to treasury transaction
        lastUpdatedAt: Int;               // For sorting/filtering
        correlation: ?TriadShared.CorrelationContext; // Operation correlation
        retryCount: Nat;                  // Number of retry attempts
        priority: TriadShared.Priority;   // Processing priority
    };

    public type RefundStats = {
        total: Nat;
        byStatus: [(Text, Nat)];           // [("Requested", 5), ("Approved", 2), ...]
        totalAmount: Nat;                  // Total amount in refund requests
    };

    public class RefundManager(
        originType: Text,
        eventManager: EventManager.EventManager
    ) {
        private var refundRequests : Buffer.Buffer<RefundRequest> = Buffer.Buffer<RefundRequest>(0);
        private var nextRefundId: Nat = 1;
        private var logStore = LoggingUtils.init();
        private let enhancedEventManager = EnhancedTriadEventManager.createEnhancedTriadEventManager(eventManager);
        private let correlationManager = CorrelationUtils.getCorrelationManager();

        // Enhanced event emission for refund requested
        private func emitRefundRequestedTriad(
            refundId: RefundRequestId,
            originType: Text,
            originId: Nat,
            requestedBy: Principal,
            amount: Nat,
            reason: ?Text,
            correlation: TriadShared.CorrelationContext
        ): async () {
            let childCorrelation = correlationManager.deriveChild(
                correlation,
                "refund-system",
                "emit-event"
            );

            let _ = await enhancedEventManager.emitTriadEvent(
                #RefundRequested,
                #RefundRequested({
                    refundId = refundId;
                    originType = originType;
                    originId = originId;
                    requestedBy = requestedBy;
                    amount = amount;
                    reason = reason;
                    timestamp = Time.now();
                }),
                childCorrelation,
                ?#high, // Refund requests are high priority
                ["refund-system"],
                ["refund", "financial"],
                [("refundId", Nat.toText(refundId)), ("amount", Nat.toText(amount))]
            );
        };

        // Create a new refund request with triad support
        public func createRefundRequest(
            originId: Nat,
            requestedBy: Principal, 
            amount: Nat,
            refundSource: RefundSource,
            reason: ?Text
        ): async Result.Result<RefundRequestId, TriadShared.TriadError> {
            // Create correlation context
            let correlation = correlationManager.createCorrelation(
                "refund-request",
                requestedBy,
                "refund-system",
                "create-request"
            );

            LoggingUtils.logInfo(
                logStore,
                "RefundManager",
                "Creating refund request for " # originType # " ID: " # Nat.toText(originId) # 
                " by " # Principal.toText(requestedBy) # " for amount: " # Nat.toText(amount),
                ?requestedBy
            );

            // Validate request
            if (amount <= 0) {
                correlationManager.completeFlowStep(correlation.correlationId, false, ?"Invalid amount");
                return #err(#Invalid({ 
                    field = "amount"; 
                    value = Nat.toText(amount); 
                    reason = "Amount must be greater than zero" 
                }));
            };

            let currentTime = Time.now();
            let refundRequest: RefundRequest = {
                id = nextRefundId;
                originId = originId;
                originType = originType;
                requestedBy = requestedBy;
                requestedAt = currentTime;
                amount = amount;
                refundSource = refundSource;
                reason = reason;
                status = "Requested";
                processingState = ?#pending;
                adminPrincipal = null;
                adminNote = null;
                processedAt = null;
                treasuryTransactionId = null;
                lastUpdatedAt = currentTime;
                correlation = ?correlation;
                retryCount = 0;
                priority = #normal; // Default priority
            };

            refundRequests.add(refundRequest);
            let requestId = nextRefundId;
            nextRefundId += 1;

            // Emit enhanced refund requested event
            let _ = await emitRefundRequestedTriad(
                requestId,
                originType,
                originId,
                requestedBy,
                amount,
                reason,
                correlation
            );

            correlationManager.completeFlowStep(correlation.correlationId, true, null);

            LoggingUtils.logInfo(
                logStore,
                "RefundManager",
                "Refund request created with ID: " # Nat.toText(requestId),
                ?requestedBy
            );

            #ok(requestId)
        };

        // List refund requests with filtering
        public func listRefundRequests(
            status: ?Text,
            requestedBy: ?Principal,
            fromDate: ?Int,
            toDate: ?Int,
            offset: Nat,
            limit: Nat
        ): async Result.Result<[RefundRequest], Text> {
            let allRequests = Buffer.toArray(refundRequests);
            
            // Apply filters
            let filteredRequests = Array.filter<RefundRequest>(allRequests, func(req: RefundRequest): Bool {
                let matchesStatus = switch (status) {
                    case (?s) req.status == s;
                    case null true;
                };
                let matchesRequestedBy = switch (requestedBy) {
                    case (?p) req.requestedBy == p;
                    case null true;
                };
                let matchesFromDate = switch (fromDate) {
                    case (?from) req.requestedAt >= from;
                    case null true;
                };
                let matchesToDate = switch (toDate) {
                    case (?to) req.requestedAt <= to;
                    case null true;
                };
                matchesStatus and matchesRequestedBy and matchesFromDate and matchesToDate
            });

            // Apply pagination
            let totalFiltered = Array.size(filteredRequests);
            if (offset >= totalFiltered) {
                return #ok([]);
            };

            let endIndex = Nat.min(offset + limit, totalFiltered);
            let paginatedRequests = Array.tabulate<RefundRequest>(endIndex - offset, func(i: Nat): RefundRequest {
                filteredRequests[offset + i]
            });

            LoggingUtils.logInfo(
                logStore,
                "RefundManager",
                "Listed " # Nat.toText(Array.size(paginatedRequests)) # " refund requests for " # originType,
                null
            );

            #ok(paginatedRequests)
        };

        // Get specific refund request
        public func getRefundRequest(requestId: RefundRequestId): async Result.Result<RefundRequest, Text> {
            let requestOpt = Buffer.toArray(refundRequests) |> Array.find<RefundRequest>(_, func(req: RefundRequest): Bool {
                req.id == requestId
            });

            switch (requestOpt) {
                case (?request) #ok(request);
                case (null) #err("Refund request not found");
            }
        };

        // Approve a refund request with enhanced tracking
        public func approveRefundRequest(
            requestId: RefundRequestId,
            adminPrincipal: Principal,
            adminNote: ?Text
        ): async Result.Result<(), TriadShared.TriadError> {
            // Create correlation context for approval
            let correlation = correlationManager.createCorrelation(
                "refund-approval",
                adminPrincipal,
                "refund-system",
                "approve-request"
            );

            LoggingUtils.logInfo(
                logStore,
                "RefundManager",
                "Approving refund request ID: " # Nat.toText(requestId) # " by admin: " # Principal.toText(adminPrincipal),
                ?adminPrincipal
            );

            var foundIndex: ?Nat = null;
            let allRequests = Buffer.toArray(refundRequests);
            
            // Find the request
            for (i in allRequests.keys()) {
                if (allRequests[i].id == requestId) {
                    foundIndex := ?i;
                };
            };

            switch (foundIndex) {
                case (?index) {
                    let request = refundRequests.get(index);
                    if (request.status != "Requested" and request.status != "PendingReview") {
                        correlationManager.completeFlowStep(
                            correlation.correlationId,
                            false,
                            ?"Invalid status for approval"
                        );
                        return #err(#Conflict({ 
                            reason = "Only requested or pending review refunds can be approved"; 
                            currentState = request.status 
                        }));
                    };

                    let currentTime = Time.now();
                    let updatedRequest: RefundRequest = {
                        request with 
                        status = "Approved";
                        processingState = ?#pending;
                        adminPrincipal = ?adminPrincipal;
                        adminNote = adminNote;
                        lastUpdatedAt = currentTime;
                        correlation = ?correlation;
                        priority = #critical; // Approved refunds get critical priority
                    };

                    refundRequests.put(index, updatedRequest);

                    // Emit enhanced refund approved event
                    let _ = await emitRefundApprovedTriad(
                        requestId,
                        adminPrincipal,
                        adminNote,
                        correlation
                    );

                    correlationManager.completeFlowStep(correlation.correlationId, true, null);

                    LoggingUtils.logInfo(
                        logStore,
                        "RefundManager",
                        "Refund request ID: " # Nat.toText(requestId) # " approved successfully",
                        ?adminPrincipal
                    );

                    #ok(())
                };
                case (null) {
                    correlationManager.completeFlowStep(
                        correlation.correlationId,
                        false,
                        ?"Refund request not found"
                    );
                    #err(#NotFound({ 
                        resource = "refund-request"; 
                        id = Nat.toText(requestId) 
                    }));
                };
            }
        };

        // Enhanced event emission for refund approved
        private func emitRefundApprovedTriad(
            refundId: RefundRequestId,
            adminPrincipal: Principal,
            adminNote: ?Text,
            correlation: TriadShared.CorrelationContext
        ): async () {
            let childCorrelation = correlationManager.deriveChild(
                correlation,
                "refund-system",
                "emit-approval-event"
            );

            let _ = await enhancedEventManager.emitTriadEvent(
                #RefundApproved,
                #RefundApproved({
                    refundId = refundId;
                    adminPrincipal = adminPrincipal;
                    adminNote = adminNote;
                    timestamp = Time.now();
                }),
                childCorrelation,
                ?#critical, // Approvals are critical events
                ["refund-system", "admin"],
                ["refund", "approval", "financial"],
                [("refundId", Nat.toText(refundId)), ("admin", Principal.toText(adminPrincipal))]
            );
        };

        // Deny a refund request with enhanced tracking
        public func denyRefundRequest(
            requestId: RefundRequestId,
            adminPrincipal: Principal,
            adminNote: ?Text
        ): async Result.Result<(), TriadShared.TriadError> {
            // Create correlation context for denial
            let correlation = correlationManager.createCorrelation(
                "refund-denial",
                adminPrincipal,
                "refund-system", 
                "deny-request"
            );

            LoggingUtils.logInfo(
                logStore,
                "RefundManager",
                "Denying refund request ID: " # Nat.toText(requestId) # " by admin: " # Principal.toText(adminPrincipal),
                ?adminPrincipal
            );

            var foundIndex: ?Nat = null;
            let allRequests = Buffer.toArray(refundRequests);
            
            // Find the request
            for (i in allRequests.keys()) {
                if (allRequests[i].id == requestId) {
                    foundIndex := ?i;
                };
            };

            switch (foundIndex) {
                case (?index) {
                    let request = refundRequests.get(index);
                    if (request.status != "Requested" and request.status != "PendingReview") {
                        correlationManager.completeFlowStep(
                            correlation.correlationId,
                            false,
                            ?"Invalid status for denial"
                        );
                        return #err(#Conflict({ 
                            reason = "Only requested or pending review refunds can be denied"; 
                            currentState = request.status 
                        }));
                    };

                    let currentTime = Time.now();
                    let updatedRequest: RefundRequest = {
                        request with 
                        status = "Denied";
                        adminPrincipal = ?adminPrincipal;
                        adminNote = adminNote;
                        lastUpdatedAt = currentTime;
                        correlation = ?correlation;
                    };

                    refundRequests.put(index, updatedRequest);

                    // Use enhanced event emission (placeholder - would need to be implemented like approval)
                    let _ = await enhancedEventManager.emitTriadEvent(
                        #RefundDenied,
                        #RefundDenied({
                            refundId = requestId;
                            adminPrincipal = adminPrincipal;
                            adminNote = adminNote;
                            timestamp = currentTime;
                        }),
                        correlation,
                        ?#critical,
                        ["refund-system", "admin"],
                        ["refund", "denial"],
                        [("refundId", Nat.toText(requestId))]
                    );

                    correlationManager.completeFlowStep(correlation.correlationId, true, null);

                    LoggingUtils.logInfo(
                        logStore,
                        "RefundManager",
                        "Refund request ID: " # Nat.toText(requestId) # " denied successfully",
                        ?adminPrincipal
                    );

                    #ok(())
                };
                case (null) {
                    correlationManager.completeFlowStep(
                        correlation.correlationId,
                        false,
                        ?"Refund request not found"
                    );
                    #err(#NotFound({ 
                        resource = "refund-request"; 
                        id = Nat.toText(requestId) 
                    }));
                };
            }
        };

        // Mark refund as processed with enhanced tracking
        public func markRefundProcessed(
            requestId: RefundRequestId,
            success: Bool,
            errorMsg: ?Text
        ): async Result.Result<(), TriadShared.TriadError> {
            var foundIndex: ?Nat = null;
            let allRequests = Buffer.toArray(refundRequests);
            
            // Find the request
            for (i in allRequests.keys()) {
                if (allRequests[i].id == requestId) {
                    foundIndex := ?i;
                };
            };

            switch (foundIndex) {
                case (?index) {
                    let request = refundRequests.get(index);
                    if (request.status != "Approved" and request.status != "Processing") {
                        return #err(#Conflict({ 
                            reason = "Only approved or processing refunds can be marked as processed"; 
                            currentState = request.status 
                        }));
                    };

                    let currentTime = Time.now();
                    let newStatus = if (success) "Completed" else "Failed";
                    let newProcessingState = if (success) ?#finalized else ?#failedCompensated;
                    
                    let updatedRequest: RefundRequest = {
                        request with 
                        status = newStatus;
                        processingState = newProcessingState;
                        processedAt = ?currentTime;
                        lastUpdatedAt = currentTime;
                    };

                    refundRequests.put(index, updatedRequest);

                    // Emit enhanced refund processed event
                    switch (request.correlation) {
                        case (?correlation) {
                            let _ = await enhancedEventManager.emitTriadEvent(
                                #RefundProcessed,
                                #RefundProcessed({
                                    refundId = requestId;
                                    processedAt = currentTime;
                                    success = success;
                                    errorMsg = errorMsg;
                                }),
                                correlation,
                                ?#high,
                                ["refund-system"],
                                ["refund", "processing"],
                                [("refundId", Nat.toText(requestId)), ("success", if (success) "true" else "false")]
                            );
                        };
                        case (null) {
                            // Fallback correlation if none exists
                            let fallbackCorrelation = correlationManager.createCorrelation(
                                "refund-processing",
                                request.requestedBy,
                                "refund-system",
                                "mark-processed"
                            );
                            let _ = await enhancedEventManager.emitTriadEvent(
                                #RefundProcessed,
                                #RefundProcessed({
                                    refundId = requestId;
                                    processedAt = currentTime;
                                    success = success;
                                    errorMsg = errorMsg;
                                }),
                                fallbackCorrelation,
                                ?#high,
                                ["refund-system"],
                                ["refund", "processing"],
                                [("refundId", Nat.toText(requestId))]
                            );
                        };
                    };

                    LoggingUtils.logInfo(
                        logStore,
                        "RefundManager",
                        "Refund request ID: " # Nat.toText(requestId) # " marked as " # newStatus,
                        null
                    );

                    #ok(())
                };
                case (null) #err(#NotFound({ 
                    resource = "refund-request"; 
                    id = Nat.toText(requestId) 
                }));
            }
        };

        // Get refund statistics
        public func getRefundStats(): async RefundStats {
            let allRequests = Buffer.toArray(refundRequests);
            
            // Count by status
            let statusCounts = Array.foldLeft<RefundRequest, [(Text, Nat)]>(allRequests, [], func(acc: [(Text, Nat)], req: RefundRequest): [(Text, Nat)] {
                let existing = Array.find<(Text, Nat)>(acc, func((status, _): (Text, Nat)): Bool { status == req.status });
                switch (existing) {
                    case (?(_status, _)) {
                        Array.map<(Text, Nat), (Text, Nat)>(acc, func((s, c): (Text, Nat)): (Text, Nat) {
                            if (s == req.status) (s, c + 1) else (s, c)
                        })
                    };
                    case (null) Array.append(acc, [(req.status, 1)]);
                }
            });

            // Calculate total amount
            let totalAmount = Array.foldLeft<RefundRequest, Nat>(allRequests, 0, func(acc: Nat, req: RefundRequest): Nat {
                acc + req.amount
            });

            {
                total = Array.size(allRequests);
                byStatus = statusCounts;
                totalAmount = totalAmount;
            }
        };

        // Get approved refunds ready for processing
        public func getApprovedRefunds(): async [RefundRequest] {
            let allRequests = Buffer.toArray(refundRequests);
            Array.filter<RefundRequest>(allRequests, func(req: RefundRequest): Bool {
                req.status == "Approved"
            })
        };

        // Process a treasury-funded refund with enhanced state management
        public func processTreasuryRefund(
            requestId: RefundRequestId,
            treasuryTransactionId: Nat
        ): async Result.Result<(), TriadShared.TriadError> {
            LoggingUtils.logInfo(
                logStore,
                "RefundManager",
                "Processing treasury refund for request ID: " # Nat.toText(requestId),
                null
            );

            var foundIndex: ?Nat = null;
            let allRequests = Buffer.toArray(refundRequests);
            
            // Find the request
            for (i in allRequests.keys()) {
                if (allRequests[i].id == requestId) {
                    foundIndex := ?i;
                };
            };

            switch (foundIndex) {
                case (?index) {
                    let request = refundRequests.get(index);
                    if (request.status != "Approved") {
                        return #err(#Conflict({ 
                            reason = "Only approved refunds can be processed"; 
                            currentState = request.status 
                        }));
                    };

                    // Check if this is a treasury-funded refund
                    switch (request.refundSource) {
                        case (#Treasury(_)) {
                            let currentTime = Time.now();
                            let updatedRequest: RefundRequest = {
                                request with 
                                status = "Completed";
                                processingState = ?#finalized;
                                processedAt = ?currentTime;
                                treasuryTransactionId = ?treasuryTransactionId;
                                lastUpdatedAt = currentTime;
                            };

                            refundRequests.put(index, updatedRequest);

                            // Emit enhanced refund processed event
                            switch (request.correlation) {
                                case (?correlation) {
                                    let _ = await enhancedEventManager.emitTriadEvent(
                                        #RefundProcessed,
                                        #RefundProcessed({
                                            refundId = requestId;
                                            processedAt = currentTime;
                                            success = true;
                                            errorMsg = null;
                                        }),
                                        correlation,
                                        ?#high,
                                        ["refund-system", "treasury"],
                                        ["refund", "processing", "treasury"],
                                        [("refundId", Nat.toText(requestId)), ("treasuryTxId", Nat.toText(treasuryTransactionId))]
                                    );
                                };
                                case (null) {
                                    // Create fallback correlation
                                    let fallbackCorrelation = correlationManager.createCorrelation(
                                        "treasury-refund-processing",
                                        request.requestedBy,
                                        "refund-system",
                                        "process-treasury-refund"
                                    );
                                    let _ = await enhancedEventManager.emitTriadEvent(
                                        #RefundProcessed,
                                        #RefundProcessed({
                                            refundId = requestId;
                                            processedAt = currentTime;
                                            success = true;
                                            errorMsg = null;
                                        }),
                                        fallbackCorrelation,
                                        ?#high,
                                        ["refund-system", "treasury"],
                                        ["refund", "processing"],
                                        [("refundId", Nat.toText(requestId))]
                                    );
                                };
                            };

                            LoggingUtils.logInfo(
                                logStore,
                                "RefundManager",
                                "Treasury refund processed successfully for request ID: " # Nat.toText(requestId),
                                null
                            );

                            #ok(())
                        };
                        case (#UserFunds(_)) {
                            #err(#Invalid({ 
                                field = "refundSource"; 
                                value = "UserFunds"; 
                                reason = "Cannot process user-funded refund through treasury processing" 
                            }));
                        };
                        case (#Hybrid(_)) {
                            #err(#Invalid({ 
                                field = "refundSource"; 
                                value = "Hybrid"; 
                                reason = "Hybrid refunds require special processing - not yet implemented" 
                            }));
                        };
                    }
                };
                case (null) #err(#NotFound({ 
                    resource = "refund-request"; 
                    id = Nat.toText(requestId) 
                }));
            }
        };

        // Create subscription refund request
        public func createSubscriptionRefund(
            subscriptionId: Nat,
            userId: Principal,
            refundAmount: Nat,
            refundType: Text, // "Cancellation" | "Prorated" | "ServiceCredit"
            reason: ?Text
        ): async Result.Result<RefundRequestId, Text> {
            LoggingUtils.logInfo(
                logStore,
                "RefundManager",
                "Creating subscription refund for subscription ID: " # Nat.toText(subscriptionId) # 
                " for user: " # Principal.toText(userId) # " amount: " # Nat.toText(refundAmount),
                ?userId
            );

            // Determine refund source based on refund type
            let refundSource: RefundSource = switch (refundType) {
                case ("ServiceCredit") #Treasury({ requiresApproval = false; context = null }); // Auto-approve service credits
                case ("Cancellation") #Treasury({ requiresApproval = true; context = null });   // Manual approval for cancellations
                case ("Prorated") #Treasury({ requiresApproval = false; context = null });     // Auto-approve prorated refunds
                case (_) #Treasury({ requiresApproval = true; context = null });               // Default to manual approval
            };

            let result = await createRefundRequest(subscriptionId, userId, refundAmount, refundSource, reason);
            switch (result) {
                case (#ok(requestId)) #ok(requestId);
                case (#err(triadError)) #err(TriadShared.errorToText(triadError));
            }
        };

        // Get treasury-funded refunds that need processing
        public func getTreasuryRefundsToProcess(): async [RefundRequest] {
            let allRequests = Buffer.toArray(refundRequests);
            Array.filter<RefundRequest>(allRequests, func(req: RefundRequest): Bool {
                if (req.status == "Approved") {
                    switch (req.refundSource) {
                        case (#Treasury(_)) true;
                        case (#Hybrid(_)) true;
                        case (#UserFunds(_)) false;
                    }
                } else {
                    false
                }
            });
        };

        // Auto-approve eligible refunds with enhanced triad event emission
        public func autoApproveEligibleRefunds(): async [RefundRequestId] {
            let allRequests = Buffer.toArray(refundRequests);
            var approvedIds: [RefundRequestId] = [];

            for (i in allRequests.keys()) {
                let request = allRequests[i];
                if (request.status == "Requested") {
                    let shouldAutoApprove = switch (request.refundSource) {
                        case (#Treasury({ requiresApproval = false })) true;
                        case (#UserFunds(_)) false; // User refunds always auto-approved elsewhere
                        case (_) false;
                    };

                    if (shouldAutoApprove) {
                        let currentTime = Time.now();
                        let systemPrincipal = Principal.fromText("2vxsx-fae"); // System principal
                        let updatedRequest: RefundRequest = {
                            request with 
                            status = "Approved";
                            adminPrincipal = ?systemPrincipal;
                            adminNote = ?"Auto-approved: Eligible for automatic processing";
                            lastUpdatedAt = currentTime;
                        };

                        refundRequests.put(i, updatedRequest);
                        approvedIds := Array.append(approvedIds, [request.id]);

                        // Emit enhanced auto-approval event
                        switch (request.correlation) {
                            case (?correlation) {
                                ignore enhancedEventManager.emitTriadEvent(
                                    #RefundApproved,
                                    #RefundApproved({
                                        refundId = request.id;
                                        adminPrincipal = systemPrincipal;
                                        adminNote = ?"Auto-approved: Eligible for automatic processing";
                                        timestamp = currentTime;
                                    }),
                                    correlation,
                                    ?#normal,
                                    ["refund-system", "auto-approval"],
                                    ["refund", "approval", "automated"],
                                    [("refundId", Nat.toText(request.id)), ("auto", "true")]
                                );
                            };
                            case (null) {
                                // Create fallback correlation for legacy requests
                                let fallbackCorrelation = correlationManager.createCorrelation(
                                    "auto-approval",
                                    systemPrincipal,
                                    "refund-system",
                                    "auto-approve-eligible"
                                );
                                ignore enhancedEventManager.emitTriadEvent(
                                    #RefundApproved,
                                    #RefundApproved({
                                        refundId = request.id;
                                        adminPrincipal = systemPrincipal;
                                        adminNote = ?"Auto-approved: Eligible for automatic processing";
                                        timestamp = currentTime;
                                    }),
                                    fallbackCorrelation,
                                    ?#normal,
                                    ["refund-system", "auto-approval"],
                                    ["refund", "approval"],
                                    [("refundId", Nat.toText(request.id))]
                                );
                            };
                        };

                        LoggingUtils.logInfo(
                            logStore,
                            "RefundManager",
                            "Auto-approved refund request ID: " # Nat.toText(request.id),
                            ?systemPrincipal
                        );
                    };
                };
            };

            approvedIds
        };
    };
}
