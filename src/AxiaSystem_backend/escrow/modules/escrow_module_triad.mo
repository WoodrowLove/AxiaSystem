import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import LoggingUtils "../../utils/logging_utils";

module {
    // Triad-native condition types
    public type Condition = {
        #manual;
        #timeLock : { notBefore : Nat64 };
        #assetTransfer : { assetId : Nat; to : Principal };
    };

    public type Status = {
        #created;
        #released;
        #canceled;
        #timedOut;
    };

    // Enhanced Triad-native escrow structure
    public type Escrow = {
        id              : Nat;
        payerIdentity   : Principal;     // who funds
        payeeIdentity   : Principal;     // who receives
        payerWalletId   : Principal;
        payeeWalletId   : Principal;
        token           : Text;          // or use your tokenId Nat
        amount          : Nat;
        condition       : Condition;
        lockId          : ?Text;         // Wallet lock reference
        clientRef       : ?Text;         // idempotency key from client
        status          : Status;
        createdAt       : Nat64;
        releasedAt      : ?Nat64;
        canceledAt      : ?Nat64;
        expiresAt       : ?Nat64;        // timeout (auto cancel)
        triadVerified   : Bool;
    };

    // Legacy compatibility type
    public type EscrowState = {
        id: Nat;
        sender: Principal;
        receiver: Principal;
        tokenId: Nat;
        amount: Nat;
        conditions: Text;
        isReleased: Bool;
        isCanceled: Bool;
        createdAt: Nat;
    };

    public type EscrowId = Nat;

    // Key helper functions
    func nk(x : Nat) : Trie.Key<Nat> = { key = x; hash = Nat32.fromNat(x % (2**32 - 1)) };
    func n64k(x : Nat64) : Trie.Key<Nat64> = { key = x; hash = Nat32.fromNat(Nat64.toNat(x) % (2**32 - 1)) };
    func pk(x : Principal) : Trie.Key<Principal> = { key = x; hash = Principal.hash(x) };
    
    // Hour bucket for expiry indexing
    func timeBucket(ts : Nat64) : Nat64 = ts / 3600; // hour epochs

    public class EscrowManager(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        eventManager: EventManager.EventManager
    ) {
        // Store constructor parameters as private variables for clarity
        private let _walletProxy = walletProxy;
        private let _eventManager = eventManager;
        
        // Legacy array for backward compatibility (currently unused in this implementation)
        private var _escrows: [EscrowState] = [];
        private let _logStore = LoggingUtils.init();

        // Triad-native storage + indexes
        private var nextId : Nat = 0;
        private var byId   : Trie.Trie<Nat, Escrow> = Trie.empty();
        // party indexes for fast queries
        private var byPayer : Trie.Trie<Principal, [Nat]> = Trie.empty();
        private var byPayee : Trie.Trie<Principal, [Nat]> = Trie.empty();
        // active by expiry (bucketed by hour)
        private var byExpiryBucket : Trie.Trie<Nat64, [Nat]> = Trie.empty();

        // ===============================
        // CORE TRIAD METHODS
        // ===============================

        // Triad-native create
        public func create(e : Escrow) : Escrow {
            let id = nextId; 
            nextId += 1;
            let rec = { e with id };
            byId := Trie.put(byId, nk(id), Nat.equal, rec).0;
            
            // Index by parties
            indexPayer(rec.payerIdentity, id);
            indexPayee(rec.payeeIdentity, id);
            
            // Index by expiry if set
            switch (rec.expiresAt) {
                case null {};
                case (?ts) indexExpiry(timeBucket(ts), id);
            };
            
            rec
        };

        public func get(id : Nat) : ?Escrow {
            Trie.get(byId, nk(id), Nat.equal)
        };

        public func listAll() : [Escrow] {
            var result : [Escrow] = [];
            for ((k, v) in Trie.iter(byId)) {
                result := Array.append(result, [v]);
            };
            result
        };

        // ===============================
        // INDEXING FUNCTIONS
        // ===============================

        private func indexPayer(payer : Principal, escrowId : Nat) {
            let existing = switch (Trie.get(byPayer, pk(payer), Principal.equal)) {
                case null [];
                case (?ids) ids;
            };
            byPayer := Trie.put(byPayer, pk(payer), Principal.equal, Array.append(existing, [escrowId])).0;
        };

        private func indexPayee(payee : Principal, escrowId : Nat) {
            let existing = switch (Trie.get(byPayee, pk(payee), Principal.equal)) {
                case null [];
                case (?ids) ids;
            };
            byPayee := Trie.put(byPayee, pk(payee), Principal.equal, Array.append(existing, [escrowId])).0;
        };

        private func indexExpiry(hourBucket : Nat64, escrowId : Nat) {
            let existing = switch (Trie.get(byExpiryBucket, n64k(hourBucket), Nat64.equal)) {
                case null [];
                case (?ids) ids;
            };
            byExpiryBucket := Trie.put(byExpiryBucket, n64k(hourBucket), Nat64.equal, Array.append(existing, [escrowId])).0;
        };

        // ===============================
        // CONVERSION HELPERS
        // ===============================

        private func escrowToLegacy(e : Escrow) : EscrowState {
            {
                id = e.id;
                sender = e.payerIdentity;
                receiver = e.payeeIdentity;
                tokenId = 0; // Default to 0 for legacy
                amount = e.amount;
                conditions = switch (e.condition) {
                    case (#manual) "manual";
                    case (#timeLock(params)) "timelock:" # Nat64.toText(params.notBefore);
                    case (#assetTransfer(params)) "asset:" # Nat.toText(params.assetId);
                };
                isReleased = switch (e.status) { case (#released) true; case (_) false };
                isCanceled = switch (e.status) { case (#canceled or #timedOut) true; case (_) false };
                createdAt = Nat64.toNat(e.createdAt);
            }
        };

        // Emit an escrow-related event
        private func emitEscrowEvent(
            eventType: EventTypes.EventType,
            payload: EventTypes.EventPayload
        ): async () {
            let event: EventTypes.Event = {
                id = Nat64.fromIntWrap(Time.now());
                eventType = eventType;
                payload = payload;
            };
            await _eventManager.emit(event);
        };

        // ===============================
        // LEGACY COMPATIBILITY METHODS
        // ===============================

        // Legacy: Create a new escrow (backward compatibility)
        public func createEscrow(
            sender: Principal,
            receiver: Principal,
            tokenId: Nat,
            amount: Nat,
            conditions: Text
        ): async Result.Result<EscrowId, Text> {
            // Convert legacy parameters to Triad format
            let condition: Condition = if (conditions == "manual") {
                #manual
            } else if (Text.startsWith(conditions, #text("timelock:"))) {
                // Parse timelock condition
                #manual // Simplified - would need proper parsing
            } else {
                #manual
            };

            // Create Triad escrow with legacy compatibility
            let escrow: Escrow = {
                id = 0; // Will be set in create()
                payerIdentity = sender;
                payeeIdentity = receiver;
                payerWalletId = sender; // Legacy: use identity as wallet ID
                payeeWalletId = receiver;
                token = "ICP"; // Default token
                amount = amount;
                condition = condition;
                lockId = null; // Legacy: no lock initially
                clientRef = null;
                status = #created;
                createdAt = Nat64.fromIntWrap(Time.now());
                releasedAt = null;
                canceledAt = null;
                expiresAt = null;
                triadVerified = false; // Mark as legacy
            };

            // Verify sender balance (legacy behavior)
            let senderBalance = await _walletProxy.getWalletBalance(sender);
            switch (senderBalance) {
                case (#err(e)) return #err("Failed to validate sender balance: " # e);
                case (#ok(balance)) {
                    if (balance < amount) {
                        return #err("Insufficient balance to create escrow.");
                    };
                };
            };

            // Deduct funds from the sender's wallet (legacy behavior)
            let debitResult = await _walletProxy.debitWallet(sender, amount, tokenId);
            switch (debitResult) {
                case (#err(e)) return #err("Failed to deduct funds: " # e);
                case (#ok(_)) {};
            };

            // Create escrow record
            let created = create(escrow);

            // Emit legacy event
            await emitEscrowEvent(
                #EscrowCreated,
                #EscrowCreated {
                    escrowId = created.id;
                    sender = created.payerIdentity;
                    receiver = created.payeeIdentity;
                    tokenId = tokenId;
                    amount = created.amount
                }
            );

            #ok(created.id)
        };

        public func releaseEscrow(escrowId: EscrowId): async Result.Result<(), Text> {
            switch (get(escrowId)) {
                case null return #err("Escrow not found.");
                case (?escrow) {
                    if (escrow.status != #created) {
                        return #err("Escrow already finalized.");
                    };

                    // Add funds to the receiver's wallet (legacy behavior)
                    let creditResult = await _walletProxy.creditWallet(escrow.payeeIdentity, escrow.amount, 0);
                    switch (creditResult) {
                        case (#err(e)) return #err("Failed to credit funds: " # e);
                        case (#ok(_)) {};
                    };

                    // Update escrow state
                    ignore markReleased(escrowId, Nat64.fromIntWrap(Time.now()));

                    // Emit legacy event
                    await emitEscrowEvent(
                        #EscrowReleased,
                        #EscrowReleased {
                            escrowId = Nat.toText(escrowId);
                            sender = Principal.toText(escrow.payerIdentity);
                            receiver = Principal.toText(escrow.payeeIdentity);
                            amount = escrow.amount;
                            tokenId = "0";
                        }
                    );

                    #ok(())
                };
            };
        };

        public func cancelEscrow(escrowId: EscrowId): async Result.Result<(), Text> {
            switch (get(escrowId)) {
                case null return #err("Escrow not found.");
                case (?escrow) {
                    if (escrow.status != #created) {
                        return #err("Escrow already finalized.");
                    };

                    // Refund funds to the sender's wallet (legacy behavior)
                    let refundResult = await _walletProxy.creditWallet(escrow.payerIdentity, escrow.amount, 0);
                    switch (refundResult) {
                        case (#err(e)) return #err("Failed to refund funds: " # e);
                        case (#ok(_)) {};
                    };

                    // Update escrow state
                    ignore markCanceled(escrowId, Nat64.fromIntWrap(Time.now()), false);

                    // Emit legacy event
                    await emitEscrowEvent(
                        #EscrowCanceled,
                        #EscrowCanceled {
                            escrowId = Nat.toText(escrowId);
                            sender = Principal.toText(escrow.payerIdentity);
                            amount = escrow.amount;
                            tokenId = "0";
                        }
                    );

                    #ok(())
                };
            };
        };

        public func markReleased(id : Nat, ts : Nat64) : ?Escrow {
            switch (Trie.get(byId, nk(id), Nat.equal)) {
                case null null;
                case (?escrow) {
                    let updated = { escrow with status = #released; releasedAt = ?ts };
                    byId := Trie.put(byId, nk(id), Nat.equal, updated).0;
                    ?updated
                };
            }
        };

        public func markCanceled(id : Nat, ts : Nat64, timedOut : Bool) : ?Escrow {
            switch (Trie.get(byId, nk(id), Nat.equal)) {
                case null null;
                case (?escrow) {
                    let status = if (timedOut) #timedOut else #canceled;
                    let updated = { escrow with status = status; canceledAt = ?ts };
                    byId := Trie.put(byId, nk(id), Nat.equal, updated).0;
                    ?updated
                };
            }
        };

        public func listExpiringOn(hourBucket : Nat64) : [Nat] {
            switch (Trie.get(byExpiryBucket, n64k(hourBucket), Nat64.equal)) {
                case null [];
                case (?ids) ids;
            }
        };

        public func processEscrowTimeouts(timeoutThreshold: Nat): async Result.Result<Nat, Text> {
            LoggingUtils.logInfo(
                _logStore,
                "EscrowModule",
                "Processing timed-out escrows with threshold: " # Nat.toText(timeoutThreshold),
                null
            );

            let now = Nat64.fromIntWrap(Time.now());
            let bucketTime = timeBucket(now);
            let ids = listExpiringOn(bucketTime);
            var timedOutCount: Nat = 0;

            // Process expired escrows
            for (id in ids.vals()) {
                switch (get(id)) {
                    case (?escrow) {
                        if (escrow.status == #created) {
                            switch (escrow.expiresAt) {
                                case (?expiry) {
                                    if (now >= expiry) {
                                        // Handle timeout based on whether it's triad or legacy
                                        if (escrow.triadVerified) {
                                            // Triad: cancel lock (would need wallet lock API)
                                            switch (escrow.lockId) {
                                                case null {};
                                                case (?_lockId) {
                                                    // await _walletProxy.cancelLock(lockId);
                                                };
                                            };
                                        } else {
                                            // Legacy: credit back to sender
                                            ignore await _walletProxy.creditWallet(escrow.payerIdentity, escrow.amount, 0);
                                        };

                                        ignore markCanceled(id, now, true);
                                        timedOutCount += 1;

                                        // Emit timeout event
                                        await emitEscrowEvent(
                                            #EscrowTimeoutProcessed,
                                            #EscrowTimeoutProcessed {
                                                timeoutCount = timedOutCount;
                                                timestamp = now;
                                            }
                                        );
                                    };
                                };
                                case null {};
                            };
                        };
                    };
                    case null {};
                };
            };

            LoggingUtils.logInfo(
                _logStore,
                "EscrowModule",
                "Timeout processing completed. Total timed-out escrows: " # Nat.toText(timedOutCount),
                null
            );

            #ok(timedOutCount)
        };

        public func getEscrow(escrowId: EscrowId): async Result.Result<EscrowState, Text> {
            switch (get(escrowId)) {
                case null #err("Escrow not found.");
                case (?escrow) #ok(escrowToLegacy(escrow));
            };
        };

        // List all escrows in legacy format
        public func listEscrows(): async [EscrowState] {
            let allEscrows = listAll();
            Array.map<Escrow, EscrowState>(allEscrows, escrowToLegacy)
        };
    };
}
