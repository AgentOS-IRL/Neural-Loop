import Foundation

struct WatchWorkoutPersistence {
    private let defaults: UserDefaults
    private let snapshotKey = "com.neuralloop.watch.activeWorkoutSnapshot"
    private let queueKey = "com.neuralloop.watch.actionQueue"
    private let acknowledgedStaleSessionKey = "com.neuralloop.watch.acknowledgedStaleSession"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSnapshot() -> ActiveWorkoutSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        do {
            return try decoder.decode(ActiveWorkoutSnapshot.self, from: data)
        } catch {
            print("WatchWorkoutPersistence: Failed to load snapshot: \(error)")
            return nil
        }
    }

    func saveSnapshot(_ snapshot: ActiveWorkoutSnapshot?) {
        guard let snapshot else {
            defaults.removeObject(forKey: snapshotKey)
            return
        }

        do {
            defaults.set(try encoder.encode(snapshot), forKey: snapshotKey)
        } catch {
            print("WatchWorkoutPersistence: Failed to save snapshot: \(error)")
        }
    }

    func loadActions() -> [WorkoutWatchAction] {
        guard let data = defaults.data(forKey: queueKey) else { return [] }
        do {
            return try decoder.decode([WorkoutWatchAction].self, from: data)
        } catch {
            print("WatchWorkoutPersistence: Failed to load action queue: \(error)")
            return []
        }
    }

    func saveActions(_ actions: [WorkoutWatchAction]) {
        do {
            defaults.set(try encoder.encode(actions), forKey: queueKey)
        } catch {
            print("WatchWorkoutPersistence: Failed to save action queue: \(error)")
        }
    }

    func loadAcknowledgedStaleSessionID() -> String? {
        defaults.string(forKey: acknowledgedStaleSessionKey)
    }

    func saveAcknowledgedStaleSessionID(_ sessionID: String?) {
        guard let sessionID else {
            defaults.removeObject(forKey: acknowledgedStaleSessionKey)
            return
        }
        defaults.set(sessionID, forKey: acknowledgedStaleSessionKey)
    }

    func clear() {
        defaults.removeObject(forKey: snapshotKey)
        defaults.removeObject(forKey: queueKey)
        defaults.removeObject(forKey: acknowledgedStaleSessionKey)
    }
}
