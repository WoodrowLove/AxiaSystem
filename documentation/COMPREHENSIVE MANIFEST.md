# COMPREHENSIVE MANIFEST — Refunds / Reversals Queue Backend Implementation

## Executive Summary

After thorough analysis of the AxiaSystem backend, we have **INSUFFICIENT** refund management capabilities for a comprehensive admin queue. The current backend provides only basic reversal/cancellation operations without proper admin workflow, request tracking, or centralized management.

## Current Backend State Analysis

### ✅ EXISTING Functionality (Confirmed via Source Code Review)

**Payment Canister** (`/AxiaSystem_backend/payment/`)
- ✅ `reversePayment(paymentId: Nat): async Result<(), Text>`
  - Only reverses "Completed" payments
  - Performs wallet debit/credit with rollback
  - Updates payment status to "Reversed"
  - Emits `PaymentReversed` event
  - **NO admin approval workflow**

**Escrow Canister** (`/AxiaSystem_backend/escrow/`)
- ✅ `cancelEscrow(escrowId: Nat): async Result<(), Text>`
  - Only cancels non-finalized escrows
  - Refunds to sender wallet
  - Sets `isCanceled = true`
  - Emits `EscrowCanceled` event
  - **NO admin approval workflow**

**Payout Canister** (`/AxiaSystem_backend/payout/`)
- ✅ `cancelPayout(payoutId: Nat): async Result<(), Text>`
  - Only cancels "Pending" payouts
  - Updates status to "Cancelled"
  - Emits `PayoutCancelled` event
  - **NO refund of allocated funds**

**Split Payment Canister** (`/AxiaSystem_backend/split_payment/`)
- ✅ `cancelSplitPayment(paymentId: Nat): async Result<(), Text>`
  - Only cancels "Pending" split payments
  - Updates status to "Cancelled"
  - Emits `SplitPaymentCancelled` event
  - **NO refund workflow**

**Event System** (`/AxiaSystem_backend/heartbeat/`)
- ✅ Events defined: `PaymentReversed`, `EscrowCanceled`, `PayoutCancelled`, `SplitPaymentCancelled`
- ✅ Event payload structures with basic metadata
- ❌ **NO event querying by type/date/user**
- ❌ **NO centralized event aggregation**

### ❌ MISSING Critical Functionality

**Admin Workflow Management**
- ❌ No refund **request** creation (vs immediate action)
- ❌ No pending review queue
- ❌ No admin approval/denial workflow
- ❌ No admin notes/reasoning storage
- ❌ No approval audit trail

**Centralized Management**
- ❌ No cross-canister refund aggregation
- ❌ No unified refund status tracking
- ❌ No filtering by refund status/type/date
- ❌ No pagination for admin lists

**Advanced Operations**
- ❌ No partial refunds
- ❌ No refund reason categories
- ❌ No automatic refund processing rules
- ❌ No refund amount validation against original transaction

## Required Backend Implementation

### Phase 1: Extend Individual Canisters

Add to **each canister** (Payment, Escrow, Payout, SplitPayment):

```motoko
// Core types for refund management
public type RefundRequestId = Nat;

public type RefundRequest = {
    id: RefundRequestId;
    originId: Nat;                    // paymentId | escrowId | payoutId | splitId
    originType: Text;                 // "Payment" | "Escrow" | "Payout" | "SplitPayment"
    requestedBy: Principal;           // User/system that requested refund
    requestedAt: Int;                 // Timestamp
    amount: Nat;                      // Amount to refund
    reason: ?Text;                    // User-provided reason
    status: Text;                     // "Requested" | "PendingReview" | "Approved" | "Denied" | "Processing" | "Completed" | "Failed"
    adminPrincipal: ?Principal;       // Admin who approved/denied
    adminNote: ?Text;                 // Admin reasoning
    processedAt: ?Int;                // When processed
    lastUpdatedAt: Int;               // For sorting/filtering
};

// Required methods for EACH canister:
public func createRefundRequest(
    originId: Nat,
    requestedBy: Principal, 
    amount: Nat,
    reason: ?Text
): async Result<RefundRequestId, Text>;

public func listRefundRequests(
    status: ?Text,
    requestedBy: ?Principal,
    fromDate: ?Int,
    toDate: ?Int,
    offset: Nat,
    limit: Nat
): async Result<[RefundRequest], Text>;

public func getRefundRequest(requestId: RefundRequestId): async Result<RefundRequest, Text>;

public func approveRefundRequest(
    requestId: RefundRequestId,
    adminPrincipal: Principal,
    adminNote: ?Text
): async Result<(), Text>;

public func denyRefundRequest(
    requestId: RefundRequestId,
    adminPrincipal: Principal,
    adminNote: ?Text
): async Result<(), Text>;

public func processApprovedRefund(requestId: RefundRequestId): async Result<(), Text>;

// Get refund statistics for admin dashboard
public func getRefundStats(): async {
    total: Nat;
    byStatus: [(Text, Nat)];           // [("Requested", 5), ("Approved", 2), ...]
    totalAmount: Nat;                  // Total amount in refund requests
};
```

