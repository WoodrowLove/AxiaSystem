import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Result "mo:base/Result";

import AxiaState "../state/axia_state";
import EventTypes "../heartbeat/event_types";
import EventManager "../heartbeat/event_manager";

module {

  public class ProjectRegistry(
    state : AxiaState.ProjectRegistryState,
    eventManager : EventManager.EventManager
  ) {

    // Registers a new project for the calling principal
    public func registerProject(
      caller: Principal,
      projectId: Text,
      name: Text,
      description: Text
    ): async Result.Result<Text, Text> {
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
        // Emit event
        let _ = await eventManager.emitProjectRegistered(projectId, caller, name);
        return #ok("Project registered successfully.");
      } else {
        return #err("Project ID already exists.");
      };
    };

    // Links a module to a registered project
    public func linkModuleToProject(
      caller: Principal,
      projectId: Text,
      moduleName: Text
    ): async Result.Result<Text, Text> {
      switch (state.getProjectById(projectId)) {
        case null {
          return #err("Project not found.");
        };
        case (?proj) {
          if (proj.owner != caller) {
            return #err("Unauthorized: You do not own this project.");
          };

          let linked = state.linkModuleToProject(projectId, moduleName);

          if (linked) {
            let _ = await eventManager.emitModuleLinkedToProject(projectId, moduleName);
            return #ok("Module linked successfully.");
          } else {
            return #err("Module already linked or error linking module.");
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

  };

};