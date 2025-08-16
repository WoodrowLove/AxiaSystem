import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Text "mo:base/Text";
import _ "mo:base/Option";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import LoggingUtils "../utils/logging_utils";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";

module {
    // Core types for refund management
    public type RefundRequestId = Nat;

    public type RefundSource = {
        #UserFunds: { fromUser: Principal };      // Refund from user's wallet/transaction
        #Treasury: { requiresApproval: Bool };    // Refund from treasury funds
        #Hybrid: { userPortion: Nat; treasuryPortion: Nat }; // Split between user and treasury
    };

    public type RefundRequest = {
        id: RefundRequestId;
        originId: Nat;                    // paymentId | escrowId | payoutId | splitId | subscriptionId
        originType: Text;                 // "Payment" | "Escrow" | "Payout" | "SplitPayment" | "Subscription"
        requestedBy: Principal;           // User/system that requested refund
        requestedAt: Int;                 // Timestamp
        amount: Nat;                      // Amount to refund
        refundSource: RefundSource;       // Where funds come from
        reason: ?Text;                    // User-provided reason
        status: Text;                     // "Requested" | "PendingReview" | "Approved" | "Denied" | "Processing" | "Completed" | "Failed"
        adminPrincipal: ?Principal;       // Admin who approved/denied
        adminNote: ?Text;                 // Admin reasoning
        processedAt: ?Int;                // When processed
        treasuryTransactionId: ?Nat;      // If funded by treasury, reference to treasury transaction
        lastUpdatedAt: Int;               // For sorting/filtering
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

        // Helper function to emit events
        private func emitEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload) : async () {
            let event : EventTypes.Event = {
                id = Int.abs(Time.now()) |> Nat64.fromNat(_);
                eventType = eventType;
                payload = payload;
            };
            await eventManager.emit(event);
        };

        // Create a new refund request
        public func createRefundRequest(
            originId: Nat,
            requestedBy: Principal, 
            amount: Nat,
            refundSource: RefundSource,
            reason: ?Text
        ): async Result.Result<RefundRequestId, Text> {
            LoggingUtils.logInfo(
                logStore,
                "RefundManager",
                "Creating refund request for " # originType # " ID: " # Nat.toText(originId) # 
                " by " # Principal.toText(requestedBy) # " for amount: " # Nat.toText(amount),
                ?requestedBy
            );

            // Validate request
            if (amount <= 0) {
                return #err("Refund amount must be greater than zero");
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
                adminPrincipal = null;
                adminNote = null;
                processedAt = null;
                treasuryTransactionId = null;
                lastUpdatedAt = currentTime;
            };

            refundRequests.add(refundRequest);
            let requestId = nextRefundId;
            nextRefundId += 1;

            // Emit refund requested event
            await emitEvent(#RefundRequested, #RefundRequested {
                refundId = requestId;
                originType = originType;
                originId = originId;
                requestedBy = requestedBy;
                amount = amount;
                reason = reason;
                timestamp = currentTime;
            });

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

        // Approve a refund request
        public func approveRefundRequest(
            requestId: RefundRequestId,
            adminPrincipal: Principal,
            adminNote: ?Text
        ): async Result.Result<(), Text> {
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
                        return #err("Only requested or pending review refunds can be approved");
                    };

                    let currentTime = Time.now();
                    let updatedRequest: RefundRequest = {
                        request with 
                        status = "Approved";
                        adminPrincipal = ?adminPrincipal;
                        adminNote = adminNote;
                        lastUpdatedAt = currentTime;
                    };

                    refundRequests.put(index, updatedRequest);

                    // Emit refund approved event
                    await emitEvent(#RefundApproved, #RefundApproved {
                        refundId = requestId;
                        adminPrincipal = adminPrincipal;
                        adminNote = adminNote;
                        timestamp = currentTime;
                    });

                    LoggingUtils.logInfo(
                        logStore,
                        "RefundManager",
                        "Refund request ID: " # Nat.toText(requestId) # " approved successfully",
                        ?adminPrincipal
                    );

                    #ok(())
                };
                case (null) #err("Refund request not found");
            }
        };

        // Deny a refund request
        public func denyRefundRequest(
            requestId: RefundRequestId,
            adminPrincipal: Principal,
            adminNote: ?Text
        ): async Result.Result<(), Text> {
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
                        return #err("Only requested or pending review refunds can be denied");
                    };

                    let currentTime = Time.now();
                    let updatedRequest: RefundRequest = {
                        request with 
                        status = "Denied";
                        adminPrincipal = ?adminPrincipal;
                        adminNote = adminNote;
                        lastUpdatedAt = currentTime;
                    };

                    refundRequests.put(index, updatedRequest);

                    // Emit refund denied event
                    await emitEvent(#RefundDenied, #RefundDenied {
                        refundId = requestId;
                        adminPrincipal = adminPrincipal;
                        adminNote = adminNote;
                        timestamp = currentTime;
                    });

                    LoggingUtils.logInfo(
                        logStore,
                        "RefundManager",
                        "Refund request ID: " # Nat.toText(requestId) # " denied successfully",
                        ?adminPrincipal
                    );

                    #ok(())
                };
                case (null) #err("Refund request not found");
            }
        };

        // Mark refund as processed
        public func markRefundProcessed(
            requestId: RefundRequestId,
            success: Bool,
            errorMsg: ?Text
        ): async Result.Result<(), Text> {
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
                        return #err("Only approved or processing refunds can be marked as processed");
                    };

                    let currentTime = Time.now();
                    let newStatus = if (success) "Completed" else "Failed";
                    let updatedRequest: RefundRequest = {
                        request with 
                        status = newStatus;
                        processedAt = ?currentTime;
                        lastUpdatedAt = currentTime;
                    };

                    refundRequests.put(index, updatedRequest);

                    // Emit refund processed event
                    await emitEvent(#RefundProcessed, #RefundProcessed {
                        refundId = requestId;
                        processedAt = currentTime;
                        success = success;
                        errorMsg = errorMsg;
                    });

                    LoggingUtils.logInfo(
                        logStore,
                        "RefundManager",
                        "Refund request ID: " # Nat.toText(requestId) # " marked as " # newStatus,
                        null
                    );

                    #ok(())
                };
                case (null) #err("Refund request not found");
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

        // Process a treasury-funded refund
        public func processTreasuryRefund(
            requestId: RefundRequestId,
            treasuryTransactionId: Nat
        ): async Result.Result<(), Text> {
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
                        return #err("Only approved refunds can be processed");
                    };

                    // Check if this is a treasury-funded refund
                    switch (request.refundSource) {
                        case (#Treasury(_)) {
                            let currentTime = Time.now();
                            let updatedRequest: RefundRequest = {
                                request with 
                                status = "Completed";
                                processedAt = ?currentTime;
                                treasuryTransactionId = ?treasuryTransactionId;
                                lastUpdatedAt = currentTime;
                            };

                            refundRequests.put(index, updatedRequest);

                            // Emit refund processed event
                            await emitEvent(#RefundProcessed, #RefundProcessed {
                                refundId = requestId;
                                processedAt = currentTime;
                                success = true;
                                errorMsg = null;
                            });

                            LoggingUtils.logInfo(
                                logStore,
                                "RefundManager",
                                "Treasury refund processed successfully for request ID: " # Nat.toText(requestId),
                                null
                            );

                            #ok(())
                        };
                        case (#UserFunds(_)) {
                            #err("Cannot process user-funded refund through treasury processing")
                        };
                        case (#Hybrid(_)) {
                            #err("Hybrid refunds require special processing - not yet implemented")
                        };
                    }
                };
                case (null) #err("Refund request not found");
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
                case ("ServiceCredit") #Treasury({ requiresApproval = false }); // Auto-approve service credits
                case ("Cancellation") #Treasury({ requiresApproval = true });   // Manual approval for cancellations
                case ("Prorated") #Treasury({ requiresApproval = false });     // Auto-approve prorated refunds
                case (_) #Treasury({ requiresApproval = true });               // Default to manual approval
            };

            await createRefundRequest(subscriptionId, userId, refundAmount, refundSource, reason)
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

        // Auto-approve eligible refunds
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

                        // Emit auto-approval event
                        ignore emitEvent(#RefundApproved, #RefundApproved {
                            refundId = request.id;
                            adminPrincipal = systemPrincipal;
                            adminNote = ?"Auto-approved: Eligible for automatic processing";
                            timestamp = currentTime;
                        });

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