### Phase 2: Centralized Refunds Canister (Optional Enhancement)

Create dedicated `refunds` canister for cross-system management:

```motoko
// Aggregated refund view across all canisters
public type AggregatedRefund = {
    id: Text;                         // Format: "payment_123" | "escrow_456"
    canisterType: Text;               // "Payment" | "Escrow" | "Payout" | "SplitPayment"
    canisterId: Principal;            // Source canister principal
    localId: Nat;                     // Local refund request ID
    request: RefundRequest;           // Full request data
};

public func listAllRefunds(
    canisterType: ?Text,
    status: ?Text,
    requestedBy: ?Principal,
    fromDate: ?Int,
    toDate: ?Int,
    offset: Nat,
    limit: Nat
): async Result<[AggregatedRefund], Text>;

public func getAggregatedRefund(id: Text): async Result<AggregatedRefund, Text>;

public func approveRefundGlobally(
    id: Text,
    adminPrincipal: Principal,
    adminNote: ?Text
): async Result<(), Text>;

public func denyRefundGlobally(
    id: Text,
    adminPrincipal: Principal,
    adminNote: ?Text
): async Result<(), Text>;

public func getGlobalRefundStats(): async {
    totalByCanister: [(Text, Nat)];   // [("Payment", 15), ("Escrow", 8), ...]
    totalByStatus: [(Text, Nat)];
    totalAmount: Nat;
    avgProcessingTime: ?Nat;          // Nanoseconds
};
```

### Phase 3: Enhanced Event System

Extend `/AxiaSystem_backend/heartbeat/` for better event querying:

```motoko
// Add to event_types.mo
#RefundRequested : { 
    refundId: Nat; 
    originType: Text; 
    originId: Nat; 
    requestedBy: Principal; 
    amount: Nat; 
    reason: ?Text; 
    timestamp: Int; 
};
#RefundApproved : { 
    refundId: Nat; 
    adminPrincipal: Principal; 
    adminNote: ?Text; 
    timestamp: Int; 
};
#RefundDenied : { 
    refundId: Nat; 
    adminPrincipal: Principal; 
    adminNote: ?Text; 
    timestamp: Int; 
};
#RefundProcessed : { 
    refundId: Nat; 
    processedAt: Int; 
    success: Bool; 
    errorMsg: ?Text; 
};

// Enhanced event querying
public func getEventsByType(
    eventType: EventType,
    fromDate: ?Int,
    toDate: ?Int,
    offset: Nat,
    limit: Nat
): async [Event];

public func getEventsByPrincipal(
    principal: Principal,
    eventTypes: ?[EventType],
    fromDate: ?Int,
    toDate: ?Int,
    offset: Nat,
    limit: Nat
): async [Event];
```

## Implementation Priority

**CRITICAL (Phase 1)** - Required for admin queue functionality:
1. `createRefundRequest()` - Users request refunds instead of immediate action
2. `listRefundRequests()` - Admin can see pending requests with filtering
3. `approveRefundRequest()` / `denyRefundRequest()` - Admin workflow
4. `processApprovedRefund()` - Execute approved refunds

**IMPORTANT (Phase 2)** - Enhanced admin experience:
5. Centralized refunds canister for cross-system view
6. Global refund statistics and reporting
7. Enhanced event tracking for audit trails

**NICE-TO-HAVE (Phase 3)** - Advanced features:
8. Automatic refund processing rules
9. Partial refund capabilities
10. Refund amount validation against original transactions

## Current Frontend Status

✅ **Frontend is COMPLETE** with comprehensive admin interface
✅ **Mock data backend** already implemented for immediate development
✅ **Real integration stubs** ready for Phase 1 backend implementation

## Integration Plan

1. **Immediate**: Use existing mock backend for UI development/testing
2. **Phase 1**: Replace mock calls with real canister integration as backend methods are implemented
3. **Phase 2**: Enhance with centralized aggregation once available
4. **Phase 3**: Add advanced features as business requirements evolve

## Estimated Implementation Effort

**Phase 1 (Core)**: 3-5 days per canister × 4 canisters = 12-20 days
**Phase 2 (Centralized)**: 5-7 days  
**Phase 3 (Enhanced)**: 3-5 days

**Total**: 20-32 days for complete refund management system

---

**Conclusion**: Current backend provides basic reversal operations but lacks comprehensive refund workflow management. Phase 1 implementation is **REQUIRED** for production-ready admin queue functionality.
