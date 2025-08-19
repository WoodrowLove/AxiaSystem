import Time "mo:base/Time";
import Result "mo:base/Result";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";

module {
    public type CryptoKey = {
        version: Nat;
        keyData: Text; // In production would be proper key material
        createdAt: Time.Time;
        expiresAt: Time.Time;
        status: KeyStatus;
        algorithm: Text;
    };

    public type KeyStatus = {
        #Active;
        #Pending;
        #Deprecated;
        #Revoked;
    };

    public type RotationSchedule = {
        intervalNanos: Int;
        nextRotation: Time.Time;
        autoRotate: Bool;
        notificationThreshold: Int; // Nanoseconds before expiry to alert
    };

    public type RotationEvent = {
        eventId: Text;
        timestamp: Time.Time;
        oldKeyVersion: Nat;
        newKeyVersion: Nat;
        reason: RotationReason;
        initiatedBy: Principal;
    };

    public type RotationReason = {
        #Scheduled;
        #Compromised;
        #Manual;
        #Emergency;
        #PolicyUpdate;
    };

    public type RotationAlert = {
        alertId: Text;
        severity: AlertSeverity;
        message: Text;
        triggeredAt: Time.Time;
        keyVersion: Nat;
        actionRequired: Bool;
    };

    public type AlertSeverity = {
        #Info;
        #Warning;
        #Critical;
        #Emergency;
    };

    public class KeyRotationManager() {
        private var currentKeyVersion: Nat = 1;
        private let keys = HashMap.HashMap<Nat, CryptoKey>(50, Nat.equal, func(n: Nat) : Nat32 { Nat32.fromNat(n) });
        private let rotationEvents = Buffer.Buffer<RotationEvent>(100);
        private let activeAlerts = Buffer.Buffer<RotationAlert>(20);
        private var rotationSchedule: RotationSchedule = {
            intervalNanos = 7 * 24 * 60 * 60 * 1_000_000_000; // 7 days
            nextRotation = Time.now() + (7 * 24 * 60 * 60 * 1_000_000_000);
            autoRotate = true;
            notificationThreshold = 24 * 60 * 60 * 1_000_000_000; // 24 hours
        };

        // Initialize with first key
        ignore do {
            let initialKey: CryptoKey = {
                version = 1;
                keyData = "initial_key_v1_" # Int.toText(Time.now());
                createdAt = Time.now();
                expiresAt = Time.now() + rotationSchedule.intervalNanos;
                status = #Active;
                algorithm = "ECDSA-SHA256";
            };
            keys.put(1, initialKey);
        };

        public func getCurrentKey() : ?CryptoKey {
            keys.get(currentKeyVersion)
        };

        public func getKey(version: Nat) : ?CryptoKey {
            keys.get(version)
        };

        public func getAllKeys() : [CryptoKey] {
            Iter.toArray(Iter.map(keys.vals(), func(key: CryptoKey) : CryptoKey { key }))
        };

        public func rotateKey(reason: RotationReason, initiatedBy: Principal) : Result.Result<CryptoKey, Text> {
            let newVersion = currentKeyVersion + 1;
            let now = Time.now();

            // Create new key
            let newKey: CryptoKey = {
                version = newVersion;
                keyData = "key_v" # Nat.toText(newVersion) # "_" # Int.toText(now);
                createdAt = now;
                expiresAt = now + rotationSchedule.intervalNanos;
                status = #Active;
                algorithm = "ECDSA-SHA256";
            };

            // Deprecate old key
            switch (keys.get(currentKeyVersion)) {
                case (?oldKey) {
                    let deprecatedKey = {
                        oldKey with status = #Deprecated
                    };
                    keys.put(currentKeyVersion, deprecatedKey);
                };
                case null {
                    return #err("Current key not found");
                };
            };

            // Store new key and update version
            keys.put(newVersion, newKey);
            currentKeyVersion := newVersion;

            // Record rotation event
            let event: RotationEvent = {
                eventId = "rot_" # Nat.toText(newVersion) # "_" # Int.toText(now);
                timestamp = now;
                oldKeyVersion = newVersion - 1;
                newKeyVersion = newVersion;
                reason = reason;
                initiatedBy = initiatedBy;
            };
            rotationEvents.add(event);

            // Update next rotation schedule
            rotationSchedule := {
                rotationSchedule with 
                nextRotation = now + rotationSchedule.intervalNanos;
            };

            // Clear old alerts and create success alert
            clearAlertsForKey(newVersion - 1);
            createAlert(#Info, "Key rotation completed successfully", newVersion, false);

            #ok(newKey)
        };

        public func scheduleRotation(intervalNanos: Int, autoRotate: Bool) : RotationSchedule {
            rotationSchedule := {
                intervalNanos = intervalNanos;
                nextRotation = Time.now() + intervalNanos;
                autoRotate = autoRotate;
                notificationThreshold = rotationSchedule.notificationThreshold;
            };
            rotationSchedule
        };

        public func checkRotationAlerts() : [RotationAlert] {
            let now = Time.now();
            let _newAlerts = Buffer.Buffer<RotationAlert>(5);

            // Check if rotation is due
            if (rotationSchedule.autoRotate and now >= rotationSchedule.nextRotation) {
                createAlert(#Critical, "Automatic key rotation is overdue", currentKeyVersion, true);
            };

            // Check if notification threshold reached
            let timeToRotation = rotationSchedule.nextRotation - now;
            if (timeToRotation <= rotationSchedule.notificationThreshold and timeToRotation > 0) {
                let hoursRemaining = timeToRotation / (60 * 60 * 1_000_000_000);
                createAlert(
                    #Warning, 
                    "Key rotation scheduled in " # Int.toText(hoursRemaining) # " hours", 
                    currentKeyVersion, 
                    false
                );
            };

            // Check for expired keys
            switch (keys.get(currentKeyVersion)) {
                case (?currentKey) {
                    if (now >= currentKey.expiresAt) {
                        createAlert(#Emergency, "Current key has expired", currentKeyVersion, true);
                    };
                };
                case null {};
            };

            Buffer.toArray(activeAlerts)
        };

        public func executeAutomaticRotation(initiatedBy: Principal) : async Result.Result<CryptoKey, Text> {
            let now = Time.now();
            
            if (not rotationSchedule.autoRotate) {
                return #err("Automatic rotation is disabled");
            };

            if (now < rotationSchedule.nextRotation) {
                return #err("Rotation not yet due");
            };

            rotateKey(#Scheduled, initiatedBy)
        };

        public func revokeKey(version: Nat, reason: Text) : Result.Result<Text, Text> {
            switch (keys.get(version)) {
                case (?key) {
                    if (version == currentKeyVersion) {
                        return #err("Cannot revoke current active key");
                    };

                    let revokedKey = {
                        key with status = #Revoked
                    };
                    keys.put(version, revokedKey);

                    createAlert(#Warning, "Key v" # Nat.toText(version) # " revoked: " # reason, version, false);
                    #ok("Key revoked successfully")
                };
                case null {
                    #err("Key not found")
                };
            }
        };

        public func getRotationHistory(limit: ?Nat) : [RotationEvent] {
            let maxLimit = Option.get(limit, 50);
            let events = Buffer.Buffer<RotationEvent>(maxLimit);
            var count = 0;

            // Get most recent events first
            let allEvents = Buffer.toArray(rotationEvents);
            let sortedEvents = Array.sort(allEvents, func(a: RotationEvent, b: RotationEvent) : {#less; #equal; #greater} {
                if (a.timestamp > b.timestamp) #less
                else if (a.timestamp < b.timestamp) #greater  
                else #equal
            });

            label eventLoop for (event in sortedEvents.vals()) {
                if (count >= maxLimit) break eventLoop;
                events.add(event);
                count += 1;
            };

            Buffer.toArray(events)
        };

        public func getRotationMetrics() : {
            currentKeyVersion: Nat;
            totalRotations: Nat;
            nextRotationIn: Int;
            activeAlerts: Nat;
            keysInRotation: Nat;
        } {
            let now = Time.now();
            let activeKeyCount = Iter.size(
                Iter.filter(keys.vals(), func(key: CryptoKey) : Bool {
                    switch (key.status) {
                        case (#Active or #Pending) true;
                        case (_) false;
                    }
                })
            );

            {
                currentKeyVersion = currentKeyVersion;
                totalRotations = rotationEvents.size();
                nextRotationIn = rotationSchedule.nextRotation - now;
                activeAlerts = activeAlerts.size();
                keysInRotation = activeKeyCount;
            }
        };

        // Private helper functions
        private func createAlert(severity: AlertSeverity, message: Text, keyVersion: Nat, actionRequired: Bool) {
            let alert: RotationAlert = {
                alertId = "alert_" # Nat.toText(keyVersion) # "_" # Int.toText(Time.now());
                severity = severity;
                message = message;
                triggeredAt = Time.now();
                keyVersion = keyVersion;
                actionRequired = actionRequired;
            };
            activeAlerts.add(alert);
        };

        private func clearAlertsForKey(keyVersion: Nat) {
            let filteredAlerts = Buffer.Buffer<RotationAlert>(activeAlerts.size());
            
            for (alert in activeAlerts.vals()) {
                if (alert.keyVersion != keyVersion) {
                    filteredAlerts.add(alert);
                }
            };

            activeAlerts.clear();
            for (alert in filteredAlerts.vals()) {
                activeAlerts.add(alert);
            };
        };
    };
}
