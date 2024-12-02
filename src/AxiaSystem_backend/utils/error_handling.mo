import _Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

// Utility module for handling errors across the Tokenization & Asset Canister
module {

    // Enum type to represent various kinds of errors in the system
    public type ErrorCode = {
        #NotFound;         // Resource not found
        #InvalidInput;     // Invalid input provided
        #Unauthorized;     // Unauthorized access attempt
        #InsufficientFunds; // Insufficient funds for transaction
        #TransactionFailed; // Transaction on XRPL or other system failed
        #InternalError;    // Generic internal server error
        #EscrowError;      // Errors related to escrow operations
        #XRPLError;        // Errors related to XRP Ledger operations
    };

    // Struct to represent detailed error information
    public type ErrorDetail = {
        code: ErrorCode;
        message: Text;
        additionalInfo: ?Text;  // Optional additional information about the error
    };

    // Helper function to create an ErrorDetail object
    public func createError(code: ErrorCode, message: Text, additionalInfo: ?Text): ErrorDetail {
        {
            code = code;
            message = message;
            additionalInfo = additionalInfo;
        }
    };

    // Function to handle input validation errors
    public func handleInvalidInputError(field: Text, expected: Text): ErrorDetail {
        let message = "Invalid input for " # field # ". Expected: " # expected;
        return createError(#InvalidInput, message, null);
    };

    // Function to handle "Not Found" errors
    public func handleNotFoundError(resource: Text): ErrorDetail {
        let message = resource # " not found.";
        return createError(#NotFound, message, null);
    };

    // Function to handle unauthorized access
    public func handleUnauthorizedError(principal: Text): ErrorDetail {
        let message = "Unauthorized access attempt by principal: " # principal;
        return createError(#Unauthorized, message, null);
    };

    // Function to handle insufficient funds for transactions
    public func handleInsufficientFundsError(requiredAmount: Nat, availableAmount: Nat): ErrorDetail {
        let message = "Insufficient funds. Required: " # Nat.toText(requiredAmount) # ", Available: " # Nat.toText(availableAmount);
        return createError(#InsufficientFunds, message, null);
    };

    // Function to handle transaction failures
    public func handleTransactionFailedError(transactionType: Text, reason: Text): ErrorDetail {
        let message = "Transaction failed for: " # transactionType # ". Reason: " # reason;
        return createError(#TransactionFailed, message, null);
    };

    // Function to handle internal errors
    public func handleInternalError(reason: Text): ErrorDetail {
        let message = "Internal server error: " # reason;
        return createError(#InternalError, message, null);
    };

    // Function to handle XRPL-related errors
    public func handleXRPLError(reason: Text): ErrorDetail {
        let message = "XRPL error: " # reason;
        return createError(#XRPLError, message, null);
    };

    // Function to handle escrow-related errors
    public func handleEscrowError(reason: Text): ErrorDetail {
        let message = "Escrow operation error: " # reason;
        return createError(#EscrowError, message, null);
    };

    // Function to generate a human-readable string for error logging or user feedback
    public func errorToString(error: ErrorDetail): Text {
        let additionalInfoText = switch (error.additionalInfo) {
            case (?info) { "Additional Info: " # info };
            case null { "" };
        };
        return "Error Code: " # errorCodeToText(error.code) # ", Message: " # error.message # ". " # additionalInfoText;
    };

    // Convert error code enum to text for logging or feedback purposes
    private func errorCodeToText(code: ErrorCode): Text {
        switch (code) {
            case (#NotFound) { "NOT_FOUND" };
            case (#InvalidInput) { "INVALID_INPUT" };
            case (#Unauthorized) { "UNAUTHORIZED" };
            case (#InsufficientFunds) { "INSUFFICIENT_FUNDS" };
            case (#TransactionFailed) { "TRANSACTION_FAILED" };
            case (#InternalError) { "INTERNAL_ERROR" };
            case (#EscrowError) { "ESCROW_ERROR" };
            case (#XRPLError) { "XRPL_ERROR" };
        }
    };

    // Function to handle logging of error details (connect this to a logging utility if needed)
    public func logError(error: ErrorDetail) {
        Debug.print("Logged Error: " # errorToString(error));
    };
}

/*Key Functions:

	•	Error Types (ErrorCode): A set of predefined error codes to categorize different types of errors, such as #NotFound, #InvalidInput, #Unauthorized, #TransactionFailed, etc. This helps in ensuring consistent error handling across the canister.
	•	Create Error (createError): A helper function to create a detailed error message with a code, description, and optional additional information.
	•	Specific Error Handlers:
	•	handleInvalidInputError: Handles errors related to invalid inputs, providing the expected value.
	•	handleNotFoundError: Manages errors for resources that cannot be found.
	•	handleUnauthorizedError: Handles access violations or unauthorized access attempts.
	•	handleInsufficientFundsError: Provides details when the user’s balance is insufficient to complete a transaction.
	•	handleTransactionFailedError: Manages errors that occur during transactions, providing details about the transaction and the reason for the failure.
	•	handleInternalError: Handles unexpected internal errors within the canister.
	•	handleXRPLError: Specifically handles errors related to the XRP Ledger (e.g., transaction failures on XRPL).
	•	handleEscrowError: Handles errors specifically related to escrow operations.
	•	Error to String (errorToString): Converts an ErrorDetail object into a human-readable string for logging or displaying errors to the user.
	•	Log Error (logError): Logs the error details, which can be connected to a logging system to keep track of critical issues in the system.

Use Cases:

	•	System-Wide Error Handling: This utility allows for consistent error management across the Tokenization & Asset Canister. Whether an error arises from a transaction, insufficient funds, or unauthorized access, this system will provide structured and meaningful error messages.
	•	User Feedback: The errorToString function ensures that errors can be easily translated into user-facing messages. This is critical for ensuring users understand what went wrong and how to address it.
	•	Logging and Monitoring: The logError function allows for tracking and monitoring errors, ensuring that any critical issues are logged and can be reviewed by administrators or developers.

Security & Reliability:

	•	Categorized Errors: By using predefined error codes, the system ensures that each type of error is handled appropriately, preventing generic error handling and providing clear reasons for failure.
	•	Additional Information: The additionalInfo field provides flexibility for adding more context to errors when necessary, making it easier to debug complex issues.
	•	Graceful Error Handling: Errors are handled gracefully within the system, ensuring that the canister can respond to invalid inputs, unauthorized access, or failed transactions without crashing or halting execution.

Integration & Flexibility:

	•	Reusable Error Handling: This error handling utility can be integrated into any part of the canister where error handling is needed. It provides a centralized way to handle, log, and track errors, improving maintainability and consistency.
	•	Modular Design: The functions can be extended to handle more specific errors as the system grows. For example, more detailed escrow or XRPL-related error types can be added as the project expands.

This error_handling.mo utility ensures that the Tokenization & Asset Canister can handle and respond to errors in a structured, meaningful, and scalable way, improving the overall robustness of the system.*/