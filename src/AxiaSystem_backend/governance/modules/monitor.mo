import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Array "mo:base/Array";
import EventTypes "../../heartbeat/event_types";
import EventManager "../../heartbeat/event_manager";

module {

  public class Monitor(eventManager: EventManager.EventManager) {

    // Configuration thresholds
    let EVENT_QUEUE_THRESHOLD: Nat = 50;
    let ERROR_SPIKE_THRESHOLD: Nat = 10;
    let VOTING_ANOMALY_THRESHOLD: Nat = 3;

    // Internal metrics
    var recentErrors: [Text] = [];
    var votingAnomalies: Nat = 0;

    // Utility: record error
    public func logError(errorMsg: Text) {
      recentErrors := Array.append(recentErrors, [errorMsg]);
    };

    // Utility: record voting anomaly
    public func logVotingAnomaly() {
      votingAnomalies += 1;
    };

    // Clear internal metrics
    public func reset() {
      recentErrors := [];
      votingAnomalies := 0;
    };

    // Main heartbeat monitor
    public func runHealthCheck(queueLength: Nat): async () {

      if (queueLength > EVENT_QUEUE_THRESHOLD) {
        await emitAlert("High Event Queue", "Queue length exceeded: " # Nat.toText(queueLength));
      };

      if (recentErrors.size() > ERROR_SPIKE_THRESHOLD) {
        await emitAlert("Error Spike", "Recent error count: " # Nat.toText(recentErrors.size()));
      };

      if (votingAnomalies > VOTING_ANOMALY_THRESHOLD) {
        await emitAlert("Voting Anomaly Detected", "Anomalies: " # Nat.toText(votingAnomalies));
      };
    };

    // Emit alert
    private func emitAlert(alertType: Text, details: Text): async () {
      let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now());
        eventType = #AlertRaised;
        payload = #AlertRaised({
          alertType = alertType;
          message = details;
          timestamp = Nat64.fromIntWrap(Time.now());
        });
      };
      await eventManager.emit(event);
    };

  };
};