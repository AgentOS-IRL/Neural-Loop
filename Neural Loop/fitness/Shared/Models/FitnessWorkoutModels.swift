import Foundation

struct MuscleMetadata: Identifiable, Equatable, Codable {
    var id: Int64 { muscleID }
    let muscleID: Int64
    let muscleName: String
    let isPrimary: Bool
}

struct ExerciseLibraryItem: Identifiable, Equatable, Codable {
    let id: Int64
    var name: String
    var type: ExerciseType
    var equipmentID: Int64?
    var equipmentName: String
    var muscles: [MuscleMetadata] = []

    var isRepBased: Bool { type.isRepBased }
    var isDurationBased: Bool { type.isDurationBased }
}

struct ExerciseLibrarySection: Identifiable, Equatable {
    var id: String { title }
    var title: String
    var items: [ExerciseLibraryItem]
}

struct WorkoutDraftValues: Equatable, Codable {
    var weight: Decimal?
    var reps: Int?
    var durationMinutes: Decimal?
    var distanceKilometers: Decimal?
    var calories: Decimal?

    var isEmpty: Bool {
        weight == nil && reps == nil && durationMinutes == nil && distanceKilometers == nil && calories == nil
    }
}

struct WorkoutHistorySource: Equatable, Codable {
    enum Scope: String, Codable, Sendable {
        case sameRoutine = "same_routine"
        case global
    }

    var scope: Scope
    var date: Date
    var sessionID: Int64

