import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Result "mo:base/Result";

import AxiaState "../state/axia_state";
import _EventTypes "../heartbeat/event_types";
import EventManager "../heartbeat/event_manager";
import TriadShared "../types/triad_shared";
import CorrelationUtils "../utils/correlation";
import EnhancedTriadEventManager "../heartbeat/enhanced_triad_event_manager";

module {

  public class ProjectRegistry(
    state : AxiaState.ProjectRegistryState,
    eventManager : EventManager.EventManager
  ) {
    private let enhancedEventManager = EnhancedTriadEventManager.createEnhancedTriadEventManager(eventManager);
    private let correlationManager = CorrelationUtils.getCorrelationManager();
    private let idempotencyManager = CorrelationUtils.getIdempotencyManager();

    // Registers a new project for the calling principal with triad support
    public func registerProject(
      caller: Principal,
      projectId: Text,
      name: Text,
      description: Text
    ): async Result.Result<Text, TriadShared.TriadError> {
      // Create correlation context for this operation
      let correlation = correlationManager.createCorrelation(
        "project-registration",
        caller,
        "project-registry",
        "register-project"
      );

      // Check idempotency
      let idempotencyKey = idempotencyManager.generateKey(
        "register-project",
        caller,
        projectId # ":" # name
      );

      switch (idempotencyManager.checkIdempotency(idempotencyKey)) {
        case (#existing(result)) {
          // Return existing result
          return #ok(result);
        };
        case (#expired(_) or #new(_)) {
          // Proceed with registration
        };
      };

      let project: AxiaState.Project = {
        id = projectId;
        owner = caller;
        name = name;
        description = description;
        linkedModules = [];
        createdAt = Nat64.toNat(Nat64.fromIntWrap(Time.now()));
      };

      let success = state.registerProject(project);

      if (success) {
        // Store idempotency result
        idempotencyManager.storeResult(
          idempotencyKey,
          "register-project",
          caller,
          "Project registered successfully.",
          24 // 24 hour TTL
        );

        // Emit enhanced event with correlation
        let _ = await enhancedEventManager.emitProjectRegisteredTriad(
          projectId, 
          caller, 
          name, 
          correlation
        );

        correlationManager.completeFlowStep(correlation.correlationId, true, null);
        return #ok("Project registered successfully.");
      } else {
        correlationManager.completeFlowStep(
          correlation.correlationId, 
          false, 
          ?"Project ID already exists"
        );
        return #err(#Conflict({ 
          reason = "Project ID already exists"; 
          currentState = "registered" 
        }));
      };
    };

    // Links a module to a registered project with correlation tracking
    public func linkModuleToProject(
      caller: Principal,
      projectId: Text,
      moduleName: Text
    ): async Result.Result<Text, TriadShared.TriadError> {
      // Create correlation context
      let correlation = correlationManager.createCorrelation(
        "module-linking",
        caller,
        "project-registry", 
        "link-module"
      );

      switch (state.getProjectById(projectId)) {
        case null {
          correlationManager.completeFlowStep(
            correlation.correlationId,
            false,
            ?"Project not found"
          );
          return #err(#NotFound({ 
            resource = "project"; 
            id = projectId 
          }));
        };
        case (?proj) {
          if (proj.owner != caller) {
            correlationManager.completeFlowStep(
              correlation.correlationId,
              false,
              ?"Unauthorized access"
            );
            return #err(#Unauthorized({ 
              principal = caller; 
              operationType = "link-module" 
            }));
          };

          let linked = state.linkModuleToProject(projectId, moduleName);

          if (linked) {
            // Emit enhanced event
            let _ = await enhancedEventManager.emitModuleLinkedTriad(
              projectId, 
              moduleName, 
              correlation
            );
            
            correlationManager.completeFlowStep(correlation.correlationId, true, null);
            return #ok("Module linked successfully.");
          } else {
            correlationManager.completeFlowStep(
              correlation.correlationId,
              false,
              ?"Module already linked or error linking module"
            );
            return #err(#Conflict({ 
              reason = "Module already linked or error linking module"; 
              currentState = "unknown" 
            }));
          };
        };
      };
    };

    // Retrieves all projects registered by the caller
    public func getProjectsByCaller(caller: Principal): [AxiaState.Project] {
      state.getProjectsByPrincipal(caller);
    };

    // Retrieves a specific project by ID (only if caller is owner)
    public func getProjectByIdIfOwner(caller: Principal, projectId: Text): ?AxiaState.Project {
      switch (state.getProjectById(projectId)) {
        case null { null };
        case (?proj) {
          if (proj.owner == caller) {
            ?proj
          } else {
            null
          }
        };
      }
    };

    // Enhanced triad-aware project registration with identity context
    public func registerProjectTriad(
      identity: TriadShared.TriadIdentity,
      projectId: Text,
      name: Text,
      description: Text,
      correlationId: ?Nat64
    ): async Result.Result<Text, TriadShared.TriadError> {
      // Use provided correlation or create new one
      let correlation = switch (correlationId) {
        case (?cId) {
          switch (correlationManager.getCorrelation(cId)) {
            case (?existing) existing;
            case null {
              correlationManager.createCorrelation(
                "triad-project-registration",
                identity.identityId,
                "project-registry",
                "register-project-triad"
              )
            };
          }
        };
        case null {
          correlationManager.createCorrelation(
            "triad-project-registration",
            identity.identityId,
            "project-registry",
            "register-project-triad"
          )
        };
      };

      // Enhanced idempotency with triad context
      let idempotencyKey = idempotencyManager.generateKey(
        "register-project-triad",
        identity.identityId,
        projectId # ":" # name # ":" # (switch (identity.userId) {
          case (?uid) Principal.toText(uid);
          case null "no-user";
        })
      );

      switch (idempotencyManager.checkIdempotency(idempotencyKey)) {
        case (#existing(result)) return #ok(result);
        case (#expired(_) or #new(_)) {};
      };

      // Verify triad identity if required
      if (not identity.verified) {
        correlationManager.completeFlowStep(
          correlation.correlationId,
          false,
          ?"Triad identity not verified"
        );
        return #err(#Unauthorized({ 
          principal = identity.identityId; 
          operationType = "register-project-triad" 
        }));
      };

      // Call standard registration
      let result = await registerProject(identity.identityId, projectId, name, description);
      
      switch (result) {
        case (#ok(message)) {
          idempotencyManager.storeResult(
            idempotencyKey,
            "register-project-triad",
            identity.identityId,
            message,
            24
          );
          #ok(message)
        };
        case (#err(error)) #err(error);
      }
    };

    // Get correlation statistics for monitoring
    public func getCorrelationStats(): {
      totalCorrelations: Nat;
      activeFlows: Nat;
      recentOperations: Nat;
    } {
      let stats = correlationManager.getStats();
      {
        totalCorrelations = stats.totalCorrelations;
        activeFlows = stats.activeFlows;
        recentOperations = stats.totalCorrelations; // Simplified
      }
    };

    // Get event statistics
    public func getEventStats(): {
      totalEvents: Nat;
      eventsByPriority: [(TriadShared.Priority, Nat)];
      recentEvents: Nat;
    } {
      enhancedEventManager.getEventStats()
    };

    // Cleanup old data
    public func performMaintenance() {
      enhancedEventManager.cleanup(48); // Keep 48 hours of events
      correlationManager.cleanup(24);   // Keep 24 hours of correlations
      idempotencyManager.cleanup();     // Clean expired keys
    };

  };

};