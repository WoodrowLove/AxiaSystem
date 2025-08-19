import Time "mo:base/Time";
import Result "mo:base/Result";
import Text "mo:base/Text";
import _Array "mo:base/Array";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Float "mo:base/Float";

module {
    public type BatchRequest = {
        batchId: Text;
        requests: [RequestItem];
        submittedAt: Time.Time;
        submittedBy: Principal;
        priority: BatchPriority;
        processingConfig: ProcessingConfig;
    };

    public type RequestItem = {
        itemId: Text;
        requestType: RequestType;
        payload: Text;
        correlationId: Text;
    };

    public type RequestType = {
        #ComplianceCheck;
        #EscrowAdvisory;
        #ModelInference;
        #ReportGeneration;
        #HealthCheck;
    };

    public type BatchPriority = {
        #Low;
        #Normal;
        #High;
        #Critical;
    };

    public type ProcessingConfig = {
        maxBatchSize: Nat;
        timeoutMs: Nat;
        retryAttempts: Nat;
        parallelProcessing: Bool;
    };

    public type BatchResponse = {
        batchId: Text;
        responses: [ResponseItem];
        processedAt: Time.Time;
        processingTimeMs: Nat;
        status: BatchStatus;
        metrics: ProcessingMetrics;
    };

    public type ResponseItem = {
        itemId: Text;
        status: ItemStatus;
        response: ?Text;
        error: ?Text;
        processingTimeMs: Nat;
    };

    public type ItemStatus = {
        #Success;
        #Failed;
        #Timeout;
        #Skipped;
    };

    public type BatchStatus = {
        #Completed;
        #PartiallyCompleted;
        #Failed;
        #Processing;
        #Queued;
    };

    public type ProcessingMetrics = {
        totalItems: Nat;
        successfulItems: Nat;
        failedItems: Nat;
        averageProcessingTimeMs: Nat;
        throughputPerSecond: Float;
    };

    public type QueueMetrics = {
        queuedBatches: Nat;
        processingBatches: Nat;
        completedBatches: Nat;
        averageWaitTimeMs: Nat;
        processingCapacity: Float;
    };

    public class BatchProcessor() {
        private var batchCounter: Nat = 0;
        private let queuedBatches = Buffer.Buffer<BatchRequest>(100);
        private let processingBatches = HashMap.HashMap<Text, BatchRequest>(50, Text.equal, Text.hash);
        private let completedBatches = HashMap.HashMap<Text, BatchResponse>(200, Text.equal, Text.hash);
        private var defaultConfig: ProcessingConfig = {
            maxBatchSize = 100;
            timeoutMs = 30000; // 30 seconds
            retryAttempts = 3;
            parallelProcessing = true;
        };

        public func submitBatch(
            requests: [RequestItem], 
            submittedBy: Principal,
            priority: ?BatchPriority,
            config: ?ProcessingConfig
        ) : Result.Result<Text, Text> {
            if (requests.size() == 0) {
                return #err("Empty batch not allowed");
            };

            batchCounter += 1;
            let batchId = "batch_" # Nat.toText(batchCounter) # "_" # Int.toText(Time.now());
            
            let batchConfig = Option.get(config, defaultConfig);
            if (requests.size() > batchConfig.maxBatchSize) {
                return #err("Batch size exceeds maximum allowed: " # Nat.toText(batchConfig.maxBatchSize));
            };

            let batch: BatchRequest = {
                batchId = batchId;
                requests = requests;
                submittedAt = Time.now();
                submittedBy = submittedBy;
                priority = Option.get(priority, #Normal);
                processingConfig = batchConfig;
            };

            // Insert batch into queue based on priority
            insertBatchByPriority(batch);
            #ok(batchId)
        };

        public func processBatch(batchId: Text) : async Result.Result<BatchResponse, Text> {
            // Find batch in queue
            var batchIndex: ?Nat = null;
            var targetBatch: ?BatchRequest = null;

            label findLoop for (i in Iter.range(0, queuedBatches.size() - 1)) {
                if (queuedBatches.get(i).batchId == batchId) {
                    batchIndex := ?i;
                    targetBatch := ?queuedBatches.get(i);
                    break findLoop;
                }
            };

            switch (targetBatch, batchIndex) {
                case (?batch, ?index) {
                    // Remove from queue and add to processing
                    ignore queuedBatches.remove(index);
                    processingBatches.put(batchId, batch);

                    // Process the batch
                    let response = await executeBatchProcessing(batch);
                    
                    // Move to completed
                    ignore processingBatches.remove(batchId);
                    completedBatches.put(batchId, response);
                    
                    #ok(response)
                };
                case (_, _) {
                    #err("Batch not found in queue")
                };
            }
        };

        public func processNextBatch() : async ?BatchResponse {
            if (queuedBatches.size() == 0) {
                return null;
            };

            // Get highest priority batch
            let batch = queuedBatches.remove(0);
            processingBatches.put(batch.batchId, batch);

            let response = await executeBatchProcessing(batch);
            
            ignore processingBatches.remove(batch.batchId);
            completedBatches.put(batch.batchId, response);
            
            ?response
        };

        public func getBatchStatus(batchId: Text) : ?BatchStatus {
            // Check completed first
            switch (completedBatches.get(batchId)) {
                case (?response) {
                    ?response.status
                };
                case null {
                    // Check processing
                    switch (processingBatches.get(batchId)) {
                        case (?_) ?#Processing;
                        case null {
                            // Check queued
                            for (batch in queuedBatches.vals()) {
                                if (batch.batchId == batchId) {
                                    return ?#Queued;
                                }
                            };
                            null
                        };
                    }
                };
            }
        };

        public func getBatchResponse(batchId: Text) : ?BatchResponse {
            completedBatches.get(batchId)
        };

        public func getQueueMetrics() : QueueMetrics {
            let totalCompleted = completedBatches.size();
            let processing = processingBatches.size();
            let queued = queuedBatches.size();

            // Calculate average wait time (simplified)
            var totalWaitTime: Int = 0;
            let now = Time.now();
            for (batch in queuedBatches.vals()) {
                totalWaitTime += (now - batch.submittedAt);
            };

            let avgWaitTimeNanos = if (queued > 0) { totalWaitTime / queued } else { 0 };
            let avgWaitTimeMs = Int.abs(avgWaitTimeNanos) / 1_000_000;

            {
                queuedBatches = queued;
                processingBatches = processing;
                completedBatches = totalCompleted;
                averageWaitTimeMs = avgWaitTimeMs;
                processingCapacity = if (queued + processing > 0) {
                    Float.fromInt(processing) / Float.fromInt(queued + processing)
                } else { 1.0 };
            }
        };

        public func optimizeBatchSize(requestType: RequestType, currentLatency: Nat) : Nat {
            // Dynamic batch size optimization based on request type and performance
            let baseSize = switch (requestType) {
                case (#ComplianceCheck) 50;
                case (#EscrowAdvisory) 25;
                case (#ModelInference) 10;
                case (#ReportGeneration) 5;
                case (#HealthCheck) 100;
            };

            // Adjust based on current latency
            if (currentLatency > 5000) { // > 5 seconds
                baseSize / 2
            } else if (currentLatency < 1000) { // < 1 second
                Nat.min(baseSize * 2, defaultConfig.maxBatchSize)
            } else {
                baseSize
            }
        };

        public func clearCompletedBatches(olderThanNanos: Int) : Nat {
            let cutoffTime = Time.now() - olderThanNanos;
            let toRemove = Buffer.Buffer<Text>(completedBatches.size());

            for ((batchId, response) in completedBatches.entries()) {
                if (response.processedAt < cutoffTime) {
                    toRemove.add(batchId);
                }
            };

            for (batchId in toRemove.vals()) {
                ignore completedBatches.remove(batchId);
            };

            toRemove.size()
        };

        // Private helper functions
        private func insertBatchByPriority(batch: BatchRequest) {
            let priorityValue = switch (batch.priority) {
                case (#Critical) 4;
                case (#High) 3;
                case (#Normal) 2;
                case (#Low) 1;
            };

            var insertIndex = queuedBatches.size();
            
            label insertLoop for (i in Iter.range(0, queuedBatches.size() - 1)) {
                let existingPriority = switch (queuedBatches.get(i).priority) {
                    case (#Critical) 4;
                    case (#High) 3;
                    case (#Normal) 2;
                    case (#Low) 1;
                };
                
                if (priorityValue > existingPriority) {
                    insertIndex := i;
                    break insertLoop;
                }
            };

            queuedBatches.insert(insertIndex, batch);
        };

        private func executeBatchProcessing(batch: BatchRequest) : async BatchResponse {
            let startTime = Time.now();
            let responses = Buffer.Buffer<ResponseItem>(batch.requests.size());
            var successCount = 0;
            var failureCount = 0;
            var totalProcessingTime = 0;

            // Process each item in the batch
            for (request in batch.requests.vals()) {
                let itemStartTime = Time.now();
                let result = await processItem(request, batch.processingConfig);
                let itemProcessingTime = Int.abs(Time.now() - itemStartTime) / 1_000_000;
                
                totalProcessingTime += itemProcessingTime;

                switch (result) {
                    case (#ok(response)) {
                        responses.add({
                            itemId = request.itemId;
                            status = #Success;
                            response = ?response;
                            error = null;
                            processingTimeMs = itemProcessingTime;
                        });
                        successCount += 1;
                    };
                    case (#err(error)) {
                        responses.add({
                            itemId = request.itemId;
                            status = #Failed;
                            response = null;
                            error = ?error;
                            processingTimeMs = itemProcessingTime;
                        });
                        failureCount += 1;
                    };
                }
            };

            let endTime = Time.now();
            let totalProcessingTimeMs = Int.abs(endTime - startTime) / 1_000_000;
            let avgProcessingTime = if (batch.requests.size() > 0) {
                totalProcessingTime / batch.requests.size()
            } else { 0 };

            let batchStatus = if (successCount == batch.requests.size()) {
                #Completed
            } else if (successCount > 0) {
                #PartiallyCompleted  
            } else {
                #Failed
            };

            let throughput = if (totalProcessingTimeMs > 0) {
                Float.fromInt(batch.requests.size() * 1000) / Float.fromInt(totalProcessingTimeMs)
            } else { 0.0 };

            {
                batchId = batch.batchId;
                responses = Buffer.toArray(responses);
                processedAt = endTime;
                processingTimeMs = totalProcessingTimeMs;
                status = batchStatus;
                metrics = {
                    totalItems = batch.requests.size();
                    successfulItems = successCount;
                    failedItems = failureCount;
                    averageProcessingTimeMs = avgProcessingTime;
                    throughputPerSecond = throughput;
                };
            }
        };

        private func processItem(request: RequestItem, _config: ProcessingConfig) : async Result.Result<Text, Text> {
            // Simulate processing based on request type
            let _processingDelay = switch (request.requestType) {
                case (#ComplianceCheck) 100; // 100ms
                case (#EscrowAdvisory) 200; // 200ms  
                case (#ModelInference) 500; // 500ms
                case (#ReportGeneration) 1000; // 1000ms
                case (#HealthCheck) 50; // 50ms
            };

            let requestTypeText = switch (request.requestType) {
                case (#ComplianceCheck) "ComplianceCheck";
                case (#EscrowAdvisory) "EscrowAdvisory";
                case (#ModelInference) "ModelInference";
                case (#ReportGeneration) "ReportGeneration";
                case (#HealthCheck) "HealthCheck";
            };

            // Simulate success/failure (90% success rate)
            let success = (Text.hash(request.itemId) % 10) != 0;

            if (success) {
                #ok("Processed: " # requestTypeText # " for " # request.itemId)
            } else {
                #err("Processing failed for " # request.itemId)
            }
        };
    };
}
