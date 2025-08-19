import Time "mo:base/Time";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import HashMap "mo:base/HashMap";
import _Array "mo:base/Array";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";

module {
    public type SecureMessage = {
        payload: Blob;
        signature: Blob;
        timestamp: Time.Time;
        keyVersion: Nat;
        correlationId: Text;
        sender: Principal;
        recipient: Principal;
        messageType: MessageType;
    };

    public type MessageType = {
        #PushNotification;
        #PullRequest;
        #BatchResponse;
        #ComplianceReport;
        #HealthCheck;
        #KeyRotation;
    };

    public type SecurityLevel = {
        #Standard;
        #Enhanced;
        #Critical;
    };

    public type ValidationResult = {
        #Valid: { verifiedAt: Time.Time; securityLevel: SecurityLevel };
        #Invalid: { reason: Text; errorCode: Nat };
        #Expired: { expiredAt: Time.Time };
        #UnknownKey: { keyVersion: Nat };
    };

    public type DeliveryReceipt = {
        messageId: Text;
        deliveredAt: Time.Time;
        recipient: Principal;
        status: DeliveryStatus;
    };

    public type DeliveryStatus = {
        #Delivered;
        #Failed: { reason: Text };
        #Pending;
        #Retrying: { attempt: Nat };
    };

    public class SecureTransport() {
        private var messageCounter: Nat = 0;
        private let messageHistory = HashMap.HashMap<Text, SecureMessage>(100, Text.equal, Text.hash);
        private let deliveryReceipts = HashMap.HashMap<Text, DeliveryReceipt>(100, Text.equal, Text.hash);
        private let pendingDeliveries = Buffer.Buffer<SecureMessage>(50);

        // Core secure messaging functionality
        public func createSecureMessage(
            payload: Blob,
            recipient: Principal,
            messageType: MessageType,
            keyVersion: Nat,
            sender: Principal
        ) : SecureMessage {
            messageCounter += 1;
            let correlationId = "msg_" # Nat.toText(messageCounter) # "_" # Int.toText(Time.now());
            
            {
                payload = payload;
                signature = generateSignature(payload, keyVersion);
                timestamp = Time.now();
                keyVersion = keyVersion;
                correlationId = correlationId;
                sender = sender;
                recipient = recipient;
                messageType = messageType;
            }
        };

        public func validateMessage(message: SecureMessage, currentKeyVersion: Nat) : ValidationResult {
            // Check message age (5 minute window)
            let messageAge = Time.now() - message.timestamp;
            if (messageAge > 300_000_000_000) {
                return #Expired({ expiredAt = message.timestamp });
            };

            // Check key version compatibility
            if (message.keyVersion > currentKeyVersion) {
                return #UnknownKey({ keyVersion = message.keyVersion });
            };

            // Verify signature
            if (not verifySignature(message.payload, message.signature, message.keyVersion)) {
                return #Invalid({ 
                    reason = "Invalid signature"; 
                    errorCode = 4001 
                });
            };

            // Determine security level based on message type
            let securityLevel = switch (message.messageType) {
                case (#ComplianceReport or #KeyRotation) #Critical;
                case (#PushNotification or #BatchResponse) #Enhanced;
                case (#PullRequest or #HealthCheck) #Standard;
            };

            #Valid({ 
                verifiedAt = Time.now(); 
                securityLevel = securityLevel 
            })
        };

        public func deliverMessage(message: SecureMessage) : async Result.Result<DeliveryReceipt, Text> {
            // Store message in history
            messageHistory.put(message.correlationId, message);

            // Attempt delivery
            switch (await attemptDelivery(message)) {
                case (#ok(receipt)) {
                    deliveryReceipts.put(message.correlationId, receipt);
                    #ok(receipt)
                };
                case (#err(error)) {
                    // Queue for retry
                    pendingDeliveries.add(message);
                    #err("Delivery failed: " # error)
                };
            }
        };

        public func processPendingDeliveries() : async [DeliveryReceipt] {
            let results = Buffer.Buffer<DeliveryReceipt>(pendingDeliveries.size());
            let stillPending = Buffer.Buffer<SecureMessage>(pendingDeliveries.size());

            for (message in pendingDeliveries.vals()) {
                switch (await attemptDelivery(message)) {
                    case (#ok(receipt)) {
                        results.add(receipt);
                        deliveryReceipts.put(message.correlationId, receipt);
                    };
                    case (#err(_)) {
                        stillPending.add(message);
                    };
                }
            };

            // Update pending queue
            pendingDeliveries.clear();
            for (msg in stillPending.vals()) {
                pendingDeliveries.add(msg);
            };

            Buffer.toArray(results)
        };

        public func getMessageHistory(limit: ?Nat) : [SecureMessage] {
            let maxLimit = Option.get(limit, 100);
            let messages = Buffer.Buffer<SecureMessage>(maxLimit);
            var count = 0;

            label historyLoop for ((_, message) in messageHistory.entries()) {
                if (count >= maxLimit) break historyLoop;
                messages.add(message);
                count += 1;
            };

            Buffer.toArray(messages)
        };

        public func getDeliveryStatus(correlationId: Text) : ?DeliveryReceipt {
            deliveryReceipts.get(correlationId)
        };

        // Security metrics
        public func getSecurityMetrics() : {
            totalMessages: Nat;
            pendingDeliveries: Nat;
            validationFailures: Nat;
            deliverySuccessRate: Float;
        } {
            let totalDeliveries = deliveryReceipts.size();
            let successfulDeliveries = Iter.size(
                Iter.filter(deliveryReceipts.vals(), func(receipt: DeliveryReceipt) : Bool {
                    switch (receipt.status) {
                        case (#Delivered) true;
                        case (_) false;
                    }
                })
            );

            {
                totalMessages = messageHistory.size();
                pendingDeliveries = pendingDeliveries.size();
                validationFailures = 0; // Would track in real implementation
                deliverySuccessRate = if (totalDeliveries > 0) {
                    Float.fromInt(successfulDeliveries) / Float.fromInt(totalDeliveries)
                } else { 0.0 };
            }
        };

        // Private helper functions
        private func generateSignature(payload: Blob, keyVersion: Nat) : Blob {
            // Simplified signature generation - in production would use proper cryptography
            let content = Blob.toArray(payload);
            let keyData = Nat.toText(keyVersion);
            Text.encodeUtf8("sig_" # keyData # "_" # Nat.toText(content.size()))
        };

        private func verifySignature(payload: Blob, signature: Blob, keyVersion: Nat) : Bool {
            // Simplified verification - in production would use proper cryptography
            let expectedSig = generateSignature(payload, keyVersion);
            Blob.equal(signature, expectedSig)
        };

        private func attemptDelivery(message: SecureMessage) : async Result.Result<DeliveryReceipt, Text> {
            // Simulate delivery attempt with potential failure
            let deliverySuccess = (message.correlationId.size() % 10) != 0; // 90% success rate

            if (deliverySuccess) {
                let receipt: DeliveryReceipt = {
                    messageId = message.correlationId;
                    deliveredAt = Time.now();
                    recipient = message.recipient;
                    status = #Delivered;
                };
                #ok(receipt)
            } else {
                #err("Network timeout")
            }
        };
    };
}