    var label: String {
        let prefix = scope == .sameRoutine ? "This routine" : "Latest use"
        return "\(prefix) • \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct WorkoutExerciseRecommendation: Identifiable, Equatable {
    let sourceSessionID: Int64
    let sourceDate: Date
    let exercise: ExerciseLibraryItem
    let sets: [WorkoutSetDraft]

    var id: Int64 { exercise.id }

    var setPatternText: String {
        let warmups = sets.filter { $0.setType == .warmup }.count
        let working = sets.filter { $0.setType == .working }.count
        var parts: [String] = []
        if warmups > 0 {
            parts.append("\(warmups) warm-up\(warmups == 1 ? "" : "s")")
        }
        if working > 0 {
            parts.append("\(working) working set\(working == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "1 working set" : parts.joined(separator: " • ")
    }
}

struct WorkoutExerciseCardState: Identifiable, Equatable, Codable {
    let id: Int64
    var exercise: ExerciseLibraryItem
    var sets: [WorkoutSetDraft]
    
    // Metadata from RoutineExercise
    var targetSets: Int?
    var targetRepRange: WorkoutRepRange?
    // Decode-only compatibility for drafts saved before rep ranges were introduced.
    var targetReps: Int?
    var warmupSets: Int?
    var loadIncrementKg: Decimal?
    var restSeconds: Int?
    var targetDuration: Decimal?
    var supersetGroupID: Int?
    var historicalHint: String?
    var historySource: WorkoutHistorySource?
    var historyUnavailable: Bool?

    var supersetLabel: String? {
        supersetGroupID?.supersetLabel
    }

    var effectiveTargetRepRange: WorkoutRepRange? {
        targetRepRange ?? targetReps.map { WorkoutRepRange(minimum: $0, maximum: $0) }
    }

    var columnHeaders: [String] {
        if exercise.isRepBased {
            return ["SET", "KG", "REPS"]
        } else {
            return ["SET", "MIN", "KM", "KCAL"]
        }
    }
}

struct WorkoutSetDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var dbId: Int64?
    var setNumber: Int
    var weightText: String
    var repsText: String
    var durationText: String
    var distanceText: String
    var caloriesText: String
    var isCompleted: Bool
    var superset_group_id: Int?
    var setType: WorkoutSetType
    var previousValues: WorkoutDraftValues?
    var suggestedValues: WorkoutDraftValues?
    var suggestionReason: WorkoutSuggestionReason?
    var routineExerciseID: Int64?

    init(
        id: UUID = UUID(),
        dbId: Int64? = nil,
        setNumber: Int,
        weightText: String = "",
        repsText: String = "",
        durationText: String = "",
        distanceText: String = "",
        caloriesText: String = "",
        isCompleted: Bool = false,
        superset_group_id: Int? = nil,
        setType: WorkoutSetType = .working,
        previousValues: WorkoutDraftValues? = nil,
        suggestedValues: WorkoutDraftValues? = nil,
        suggestionReason: WorkoutSuggestionReason? = nil,
        routineExerciseID: Int64? = nil
    ) {
        self.id = id
        self.dbId = dbId
        self.setNumber = setNumber
        self.weightText = weightText
        self.repsText = repsText
        self.durationText = durationText
        self.distanceText = distanceText
        self.caloriesText = caloriesText
        self.isCompleted = isCompleted
        self.superset_group_id = superset_group_id
        self.setType = setType
        self.previousValues = previousValues
        self.suggestedValues = suggestedValues
        self.suggestionReason = suggestionReason
        self.routineExerciseID = routineExerciseID
    }

    private enum CodingKeys: String, CodingKey {
        case id, dbId, setNumber, weightText, repsText, durationText, distanceText, caloriesText
        case isCompleted, superset_group_id, setType, previousValues, suggestedValues, suggestionReason, routineExerciseID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dbId = try container.decodeIfPresent(Int64.self, forKey: .dbId)
        setNumber = try container.decode(Int.self, forKey: .setNumber)
        weightText = try container.decodeIfPresent(String.self, forKey: .weightText) ?? ""
        repsText = try container.decodeIfPresent(String.self, forKey: .repsText) ?? ""
        durationText = try container.decodeIfPresent(String.self, forKey: .durationText) ?? ""
        distanceText = try container.decodeIfPresent(String.self, forKey: .distanceText) ?? ""
        caloriesText = try container.decodeIfPresent(String.self, forKey: .caloriesText) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        superset_group_id = try container.decodeIfPresent(Int.self, forKey: .superset_group_id)
        setType = try container.decodeIfPresent(WorkoutSetType.self, forKey: .setType) ?? .working
        previousValues = try container.decodeIfPresent(WorkoutDraftValues.self, forKey: .previousValues)
        suggestedValues = try container.decodeIfPresent(WorkoutDraftValues.self, forKey: .suggestedValues)
        suggestionReason = try container.decodeIfPresent(WorkoutSuggestionReason.self, forKey: .suggestionReason)
        routineExerciseID = try container.decodeIfPresent(Int64.self, forKey: .routineExerciseID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(dbId, forKey: .dbId)
        try container.encode(setNumber, forKey: .setNumber)
        try container.encode(weightText, forKey: .weightText)
        try container.encode(repsText, forKey: .repsText)
        try container.encode(durationText, forKey: .durationText)
        try container.encode(distanceText, forKey: .distanceText)
        try container.encode(caloriesText, forKey: .caloriesText)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(superset_group_id, forKey: .superset_group_id)
        try container.encode(setType, forKey: .setType)
        try container.encodeIfPresent(previousValues, forKey: .previousValues)
        try container.encodeIfPresent(suggestedValues, forKey: .suggestedValues)
        try container.encodeIfPresent(suggestionReason, forKey: .suggestionReason)
        try container.encodeIfPresent(routineExerciseID, forKey: .routineExerciseID)
    }

    var hasRequiredStrengthValues: Bool {
        guard let reps = Int(repsText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return reps > 0
    }

    var hasRequiredCardioValues: Bool {
        (NumericFormatter.parse(durationText) ?? 0) > 0
            || (NumericFormatter.parse(distanceText) ?? 0) > 0
            || (NumericFormatter.parse(caloriesText) ?? 0) > 0
    }

    func weightAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) kilograms"
    }

    func repsAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) reps"
    }

    func durationAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) duration"
    }

    func distanceAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) distance"
    }

    func caloriesAccessibilityLabel(exerciseName: String) -> String {
        "\(exerciseName) set \(setNumber) calories"
    }
}

