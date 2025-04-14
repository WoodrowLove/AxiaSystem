import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Result "mo:base/Result";

module {

  public type WasmData = {
    version: Text;
    wasmModule: Blob;
    uploadedAt: Nat64;
  };

  public class UpgradeEngine() {
    // Registered canisters for upgrade tracking
    private var registeredCanisters: [Principal] = [];

    // Mapping from canister → uploaded Wasm
    private let wasmStore = HashMap.HashMap<Principal, WasmData>(10, Principal.equal, Principal.hash);

    // Track upgrade history (versioned logs)
    private var upgradeHistory : [(Principal, Text)] = [];

    // Register a canister for upgrade tracking
    public func registerCanisterForUpgrade(canisterId: Principal): async Bool {
      let alreadyRegistered = Array.indexOf<Principal>(
        canisterId,
        registeredCanisters,
        func(a: Principal, b: Principal): Bool = a == b
      );
      switch (alreadyRegistered) {
        case (?_) return false; // Already registered
        case null {
          registeredCanisters := Array.append<Principal>(registeredCanisters, [canisterId]);
          return true;
        };
      };
    };

    // Upload a Wasm blob
    public func uploadUpgradeWasm(canisterId: Principal, version: Text, wasmModule: Blob): async Bool {
      let data: WasmData = {
        version = version;
        wasmModule = wasmModule;
        uploadedAt = Nat64.fromIntWrap(Time.now());
      };
      wasmStore.put(canisterId, data);
      true
    };

    // Get version for stored wasm
    public func getWasmVersion(canisterId: Principal): async ?Text {
      switch (wasmStore.get(canisterId)) {
        case (?data) return ?data.version;
        case null return null;
      };
    };

    // Get full wasm blob
    public func getStoredWasm(canisterId: Principal): async ?Blob {
      switch (wasmStore.get(canisterId)) {
        case (?data) return ?data.wasmModule;
        case null return null;
      };
    };

    // (Optional) Get list of all registered upgrade canisters
    public func getRegisteredUpgradeTargets(): async [Principal] {
      registeredCanisters
    };
  
    // ✅ Function to simulate upgrade execution
  public func executeUpgrade(canisterId: Principal): async Result.Result<Text, Text> {
    let wasmOpt = wasmStore.get(canisterId);
    switch (wasmOpt) {
      case null return #err("No Wasm module found for target canister.");
      case (?data) {
        // In production, we'd call `install_code` here.
        // For now we simulate a successful upgrade:
        return #ok("Upgrade executed on " # Principal.toText(canisterId) # " using version " # data.version);
      };
    };
  };

  // ✅ Simulated verification (checksum/hash logic can be added later)
  public func verifyUpgradeIntegrity(canisterId: Principal): async Bool {
 switch (wasmStore.get(canisterId)) {
 case null return false;
 case (?data) {
 let length = Array.size(Blob.toArray(data.wasmModule));
 return length > 0; // ✅ simple check to ensure blob isn't empty
 };
 };
};

// ✅ Rollback to previous version (simulated)
public func rollbackUpgrade(canisterId: Principal): async Result.Result<Text, Text> {
  // Check upgrade history for at least one previous version
  let history = Array.filter<(Principal, Text)>(
    upgradeHistory,
    func(entry) = entry.0 == canisterId
  );

  if (history.size() < 2) {
    return #err("No previous version available for rollback.");
  };

  // Rollback to second latest version (simulate)
  let previous = history[history.size() - 2];
  let rolledBackVersion = previous.1;

  // Overwrite current wasmStore with previous version if it exists
  let current = wasmStore.get(canisterId);
  switch (current) {
    case null return #err("Current version not found.");
    case (?currentData) {
      let newData: WasmData = {
        version = rolledBackVersion;
        wasmModule = currentData.wasmModule; // In reality you'd restore a separate stored blob
        uploadedAt = Nat64.fromIntWrap(Time.now());
      };
      wasmStore.put(canisterId, newData);
      upgradeHistory := Array.append(upgradeHistory, [(canisterId, rolledBackVersion)]);
      return #ok("Rolled back to version: " # rolledBackVersion);
    };
  };
};

// ✅ List upgrade history for auditing
public func listUpgradeHistory(canisterId: Principal): async [Text] {
  Array.map<(Principal, Text), Text>(
    Array.filter<(Principal, Text)>(
      upgradeHistory,
      func(entry: (Principal, Text)): Bool {
        entry.0 == canisterId
      }
    ),
    func(entry: (Principal, Text)): Text {
      entry.1
    }
  )
};
};
};
