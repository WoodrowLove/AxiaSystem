//! AI Router - Notification Integration Module
//! Handles communication between AI Router and Notification System

import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Int "mo:base/Int";

import AI "../types/ai_envelope";
import NotificationTypes "../AxiaSystem_backend/notification/types";
import PolicyEngine "../policy/policy_engine";

module AINotificationBridge {
    type AIRequest = AI.AIRequest;
    type AIResponse = AI.AIResponse;
    type Message = NotificationTypes.Message;
    type Recipient = NotificationTypes.Recipient;
    type Severity = NotificationTypes.Severity;
    type Action = NotificationTypes.Action;
    type PolicyDecision = PolicyEngine.PolicyDecision;

    // Notification canister interface
    public type NotificationCanister = actor {
        sendFromAIRouter : (
            to: Recipient,
            severity: Severity,
            triad: NotificationTypes.TriadCtx,
            corrId: Text,
            title: Text,
            body: Text,
            actions: [Action],
            tags: [Text]
        ) -> async Result.Result<Text, NotificationTypes.NotificationError>;
    };

    // Configuration
    private let NOTIFICATION_CANISTER_ID = "notification-canister-id"; // Would be configured

    // Convert AI Request severity to Notification severity
    private func _mapAIToNotificationSeverity(priority: AI.Priority): Severity {
        switch (priority) {
            case (#Critical) #critical;
            case (#High) #warn;
            case (#Normal) #info;
            case (#Background) #info;
        }
    };

    // Convert Policy Decision to notification tags and actions
    private func mapPolicyDecisionToNotification(decision: PolicyDecision, corrId: Text): {
        severity: Severity;
        actions: [Action];
        tags: [Text];
    } {
        switch (decision) {
            case (#RequireMFA) {
                {
                    severity = #warn;
                    actions = [{
                        labelText = "Complete MFA";
                        command = {
                            scope = "auth:mfa";
                            name = "completeMFA";
                            args = Text.encodeUtf8(corrId);
                        };
                        url = ?("app://mfa?corr=" # corrId);
                    }];
                    tags = ["mfa", "security"];
                }
            };
            case (#Hold) {
                {
                    severity = #critical;
                    actions = [
                        {
                            labelText = "Release Hold";
                            command = {
                                scope = "admin:holds";
                                name = "releaseHold";
                                args = Text.encodeUtf8(corrId);
                            };
                            url = ?("app://admin/holds?action=release&corr=" # corrId);
                        },
                        {
                            labelText = "Extend Hold";
                            command = {
                                scope = "admin:holds";
                                name = "extendHold";
                                args = Text.encodeUtf8(corrId);
                            };
                            url = ?("app://admin/holds?action=extend&corr=" # corrId);
                        }
                    ];
                    tags = ["hold", "review", "compliance"];
                }
            };
            case (#Block) {
                {
                    severity = #critical;
                    actions = [{
                        labelText = "Review Block";
                        command = {
                            scope = "admin:blocks";
                            name = "reviewBlock";
                            args = Text.encodeUtf8(corrId);
                        };
                        url = ?("app://admin/blocks?corr=" # corrId);
                    }];
                    tags = ["blocked", "security", "review"];
                }
            };
            case (#Escalate(level)) {
                {
                    severity = #critical;
                    actions = [{
                        labelText = "Handle Escalation";
                        command = {
                            scope = "escalation:handle";
                            name = "processEscalation";
                            args = Text.encodeUtf8(corrId);
                        };
                        url = ?("app://escalation?level=" # debug_show(level) # "&corr=" # corrId);
                    }];
                    tags = ["escalation", "urgent", debug_show(level)];
                }
            };
            case (#SuggestHold) {
                {
                    severity = #warn;
                    actions = [
                        {
                            labelText = "Accept Suggestion";
                            command = {
                                scope = "escrow:suggestions";
                                name = "acceptHoldSuggestion";
                                args = Text.encodeUtf8(corrId);
                            };
                            url = ?("app://escrow/suggestions?action=accept&corr=" # corrId);
                        },
                        {
                            labelText = "Reject Suggestion";
                            command = {
                                scope = "escrow:suggestions";
                                name = "rejectHoldSuggestion";
                                args = Text.encodeUtf8(corrId);
                            };
                            url = ?("app://escrow/suggestions?action=reject&corr=" # corrId);
                        }
                    ];
                    tags = ["suggestion", "escrow", "ai_advisory"];
                }
            };
            case (#Flag) {
                {
                    severity = #warn;
                    actions = [{
                        labelText = "Review Flag";
                        command = {
                            scope = "governance:flags";
                            name = "reviewFlag";
                            args = Text.encodeUtf8(corrId);
                        };
                        url = ?("app://governance/flags?corr=" # corrId);
                    }];
                    tags = ["flagged", "governance", "review"];
                }
            };
            case (#Proceed) {
                {
                    severity = #info;
                    actions = [];
                    tags = ["info", "proceeded"];
                }
            };
        }
    };

    // Send notification when AI Router makes a policy decision
    public func notifyPolicyDecision(
        request: AIRequest,
        decision: PolicyDecision,
        reasoning: [Text],
        targetUser: Principal
    ): async Result.Result<Text, Text> {
        
        let notificationCanister = actor(NOTIFICATION_CANISTER_ID) : NotificationCanister;
        
        // Map decision to notification parameters
        let notificationParams = mapPolicyDecisionToNotification(decision, request.correlationId);
        
        // Create notification title and body based on decision
        let (title, bodyText) = switch (decision) {
            case (#RequireMFA) {
                let reasoningText = if (reasoning.size() > 0) { " Reason: " # reasoning[0] } else { "" };
                ("Multi-Factor Authentication Required", 
                 "Your " # debug_show(request.requestType) # " request requires additional authentication." # reasoningText)
            };
            case (#Hold) {
                let reasoningText = if (reasoning.size() > 0) { " Reason: " # reasoning[0] } else { "" };
                ("Transaction Held for Review", 
                 "Your " # debug_show(request.requestType) # " has been placed on hold pending review." # reasoningText)
            };
            case (#Block) {
                let reasoningText = if (reasoning.size() > 0) { " Reason: " # reasoning[0] } else { "" };
                ("Transaction Blocked", 
                 "Your " # debug_show(request.requestType) # " has been blocked due to security concerns." # reasoningText)
            };
            case (#Escalate(level)) {
                let reasoningText = if (reasoning.size() > 0) { " Reason: " # reasoning[0] } else { "" };
                ("Request Escalated", 
                 "Your " # debug_show(request.requestType) # " has been escalated to " # debug_show(level) # " level." # reasoningText)
            };
            case (#SuggestHold) {
                let reasoningText = if (reasoning.size() > 0) { " AI Analysis: " # reasoning[0] } else { "" };
                ("AI Suggests Hold", 
                 "AI analysis suggests holding your " # debug_show(request.requestType) # " for review." # reasoningText)
            };
            case (#Flag) {
                let reasoningText = if (reasoning.size() > 0) { " Reason: " # reasoning[0] } else { "" };
                ("Request Flagged", 
                 "Your " # debug_show(request.requestType) # " has been flagged for governance review." # reasoningText)
            };
            case (#Proceed) {
                let reasoningText = if (reasoning.size() > 0) { " AI Analysis: " # reasoning[0] } else { "" };
                ("Request Approved", 
                 "Your " # debug_show(request.requestType) # " has been approved and is proceeding." # reasoningText)
            };
        };

        // Create triad context from AI request
        let triadCtx: NotificationTypes.TriadCtx = {
            identityId = targetUser;
            userId = switch (request.triadContext) {
                case (?ctx) {
                    switch (ctx.moduleType) {
                        case (#Payment or #Escrow or #Treasury) ?targetUser;
                        case (_) null;
                    }
                };
                case null null;
            };
            walletId = null; // Would extract from request if available
        };

        try {
            let result = await notificationCanister.sendFromAIRouter(
                #Identity(targetUser),
                notificationParams.severity,
                triadCtx,
                request.correlationId,
                title,
                bodyText,
                notificationParams.actions,
                notificationParams.tags
            );
            
            switch (result) {
                case (#ok(msgId)) #ok(msgId);
                case (#err(error)) #err("Notification failed: " # debug_show(error));
            }
        } catch (_e) {
            #err("Failed to send notification")
        }
    };

    // Send approval request notification
    public func requestApproval(
        request: AIRequest,
        approvalType: Text,
        targetUser: Principal,
        approverRole: Text
    ): async Result.Result<Text, Text> {
        
        let notificationCanister = actor(NOTIFICATION_CANISTER_ID) : NotificationCanister;
        
        let title = "Approval Required: " # approvalType;
        let bodyText = "Request @{requestRef} requires " # approvalType # " approval. Please review and approve or deny.";
        
        // Create approval actions
        let approvalActions: [Action] = [
            {
                labelText = "Approve";
                command = {
                    scope = approverRole # ":approve";
                    name = "approve";
                    args = Text.encodeUtf8(request.correlationId);
                };
                url = ?("app://approval?action=approve&corr=" # request.correlationId);
            },
            {
                labelText = "Deny";
                command = {
                    scope = approverRole # ":deny";
                    name = "deny";
                    args = Text.encodeUtf8(request.correlationId);
                };
                url = ?("app://approval?action=deny&corr=" # request.correlationId);
            }
        ];

        let triadCtx: NotificationTypes.TriadCtx = {
            identityId = targetUser;
            userId = ?targetUser;
            walletId = null;
        };

        try {
            let result = await notificationCanister.sendFromAIRouter(
                #Identity(targetUser),
                #critical,
                triadCtx,
                request.correlationId,
                title,
                bodyText,
                approvalActions,
                ["approval", approvalType, "urgent"]
            );
            
            switch (result) {
                case (#ok(msgId)) #ok(msgId);
                case (#err(error)) #err("Approval notification failed: " # debug_show(error));
            }
        } catch (_e) {
            #err("Failed to send approval notification")
        }
    };

    // Send AI analysis completion notification
    public func notifyAnalysisComplete(
        request: AIRequest,
        response: AIResponse,
        targetUser: Principal
    ): async Result.Result<Text, Text> {
        
        let notificationCanister = actor(NOTIFICATION_CANISTER_ID) : NotificationCanister;
        
        let (title, bodyText, severity) = switch (response.status) {
            case (#Success) {
                ("AI Analysis Complete", 
                 "Analysis of your " # debug_show(request.requestType) # " is complete with " # 
                 Float.toText(response.confidence * 100.0) # "% confidence.",
                 #info)
            };
            case (#Failed(failure)) {
                ("AI Analysis Failed", 
                 "Analysis of your " # debug_show(request.requestType) # " failed: " # failure.message,
                 #warn)
            };
            case (#Timeout) {
                ("AI Analysis Timeout", 
                 "Analysis of your " # debug_show(request.requestType) # " timed out. Please try again.",
                 #warn)
            };
            case (_) {
                ("AI Analysis Status", 
                 "Your " # debug_show(request.requestType) # " analysis status: " # debug_show(response.status),
                 #info)
            };
        };

        let triadCtx: NotificationTypes.TriadCtx = {
            identityId = targetUser;
            userId = ?targetUser;
            walletId = null;
        };

        try {
            let result = await notificationCanister.sendFromAIRouter(
                #Identity(targetUser),
                severity,
                triadCtx,
                request.correlationId,
                title,
                bodyText,
                [], // No actions for status notifications
                ["ai_analysis", "status", debug_show(request.requestType)]
            );
            
            switch (result) {
                case (#ok(msgId)) #ok(msgId);
                case (#err(error)) #err("Analysis notification failed: " # debug_show(error));
            }
        } catch (_e) {
            #err("Failed to send analysis notification")
        }
    };

    // Send security alert notification
    public func alertSecurity(
        request: AIRequest,
        alertType: Text,
        alertDetails: Text,
        securityTeam: [Principal]
    ): async Result.Result<[Text], Text> {
        
        let notificationCanister = actor(NOTIFICATION_CANISTER_ID) : NotificationCanister;
        
        let title = "🚨 SECURITY ALERT: " # alertType;
        let bodyText = "Security alert for " # debug_show(request.requestType) # ": " # alertDetails;
        
        let investigateAction: [Action] = [{
            labelText = "Investigate";
            command = {
                scope = "security:investigate";
                name = "startInvestigation";
                args = Text.encodeUtf8(request.correlationId);
            };
            url = ?("app://security/investigate?corr=" # request.correlationId);
        }];

        let triadCtx: NotificationTypes.TriadCtx = {
            identityId = Principal.fromText("security-system");
            userId = null;
            walletId = null;
        };

        let resultBuffer = Array.init<Text>(securityTeam.size(), "");
        var index = 0;

        for (member in securityTeam.vals()) {
            try {
                let result = await notificationCanister.sendFromAIRouter(
                    #Identity(member),
                    #critical,
                    triadCtx,
                    request.correlationId # "_security_" # Principal.toText(member),
                    title,
                    bodyText,
                    investigateAction,
                    ["security", "alert", alertType, "urgent"]
                );
                
                switch (result) {
                    case (#ok(msgId)) { resultBuffer[index] := msgId };
                    case (#err(error)) { resultBuffer[index] := "ERROR: " # debug_show(error) };
                }
            } catch (_e) {
                resultBuffer[index] := "EXCEPTION: notification_failed";
            };
            index += 1;
        };

        #ok(Array.freeze(resultBuffer))
    };

    // Helper function to create safe notification variables (Q1 compliant)
    public func createSafeVariables(request: AIRequest): [(Text, Text)] {
        [
            ("requestRef", request.correlationId),
            ("requestType", debug_show(request.requestType)),
            ("amountTier", Nat.toText(request.payload.amountTier)),
            ("userRef", request.payload.userId),
            ("timestamp", Int.toText(request.timestamp))
        ]
    };
}