nonisolated struct ActiveWorkoutDraft: Codable, Equatable, Identifiable {
    let routineID: Int64
    var id: Int64 { routineID }
    var session: WorkoutSession
    var exercises: [WorkoutExerciseCardState]
    var createdAt: Date
    var updatedAt: Date
    var revision: Int
    var lastProcessedWatchSequence: Int
    var processedWatchActionIDs: Set<UUID>
    var restEndDate: Date?
    var restTotalSeconds: Int?

    init(
        routineID: Int64,
        session: WorkoutSession,
        exercises: [WorkoutExerciseCardState],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        revision: Int = 0,
        lastProcessedWatchSequence: Int = 0,
        processedWatchActionIDs: Set<UUID> = [],
        restEndDate: Date? = nil,
        restTotalSeconds: Int? = nil
    ) {
        self.routineID = routineID
        self.session = session
        self.exercises = exercises
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
        self.lastProcessedWatchSequence = lastProcessedWatchSequence
        self.processedWatchActionIDs = processedWatchActionIDs
        self.restEndDate = restEndDate
        self.restTotalSeconds = restTotalSeconds
    }

    mutating func apply(watchAction action: WorkoutWatchAction) {
        markProcessed(action: action)
        
        switch action.payload {
        case .requestSnapshot:
            break // No-op for draft mutation
            
        case .updateSetValues(let payload):
            guard let exerciseID = Self.resolveExerciseID(payload.reference.exerciseID, routineExerciseID: payload.reference.routineExerciseID),
                  let setUUID = UUID(uuidString: payload.reference.setID) else { return }
            
            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
               let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setUUID }) {
                if let kg = payload.values.kg {
                    exercises[exerciseIndex].sets[setIndex].weightText = "\(kg)"
                }
                if let reps = payload.values.reps {
                    exercises[exerciseIndex].sets[setIndex].repsText = "\(reps)"
                }
                if let duration = payload.values.durationMinutes {
                    exercises[exerciseIndex].sets[setIndex].durationText = NumericFormatter.format(duration)
                }
                if let distance = payload.values.distanceKilometers {
                    exercises[exerciseIndex].sets[setIndex].distanceText = NumericFormatter.format(distance)
                }
                if let calories = payload.values.calories {
                    exercises[exerciseIndex].sets[setIndex].caloriesText = NumericFormatter.format(calories)
                }
                updatedAt = Date()
            }
            
        case .toggleSetCompletion(let payload):
            guard let exerciseID = Self.resolveExerciseID(payload.reference.exerciseID, routineExerciseID: payload.reference.routineExerciseID),
                  let setUUID = UUID(uuidString: payload.reference.setID) else { return }
            
            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
               let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setUUID }) {
                if payload.isCompleted {
                    let set = exercises[exerciseIndex].sets[setIndex]
                    let canComplete = exercises[exerciseIndex].exercise.isRepBased
                        ? set.hasRequiredStrengthValues
                        : set.hasRequiredCardioValues
                    guard canComplete else { return }
                }
                exercises[exerciseIndex].sets[setIndex].isCompleted = payload.isCompleted
                updatedAt = Date()
            }
            
        case .addSet(let reference):
            guard let exerciseID = Self.resolveExerciseID(reference.exerciseID, routineExerciseID: reference.routineExerciseID) else { return }
            
            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }) {
                let lastWorkingSet = exercises[exerciseIndex].sets.last(where: { $0.setType == .working })
                let newSet = WorkoutSetDraft(
                    id: action.id, // Use action ID for the new set
                    setNumber: (lastWorkingSet?.setNumber ?? 0) + 1,
                    isCompleted: false,
                    setType: .working,
                    previousValues: lastWorkingSet?.previousValues,
                    suggestedValues: lastWorkingSet?.suggestedValues,
                    suggestionReason: lastWorkingSet?.suggestionReason
                )
                exercises[exerciseIndex].sets.append(newSet)
                updatedAt = Date()
            }
            
        case .updateExerciseCompletion(let payload):
            guard let exerciseID = Self.resolveExerciseID(payload.reference.exerciseID, routineExerciseID: payload.reference.routineExerciseID) else { return }
            
            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }) {
                if payload.isCompleted {
                    let exercise = exercises[exerciseIndex]
                    let allEntered = exercise.sets.allSatisfy { set in
                        exercise.exercise.isRepBased
                            ? set.hasRequiredStrengthValues
                            : set.hasRequiredCardioValues
                    }
                    guard allEntered else { return }
                }
                for i in 0..<exercises[exerciseIndex].sets.count {
                    exercises[exerciseIndex].sets[i].isCompleted = payload.isCompleted
                }
                updatedAt = Date()
            }
            
        case .finishWorkout:
            break // Handled at a higher level (saving to DB and clearing draft)
            
        case .cancelRestTimer:
            restEndDate = nil
            restTotalSeconds = nil
            updatedAt = Date()
        }
    }

    mutating func markProcessed(action: WorkoutWatchAction) {
        processedWatchActionIDs.insert(action.id)
        if action.sequence > 0 {
            lastProcessedWatchSequence = action.sequence
        }
    }

    /// Resolves an exercise ID from a watch action reference.
    /// Prefers routineExerciseID for reliable matching; falls back to parsing the string.
    static func resolveExerciseID(_ stringID: String, routineExerciseID: Int64?) -> Int64? {
        if let routineExerciseID { return routineExerciseID }
        return Int64(stringID)
    }
}

