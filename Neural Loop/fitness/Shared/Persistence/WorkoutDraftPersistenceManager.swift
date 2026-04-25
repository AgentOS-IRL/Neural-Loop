import Foundation

class WorkoutDraftPersistenceManager {
    private let userDefaults: UserDefaults
    private let draftKey = "active_workout_draft"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func save(draft: ActiveWorkoutDraft) {
        do {
            let data = try encoder.encode(draft)
            userDefaults.set(data, forKey: draftKey)
        } catch {
            print("Failed to encode workout draft: \(error)")
        }
    }

    func load() -> ActiveWorkoutDraft? {
        guard let data = userDefaults.data(forKey: draftKey) else { return nil }
        do {
            return try decoder.decode(ActiveWorkoutDraft.self, from: data)
        } catch {
            print("Failed to decode workout draft: \(error)")
            return nil
        }
    }

    func clear() {
        userDefaults.removeObject(forKey: draftKey)
    }
}
