/*This utility provides logging functions to track important operations, errors, and activities in the Tokenization & Asset Canister. It helps with monitoring, debugging, and audit trails.

logging_utils.mo*/

// logging_utils.mo

import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import _Int "mo:base/Int";

// Utility module for logging operations within the Tokenization & Asset Canister
module {

    // Types of log levels for differentiating between log messages
    public type LogLevel = {
        #Info;
        #Warning;
        #Error;
        #Debug;
    };

    // Log entry structure to capture log details
    public type LogEntry = {
        timestamp: Nat;
        level: LogLevel;
        context: Text;    // Context tag (e.g., "[ICP]" or "[XRPL]")
        message: Text;
        principal: ?Principal;  // Optional: Principal who triggered the log (could be null for system-level logs)
    };

    // Type for the log storage
    public type LogStore = {
        var entries: [LogEntry];
    };

    // Initialize an empty log store
    public func init() : LogStore {
        {
            var entries = [];
        }
    };

    // Add a log entry to the system with context
    public func log(store: LogStore, level: LogLevel, context: Text, message: Text, principal: ?Principal) {
        let entry: LogEntry = {
            timestamp = Nat64.toNat(Nat64.fromIntWrap(Time.now()));
            level = level;
            context = context;
            message = message;
            principal = principal;
        };
        store.entries := Array.append(store.entries, [entry]);
        // Use canister logging
        Debug.print(debug_show(entry));
    };

    // Convenience method for logging ICP-related information messages
    public func logICPInfo(store: LogStore, message: Text, principal: ?Principal) {
        log(store, #Info, "[ICP]", message, principal);
    };

    // Convenience method for logging XRPL-related information messages
    public func logXRPLInfo(store: LogStore, message: Text, principal: ?Principal) {
        log(store, #Info, "[XRPL]", message, principal);
    };

    // Convenience method for logging ICP-related errors
    public func logICPError(store: LogStore, message: Text, principal: ?Principal) {
        log(store, #Error, "[ICP]", message, principal);
    };

    // Convenience method for logging XRPL-related errors
    public func logXRPLError(store: LogStore, message: Text, principal: ?Principal) {
        log(store, #Error, "[XRPL]", message, principal);
    };

    // Convenience method for logging generic debug messages
    public func logDebug(store: LogStore, context: Text, message: Text, principal: ?Principal) {
        log(store, #Debug, context, message, principal);
    };

   // Convenience method for logging information messages
public func logInfo(store: LogStore, message: Text, context: Text, principal: ?Principal) {
    log(store, #Info, context, message, principal);
};

// Convenience method for logging warnings
public func logWarning(store: LogStore, category: Text, message: Text, principal: ?Principal) {
    log(store, #Warning, category, message, principal);
};

// Convenience method for logging errors
public func logError(store: LogStore, category: Text, message: Text, principal: ?Principal) {
    log(store, #Error, category, message, principal);
};

    // Convert log level to text for human-readable logging
    public func logLevelToText(level: LogLevel): Text {
        switch (level) {
            case (#Info) { "INFO" };
            case (#Warning) { "WARNING" };
            case (#Error) { "ERROR" };
            case (#Debug) { "DEBUG" };
        }
    };

    // Retrieve all logs
    public func getLogs(store: LogStore): [LogEntry] {
        store.entries
    };

    // Clear all logs (admin use only)
    public func clearLogs(store: LogStore) {
        store.entries := [];
    };

    // Filter logs by level (e.g., retrieve only error logs)
    public func getLogsByLevel(store: LogStore, level: LogLevel): [LogEntry] {
        Array.filter(store.entries, func(log: LogEntry): Bool { log.level == level })
    };

    // Filter logs by Principal (e.g., retrieve logs related to a specific user)
    public func getLogsByPrincipal(store: LogStore, principal: Principal): [LogEntry] {
        Array.filter(store.entries, func(log: LogEntry): Bool {
            switch (log.principal) {
                case (?p) { p == principal };
                case null { false };
            }
        })
    };

    // Filter logs by context (e.g., "[ICP]" or "[XRPL]")
    public func getLogsByContext(store: LogStore, context: Text): [LogEntry] {
        Array.filter(store.entries, func(log: LogEntry): Bool { log.context == context })
    };
}


/*Key Functions:

	•	Log Entry (log): The core function that logs an entry, which includes a timestamp, log level, message, and the optional principal (the user who triggered the log). It also prints the log to the console for development/debugging purposes.
	•	Log Levels: Different log levels allow the system to differentiate between:
	•	#Info: General information about operations.
	•	#Warning: Warnings about potential issues that aren’t critical.
	•	#Error: Errors that need attention.
	•	#Debug: Debugging information during development.
	•	Convenience Logging Methods:
	•	logInfo: Logs an informational message.
	•	logWarning: Logs a warning message.
	•	logError: Logs an error message.
	•	logDebug: Logs a debug message.
	•	Print Log (printLog): Converts the log entry to a human-readable format and prints it to the console. This is useful for development and debugging but can be disabled in a production environment.
	•	Retrieve Logs (getLogs): Returns all the log entries stored in the system. This is useful for audit trails or monitoring.
	•	Clear Logs (clearLogs): Clears all logs from the system. This function would typically be restricted to admin use.
	•	Filter Logs by Level (getLogsByLevel): Allows retrieval of logs by their log level (e.g., only errors, only debug logs, etc.).
	•	Filter Logs by Principal (getLogsByPrincipal): Retrieves logs associated with a specific user (or principal), which is useful for tracking user activities.

Use Cases:

	•	Audit Trails: The logging system can track important events in the Tokenization & Asset Canister, ensuring that there’s a clear record of activities. This is especially important for transactions, token minting, and sensitive operations.
	•	Error Monitoring: By logging errors, the system can provide administrators or developers with clear feedback on what went wrong, making it easier to debug and maintain the system.
	•	Debugging: During development, logDebug can be used to track detailed internal operations, helping developers trace issues and monitor the state of the canister during testing.
	•	Security: By logging and filtering by principal, the system can track actions performed by specific users, which is critical for ensuring accountability, especially in systems handling financial data.

Security & Reliability:

	•	Persistent Logging: Logs are stored in a stable variable, meaning they are persisted across upgrades and provide a continuous history of actions and events.
	•	Principal Tracking: Logs can optionally track the principal responsible for an action, allowing for detailed auditing and accountability, especially in environments where user activity must be monitored.
	•	Selective Log Retrieval: Admins or auditors can retrieve logs based on specific criteria (e.g., only errors, or logs related to a specific user), making it easier to pinpoint issues.

Flexibility & Customization:

	•	Log Levels: The system is flexible in how it logs messages, with multiple log levels to differentiate between critical errors, warnings, and general information. This can be extended to include more levels if needed.
	•	Modular Design: This utility can be integrated into any other part of the system where logging is necessary. It centralizes the logging functionality, making it easier to maintain and extend.

This logging utility ensures that the Tokenization & Asset Canister has a robust and scalable logging mechanism in place for tracking operations, errors, and user activity.*/