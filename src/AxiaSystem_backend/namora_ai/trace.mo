/// 🧩 NamoraAI Trace Normalization Layer
/// 
/// Cross-Canister, Multi-Module Event Linking and Causal Inference
/// 
/// This module serves as the connective tissue between all NamoraSystem modules,
/// enabling NamoraAI to link events across canisters with precision and context.
/// It allows tracking and unifying related events across all system modules,
/// even if they originate in different canisters, at different times, or from different actors.

import _Time "mo:base/Time";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";

module {
  
  // =============================================================================
  // 🧩 TRACE TYPES AND STRUCTURES
  // =============================================================================
  
  /// A link connecting an entry to a trace across the system
  public type TraceLink = {
    traceId: Text;              // Unique trace identifier
    entryId: Nat;               // ID of memory, audit, or reasoning entry
    entryType: Text;            // "memory" | "audit" | "reasoning" | "insight"
    timestamp: Int;             // When this link was created
    source: Text;               // Source module: "wallet", "user", "payment", etc.
    principal: ?Principal;      // Associated principal/user if applicable
    tags: [Text];               // User-defined system tags for categorization
    metadata: [(Text, Text)];   // Additional contextual information
  };
  
  /// Summary view of a complete trace
  public type TraceSummary = {
    traceId: Text;              // The trace identifier
    start: Int;                 // Earliest timestamp in trace
    end: Int;                   // Latest timestamp in trace
    sourceModules: [Text];      // All modules involved in this trace
    relatedPrincipals: [Principal]; // All principals involved
    entryCount: Nat;            // Total number of linked entries
    tags: [Text];               // All unique tags in this trace
    duration: Int;              // Total time span of the trace
    primarySource: Text;        // Most frequent source module
    severity: Text;             // Overall severity based on linked entries
  };
  
  /// Causal relationship between two trace entries
  public type CausalLink = {
    fromEntryId: Nat;           // Source entry ID
    toEntryId: Nat;             // Target entry ID
    traceId: Text;              // Trace they belong to
    relationshipType: Text;     // "caused_by", "triggered", "related_to"
    confidence: Float;          // Confidence in this causal relationship (0.0-1.0)
    timeGap: Int;               // Time difference between entries
    description: Text;          // Human-readable description of the relationship
  };
  
  /// Timeline event for trace visualization
  public type TraceTimelineEvent = {
    timestamp: Int;
    entryId: Nat;
    entryType: Text;
    source: Text;
    description: Text;
    severity: Text;
    tags: [Text];
  };
  
  /// Stable storage for the trace system
  public type TraceState = {
    traceLinks: [TraceLink];
    causalLinks: [CausalLink];
    traceMetadata: [(Text, TraceSummary)]; // Cache for performance
  };
  
  /// Trace analytics for system insights
  public type TraceAnalytics = {
    totalTraces: Nat;
    avgTraceLength: Float;
    mostActiveModule: Text;
    commonTags: [(Text, Nat)];
    tracesWithErrors: Nat;
    avgTraceDuration: Int;
    principalActivity: [(Principal, Nat)];
  };
  
  // =============================================================================
  // 🧠 TRACE NORMALIZATION ENGINE CLASS
  // =============================================================================
  
  public class TraceEngine() {
    
    // Stable storage
    private var _traceLinks = Buffer.Buffer<TraceLink>(0);
    private var _causalLinks = Buffer.Buffer<CausalLink>(0);
    private let _traceCache = HashMap.HashMap<Text, TraceSummary>(100, Text.equal, Text.hash);
    
    // Performance indexes
    private let _principalIndex = HashMap.HashMap<Text, [Text]>(50, Text.equal, Text.hash);
    private let _tagIndex = HashMap.HashMap<Text, [Text]>(100, Text.equal, Text.hash);
    private let _sourceIndex = HashMap.HashMap<Text, [Text]>(50, Text.equal, Text.hash);
    
    public func initialize(existingState: TraceState) {
      _traceLinks.clear();
      for (link in existingState.traceLinks.vals()) {
        _traceLinks.add(link);
      };
      
      _causalLinks.clear();
      for (causal in existingState.causalLinks.vals()) {
        _causalLinks.add(causal);
      };
      
      // Rebuild cache and indexes
      _rebuildIndexes();
      
      Debug.print("TRACE: Initialized with " # Nat.toText(_traceLinks.size()) # " trace links");
    };
    
    public func getState(): TraceState {
      {
        traceLinks = Buffer.toArray(_traceLinks);
        causalLinks = Buffer.toArray(_causalLinks);
        traceMetadata = Iter.toArray(_traceCache.entries());
      }
    };
    
    // =============================================================================
    // 🔗 TRACE LINK MANAGEMENT
    // =============================================================================
    
    /// Register a new trace link connecting an entry to a trace
    public func registerTraceLink(link: TraceLink): async Bool {
      Debug.print("TRACE: Registering link for trace " # link.traceId # " from " # link.source);
      
      // Validate the link
      if (not _validateTraceLink(link)) {
        Debug.print("TRACE: Invalid trace link rejected");
        return false;
      };
      
      // Add the link
      _traceLinks.add(link);
      
      // Update indexes
      _updateIndexes(link);
      
      // Invalidate cache for this trace
      _traceCache.delete(link.traceId);
      
      // Detect potential causal relationships
      let _ = await _detectCausalRelationships(link);
      
      Debug.print("TRACE: Successfully registered link " # Nat.toText(link.entryId) # " to trace " # link.traceId);
      true
    };
    
    /// Register multiple trace links in batch for performance
    public func registerTraceLinks(links: [TraceLink]): async Nat {
      Debug.print("TRACE: Batch registering " # Nat.toText(links.size()) # " trace links");
      
      var successCount = 0;
      for (link in links.vals()) {
        if (await registerTraceLink(link)) {
          successCount += 1;
        };
      };
      
      Debug.print("TRACE: Batch registration completed: " # Nat.toText(successCount) # "/" # Nat.toText(links.size()));
      successCount
    };
    
    /// Register a causal relationship between two entries
    public func registerCausalLink(causal: CausalLink): async Bool {
      Debug.print("TRACE: Registering causal link: " # Nat.toText(causal.fromEntryId) # " -> " # Nat.toText(causal.toEntryId));
      
      // Validate the causal link
      if (not _validateCausalLink(causal)) {
        return false;
      };
      
      _causalLinks.add(causal);
      
      // Invalidate cache for this trace
      _traceCache.delete(causal.traceId);
      
      true
    };
    
    // =============================================================================
    // 🔍 TRACE RETRIEVAL AND QUERYING
    // =============================================================================
    
    /// Get all links for a specific trace
    public func getTrace(traceId: Text): async [TraceLink] {
      Debug.print("TRACE: Retrieving trace " # traceId);
      
      let traceLinks = Array.filter<TraceLink>(
        Buffer.toArray(_traceLinks),
        func(link) = link.traceId == traceId
      );
      
      // Sort by timestamp for chronological order
      Array.sort<TraceLink>(traceLinks, func(a, b) = Int.compare(a.timestamp, b.timestamp))
    };
    
    /// Get causal relationships for a specific trace
    public func getTraceCausalLinks(traceId: Text): async [CausalLink] {
      Array.filter<CausalLink>(
        Buffer.toArray(_causalLinks),
        func(causal) = causal.traceId == traceId
      )
    };
    
    /// Generate a comprehensive summary of a trace
    public func summarize(traceId: Text): async TraceSummary {
      Debug.print("TRACE: Generating summary for trace " # traceId);
      
      // Check cache first
      switch (_traceCache.get(traceId)) {
        case (?cached) return cached;
        case null {};
      };
      
      let traceLinks = await getTrace(traceId);
      
      if (traceLinks.size() == 0) {
        let emptySummary: TraceSummary = {
          traceId = traceId;
          start = 0;
          end = 0;
          sourceModules = [];
          relatedPrincipals = [];
          entryCount = 0;
          tags = [];
          duration = 0;
          primarySource = "";
          severity = "unknown";
        };
        return emptySummary;
      };
      
      // Calculate summary data
      let timestamps = Array.map<TraceLink, Int>(traceLinks, func(link) = link.timestamp);
      let start = Array.foldLeft<Int, Int>(timestamps, timestamps[0], func(acc, t) = Int.min(acc, t));
      let end = Array.foldLeft<Int, Int>(timestamps, timestamps[0], func(acc, t) = Int.max(acc, t));
      
      // Collect unique sources
      let sourceSet = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);
      for (link in traceLinks.vals()) {
        sourceSet.put(link.source, true);
      };
      let sourceModules = Iter.toArray(sourceSet.keys());
      
      // Collect unique principals
      let principalSet = HashMap.HashMap<Text, Principal>(10, Text.equal, Text.hash);
      for (link in traceLinks.vals()) {
        switch (link.principal) {
          case (?p) { principalSet.put(Principal.toText(p), p); };
          case null {};
        };
      };
      let relatedPrincipals = Array.map<(Text, Principal), Principal>(
        Iter.toArray(principalSet.entries()),
        func((_, p)) = p
      );
      
      // Collect unique tags
      let tagSet = HashMap.HashMap<Text, Bool>(20, Text.equal, Text.hash);
      for (link in traceLinks.vals()) {
        for (tag in link.tags.vals()) {
          tagSet.put(tag, true);
        };
      };
      let tags = Iter.toArray(tagSet.keys());
      
      // Find primary source (most frequent)
      let sourceCounts = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
      for (link in traceLinks.vals()) {
        switch (sourceCounts.get(link.source)) {
          case (?count) { sourceCounts.put(link.source, count + 1); };
          case null { sourceCounts.put(link.source, 1); };
        };
      };
      
      var primarySource = "";
      var maxCount = 0;
      for ((source, count) in sourceCounts.entries()) {
        if (count > maxCount) {
          maxCount := count;
          primarySource := source;
        };
      };
      
      // Determine severity based on tags and entry types
      let severity = _determineSeverity(traceLinks, tags);
      
      let summary: TraceSummary = {
        traceId = traceId;
        start = start;
        end = end;
        sourceModules = sourceModules;
        relatedPrincipals = relatedPrincipals;
        entryCount = traceLinks.size();
        tags = tags;
        duration = end - start;
        primarySource = primarySource;
        severity = severity;
      };
      
      // Cache the summary
      _traceCache.put(traceId, summary);
      
      summary
    };
    
    /// Get all trace IDs involving a specific principal
    public func getTracesByPrincipal(principal: Principal): async [Text] {
      Debug.print("TRACE: Finding traces for principal " # Principal.toText(principal));
      
      let principalText = Principal.toText(principal);
      
      // Check index first
      switch (_principalIndex.get(principalText)) {
        case (?cached) return cached;
        case null {};
      };
      
      let traceSet = HashMap.HashMap<Text, Bool>(20, Text.equal, Text.hash);
      
      for (link in Buffer.toArray(_traceLinks).vals()) {
        switch (link.principal) {
          case (?p) {
            if (Principal.equal(p, principal)) {
              traceSet.put(link.traceId, true);
            };
          };
          case null {};
        };
      };
      
      Iter.toArray(traceSet.keys())
    };
    
    /// Get all trace IDs containing a specific tag
    public func getTracesByTag(tag: Text): async [Text] {
      Debug.print("TRACE: Finding traces with tag " # tag);
      
      // Check index first
      switch (_tagIndex.get(tag)) {
        case (?cached) return cached;
        case null {};
      };
      
      let traceSet = HashMap.HashMap<Text, Bool>(20, Text.equal, Text.hash);
      
      for (link in Buffer.toArray(_traceLinks).vals()) {
        for (linkTag in link.tags.vals()) {
          if (linkTag == tag) {
            traceSet.put(link.traceId, true);
          };
        };
      };
      
      Iter.toArray(traceSet.keys())
    };
    
    /// Get all trace IDs from a specific source module
    public func getTracesBySource(source: Text): async [Text] {
      Debug.print("TRACE: Finding traces from source " # source);
      
      // Check index first
      switch (_sourceIndex.get(source)) {
        case (?cached) return cached;
        case null {};
      };
      
      let traceSet = HashMap.HashMap<Text, Bool>(20, Text.equal, Text.hash);
      
      for (link in Buffer.toArray(_traceLinks).vals()) {
        if (link.source == source) {
          traceSet.put(link.traceId, true);
        };
      };
      
      Iter.toArray(traceSet.keys())
    };
    
    /// Get traces within a time range
    public func getTracesByTimeRange(startTime: Int, endTime: Int): async [Text] {
      Debug.print("TRACE: Finding traces in time range " # Int.toText(startTime) # " to " # Int.toText(endTime));
      
      let traceSet = HashMap.HashMap<Text, Bool>(20, Text.equal, Text.hash);
      
      for (link in Buffer.toArray(_traceLinks).vals()) {
        if (link.timestamp >= startTime and link.timestamp <= endTime) {
          traceSet.put(link.traceId, true);
        };
      };
      
      Iter.toArray(traceSet.keys())
    };
    
    // =============================================================================
    // 📊 TRACE ANALYTICS AND VISUALIZATION
    // =============================================================================
    
    /// Generate a timeline view of a trace for visualization
    public func getTraceTimeline(traceId: Text): async [TraceTimelineEvent] {
      Debug.print("TRACE: Generating timeline for trace " # traceId);
      
      let traceLinks = await getTrace(traceId);
      
      let timeline = Array.map<TraceLink, TraceTimelineEvent>(traceLinks, func(link) = {
        timestamp = link.timestamp;
        entryId = link.entryId;
        entryType = link.entryType;
        source = link.source;
        description = _generateEventDescription(link);
        severity = _inferSeverityFromTags(link.tags);
        tags = link.tags;
      });
      
      // Sort by timestamp
      Array.sort<TraceTimelineEvent>(timeline, func(a, b) = Int.compare(a.timestamp, b.timestamp))
    };
    
    /// Get comprehensive analytics across all traces
    public func getTraceAnalytics(): async TraceAnalytics {
      Debug.print("TRACE: Generating trace analytics");
      
      let allLinks = Buffer.toArray(_traceLinks);
      let traceSet = HashMap.HashMap<Text, Bool>(100, Text.equal, Text.hash);
      let sourceCounts = HashMap.HashMap<Text, Nat>(20, Text.equal, Text.hash);
      let tagCounts = HashMap.HashMap<Text, Nat>(50, Text.equal, Text.hash);
      let principalCounts = HashMap.HashMap<Text, Nat>(50, Text.equal, Text.hash);
      
      var _totalDuration: Int = 0;
      var tracesWithErrors = 0;
      
      // Collect unique traces
      for (link in allLinks.vals()) {
        traceSet.put(link.traceId, true);
        
        // Count sources
        switch (sourceCounts.get(link.source)) {
          case (?count) { sourceCounts.put(link.source, count + 1); };
          case null { sourceCounts.put(link.source, 1); };
        };
        
        // Count tags
        for (tag in link.tags.vals()) {
          switch (tagCounts.get(tag)) {
            case (?count) { tagCounts.put(tag, count + 1); };
            case null { tagCounts.put(tag, 1); };
          };
          
          // Check for error indicators
          if (tag == "error" or tag == "failure" or tag == "critical") {
            tracesWithErrors += 1;
          };
        };
        
        // Count principals
        switch (link.principal) {
          case (?p) {
            let pText = Principal.toText(p);
            switch (principalCounts.get(pText)) {
              case (?count) { principalCounts.put(pText, count + 1); };
              case null { principalCounts.put(pText, 1); };
            };
          };
          case null {};
        };
      };
      
      let totalTraces = traceSet.size();
      let avgTraceLength = if (totalTraces > 0) {
        Float.fromInt(allLinks.size()) / Float.fromInt(totalTraces)
      } else {
        0.0
      };
      
      // Find most active module
      var mostActiveModule = "";
      var maxModuleCount = 0;
      for ((source, count) in sourceCounts.entries()) {
        if (count > maxModuleCount) {
          maxModuleCount := count;
          mostActiveModule := source;
        };
      };
      
      // Calculate average trace duration (simplified)
      let avgTraceDuration = if (totalTraces > 0) {
        3600_000_000_000 // 1 hour default estimate
      } else {
        0
      };
      
      {
        totalTraces = traceSet.size();
        avgTraceLength = avgTraceLength;
        mostActiveModule = mostActiveModule;
        commonTags = Iter.toArray(tagCounts.entries());
        tracesWithErrors = tracesWithErrors;
        avgTraceDuration = avgTraceDuration;
        principalActivity = Array.map<(Text, Nat), (Principal, Nat)>(
          Iter.toArray(principalCounts.entries()),
          func((pText, count)) = (Principal.fromText(pText), count)
        );
      }
    };
    
    /// Search traces by multiple criteria
    public func searchTraces(
      sources: ?[Text],
      tags: ?[Text],
      principals: ?[Principal],
      timeRange: ?(Int, Int),
      entryTypes: ?[Text]
    ): async [Text] {
      Debug.print("TRACE: Searching traces with multiple criteria");
      
      let traceSet = HashMap.HashMap<Text, Bool>(50, Text.equal, Text.hash);
      
      for (link in Buffer.toArray(_traceLinks).vals()) {
        var matches = true;
        
        // Check source filter
        switch (sources) {
          case (?sourceList) {
            if (Array.find<Text>(sourceList, func(s) = s == link.source) == null) {
              matches := false;
            };
          };
          case null {};
        };
        
        // Check tag filter
        switch (tags) {
          case (?tagList) {
            var hasMatchingTag = false;
            for (tag in tagList.vals()) {
              if (Array.find<Text>(link.tags, func(t) = t == tag) != null) {
                hasMatchingTag := true;
              };
            };
            if (not hasMatchingTag) {
              matches := false;
            };
          };
          case null {};
        };
        
        // Check principal filter
        switch (principals) {
          case (?principalList) {
            switch (link.principal) {
              case (?linkPrincipal) {
                if (Array.find<Principal>(principalList, func(p) = Principal.equal(p, linkPrincipal)) == null) {
                  matches := false;
                };
              };
              case null { matches := false; };
            };
          };
          case null {};
        };
        
        // Check time range filter
        switch (timeRange) {
          case (?(start, end)) {
            if (link.timestamp < start or link.timestamp > end) {
              matches := false;
            };
          };
          case null {};
        };
        
        // Check entry type filter
        switch (entryTypes) {
          case (?typeList) {
            if (Array.find<Text>(typeList, func(t) = t == link.entryType) == null) {
              matches := false;
            };
          };
          case null {};
        };
        
        if (matches) {
          traceSet.put(link.traceId, true);
        };
      };
      
      Iter.toArray(traceSet.keys())
    };
    
    // =============================================================================
    // 🧠 CAUSAL INFERENCE AND RELATIONSHIP DETECTION
    // =============================================================================
    
    /// Detect potential causal relationships when a new link is added
    private func _detectCausalRelationships(newLink: TraceLink): async Bool {
      // Get other links in the same trace
      let traceLinks = Array.filter<TraceLink>(
        Buffer.toArray(_traceLinks),
        func(link) = link.traceId == newLink.traceId and link.entryId != newLink.entryId
      );
      
      var detectedRelationships = 0;
      
      for (existingLink in traceLinks.vals()) {
        let relationship = _analyzeRelationship(existingLink, newLink);
        
        if (relationship.confidence > 0.7) {
          let causal: CausalLink = {
            fromEntryId = if (existingLink.timestamp < newLink.timestamp) existingLink.entryId else newLink.entryId;
            toEntryId = if (existingLink.timestamp < newLink.timestamp) newLink.entryId else existingLink.entryId;
            traceId = newLink.traceId;
            relationshipType = relationship.relationshipType;
            confidence = relationship.confidence;
            timeGap = Int.abs(newLink.timestamp - existingLink.timestamp);
            description = relationship.description;
          };
          
          _causalLinks.add(causal);
          detectedRelationships += 1;
        };
      };
      
      if (detectedRelationships > 0) {
        Debug.print("TRACE: Detected " # Nat.toText(detectedRelationships) # " causal relationships");
      };
      
      detectedRelationships > 0
    };
    
    /// Analyze the relationship between two trace links
    private func _analyzeRelationship(link1: TraceLink, link2: TraceLink): {
      relationshipType: Text;
      confidence: Float;
      description: Text;
    } {
      var confidence: Float = 0.0;
      var relationshipType = "related_to";
      var description = "";
      
      // Time-based analysis
      let timeGap = Int.abs(link2.timestamp - link1.timestamp);
      let timeProximity = if (timeGap < 60_000_000_000) { // Within 1 minute
        0.8
      } else if (timeGap < 300_000_000_000) { // Within 5 minutes
        0.6
      } else if (timeGap < 3600_000_000_000) { // Within 1 hour
        0.4
      } else {
        0.1
      };
      
      // Principal correlation
      let principalMatch = switch (link1.principal, link2.principal) {
        case (?p1, ?p2) { if (Principal.equal(p1, p2)) 0.5 else 0.0 };
        case _ 0.0;
      };
      
      // Tag correlation
      var tagOverlap: Float = 0.0;
      var sharedTags = 0;
      for (tag1 in link1.tags.vals()) {
        for (tag2 in link2.tags.vals()) {
          if (tag1 == tag2) {
            sharedTags += 1;
          };
        };
      };
      if (link1.tags.size() > 0 and link2.tags.size() > 0) {
        tagOverlap := Float.fromInt(sharedTags) / Float.fromInt(Int.max(link1.tags.size(), link2.tags.size()));
      };
      
      // Source correlation
      let sourceCorrelation = _getSourceCorrelation(link1.source, link2.source);
      
      // Calculate overall confidence
      confidence := (timeProximity * 0.4) + (principalMatch * 0.3) + (tagOverlap * 0.2) + (sourceCorrelation * 0.1);
      
      // Determine relationship type
      if (timeGap < 300_000_000_000 and principalMatch > 0.0) {
        relationshipType := "triggered";
        description := link1.source # " action triggered " # link2.source # " response";
      } else if (tagOverlap > 0.5) {
        relationshipType := "caused_by";
        description := "Events share common context indicating causation";
      } else {
        relationshipType := "related_to";
        description := "Events appear to be related through timing or context";
      };
      
      {
        relationshipType = relationshipType;
        confidence = confidence;
        description = description;
      }
    };
    
    // =============================================================================
    // 🔧 PRIVATE HELPER FUNCTIONS
    // =============================================================================
    
    /// Validate a trace link before registration
    private func _validateTraceLink(link: TraceLink): Bool {
      // Basic validation
      if (Text.size(link.traceId) == 0) return false;
      if (Text.size(link.source) == 0) return false;
      if (Text.size(link.entryType) == 0) return false;
      if (link.timestamp <= 0) return false;
      
      // Entry type validation
      let validTypes = ["memory", "audit", "reasoning", "insight"];
      if (Array.find<Text>(validTypes, func(t) = t == link.entryType) == null) {
        return false;
      };
      
      true
    };
    
    /// Validate a causal link before registration
    private func _validateCausalLink(causal: CausalLink): Bool {
      if (Text.size(causal.traceId) == 0) return false;
      if (causal.fromEntryId == causal.toEntryId) return false;
      if (causal.confidence < 0.0 or causal.confidence > 1.0) return false;
      
      true
    };
    
    /// Update performance indexes when a new link is added
    private func _updateIndexes(link: TraceLink) {
      _updateIndexesWithMaps(link, _principalIndex, _tagIndex, _sourceIndex);
    };
    
    /// Update indexes with specific HashMap instances
    private func _updateIndexesWithMaps(
      link: TraceLink,
      principalIndex: HashMap.HashMap<Text, [Text]>,
      tagIndex: HashMap.HashMap<Text, [Text]>,
      sourceIndex: HashMap.HashMap<Text, [Text]>
    ) {
      // Update principal index
      switch (link.principal) {
        case (?p) {
          let pText = Principal.toText(p);
          let existingTraces = switch (principalIndex.get(pText)) {
            case (?traces) traces;
            case null [];
          };
          if (Array.find<Text>(existingTraces, func(t) = t == link.traceId) == null) {
            let newTraces = Array.append<Text>(existingTraces, [link.traceId]);
            principalIndex.put(pText, newTraces);
          };
        };
        case null {};
      };
      
      // Update tag indexes
      for (tag in link.tags.vals()) {
        let existingTraces = switch (tagIndex.get(tag)) {
          case (?traces) traces;
          case null [];
        };
        if (Array.find<Text>(existingTraces, func(t) = t == link.traceId) == null) {
          let newTraces = Array.append<Text>(existingTraces, [link.traceId]);
          tagIndex.put(tag, newTraces);
        };
      };
      
      // Update source index
      let existingTraces = switch (sourceIndex.get(link.source)) {
        case (?traces) traces;
        case null [];
      };
      if (Array.find<Text>(existingTraces, func(t) = t == link.traceId) == null) {
        let newTraces = Array.append<Text>(existingTraces, [link.traceId]);
        sourceIndex.put(link.source, newTraces);
      };
    };
    
    /// Rebuild all indexes from scratch
    private func _rebuildIndexes() {
      // Clear by creating new HashMaps
      let newPrincipalIndex = HashMap.HashMap<Text, [Text]>(50, Text.equal, Text.hash);
      let newTagIndex = HashMap.HashMap<Text, [Text]>(100, Text.equal, Text.hash);
      let newSourceIndex = HashMap.HashMap<Text, [Text]>(50, Text.equal, Text.hash);
      
      for (link in Buffer.toArray(_traceLinks).vals()) {
        _updateIndexesWithMaps(link, newPrincipalIndex, newTagIndex, newSourceIndex);
      };
    };
    
    /// Determine overall severity for a trace
    private func _determineSeverity(traceLinks: [TraceLink], tags: [Text]): Text {
      // Check for critical/error tags
      for (tag in tags.vals()) {
        if (tag == "critical" or tag == "failure" or tag == "error") {
          return "critical";
        };
      };
      
      // Check for warning indicators
      for (tag in tags.vals()) {
        if (tag == "warning" or tag == "suspicious" or tag == "anomaly") {
          return "warning";
        };
      };
      
      // Check entry types for severity indicators
      for (link in traceLinks.vals()) {
        if (link.entryType == "reasoning" and Array.find<Text>(link.tags, func(t) = t == "critical") != null) {
          return "critical";
        };
      };
      
      "info"
    };
    
    /// Infer severity from tags
    private func _inferSeverityFromTags(tags: [Text]): Text {
      for (tag in tags.vals()) {
        if (tag == "critical" or tag == "error" or tag == "failure") {
          return "critical";
        };
      };
      
      for (tag in tags.vals()) {
        if (tag == "warning" or tag == "suspicious") {
          return "warning";
        };
      };
      
      "info"
    };
    
    /// Generate a human-readable description for a timeline event
    private func _generateEventDescription(link: TraceLink): Text {
      let baseDescription = link.source # " " # link.entryType # " entry #" # Nat.toText(link.entryId);
      
      if (link.tags.size() > 0) {
        baseDescription # " [" # Text.join(", ", link.tags.vals()) # "]"
      } else {
        baseDescription
      }
    };
    
    /// Get correlation score between two source modules
    private func _getSourceCorrelation(source1: Text, source2: Text): Float {
      if (source1 == source2) return 1.0;
      
      // Define known correlations between modules
      let correlations = [
        ("user", "wallet", 0.8),
        ("wallet", "payment", 0.9),
        ("payment", "escrow", 0.7),
        ("governance", "treasury", 0.6),
        ("identity", "user", 0.9),
        ("token", "payment", 0.8),
        ("nft", "asset", 0.7)
      ];
      
      for ((s1, s2, score) in correlations.vals()) {
        if ((s1 == source1 and s2 == source2) or (s1 == source2 and s2 == source1)) {
          return score;
        };
      };
      
      0.1 // Default low correlation
    };
    
    // =============================================================================
    // 🧹 MAINTENANCE AND CLEANUP
    // =============================================================================
    
    /// Clear all trace data (admin function)
    public func clearAllTraces(): async Bool {
      Debug.print("TRACE: Clearing all trace data");
      
      _traceLinks.clear();
      _causalLinks.clear();
      
      // Clear HashMaps by removing all keys
      for (key in _traceCache.keys()) {
        _traceCache.delete(key);
      };
      for (key in _principalIndex.keys()) {
        _principalIndex.delete(key);
      };
      for (key in _tagIndex.keys()) {
        _tagIndex.delete(key);
      };
      for (key in _sourceIndex.keys()) {
        _sourceIndex.delete(key);
      };
      
      true
    };
    
    /// Prune old trace links before a specific timestamp
    public func pruneTracesBefore(timestamp: Int): async Nat {
      Debug.print("TRACE: Pruning traces before " # Int.toText(timestamp));
      
      let originalSize = _traceLinks.size();
      let filteredLinks = Array.filter<TraceLink>(
        Buffer.toArray(_traceLinks),
        func(link) = link.timestamp >= timestamp
      );
      
      _traceLinks.clear();
      for (link in filteredLinks.vals()) {
        _traceLinks.add(link);
      };
      
      // Rebuild indexes
      _rebuildIndexes();
      
      // Clear cache by removing all keys
      for (key in _traceCache.keys()) {
        _traceCache.delete(key);
      };
      
      let prunedCount = if (originalSize >= _traceLinks.size()) {
        Nat.sub(originalSize, _traceLinks.size())
      } else {
        0
      };
      Debug.print("TRACE: Pruned " # Nat.toText(prunedCount) # " trace links");
      
      prunedCount
    };
    
    /// Get trace system statistics
    public func getTraceStats(): async {
      totalLinks: Nat;
      totalCausalLinks: Nat;
      uniqueTraces: Nat;
      indexedPrincipals: Nat;
      indexedTags: Nat;
      indexedSources: Nat;
      cacheSize: Nat;
    } {
      let traceSet = HashMap.HashMap<Text, Bool>(100, Text.equal, Text.hash);
      for (link in Buffer.toArray(_traceLinks).vals()) {
        traceSet.put(link.traceId, true);
      };
      
      {
        totalLinks = _traceLinks.size();
        totalCausalLinks = _causalLinks.size();
        uniqueTraces = traceSet.size();
        indexedPrincipals = _principalIndex.size();
        indexedTags = _tagIndex.size();
        indexedSources = _sourceIndex.size();
        cacheSize = _traceCache.size();
      }
    };
  };
}
