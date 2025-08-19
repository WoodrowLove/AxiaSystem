#!/bin/bash

# Test AI Router with proper request structure
echo "=== Testing AI Router with Proper Request Structure ==="

# Get current timestamp
TIMESTAMP=$(date +%s)
NANOS=$(date +%N)
FULL_TIMESTAMP="${TIMESTAMP}${NANOS:0:6}000"

# Create a proper AI request
echo "[TEST] Creating proper AI request..."

dfx canister call wykia-ph777-77774-qaama-cai submit "(
  record {
    correlationId = \"test-correlation-${TIMESTAMP}\";
    idempotencyKey = \"test-idempotency-${TIMESTAMP}\";
    sessionId = \"test-session-${TIMESTAMP}\";
    submitterId = \"test-submitter\";
    timestamp = ${FULL_TIMESTAMP};
    requestType = variant { PaymentRisk };
    priority = variant { Normal };
    timeoutMs = 30000;
    retryCount = 0;
    payload = record {
      userId = \"test-user-id\";
      transactionId = opt \"test-transaction-123\";
      amountTier = 1;
      riskFactors = vec { \"test_factor_1\"; \"test_factor_2\" };
      patternHash = \"test-pattern-hash\";
      contextBlob = blob \"\\48\\65\\6C\\6C\\6F\\20\\57\\6F\\72\\6C\\64\";
      metadata = vec { 
        record { \"key1\"; \"value1\" };
        record { \"key2\"; \"value2\" };
      };
    };
    triadContext = null;
  }
)"

echo ""
echo "[TEST] Checking performance metrics after request..."
dfx canister call wykia-ph777-77774-qaama-cai performanceMetrics

echo ""
echo "[TEST] Checking system health..."
dfx canister call wykia-ph777-77774-qaama-cai health

echo ""
echo "Test completed successfully!"
