import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Array "mo:base/Array";
import _ "mo:base/Option";
import Nat64 "mo:base/Nat64";
import LoggingUtils "../utils/logging_utils";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";
import RefundModule "./refund_module";

module {
    public type TreasuryInterface = actor {
        withdrawFunds: (userId: Principal, amount: Nat, tokenId: ?Nat, description: Text) -> async Result.Result<(), Text>;
        getTreasuryBalance: (tokenId: ?Nat) -> async Nat;
        isTreasuryLocked: () -> async Bool;
    };

    public type WalletInterface = actor {
        creditWallet: (userId: Principal, amount: Nat) -> async Result.Result<Nat, Text>;
        getWalletBalance: (userId: Principal) -> async Result.Result<Nat, Text>;
    };

    public class TreasuryRefundProcessor(
        treasuryCanister: TreasuryInterface,
        _walletCanister: WalletInterface,
        eventManager: EventManager.EventManager
    ) {
        private var logStore = LoggingUtils.init();

        // Process all approved treasury-funded refunds
        public func processApprovedTreasuryRefunds(
            refundManager: RefundModule.RefundManager
        ): async Result.Result<[RefundModule.RefundRequestId], Text> {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryRefundProcessor",
                "Starting processing of approved treasury refunds",
                null
            );

            // Check if treasury is locked
            let isLocked = await treasuryCanister.isTreasuryLocked();
            if (isLocked) {
                return #err("Treasury is currently locked - cannot process refunds");
            };

            // Get all treasury refunds that need processing
            let refundsToProcess = await refundManager.getTreasuryRefundsToProcess();
            var processedRefunds: [RefundModule.RefundRequestId] = [];
            var failedRefunds: [RefundModule.RefundRequestId] = [];

            for (refund in refundsToProcess.vals()) {
                let processResult = await processSingleTreasuryRefund(refund, refundManager);
                switch (processResult) {
                    case (#ok(refundId)) {
                        processedRefunds := Array.append(processedRefunds, [refundId]);
                    };
                    case (#err(error)) {
                        LoggingUtils.logError(
                            logStore,
                            "TreasuryRefundProcessor",
                            "Failed to process refund ID " # Nat.toText(refund.id) # ": " # error,
                            null
                        );
                        failedRefunds := Array.append(failedRefunds, [refund.id]);
                        
                        // Mark refund as failed
                        ignore refundManager.markRefundProcessed(refund.id, false, ?error);
                    };
                };
            };

            LoggingUtils.logInfo(
                logStore,
                "TreasuryRefundProcessor",
                "Processed " # Nat.toText(Array.size(processedRefunds)) # " refunds successfully, " # 
                Nat.toText(Array.size(failedRefunds)) # " failed",
                null
            );

            #ok(processedRefunds)
        };

        // Process a single treasury-funded refund
        private func processSingleTreasuryRefund(
            refund: RefundModule.RefundRequest,
            refundManager: RefundModule.RefundManager
        ): async Result.Result<RefundModule.RefundRequestId, Text> {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryRefundProcessor",
                "Processing treasury refund ID: " # Nat.toText(refund.id) # " for amount: " # Nat.toText(refund.amount),
                ?refund.requestedBy
            );

            // Determine token ID based on refund source
            let tokenId: ?Nat = switch (refund.refundSource) {
                case (#Treasury(_)) null; // Default to native tokens
                case (#Hybrid({ userPortion = _; treasuryPortion = _ })) null; // For now, treasury portion uses native tokens
                case (#UserFunds(_)) return #err("Cannot process user-funded refund through treasury processor");
            };

            // Check treasury balance
            let treasuryBalance = await treasuryCanister.getTreasuryBalance(tokenId);
            let requiredAmount = switch (refund.refundSource) {
                case (#Treasury(_)) refund.amount;
                case (#Hybrid({ treasuryPortion; userPortion = _ })) treasuryPortion;
                case (#UserFunds(_)) 0; // Should not reach here
            };

            if (treasuryBalance < requiredAmount) {
                return #err("Insufficient treasury balance: required " # Nat.toText(requiredAmount) # 
                           ", available " # Nat.toText(treasuryBalance));
            };

            // Execute treasury withdrawal and user credit
            let withdrawResult = await treasuryCanister.withdrawFunds(
                refund.requestedBy,
                requiredAmount,
                tokenId,
                "Refund processing for " # refund.originType # " ID: " # Nat.toText(refund.originId)
            );

            switch (withdrawResult) {
                case (#ok(())) {
                    // Mark refund as successfully processed
                    let markResult = await refundManager.processTreasuryRefund(
                        refund.id,
                        Int.abs(Time.now()) // Use current time as transaction ID
                    );

                    switch (markResult) {
                        case (#ok(())) {
                            // Emit successful refund processing event
                            await emitRefundProcessedEvent(refund.id, true, null);
                            
                            LoggingUtils.logInfo(
                                logStore,
                                "TreasuryRefundProcessor",
                                "Successfully processed treasury refund ID: " # Nat.toText(refund.id),
                                ?refund.requestedBy
                            );

                            #ok(refund.id)
                        };
                        case (#err(error)) {
                            LoggingUtils.logError(
                                logStore,
                                "TreasuryRefundProcessor",
                                "Failed to mark refund as processed: " # error,
                                ?refund.requestedBy
                            );
                            #err("Failed to mark refund as processed: " # error)
                        };
                    }
                };
                case (#err(error)) {
                    LoggingUtils.logError(
                        logStore,
                        "TreasuryRefundProcessor",
                        "Treasury withdrawal failed for refund ID " # Nat.toText(refund.id) # ": " # error,
                        ?refund.requestedBy
                    );
                    #err("Treasury withdrawal failed: " # error)
                };
            }
        };

        // Process hybrid refunds (part user funds, part treasury)
        public func processHybridRefund(
            refund: RefundModule.RefundRequest,
            refundManager: RefundModule.RefundManager,
            _userFundsSource: Principal // Principal of the user whose funds will be used for user portion
        ): async Result.Result<(), Text> {
            switch (refund.refundSource) {
                case (#Hybrid({ userPortion; treasuryPortion })) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryRefundProcessor",
                        "Processing hybrid refund - User portion: " # Nat.toText(userPortion) # 
                        ", Treasury portion: " # Nat.toText(treasuryPortion),
                        ?refund.requestedBy
                    );

                    // Check treasury balance for treasury portion
                    let treasuryBalance = await treasuryCanister.getTreasuryBalance(null);
                    if (treasuryBalance < treasuryPortion) {
                        return #err("Insufficient treasury balance for hybrid refund");
                    };

                    // Check user balance for user portion (this would need to be implemented)
                    // For now, we'll assume the user funds are available

                    // Process treasury portion
                    let treasuryResult = await treasuryCanister.withdrawFunds(
                        refund.requestedBy,
                        treasuryPortion,
                        null,
                        "Hybrid refund (treasury portion) for " # refund.originType # " ID: " # Nat.toText(refund.originId)
                    );

                    switch (treasuryResult) {
                        case (#ok(())) {
                            // Here you would also process the user portion
                            // This requires integration with the specific canister that holds user funds
                            
                            // Mark refund as processed
                            ignore refundManager.markRefundProcessed(refund.id, true, null);
                            
                            await emitRefundProcessedEvent(refund.id, true, null);
                            #ok(())
                        };
                        case (#err(error)) {
                            #err("Failed to process treasury portion: " # error)
                        };
                    }
                };
                case (_) {
                    #err("Cannot process non-hybrid refund as hybrid refund")
                };
            }
        };

        // Auto-approve and process eligible refunds
        public func autoProcessEligibleRefunds(
            refundManager: RefundModule.RefundManager
        ): async Result.Result<[RefundModule.RefundRequestId], Text> {
            LoggingUtils.logInfo(
                logStore,
                "TreasuryRefundProcessor",
                "Starting auto-processing of eligible refunds",
                null
            );

            // First, auto-approve eligible refunds
            let autoApprovedIds = await refundManager.autoApproveEligibleRefunds();
            
            // Then process all approved treasury refunds
            let processResult = await processApprovedTreasuryRefunds(refundManager);
            
            switch (processResult) {
                case (#ok(processedIds)) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TreasuryRefundProcessor",
                        "Auto-approved " # Nat.toText(Array.size(autoApprovedIds)) # 
                        " refunds, processed " # Nat.toText(Array.size(processedIds)) # " refunds",
                        null
                    );
                    #ok(processedIds)
                };
                case (#err(error)) {
                    LoggingUtils.logError(
                        logStore,
                        "TreasuryRefundProcessor",
                        "Failed to auto-process refunds: " # error,
                        null
                    );
                    #err(error)
                };
            }
        };

        // Validate refund request against treasury capacity
        public func validateRefundRequest(
            amount: Nat,
            refundSource: RefundModule.RefundSource,
            tokenId: ?Nat
        ): async Result.Result<(), Text> {
            switch (refundSource) {
                case (#Treasury(_)) {
                    let balance = await treasuryCanister.getTreasuryBalance(tokenId);
                    if (balance < amount) {
                        #err("Insufficient treasury balance: required " # Nat.toText(amount) # 
                             ", available " # Nat.toText(balance))
                    } else {
                        #ok(())
                    };
                };
                case (#Hybrid({ treasuryPortion; userPortion = _ })) {
                    let balance = await treasuryCanister.getTreasuryBalance(tokenId);
                    if (balance < treasuryPortion) {
                        #err("Insufficient treasury balance for hybrid refund: required " # Nat.toText(treasuryPortion) # 
                             ", available " # Nat.toText(balance))
                    } else {
                        #ok(())
                    };
                };
                case (#UserFunds(_)) {
                    // User funds validation would be handled by the specific canister
                    #ok(())
                };
            }
        };

        // Helper function to emit refund processed events
        private func emitRefundProcessedEvent(
            refundId: RefundModule.RefundRequestId, 
            success: Bool, 
            errorMsg: ?Text
        ): async () {
            let event: EventTypes.Event = {
                id = Time.now() |> Nat64.fromIntWrap(_);
                eventType = #RefundProcessed;
                payload = #RefundProcessed {
                    refundId = refundId;
                    processedAt = Time.now();
                    success = success;
                    errorMsg = errorMsg;
                };
            };
            await eventManager.emit(event);
        };

        // Get treasury refund processing stats
        public func getTreasuryRefundStats(): async { 
            availableBalance: Nat; 
            isLocked: Bool; 
            canProcessRefunds: Bool 
        } {
            let balance = await treasuryCanister.getTreasuryBalance(null);
            let locked = await treasuryCanister.isTreasuryLocked();
            
            {
                availableBalance = balance;
                isLocked = locked;
                canProcessRefunds = not locked and balance > 0;
            }
        };
    };
}
