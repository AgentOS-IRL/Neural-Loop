import Foundation

nonisolated final class WorkoutDraftPersistenceManager: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let legacyDraftKey = "active_workout_draft"
    private let sessionPointerKey = "active_workout_session_pointer"
    private let draftTTL: TimeInterval = 24 * 60 * 60

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    private func draftKey(for routineID: Int64) -> String {
        "active_workout_draft_\(routineID)"
    }

    func save(draft: ActiveWorkoutDraft) {
        do {
            let data = try JSONEncoder().encode(draft)
            userDefaults.set(data, forKey: draftKey(for: draft.routineID))
        } catch {
            print("Failed to encode workout draft: \(error)")
        }
    }

    func load(routineID: Int64) -> ActiveWorkoutDraft? {
        let key = draftKey(for: routineID)
        guard let data = userDefaults.data(forKey: key) else {
            return loadLegacyDraft(routineID: routineID)
        }

        do {
            let draft = try JSONDecoder().decode(ActiveWorkoutDraft.self, from: data)

            guard draft.routineID == routineID else {
                userDefaults.removeObject(forKey: key)
                return nil
            }

            guard Date().timeIntervalSince(draft.updatedAt) <= draftTTL else {
                userDefaults.removeObject(forKey: key)
                return nil
            }

            return draft
        } catch {
            print("Failed to decode workout draft: \(error)")
            userDefaults.removeObject(forKey: key)
            return nil
        }
    }

    private func loadLegacyDraft(routineID: Int64) -> ActiveWorkoutDraft? {
        guard let data = userDefaults.data(forKey: legacyDraftKey) else { return nil }

        do {
            let legacyDraft = try JSONDecoder().decode(LegacyActiveWorkoutDraft.self, from: data)
            let now = Date()
            let draft = ActiveWorkoutDraft(
                routineID: routineID,
                session: legacyDraft.session,
                exercises: legacyDraft.exercises,
                createdAt: now,
                updatedAt: now
            )

            save(draft: draft)
            userDefaults.removeObject(forKey: legacyDraftKey)
            return draft
        } catch {
            print("Failed to decode legacy workout draft: \(error)")
            userDefaults.removeObject(forKey: legacyDraftKey)
            return nil
        }
    }

    func saveActiveSessionPointer(_ pointer: WorkoutSessionPointer) {
        do {
            let data = try JSONEncoder().encode(pointer)
            userDefaults.set(data, forKey: sessionPointerKey)
        } catch {
            print("Failed to encode workout session pointer: \(error)")
        }
    }

    func loadActiveSessionPointer() -> WorkoutSessionPointer? {
        guard let data = userDefaults.data(forKey: sessionPointerKey) else { return nil }

        do {
            let pointer = try JSONDecoder().decode(WorkoutSessionPointer.self, from: data)

            // Verify the draft still exists and is not stale
            guard let routineID = pointer.routineID else {
                clearActiveSessionPointer()
                return nil
            }

            if load(routineID: routineID) != nil {
                return pointer
            } else {
                clearActiveSessionPointer()
                return nil
            }
        } catch {
            print("Failed to decode workout session pointer: \(error)")
            clearActiveSessionPointer()
            return nil
        }
    }

    func clearActiveSessionPointer() {
        userDefaults.removeObject(forKey: sessionPointerKey)
    }

    func clear(routineID: Int64) {
        userDefaults.removeObject(forKey: draftKey(for: routineID))

        if let data = userDefaults.data(forKey: sessionPointerKey),
           let pointer = try? JSONDecoder().decode(WorkoutSessionPointer.self, from: data),
           pointer.routineID == routineID {
            clearActiveSessionPointer()
        }
    }

    func apply(action: WorkoutWatchActionPayload) -> ActiveWorkoutDraft? {
        guard let routineID = action.session.routineID else { return nil }
        
        guard var draft = load(routineID: routineID) else { return nil }
        
        // Validate session ID to avoid applying stale actions from previous runs
        guard draft.watchSessionPointer.id == action.session.id else { return nil }

        draft.apply(watchAction: action)
        save(draft: draft)
        
        return draft
    }
}

nonisolated private struct LegacyActiveWorkoutDraft: Codable {
    var session: WorkoutSession
    var exercises: [WorkoutExerciseCardState]
}
