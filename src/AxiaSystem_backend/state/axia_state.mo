import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import _Time "mo:base/Time";
import Trie "mo:base/Trie";
import _Hash "mo:base/Hash";
import _Iter "mo:base/Iter";
import Array "mo:base/Array";

module {

  public type Project = {
    id: Text;
    owner: Principal;
    name: Text;
    description: Text;
    linkedModules: [Text];
    createdAt: Nat;
  };

  public class ProjectRegistryState() {

    // Maps project ID to project metadata
    private var projectsById: Trie.Trie<Text, Project> = Trie.empty();

    // Maps developer Principal to their registered project IDs
    private var projectsByOwner: Trie.Trie<Principal, [Text]> = Trie.empty();

    // Add a new project
    public func registerProject(project: Project): Bool {
      let existing = Trie.get(projectsById, key(project.id), Text.equal);
      if (existing != null) {
        return false; // Project ID already exists
      };

      projectsById := Trie.put(projectsById, key(project.id), Text.equal, project).0;

      let ownerKey = { key = project.owner; hash = Principal.hash(project.owner) };
      let updatedList = switch (Trie.get(projectsByOwner, ownerKey, Principal.equal)) {
        case null { [project.id] };
        case (?existing) { Array.append(existing, [project.id]) };
      };

      projectsByOwner := Trie.put(projectsByOwner, ownerKey, Principal.equal, updatedList).0;
      return true;
    };

    // Link a module to an existing project
    public func linkModuleToProject(projectId: Text, moduleName: Text): Bool {
      switch (Trie.get(projectsById, key(projectId), Text.equal)) {
        case null { return false };
        case (?proj) {
          if (Array.find<Text>(proj.linkedModules, func (m: Text): Bool { m == moduleName }) != null) {
  return false;
};
let updatedProject = {
  proj with
  linkedModules = Array.append(proj.linkedModules, [moduleName])
};
          projectsById := Trie.put(projectsById, key(projectId), Text.equal, updatedProject).0;
          return true;
        };
      };
    };

    // Get all projects registered by a developer
    public func getProjectsByPrincipal(dev: Principal): [Project] {
      let projectIds = switch (Trie.get(projectsByOwner, { key = dev; hash = Principal.hash(dev) }, Principal.equal)) {
        case null { [] };
        case (?ids) { ids };
      };

  Array.mapFilter<Text, Project>(
    projectIds,
    func (id: Text): ?Project {
      Trie.get(projectsById, key(id), Text.equal)
    }
  )
    };

    // Retrieve a specific project
    public func getProjectById(projectId: Text): ?Project {
      Trie.get(projectsById, key(projectId), Text.equal)
    };

    // Helper key function
    private func key(t: Text): Trie.Key<Text> = {
      key = t;
      hash = Text.hash(t);
    };

  };

};