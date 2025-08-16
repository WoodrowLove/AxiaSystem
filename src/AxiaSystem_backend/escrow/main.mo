import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import EventManager "../heartbeat/event_manager";
import EscrowModule "./modules/escrow_module";
import EscrowService "./services/escrow_service";
import RefundModule "../modules/refund_module";

// 🧠 NamoraAI Observability Imports
import Insight "../types/insight";
import Time "mo:base/Time";

persistent actor {

    // 🧠 NamoraAI Observability Helper
    private func emitInsight(severity: Text, message: Text) : async () {
        let _insight : Insight.SystemInsight = {
            source = "escrow";
            severity = severity;
            message = message;
            timestamp = Time.now();
        };
        Debug.print("🧠 ESCROW INSIGHT [" # severity # "]: " # message);
        // await NamoraAI.pushInsight(insight);
    };

    private transient let walletProxy = WalletCanisterProxy.WalletCanisterProxy(
    Principal.fromText("xhc3x-m7777-77774-qaaiq-cai"), // Wallet Canister ID
    Principal.fromText("xad5d-bh777-77774-qaaia-cai")  // User Canister ID
);
    private transient let eventManager = EventManager.EventManager();

    // Initialize the Refund Manager for escrow-specific refunds
    private transient let refundManager = RefundModule.RefundManager("Escrow", eventManager);

    // Initialize the Escrow Service
    private transient let escrowService = EscrowService.createEscrowService(walletProxy, eventManager);

    // API: Create a new escrow
    public shared func createEscrow(
        sender: Principal,
        receiver: Principal,
        tokenId: Nat,
        amount: Nat,
        conditions: Text
    ): async Result.Result<Nat, Text> {
        await emitInsight("info", "Escrow creation initiated from " # Principal.toText(sender) # " to " # Principal.toText(receiver) # " for amount: " # Nat.toText(amount));
        
        let result = await escrowService.createEscrow(sender, receiver, tokenId, amount, conditions);
        
        switch (result) {
            case (#ok(escrowId)) {
                await emitInsight("info", "Escrow #" # Nat.toText(escrowId) # " successfully created - amount: " # Nat.toText(amount));
            };
            case (#err(error)) {
                await emitInsight("error", "Escrow creation failed: " # error);
            };
        };
        
        result
    };

    // API: Release an escrow
    public shared func releaseEscrow(escrowId: Nat): async Result.Result<(), Text> {
        await emitInsight("info", "Escrow release requested for escrow #" # Nat.toText(escrowId));
        
        let result = await escrowService.releaseEscrow(escrowId);
        
        switch (result) {
            case (#ok(())) {
                await emitInsight("info", "Escrow #" # Nat.toText(escrowId) # " successfully released to receiver");
            };
            case (#err(error)) {
                await emitInsight("error", "Escrow release failed for #" # Nat.toText(escrowId) # ": " # error);
            };
        };
        
        result
    };

    // API: Cancel an escrow
    public shared func cancelEscrow(escrowId: Nat): async Result.Result<(), Text> {
        await escrowService.cancelEscrow(escrowId);
    };

    // API: Get details of a specific escrow
    public shared func getEscrow(escrowId: Nat): async Result.Result<EscrowModule.EscrowState, Text> {
        try {
            await escrowService.getEscrow(escrowId);
        } catch (e) {
            #err("Failed to get escrow details: " # Error.message(e))
        }
    };

    // API: List all escrows
    public shared func listEscrows(): async [EscrowModule.EscrowState] {
        await escrowService.listEscrows();
    };

    // System Health Check
    public shared func healthCheck(): async Text {
        try {
            let allEscrows = await escrowService.listEscrows();
            if (allEscrows.size() > 0) {
                "Escrow service is operational. Total escrows: " # Nat.toText(allEscrows.size())
            } else {
                "Escrow service is operational. No escrows found."
            }
        } catch (e) {
            "Escrow health check failed: " # Error.message(e);
        }
    };

      // API: Process escrow timeouts
    public shared func processEscrowTimeouts(timeoutThreshold: Nat): async Result.Result<Nat, Text> {
        try {
            await escrowService.processEscrowTimeouts(timeoutThreshold);
        } catch (e) {
            #err("Timeout processing failed: " # Error.message(e))
        }
    };

    // Heartbeat Integration (Optional)
    public shared func runHeartbeat(): async () {
        Debug.print("Escrow canister heartbeat executed.");
        // Example: Clean up stale or inactive escrows (optional implementation)
    };

    // ======= REFUND MANAGEMENT API =======

    // API: Create an escrow refund request
    public shared func createEscrowRefundRequest(
        escrowId: Nat,
        requestedBy: Principal,
        amount: Nat,
        reason: ?Text
    ): async Result.Result<Nat, Text> {
        await emitInsight("info", "Escrow refund request initiated for escrow #" # Nat.toText(escrowId) # " by " # Principal.toText(requestedBy));
        
        let refundSource = #UserFunds({ fromUser = requestedBy });
        let result = await refundManager.createRefundRequest(escrowId, requestedBy, amount, refundSource, reason);
        
        switch (result) {
            case (#ok(refundId)) {
                await emitInsight("info", "Escrow refund request #" # Nat.toText(refundId) # " created for escrow #" # Nat.toText(escrowId));
            };
            case (#err(error)) {
                await emitInsight("error", "Escrow refund request creation failed: " # error);
            };
        };
        
        result
    };

    // API: List escrow refund requests
    public shared func listEscrowRefundRequests(
        status: ?Text,
        requestedBy: ?Principal,
        fromTime: ?Int,
        toTime: ?Int,
        offset: Nat,
        limit: Nat
    ): async Result.Result<[RefundModule.RefundRequest], Text> {
        try {
            await refundManager.listRefundRequests(status, requestedBy, fromTime, toTime, offset, limit)
        } catch (e) {
            #err("Failed to list escrow refund requests: " # Error.message(e))
        }
    };

    // API: Get specific escrow refund request
    public shared func getEscrowRefundRequest(refundId: Nat): async Result.Result<RefundModule.RefundRequest, Text> {
        try {
            await refundManager.getRefundRequest(refundId)
        } catch (e) {
            #err("Failed to get escrow refund request: " # Error.message(e))
        }
    };

    // API: Approve escrow refund request (Admin only)
    public shared func approveEscrowRefundRequest(
        refundId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        await emitInsight("info", "Escrow refund approval initiated for request #" # Nat.toText(refundId) # " by admin " # Principal.toText(adminPrincipal));
        
        let result = await refundManager.approveRefundRequest(refundId, adminPrincipal, adminNote);
        
        switch (result) {
            case (#ok(())) {
                await emitInsight("info", "Escrow refund request #" # Nat.toText(refundId) # " approved by admin");
            };
            case (#err(error)) {
                await emitInsight("error", "Escrow refund approval failed: " # error);
            };
        };
        
        result
    };

    // API: Deny escrow refund request (Admin only)
    public shared func denyEscrowRefundRequest(
        refundId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        await emitInsight("info", "Escrow refund denial initiated for request #" # Nat.toText(refundId) # " by admin " # Principal.toText(adminPrincipal));
        
        let result = await refundManager.denyRefundRequest(refundId, adminPrincipal, adminNote);
        
        switch (result) {
            case (#ok(())) {
                await emitInsight("info", "Escrow refund request #" # Nat.toText(refundId) # " denied by admin");
            };
            case (#err(error)) {
                await emitInsight("error", "Escrow refund denial failed: " # error);
            };
        };
        
        result
    };

    // API: Mark escrow refund as processed
    public shared func markEscrowRefundProcessed(
        refundId: Nat,
        success: Bool,
        errorMsg: ?Text
    ): async Result.Result<(), Text> {
        await emitInsight("info", "Marking escrow refund #" # Nat.toText(refundId) # " as processed");
        
        let result = await refundManager.markRefundProcessed(refundId, success, errorMsg);
        
        switch (result) {
            case (#ok(())) {
                await emitInsight("info", "Escrow refund #" # Nat.toText(refundId) # " marked as processed");
            };
            case (#err(error)) {
                await emitInsight("error", "Escrow refund processing marking failed: " # error);
            };
        };
        
        result
    };

    // API: Get escrow refund statistics
    public shared func getEscrowRefundStats(): async RefundModule.RefundStats {
        await refundManager.getRefundStats()
    };
};