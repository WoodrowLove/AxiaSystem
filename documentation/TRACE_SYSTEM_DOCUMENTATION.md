# NamoraAI Trace Normalization System

## Overview

The Trace Normalization Layer is a comprehensive system for linking events across all AxiaSystem modules, providing causal inference and cross-canister correlation capabilities. This system acts as the "connective tissue" between all components of the NamoraSystem.

## Core Concepts

### Trace Links
A `TraceLink` connects an entry (memory, audit, reasoning) to a trace thread:
```motoko
type TraceLink = {
  traceId: Text;           // Unique trace identifier
  entryId: Nat;           // ID of the linked entry
  entryType: Text;        // "memory", "audit", "reasoning", etc.
  timestamp: Int;         // When this link was created
  source: Text;           // Source module/component
  principal: ?Principal;  // Associated user/principal
  tags: [Text];          // Searchable tags
  metadata: [(Text, Text)]; // Additional context
};
```

### Causal Links
A `CausalLink` establishes causal relationships between entries:
```motoko
type CausalLink = {
  traceId: Text;          // Associated trace
  causeEntryId: Nat;      // Entry that causes
  effectEntryId: Nat;     // Entry that is caused
  relationship: Text;     // "triggers", "enables", "prevents", etc.
  confidence: Float;      // Confidence score 0.0-1.0
  timestamp: Int;         // When relationship was detected
  evidence: [Text];       // Supporting evidence
};
```

## API Functions

### Basic Trace Management

#### Register Single Trace Link
```motoko
public func registerTraceLink(link: TraceLink): async Bool
```

#### Register Multiple Trace Links
```motoko
public func registerTraceLinks(links: [TraceLink]): async Nat
```

#### Get Trace Links
```motoko
public func getTrace(traceId: Text): async [TraceLink]
```

### Enhanced Creation Functions

#### Create Memory Entry with Trace
```motoko
public func createTracedMemoryEntry(
  summary: Text,
  category: Text,
  details: Text,
  metadata: [(Text, Text)],
  traceId: ?Text,
  tags: [Text]
): async MemoryEntry
```

#### Analyze Patterns with Trace
```motoko
public func analyzeSystemPatternsWithTrace(
  input: ?ReasoningInput,
  traceId: ?Text,
  tags: [Text]
): async ReasoningOutput
```

#### Log Audit Entry with Trace
```motoko
public func logAuditEntryWithTrace(
  entry: AuditEntry,
  traceId: ?Text,
  tags: [Text]
): async Bool
```

### Query and Analytics

#### Search Traces
```motoko
public func searchTraces(
  sources: ?[Text],
  tags: ?[Text],
  principals: ?[Principal],
  timeRange: ?(Int, Int),
  entryTypes: ?[Text]
): async [Text]
```

#### Get Trace Timeline
```motoko
public func getTraceTimeline(traceId: Text): async [TraceTimelineEvent]
```

#### Get Comprehensive Trace Story
```motoko
public func getTraceStory(traceId: Text): async {
  summary: TraceSummary;
  timeline: [TraceTimelineEvent];
  memoryEntries: [MemoryEntry];
  auditEntries: [AuditEntry];
  reasoningResults: [ReasoningOutput];
  causalLinks: [CausalLink];
}
```

### Causal Relationships

#### Register Causal Link
```motoko
public func registerCausalLink(causal: CausalLink): async Bool
```

#### Get Causal Links for Trace
```motoko
public func getTraceCausalLinks(traceId: Text): async [CausalLink]
```

## Usage Examples

### Example 1: User Authentication Flow Trace

```motoko
// 1. User attempts login - create trace
let traceId = "auth_flow_" # Principal.toText(userPrincipal) # "_" # Int.toText(Time.now());

// 2. Log audit entry for login attempt
let loginAttempt: AuditEntry = {
  id = 1;
  timestamp = Time.now();
  actorName = "identity";
  category = "authentication";
  summary = "User login attempt";
  details = "User attempting to authenticate";
  severity = "info";
  metadata = [("user", Principal.toText(userPrincipal))];
};

let _ = await logAuditEntryWithTrace(
  loginAttempt,
  ?traceId,
  ["authentication", "user_flow"]
);

// 3. Create memory entry for user session
let sessionMemory = await createTracedMemoryEntry(
  "User session established",
  "authentication",
  "Active user session with valid credentials",
  [("session_duration", "3600"), ("device", "mobile")],
  ?traceId,
  ["session", "active_user"]
);

// 4. Register causal relationship
let causalLink: CausalLink = {
  traceId = traceId;
  causeEntryId = loginAttempt.id;
  effectEntryId = sessionMemory.id;
  relationship = "enables";
  confidence = 0.95;
  timestamp = Time.now();
  evidence = ["successful_authentication", "valid_credentials"];
};

let _ = await registerCausalLink(causalLink);
```

### Example 2: Cross-Module Transaction Trace

```motoko
// 1. Payment initiated
let traceId = "payment_flow_" # paymentId;

// 2. Log payment creation
let paymentAudit = await logAuditEntryWithTrace(
  paymentEntry,
  ?traceId,
  ["payment", "transaction"]
);

// 3. Escrow validation
let escrowMemory = await createTracedMemoryEntry(
  "Escrow conditions validated",
  "escrow",
  "All conditions met for payment release",
  [("amount", "1000"), ("currency", "ICP")],
  ?traceId,
  ["escrow", "validation"]
);

// 4. NFT transfer (if applicable)
let nftTransferAudit = await logAuditEntryWithTrace(
  nftTransferEntry,
  ?traceId,
  ["nft", "transfer", "payment_related"]
);

// 5. Treasury update
let treasuryMemory = await createTracedMemoryEntry(
  "Treasury balance updated",
  "treasury",
  "Balance adjusted for completed payment",
  [("balance_change", "-1000")],
  ?traceId,
  ["treasury", "balance_update"]
);
```

### Example 3: Querying and Analytics

```motoko
// Get all authentication-related traces
let authTraces = await searchTraces(
  ?["identity"],                    // sources
  ?["authentication", "login"],     // tags
  null,                            // principals
  null,                            // timeRange
  ?["audit", "memory"]             // entryTypes
);

// Get comprehensive story for a specific trace
let traceStory = await getTraceStory("auth_flow_user123_1234567890");

// Get timeline visualization
let timeline = await getTraceTimeline("payment_flow_txn456");

// Get system-wide analytics
let analytics = await getTraceAnalytics();
Debug.print("Total traces: " # Nat.toText(analytics.totalTraces));
Debug.print("Average trace length: " # Float.toText(analytics.averageTraceLength));
```

## Benefits

1. **Cross-Canister Correlation**: Link events across all AxiaSystem modules
2. **Causal Understanding**: Establish and query cause-effect relationships
3. **Comprehensive Auditing**: Enhanced audit trails with trace context
4. **Pattern Recognition**: Identify recurring patterns across system operations
5. **Debugging Support**: Trace the flow of complex multi-canister operations
6. **Analytics**: System-wide insights and trend analysis
7. **Compliance**: Enhanced regulatory compliance through detailed event correlation

## Integration Points

The trace system integrates with:
- **Memory System**: Automatic trace linking for memory entries
- **Audit System**: Enhanced audit logs with trace context
- **Reasoning Engine**: Pattern analysis with trace correlation
- **All Business Logic**: Any operation can participate in trace flows

This system provides the foundation for sophisticated AI analysis, compliance reporting, and system understanding across the entire AxiaSystem ecosystem.
