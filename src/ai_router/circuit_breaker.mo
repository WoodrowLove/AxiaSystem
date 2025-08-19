import _Debug "mo:base/Debug";
import Time "mo:base/Time";
import Text "mo:base/Text";
import _Result "mo:base/Result";
import _HashMap "mo:base/HashMap";
import _Array "mo:base/Array";
import Int "mo:base/Int";
import Float "mo:base/Float";

module CircuitBreaker {
    
    public type CircuitState = {
        #Closed;   // Normal operation
        #Open;     // Circuit broken, failing fast
        #HalfOpen; // Testing recovery
    };
    
    public type CircuitConfig = {
        failureThreshold: Nat;     // Failures before opening
        timeoutThreshold: Nat;     // Timeout threshold in ms
        resetTimeoutMs: Nat;       // Time before attempting reset
        successThreshold: Nat;     // Successes needed to close from half-open
    };
    
    public type CircuitMetrics = {
        state: CircuitState;
        failureCount: Nat;
        successCount: Nat;
        timeoutCount: Nat;
        lastFailureTime: Time.Time;
        lastSuccessTime: Time.Time;
        lastStateChange: Time.Time;
        totalRequests: Nat;
        requestsSinceLastReset: Nat;
    };
    
    public type CircuitBreaker = {
        config: CircuitConfig;
        var metrics: CircuitMetrics;
        var state: CircuitState;
    };
    
    public type RequestResult = {
        #Success: { durationMs: Nat };
        #Failure: { error: Text; durationMs: Nat };
        #Timeout: { durationMs: Nat };
    };
    
    public func createCircuitBreaker(config: CircuitConfig) : CircuitBreaker {
        let now = Time.now();
        {
            config = config;
            var metrics = {
                state = #Closed;
                failureCount = 0;
                successCount = 0;
                timeoutCount = 0;
                lastFailureTime = now;
                lastSuccessTime = now;
                lastStateChange = now;
                totalRequests = 0;
                requestsSinceLastReset = 0;
            };
            var state = #Closed;
        }
    };
    
    public func shouldAllowRequest(circuit: CircuitBreaker) : Bool {
        let now = Time.now();
        
        switch (circuit.state) {
            case (#Closed) {
                true // Always allow in closed state
            };
            case (#Open) {
                // Check if enough time has passed to try half-open
                let timeSinceLastChange = (now - circuit.metrics.lastStateChange) / 1000000; // Convert to ms
                if (Int.abs(timeSinceLastChange) >= circuit.config.resetTimeoutMs) {
                    circuit.state := #HalfOpen;
                    circuit.metrics := {
                        circuit.metrics with
                        state = #HalfOpen;
                        lastStateChange = now;
                        requestsSinceLastReset = 0;
                    };
                    true
                } else {
                    false // Still in open state, reject
                }
            };
            case (#HalfOpen) {
                // Allow limited requests to test recovery
                circuit.metrics.requestsSinceLastReset < 3
            };
        }
    };
    
    public func recordRequest(circuit: CircuitBreaker, result: RequestResult) {
        let now = Time.now();
        
        circuit.metrics := {
            circuit.metrics with
            totalRequests = circuit.metrics.totalRequests + 1;
            requestsSinceLastReset = circuit.metrics.requestsSinceLastReset + 1;
        };
        
        switch (result) {
            case (#Success({ durationMs = _ })) {
                circuit.metrics := {
                    circuit.metrics with
                    successCount = circuit.metrics.successCount + 1;
                    lastSuccessTime = now;
                };
                
                // Handle state transitions on success
                switch (circuit.state) {
                    case (#HalfOpen) {
                        if (circuit.metrics.successCount >= circuit.config.successThreshold) {
                            // Close the circuit - recovery successful
                            circuit.state := #Closed;
                            circuit.metrics := {
                                circuit.metrics with
                                state = #Closed;
                                lastStateChange = now;
                                failureCount = 0; // Reset failure count
                                requestsSinceLastReset = 0;
                            };
                        };
                    };
                    case (_) {}; // No state change for closed circuit on success
                };
            };
            case (#Failure({ error = _; durationMs = _ })) {
                circuit.metrics := {
                    circuit.metrics with
                    failureCount = circuit.metrics.failureCount + 1;
                    lastFailureTime = now;
                };
                
                checkForCircuitOpen(circuit, now);
            };
            case (#Timeout({ durationMs = _ })) {
                circuit.metrics := {
                    circuit.metrics with
                    timeoutCount = circuit.metrics.timeoutCount + 1;
                    failureCount = circuit.metrics.failureCount + 1;
                    lastFailureTime = now;
                };
                
                checkForCircuitOpen(circuit, now);
            };
        };
    };
    
    private func checkForCircuitOpen(circuit: CircuitBreaker, now: Time.Time) {
        if (circuit.metrics.failureCount >= circuit.config.failureThreshold) {
            circuit.state := #Open;
            circuit.metrics := {
                circuit.metrics with
                state = #Open;
                lastStateChange = now;
                requestsSinceLastReset = 0;
            };
        };
    };
    
    public func getMetrics(circuit: CircuitBreaker) : CircuitMetrics {
        circuit.metrics
    };
    
    public func reset(circuit: CircuitBreaker) {
        let now = Time.now();
        circuit.state := #Closed;
        circuit.metrics := {
            circuit.metrics with
            state = #Closed;
            failureCount = 0;
            successCount = 0;
            timeoutCount = 0;
            lastStateChange = now;
            requestsSinceLastReset = 0;
        };
    };
    
    public func forceOpen(circuit: CircuitBreaker) {
        let now = Time.now();
        circuit.state := #Open;
        circuit.metrics := {
            circuit.metrics with
            state = #Open;
            lastStateChange = now;
        };
    };
    
    public func getHealthStatus(circuit: CircuitBreaker) : {
        isHealthy: Bool;
        state: CircuitState;
        failureRate: Float;
        avgResponseTime: Float;
        recommendation: Text;
    } {
        let totalRequests = circuit.metrics.totalRequests;
        let failureRate = if (totalRequests > 0) {
            Float.fromInt(circuit.metrics.failureCount) / Float.fromInt(totalRequests)
        } else {
            0.0
        };
        
        let isHealthy = switch (circuit.state) {
            case (#Closed) { failureRate < 0.1 }; // Less than 10% failure rate
            case (#HalfOpen) { false }; // Uncertain state
            case (#Open) { false }; // Definitely unhealthy
        };
        
        let recommendation = switch (circuit.state) {
            case (#Closed) {
                if (failureRate > 0.05) "Monitor closely - elevated failure rate"
                else "Operating normally"
            };
            case (#HalfOpen) "Testing recovery - limited traffic allowed";
            case (#Open) "Service unavailable - failing fast to protect downstream";
        };
        
        {
            isHealthy = isHealthy;
            state = circuit.state;
            failureRate = failureRate;
            avgResponseTime = 0.0; // Would calculate from historical data
            recommendation = recommendation;
        }
    };
}
