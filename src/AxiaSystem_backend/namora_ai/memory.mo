/// 🧠 NamoraAI Memory System
/// 
/// Reflexive Memory System for NamoraAI - Long-term recall, pattern tracking, and self-awareness
/// 
/// This module enables NamoraAI to:
/// - Store historical system insights and AI actions
/// - Maintain event traces and their final outcomes
/// - Build user/system behavior summaries
/// - Learn patterns and anomalies for future reasoning
/// - Provide reflexive loops for self-correction and intelligent action
///
/// Usage:
/// - remember(): Store new memory entries with auto-ID assignment
/// - recallAll(): Retrieve all memory entries (recent-first)
/// - recallByCategory(): Filter by category (insight, action, reasoning)
/// - recallByTrace(): Filter by trace ID for cross-system linkage
/// - getLastN(): Get most recent N entries
/// - summarize(): Memory statistics and category breakdown

import Time "mo:base/Time";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Float "mo:base/Float";

module {
  /// Core memory entry structure for long-term storage
  public type MemoryEntry = {
    id: Nat;                    // Unique, auto-incremented identifier
    timestamp: Int;             // Nanosecond UTC timestamp
    category: Text;             // E.g., "insight", "action", "reasoning", "anomaly"
    traceId: ?Text;            // Optional linkage to cross-system trace
    summary: Text;             // Human-readable description of the memory
    data: Blob;                // Raw candid-encoded payload for full context
  };

  /// Memory index structure for stable storage
  public type MemoryIndex = {
    idCounter: Nat;            // Auto-incrementing ID counter
    entries: [MemoryEntry];    // All memory entries stored
  };

  /// Memory statistics for system overview
  public type MemoryStats = {
    total: Nat;                           // Total number of memory entries
    byCategory: [(Text, Nat)];           // Count by category
    oldestTimestamp: ?Int;               // Timestamp of oldest entry
    newestTimestamp: ?Int;               // Timestamp of newest entry
    totalDataSize: Nat;                  // Total size of stored data in bytes
    averageEntrySize: Nat;               // Average size per entry
    memoryEfficiency: Float;             // Storage efficiency ratio
    topCategories: [(Text, Nat)];        // Top 5 categories by count
  };

  /// Pattern analysis result for reflexive learning
  public type PatternAnalysis = {
    category: Text;                       // Category being analyzed
    entryCount: Nat;                     // Number of entries in pattern
    timeSpan: Int;                       // Time span covered (nanoseconds)
    frequency: Float;                    // Average entries per hour
    trends: [Text];                      // Detected trend descriptions
    anomalies: [Text];                   // Detected anomaly descriptions
    correlations: [(Text, Float)];       // Correlations with other categories
  };

  /// Advanced memory system with reflexive capabilities
  public class MemorySystem() {
    /// Maximum memory entries to retain (prevents unbounded growth)
    private let MAX_MEMORY_ENTRIES: Nat = 25000;
    
    /// Memory index with stable storage persistence
    private var memoryIndex: MemoryIndex = {
      idCounter = 1;
      entries = [];
    };

    /// Initialize memory system with existing data
    public func initialize(existingIndex: MemoryIndex) {
      memoryIndex := existingIndex;
    };

    /// Get current memory index for stable storage
    public func getIndex(): MemoryIndex {
      memoryIndex
    };

    /// Track memory access patterns for optimization insights
    private var accessPatterns = Buffer.Buffer<(Text, Int)>(100); // (operation, timestamp)
    
    /// Record memory access for pattern analysis
    private func recordAccess(operation: Text) {
      accessPatterns.add((operation, Time.now()));
      
      // Keep only last 1000 access records
      if (accessPatterns.size() > 1000) {
        let recentAccess = Array.subArray<(Text, Int)>(
          Buffer.toArray(accessPatterns), 
          accessPatterns.size() - 1000, 
          1000
        );
        accessPatterns := Buffer.fromArray<(Text, Int)>(recentAccess);
      };
    };
    
    /// Get memory access analytics for performance optimization
    public func getAccessAnalytics(): async [(Text, Nat, Float)] {
      let recent = Buffer.toArray(accessPatterns);
      let analyticsBuf = Buffer.Buffer<(Text, Nat, Float)>(10);
      let operations = ["remember", "recallAll", "recallByCategory", "recallByTrace", "search"];
      
      for (op in operations.vals()) {
        let opAccesses = Array.filter<(Text, Int)>(
          recent,
          func((operation, _): (Text, Int)): Bool { operation == op }
        );
        
        let count = opAccesses.size();
        let frequency = if (recent.size() > 0) {
          Float.fromInt(count) / Float.fromInt(recent.size())
        } else 0.0;
        
        analyticsBuf.add((op, count, frequency));
      };
      
      Buffer.toArray(analyticsBuf)
    };

    /// Store a new memory entry with automatic ID assignment and FIFO eviction
    public func remember(category: Text, traceId: ?Text, summary: Text, data: Blob): async Bool {
      recordAccess("remember");
      let newEntry: MemoryEntry = {
        id = memoryIndex.idCounter;
        timestamp = Time.now();
        category = category;
        traceId = traceId;
        summary = summary;
        data = data;
      };

      // Add to entries
      let updatedEntries = Array.append<MemoryEntry>(memoryIndex.entries, [newEntry]);
      
      // Update memory index with new entry and incremented counter
      memoryIndex := {
        idCounter = memoryIndex.idCounter + 1;
        entries = updatedEntries;
      };

      // Evict oldest entries if we exceed the maximum
      await evictIfNeeded();

      Debug.print("🧠 MEMORY: Stored entry #" # Nat.toText(newEntry.id) # " [" # category # "]: " # summary);
      true
    };

    /// Create and store a memory entry, returning the created entry
    public func createMemoryEntry(summary: Text, category: Text, details: Text, metadata: [(Text, Text)]): async MemoryEntry {
      recordAccess("createMemoryEntry");
      
      // Convert metadata to blob for storage
      let metadataText = Array.foldLeft<(Text, Text), Text>(
        metadata,
        "",
        func(acc: Text, item: (Text, Text)): Text {
          acc # item.0 # ":" # item.1 # "|"
        }
      );
      let data = Text.encodeUtf8(details # "||METADATA||" # metadataText);
      
      let newEntry: MemoryEntry = {
        id = memoryIndex.idCounter;
        timestamp = Time.now();
        category = category;
        traceId = null; // No trace ID for direct entries
        summary = summary;
        data = data;
      };

      // Add to entries
      let updatedEntries = Array.append<MemoryEntry>(memoryIndex.entries, [newEntry]);
      
      // Update memory index with new entry and incremented counter
      memoryIndex := {
        idCounter = memoryIndex.idCounter + 1;
        entries = updatedEntries;
      };

      // Evict oldest entries if we exceed the maximum
      await evictIfNeeded();

      Debug.print("🧠 MEMORY: Created entry #" # Nat.toText(newEntry.id) # " [" # category # "]: " # summary);
      newEntry
    };

    /// Retrieve all memory entries, ordered by timestamp (most recent first)
    public func recallAll(): async [MemoryEntry] {
      recordAccess("recallAll");
      let sortedEntries = Array.sort<MemoryEntry>(
        memoryIndex.entries,
        func(a: MemoryEntry, b: MemoryEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      );
      sortedEntries
    };

    /// Retrieve memory entries filtered by category
    public func recallByCategory(category: Text): async [MemoryEntry] {
      let filtered = Array.filter<MemoryEntry>(
        memoryIndex.entries,
        func(entry: MemoryEntry): Bool {
          entry.category == category
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<MemoryEntry>(
        filtered,
        func(a: MemoryEntry, b: MemoryEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Retrieve memory entries filtered by trace ID
    public func recallByTrace(traceId: Text): async [MemoryEntry] {
      let filtered = Array.filter<MemoryEntry>(
        memoryIndex.entries,
        func(entry: MemoryEntry): Bool {
          switch (entry.traceId) {
            case (?id) id == traceId;
            case null false;
          }
        }
      );
      
      // Sort by timestamp (chronological order for trace reconstruction)
      Array.sort<MemoryEntry>(
        filtered,
        func(a: MemoryEntry, b: MemoryEntry): {#less; #equal; #greater} {
          if (a.timestamp < b.timestamp) #less
          else if (a.timestamp > b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get the last N memory entries (most recent first)
    public func getLastN(n: Nat): async [MemoryEntry] {
      let sortedEntries = Array.sort<MemoryEntry>(
        memoryIndex.entries,
        func(a: MemoryEntry, b: MemoryEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      );
      
      if (sortedEntries.size() <= n) {
        sortedEntries
      } else {
        Array.subArray<MemoryEntry>(sortedEntries, 0, n)
      }
    };

    /// Retrieve memory entries within a specific time range
    public func recallByTimeRange(startTime: Int, endTime: Int): async [MemoryEntry] {
      let filtered = Array.filter<MemoryEntry>(
        memoryIndex.entries,
        func(entry: MemoryEntry): Bool {
          entry.timestamp >= startTime and entry.timestamp <= endTime
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<MemoryEntry>(
        filtered,
        func(a: MemoryEntry, b: MemoryEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Get comprehensive memory statistics and category breakdown
    public func summarize(): async MemoryStats {
      let entries = memoryIndex.entries;
      let total = entries.size();
      
      if (total == 0) {
        return {
          total = 0;
          byCategory = [];
          oldestTimestamp = null;
          newestTimestamp = null;
          totalDataSize = 0;
          averageEntrySize = 0;
          memoryEfficiency = 0.0;
          topCategories = [];
        };
      };

      // Count by category
      let categoryBuffer = Buffer.Buffer<(Text, Nat)>(10);
      
      for (entry in entries.vals()) {
        // Check if category already exists
        var found = false;
        let updatedCategories = Buffer.Buffer<(Text, Nat)>(categoryBuffer.size());
        
        for ((cat, count) in categoryBuffer.vals()) {
          if (cat == entry.category) {
            updatedCategories.add((cat, count + 1));
            found := true;
          } else {
            updatedCategories.add((cat, count));
          }
        };
        
        if (not found) {
          updatedCategories.add((entry.category, 1));
        };
        
        categoryBuffer.clear();
        for (item in updatedCategories.vals()) {
          categoryBuffer.add(item);
        };
      };

      // Find oldest and newest timestamps
      var oldestTimestamp: ?Int = null;
      var newestTimestamp: ?Int = null;
      var totalDataSize: Nat = 0;
      
      for (entry in entries.vals()) {
        // Update oldest
        switch (oldestTimestamp) {
          case null { oldestTimestamp := ?entry.timestamp; };
          case (?oldest) {
            if (entry.timestamp < oldest) {
              oldestTimestamp := ?entry.timestamp;
            };
          };
        };
        
        // Update newest
        switch (newestTimestamp) {
          case null { newestTimestamp := ?entry.timestamp; };
          case (?newest) {
            if (entry.timestamp > newest) {
              newestTimestamp := ?entry.timestamp;
            };
          };
        };
        
        // Accumulate data size
        totalDataSize += entry.data.size();
      };

      // Calculate enhanced statistics
      let averageEntrySize = if (total > 0) totalDataSize / total else 0;
      let memoryEfficiency = if (total > 0) {
        Float.fromInt(total) / Float.fromInt(MAX_MEMORY_ENTRIES)
      } else 0.0;
      
      // Get top categories (sorted by count, top 5)
      let sortedCategories = Array.sort<(Text, Nat)>(
        Buffer.toArray(categoryBuffer),
        func(a: (Text, Nat), b: (Text, Nat)): {#less; #equal; #greater} {
          if (a.1 > b.1) #less
          else if (a.1 < b.1) #greater
          else #equal
        }
      );
      let topCategories = if (sortedCategories.size() <= 5) {
        sortedCategories
      } else {
        Array.subArray<(Text, Nat)>(sortedCategories, 0, 5)
      };

      {
        total = total;
        byCategory = Buffer.toArray(categoryBuffer);
        oldestTimestamp = oldestTimestamp;
        newestTimestamp = newestTimestamp;
        totalDataSize = totalDataSize;
        averageEntrySize = averageEntrySize;
        memoryEfficiency = memoryEfficiency;
        topCategories = topCategories;
      }
    };

    /// Search memory entries by summary text (case-insensitive)
    public func searchBySummary(searchTerm: Text): async [MemoryEntry] {
      let lowerSearchTerm = Text.toLowercase(searchTerm);
      let filtered = Array.filter<MemoryEntry>(
        memoryIndex.entries,
        func(entry: MemoryEntry): Bool {
          Text.contains(Text.toLowercase(entry.summary), #text lowerSearchTerm)
        }
      );
      
      // Sort by timestamp (most recent first)
      Array.sort<MemoryEntry>(
        filtered,
        func(a: MemoryEntry, b: MemoryEntry): {#less; #equal; #greater} {
          if (a.timestamp > b.timestamp) #less
          else if (a.timestamp < b.timestamp) #greater
          else #equal
        }
      )
    };

    /// Advanced pattern analysis for reflexive learning insights
    public func analyzePatterns(): async [PatternAnalysis] {
      let stats = await summarize();
      let analysisBuffer = Buffer.Buffer<PatternAnalysis>(10);
      
      for ((category, count) in stats.byCategory.vals()) {
        let categoryEntries = Array.filter<MemoryEntry>(
          memoryIndex.entries,
          func(entry: MemoryEntry): Bool {
            entry.category == category
          }
        );
        
        if (categoryEntries.size() > 1) {
          // Calculate time span and frequency
          let sortedEntries = Array.sort<MemoryEntry>(
            categoryEntries,
            func(a: MemoryEntry, b: MemoryEntry): {#less; #equal; #greater} {
              if (a.timestamp < b.timestamp) #less
              else if (a.timestamp > b.timestamp) #greater
              else #equal
            }
          );
          
          let oldestEntry = sortedEntries[0];
          let newestEntry = sortedEntries[sortedEntries.size() - 1];
          let timeSpan = newestEntry.timestamp - oldestEntry.timestamp;
          
          let frequency = if (timeSpan > 0) {
            Float.fromInt(count) / (Float.fromInt(timeSpan) / 3_600_000_000_000.0) // entries per hour
          } else 0.0;
          
          // Detect trends (simplified - could be enhanced with more sophisticated analysis)
          let trends = Buffer.Buffer<Text>(5);
          if (frequency > 10.0) {
            trends.add("High frequency activity");
          } else if (frequency < 0.1) {
            trends.add("Low frequency activity");
          } else {
            trends.add("Normal frequency activity");
          };
          
          if (count > 100) {
            trends.add("High volume category");
          };
          
          // Detect anomalies (basic implementation)
          let anomalies = Buffer.Buffer<Text>(5);
          let hourInNanos = 3_600_000_000_000;
          let recentEntries = Array.filter<MemoryEntry>(
            categoryEntries,
            func(entry: MemoryEntry): Bool {
              (Time.now() - entry.timestamp) < hourInNanos
            }
          );
          
          if (recentEntries.size() > (count / 10)) {
            anomalies.add("Sudden spike in recent activity");
          };
          
          // Basic correlations with other categories (simplified)
          let correlations = Buffer.Buffer<(Text, Float)>(5);
          for ((otherCategory, otherCount) in stats.byCategory.vals()) {
            if (otherCategory != category and otherCount > 0) {
              let correlation = Float.min(Float.fromInt(count), Float.fromInt(otherCount)) / 
                               Float.max(Float.fromInt(count), Float.fromInt(otherCount));
              if (correlation > 0.3) {
                correlations.add((otherCategory, correlation));
              };
            };
          };
          
          let analysis: PatternAnalysis = {
            category = category;
            entryCount = count;
            timeSpan = timeSpan;
            frequency = frequency;
            trends = Buffer.toArray(trends);
            anomalies = Buffer.toArray(anomalies);
            correlations = Buffer.toArray(correlations);
          };
          
          analysisBuffer.add(analysis);
        };
      };
      
      Buffer.toArray(analysisBuffer)
    };

    /// Get memory entries for pattern analysis (grouped by category with recent data)
    public func getPatternData(): async [(Text, [MemoryEntry])] {
      // Get unique categories
      let categoryBuffer = Buffer.Buffer<Text>(10);
      for (entry in memoryIndex.entries.vals()) {
        var found = false;
        for (cat in categoryBuffer.vals()) {
          if (cat == entry.category) {
            found := true;
          };
        };
        if (not found) {
          categoryBuffer.add(entry.category);
        };
      };
      
      let patterns = Buffer.Buffer<(Text, [MemoryEntry])>(categoryBuffer.size());
      
      for (category in categoryBuffer.vals()) {
        let categoryEntries = Array.filter<MemoryEntry>(
          memoryIndex.entries,
          func(entry: MemoryEntry): Bool {
            entry.category == category
          }
        );
        
        // Sort by timestamp (most recent first)
        let sortedCategoryEntries = Array.sort<MemoryEntry>(
          categoryEntries,
          func(a: MemoryEntry, b: MemoryEntry): {#less; #equal; #greater} {
            if (a.timestamp > b.timestamp) #less
            else if (a.timestamp < b.timestamp) #greater
            else #equal
          }
        );
        
        // Limit to last 100 entries per category for pattern analysis
        let recentEntries = if (sortedCategoryEntries.size() <= 100) {
          sortedCategoryEntries
        } else {
          Array.subArray<MemoryEntry>(sortedCategoryEntries, 0, 100)
        };
        patterns.add((category, recentEntries));
      };
      
      Buffer.toArray(patterns)
    };

    /// Clear all memory entries (admin function - use with caution)
    public func clearAllMemory(): async Bool {
      memoryIndex := {
        idCounter = 1;
        entries = [];
      };
      Debug.print("🧠 MEMORY: All memory entries cleared");
      true
    };

    /// Intelligent memory compression - summarize old entries to save space
    public func compressOldMemories(olderThanHours: Nat): async Nat {
      let cutoffTime = Time.now() - (olderThanHours * 3_600_000_000_000);
      let oldEntries = Array.filter<MemoryEntry>(
        memoryIndex.entries,
        func(entry: MemoryEntry): Bool {
          entry.timestamp < cutoffTime
        }
      );
      let recentEntries = Array.filter<MemoryEntry>(
        memoryIndex.entries,
        func(entry: MemoryEntry): Bool {
          entry.timestamp >= cutoffTime
        }
      );
      
      if (oldEntries.size() == 0) {
        return 0;
      };
      
      // Group old entries by category for summarization
      let categoryGroups = Buffer.Buffer<(Text, [MemoryEntry])>(10);
      let processedCategories = Buffer.Buffer<Text>(10);
      
      for (entry in oldEntries.vals()) {
        var categoryExists = false;
        for (cat in processedCategories.vals()) {
          if (cat == entry.category) {
            categoryExists := true;
          };
        };
        
        if (not categoryExists) {
          processedCategories.add(entry.category);
          let categoryEntries = Array.filter<MemoryEntry>(
            oldEntries,
            func(e: MemoryEntry): Bool { e.category == entry.category }
          );
          categoryGroups.add((entry.category, categoryEntries));
        };
      };
      
      // Create summary entries for each category
      let summaryEntries = Buffer.Buffer<MemoryEntry>(categoryGroups.size());
      var compressedCount = 0;
      
      for ((category, entries) in categoryGroups.vals()) {
        if (entries.size() > 5) { // Only compress if there are enough entries
          let oldestTimestamp = entries[0].timestamp;
          let newestTimestamp = entries[entries.size() - 1].timestamp;
          
          let summaryText = "COMPRESSED: " # Nat.toText(entries.size()) # " " # category # 
                           " entries from " # Int.toText(oldestTimestamp) # 
                           " to " # Int.toText(newestTimestamp);
          
          let summaryEntry: MemoryEntry = {
            id = memoryIndex.idCounter;
            timestamp = newestTimestamp;
            category = category # "_summary";
            traceId = ?("compression_" # Int.toText(Time.now()));
            summary = summaryText;
            data = Text.encodeUtf8(summaryText);
          };
          
          summaryEntries.add(summaryEntry);
          compressedCount += entries.size();
          
          // Update ID counter
          memoryIndex := {
            idCounter = memoryIndex.idCounter + 1;
            entries = memoryIndex.entries;
          };
        } else {
          // Keep entries that are too few to compress
          for (entry in entries.vals()) {
            summaryEntries.add(entry);
          };
        };
      };
      
      // Combine recent entries with summary entries
      let finalEntries = Array.append<MemoryEntry>(recentEntries, Buffer.toArray(summaryEntries));
      
      memoryIndex := {
        idCounter = memoryIndex.idCounter;
        entries = finalEntries;
      };
      
      Debug.print("🧠 MEMORY: Compressed " # Nat.toText(compressedCount) # " entries older than " # Nat.toText(olderThanHours) # " hours");
      compressedCount
    };

    /// Remove entries older than specified timestamp
    public func pruneMemoryBefore(timestamp: Int): async Nat {
      let originalSize = memoryIndex.entries.size();
      let filtered = Array.filter<MemoryEntry>(
        memoryIndex.entries,
        func(entry: MemoryEntry): Bool {
          entry.timestamp >= timestamp
        }
      );
      
      let newSize = filtered.size();
      let removedCount = if (originalSize > newSize) {
        originalSize - newSize : Nat
      } else {
        0 // Should not happen, but safe fallback
      };
      
      memoryIndex := {
        idCounter = memoryIndex.idCounter;
        entries = filtered;
      };
      
      Debug.print("🧠 MEMORY: Pruned " # Nat.toText(removedCount) # " entries before timestamp " # Int.toText(timestamp));
      removedCount
    };

    /// Internal: Evict oldest entries if memory exceeds maximum capacity
    private func evictIfNeeded(): async () {
      let currentSize = memoryIndex.entries.size();
      if (currentSize > MAX_MEMORY_ENTRIES) {
        let excessCount = currentSize - MAX_MEMORY_ENTRIES : Nat;
        
        // Sort by timestamp and keep only the most recent entries
        let sortedEntries = Array.sort<MemoryEntry>(
          memoryIndex.entries,
          func(a: MemoryEntry, b: MemoryEntry): {#less; #equal; #greater} {
            if (a.timestamp > b.timestamp) #less
            else if (a.timestamp < b.timestamp) #greater
            else #equal
          }
        );
        
        let keptEntries = Array.subArray<MemoryEntry>(sortedEntries, 0, MAX_MEMORY_ENTRIES);
        
        memoryIndex := {
          idCounter = memoryIndex.idCounter;
          entries = keptEntries;
        };
        
        Debug.print("🧠 MEMORY: Evicted " # Nat.toText(excessCount) # " oldest entries (FIFO), kept " # Nat.toText(MAX_MEMORY_ENTRIES));
      };
    };
  };
}
