import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import _Debug "mo:base/Debug";
import Iter "mo:base/Iter";

module PerformanceMonitor {
    
    // Performance tracking types
    public type LatencyBucket = {
        p50: Float;    // 50th percentile (median)
        p90: Float;    // 90th percentile
        p95: Float;    // 95th percentile
        p99: Float;    // 99th percentile
        max: Float;    // Maximum latency
        min: Float;    // Minimum latency
        avg: Float;    // Average latency
        count: Nat;    // Total samples
    };
    
    public type PerformanceMetrics = {
        requestLatency: LatencyBucket;
        throughput: {
            requestsPerSecond: Float;
            requestsPerMinute: Float;
        };
        errorRates: {
            circuitBreakerTrips: Nat;
            rateLimitViolations: Nat;
            timeouts: Nat;
            failures: Nat;
        };
        resourceUtilization: {
            memoryUsageMB: Float;
            cpuUtilization: Float;
            activeConnections: Nat;
        };
    };
    
    public type LatencyMeasurement = {
        startTime: Int;
        endTime: Int;
        operation: Text;
        success: Bool;
    };
    
    // Performance monitor state
    public class PerformanceTracker() {
        private var latencyMeasurements = Buffer.Buffer<LatencyMeasurement>(1000);
        private var totalRequests: Nat = 0;
        private var totalErrors: Nat = 0;
        private var circuitBreakerTrips: Nat = 0;
        private var rateLimitViolations: Nat = 0;
        private var timeouts: Nat = 0;
        private var failures: Nat = 0;
        private var windowStartTime: Int = Time.now();
        
        // Start timing an operation
        public func startTimer(_operation: Text) : Int {
            Time.now()
        };
        
        // Record completed operation
        public func recordLatency(startTime: Int, _operation: Text, success: Bool) {
            let endTime = Time.now();
            let measurement: LatencyMeasurement = {
                startTime = startTime;
                endTime = endTime;
                operation = _operation;
                success = success;
            };
            
            latencyMeasurements.add(measurement);
            totalRequests += 1;
            
            if (not success) {
                totalErrors += 1;
                
                // Categorize errors
                switch (_operation) {
                    case ("circuit_breaker_trip") { circuitBreakerTrips += 1; };
                    case ("rate_limit_violation") { rateLimitViolations += 1; };
                    case ("timeout") { timeouts += 1; };
                    case ("failure") { failures += 1; };
                    case (_) { failures += 1; };
                };
            };
            
            // Keep rolling window of last 10000 measurements
            if (latencyMeasurements.size() > 10000) {
                let newBuffer = Buffer.Buffer<LatencyMeasurement>(1000);
                let measurements = Buffer.toArray(latencyMeasurements);
                let measurementCount = measurements.size();
                
                if (measurementCount > 5000) {
                    let keepFromNat = Int.abs(measurementCount - 5000); // Keep last 5000
                    
                    for (i in Iter.range(keepFromNat, measurementCount - 1)) {
                        newBuffer.add(measurements[i]);
                    };
                    
                    latencyMeasurements := newBuffer;
                };
            };
        };
        
        // Calculate percentiles from latency measurements
        public func calculateLatencyBuckets() : LatencyBucket {
            let measurements = Buffer.toArray(latencyMeasurements);
            
            if (measurements.size() == 0) {
                return {
                    p50 = 0.0;
                    p90 = 0.0;
                    p95 = 0.0;
                    p99 = 0.0;
                    max = 0.0;
                    min = 0.0;
                    avg = 0.0;
                    count = 0;
                };
            };
            
            // Convert to latency values in milliseconds
            let latencies = Array.map<LatencyMeasurement, Float>(measurements, func(m) : Float {
                Float.fromInt(Int.abs(m.endTime - m.startTime)) / 1_000_000.0 // Convert to ms
            });
            
            // Sort latencies for percentile calculation
            let sortedLatencies = Array.sort<Float>(latencies, Float.compare);
            let count = sortedLatencies.size();
            
            // Calculate percentiles
            let p50Index = count * 50 / 100;
            let p90Index = count * 90 / 100;
            let p95Index = count * 95 / 100;
            let p99Index = count * 99 / 100;
            
            let p50 = if (p50Index < count) { sortedLatencies[p50Index] } else { 0.0 };
            let p90 = if (p90Index < count) { sortedLatencies[p90Index] } else { 0.0 };
            let p95 = if (p95Index < count) { sortedLatencies[p95Index] } else { 0.0 };
            let p99 = if (p99Index < count) { sortedLatencies[p99Index] } else { 0.0 };
            
            let max = sortedLatencies[count - 1];
            let min = sortedLatencies[0];
            
            // Calculate average
            var sum: Float = 0.0;
            for (latency in sortedLatencies.vals()) {
                sum += latency;
            };
            let avg = sum / Float.fromInt(count);
            
            {
                p50 = p50;
                p90 = p90;
                p95 = p95;
                p99 = p99;
                max = max;
                min = min;
                avg = avg;
                count = count;
            }
        };
        
        // Calculate throughput metrics
        public func calculateThroughput() : { requestsPerSecond: Float; requestsPerMinute: Float } {
            let now = Time.now();
            let windowDurationSeconds = Float.fromInt(Int.abs(now - windowStartTime)) / 1_000_000_000.0;
            
            if (windowDurationSeconds > 0.0) {
                let rps = Float.fromInt(totalRequests) / windowDurationSeconds;
                let rpm = rps * 60.0;
                { requestsPerSecond = rps; requestsPerMinute = rpm }
            } else {
                { requestsPerSecond = 0.0; requestsPerMinute = 0.0 }
            }
        };
        
        // Get comprehensive performance metrics
        public func getPerformanceMetrics() : PerformanceMetrics {
            let latencyBuckets = calculateLatencyBuckets();
            let throughput = calculateThroughput();
            
            {
                requestLatency = latencyBuckets;
                throughput = throughput;
                errorRates = {
                    circuitBreakerTrips = circuitBreakerTrips;
                    rateLimitViolations = rateLimitViolations;
                    timeouts = timeouts;
                    failures = failures;
                };
                resourceUtilization = {
                    memoryUsageMB = 0.0; // TODO: Implement actual memory tracking
                    cpuUtilization = 0.0; // TODO: Implement actual CPU tracking
                    activeConnections = totalRequests;
                };
            }
        };
        
        // Reset performance counters (useful for testing)
        public func reset() {
            latencyMeasurements := Buffer.Buffer<LatencyMeasurement>(1000);
            totalRequests := 0;
            totalErrors := 0;
            circuitBreakerTrips := 0;
            rateLimitViolations := 0;
            timeouts := 0;
            failures := 0;
            windowStartTime := Time.now();
        };
        
        // Record specific error types
        public func recordCircuitBreakerTrip() {
            circuitBreakerTrips += 1;
            totalErrors += 1;
        };
        
        public func recordRateLimitViolation() {
            rateLimitViolations += 1;
            totalErrors += 1;
        };
        
        public func recordTimeout() {
            timeouts += 1;
            totalErrors += 1;
        };
        
        public func recordFailure() {
            failures += 1;
            totalErrors += 1;
        };
    };
}
