import Combine
import Foundation

enum WorkoutTemplateEditorMode: Equatable {
    case create
    case edit(WorkoutTemplateSummary)
}

@MainActor
final class WorkoutTemplateEditorViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var notes: String = ""
    @Published private(set) var exerciseDrafts: [WorkoutTemplateExerciseDraft] = []
    @Published private(set) var availableExercises: [ExerciseLibraryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let mode: WorkoutTemplateEditorMode

    private let dataManager: any WorkoutCatalogReading & WorkoutRoutineReading & WorkoutRoutineWriting
    private let generatedRoutine: WorkoutRoutineGenerationPayload?
    private var hasLoaded = false

    init(
        mode: WorkoutTemplateEditorMode,
        dataManager: any WorkoutCatalogReading & WorkoutRoutineReading & WorkoutRoutineWriting,
        generatedRoutine: WorkoutRoutineGenerationPayload? = nil
    ) {
        self.mode = mode
        self.dataManager = dataManager
        self.generatedRoutine = generatedRoutine

        if case .create = mode, let generatedRoutine {
            title = generatedRoutine.routineName
            notes = generatedRoutine.notes
        }
    }

    var selectedExerciseIDs: Set<Int64> {
        Set(exerciseDrafts.map { $0.exercise.id })
    }

    var subtitleText: String {
        let setCount = exerciseDrafts.reduce(0) { partialResult, draft in
            partialResult
                + max(parsedSetCount(from: draft.workingSetsText) ?? 1, 1)
                + max(parsedInteger(from: draft.warmupSetsText) ?? 0, 0)
        }
        return "\(exerciseDrafts.count) exercises, \(setCount) sets"
    }

    var canSave: Bool {
        !isLoading && !isSaving && validationError() == nil
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else {
            return
        }

        await load()
    }

    func syncExercises(with selections: [ExerciseLibraryItem]) {
        let selectionsByID = Dictionary(uniqueKeysWithValues: selections.map { ($0.id, $0) })
        let selectedIDs = Set(selectionsByID.keys)

        exerciseDrafts = exerciseDrafts
            .filter { selectedIDs.contains($0.exercise.id) }
            .map { draft in
                var updatedDraft = draft
                if let updatedExercise = selectionsByID[draft.exercise.id] {
                    updatedDraft.exercise = updatedExercise
                }
                return updatedDraft
            }

        let retainedIDs = Set(exerciseDrafts.map { $0.exercise.id })
        for item in selections where !retainedIDs.contains(item.id) {
            exerciseDrafts.append(Self.makeNewDraft(for: item, orderIndex: exerciseDrafts.count + 1))
        }

        renumberDraftOrderIndexes()
    }

    func removeExercise(id: UUID) {
        exerciseDrafts.removeAll { $0.id == id }
        renumberDraftOrderIndexes()
    }

    func moveExercise(id: UUID, by offset: Int) {
        guard let currentIndex = exerciseDrafts.firstIndex(where: { $0.id == id }) else {
            return
        }

        let targetIndex = currentIndex + offset
        guard exerciseDrafts.indices.contains(targetIndex) else {
            return
        }

        let draft = exerciseDrafts.remove(at: currentIndex)
        exerciseDrafts.insert(draft, at: targetIndex)
        renumberDraftOrderIndexes()
    }

    func updateTargetSets(id: UUID, value: String) {
        updateDraft(id: id) { draft in
            draft.workingSetsText = value
        }
    }

    func updateWarmupSets(id: UUID, value: String) {
        updateDraft(id: id) { draft in
            draft.warmupSetsText = value
        }
    }

    func updateTargetRepsMin(id: UUID, value: String) {
        updateDraft(id: id) { draft in
            draft.targetRepsMinText = value
        }
    }

    func updateTargetRepsMax(id: UUID, value: String) {
        updateDraft(id: id) { draft in
            draft.targetRepsMaxText = value
        }
    }

    func updateLoadIncrement(id: UUID, value: String) {
        updateDraft(id: id) { draft in
            draft.loadIncrementKgText = value
        }
    }

    func updateDuration(id: UUID, value: String) {
        updateDraft(id: id) { draft in
            draft.durationText = value
        }
    }

    func updateRestSeconds(id: UUID, value: String) {
        updateDraft(id: id) { draft in
            draft.restSecondsText = value
        }
    }

    func save() async -> Bool {
        let validationError = validationError()
        guard validationError == nil else {
            errorMessage = validationError?.localizedDescription
            return false
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let routineNotes = trimmedNotes.isEmpty ? nil : trimmedNotes

            switch mode {
            case .create:
                try await createTemplate(name: trimmedTitle, notes: routineNotes)
            case .edit(let summary):
                try await editTemplate(summary: summary, name: trimmedTitle, notes: routineNotes)
            }

            hasLoaded = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let equipmentRows = dataManager.fetchAllEquipment()
            async let exerciseRows = dataManager.fetchAllExercisesWithMuscles()

            switch mode {
            case .create:
                let (equipment, exercises) = try await (equipmentRows, exerciseRows)
                availableExercises = WorkoutCatalogMapper.makeLibraryItems(
                    equipment: equipment,
                    exercises: exercises
                )
                if let generatedRoutine {
                    title = generatedRoutine.routineName
                    notes = generatedRoutine.notes
                    exerciseDrafts = WorkoutCatalogMapper.makeDrafts(
                        from: generatedRoutine,
                        availableExercises: availableExercises
                    )
                } else {
                    title = ""
                    notes = ""
                    exerciseDrafts = []
                }

            case .edit(let summary):
                async let routineRow = dataManager.fetchRoutine(by: summary.id)
                async let routineExerciseRows = dataManager.fetchRoutineExercises(routineId: summary.id)

                let (equipment, exercises, routine, routineExercises) = try await (
                    equipmentRows,
                    exerciseRows,
                    routineRow,
                    routineExerciseRows
                )

                guard let routine else {
                    throw WorkoutTemplateEditorError.missingRoutine
                }

                availableExercises = WorkoutCatalogMapper.makeLibraryItems(
                    equipment: equipment,
                    exercises: exercises
                )
                title = routine.name
                notes = routine.notes ?? ""
                exerciseDrafts = Self.makeDrafts(
                    from: routineExercises.sorted { $0.order_index < $1.order_index },
                    exercisesByID: Dictionary(uniqueKeysWithValues: availableExercises.map { ($0.id, $0) })
                )
            }

            renumberDraftOrderIndexes()
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createTemplate(name: String, notes: String?) async throws {
        let routine = try await dataManager.createRoutine(
            CreateRoutineRequest(name: name, notes: notes)
        )

        guard let routineID = routine.id else {
            throw WorkoutDatabaseError.missingIdentifier
        }

        do {
            try await createRoutineExercises(routineID: routineID)
        } catch let saveError {
            do {
                try await dataManager.deleteRoutine(id: routineID)
            } catch let cleanupError {
                throw WorkoutTemplateEditorError.saveCleanupFailed(
                    originalError: saveError,
                    cleanupError: cleanupError
                )
            }

            throw saveError
        }
    }

    private func editTemplate(summary: WorkoutTemplateSummary, name: String, notes: String?) async throws {
        let updatedRoutine = try await dataManager.updateRoutine(
            Routine(
                id: summary.id,
                name: name,
                notes: notes
            )
        )

        let routineID = updatedRoutine.id ?? summary.id
        try await reconcileRoutineExercises(routineID: routineID)
    }

    private func createRoutineExercises(routineID: Int64) async throws {
        for (index, draft) in exerciseDrafts.enumerated() {
            try await dataManager.addRoutineExercise(
                makeCreateRequest(
                    for: draft,
                    routineID: routineID,
                    orderIndex: index + 1
                )
            )
        }
    }

    private func reconcileRoutineExercises(routineID: Int64) async throws {
        let currentRows = try await dataManager.fetchRoutineExercises(routineId: routineID)
        let retainedRoutineExerciseIDs = Set(exerciseDrafts.compactMap { $0.routineExerciseID })
        let rowsToDelete = currentRows.filter { row in
            guard let id = row.id else { return false }
            return !retainedRoutineExerciseIDs.contains(id)
        }
        var createdRoutineExerciseIDs: [Int64] = []

        do {
            for row in rowsToDelete {
                guard let id = row.id else { continue }
                try await dataManager.deleteRoutineExercise(id: id)
            }

            for (offset, draft) in exerciseDrafts.enumerated() where draft.routineExerciseID != nil {
                try await dataManager.updateRoutineExercise(
                    makeRoutineExercise(
                        for: draft,
                        routineID: routineID,
                        orderIndex: -1_000 - offset
                    )
                )
            }

            for (index, draft) in exerciseDrafts.enumerated() where draft.routineExerciseID == nil {
                let createdRoutineExercise = try await dataManager.addRoutineExercise(
                    makeCreateRequest(
                        for: draft,
                        routineID: routineID,
                        orderIndex: index + 1
                    )
                )

                guard let createdID = createdRoutineExercise.id else {
                    throw WorkoutDatabaseError.missingIdentifier
                }
                createdRoutineExerciseIDs.append(createdID)
            }

            for (index, draft) in exerciseDrafts.enumerated() where draft.routineExerciseID != nil {
                try await dataManager.updateRoutineExercise(
                    makeRoutineExercise(
                        for: draft,
                        routineID: routineID,
                        orderIndex: index + 1
                    )
                )
            }
        } catch let saveError {
            do {
                try await rollbackRoutineExercises(
                    originalRows: currentRows,
                    rowsToDelete: rowsToDelete,
                    createdRoutineExerciseIDs: createdRoutineExerciseIDs
                )
            } catch let rollbackError {
                throw WorkoutTemplateEditorError.saveRollbackFailed(
                    originalError: saveError,
                    rollbackError: rollbackError
                )
            }

            throw saveError
        }
    }

    private func validationError() -> WorkoutTemplateEditorValidationError? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .missingName
        }

        guard !exerciseDrafts.isEmpty else {
            return .missingExercises
        }

        for draft in exerciseDrafts {
            guard let setCount = parsedSetCount(from: draft.workingSetsText), setCount > 0 else {
                return .invalidSetCount(exerciseName: draft.exercise.name)
            }

            guard let warmupCount = parsedInteger(from: draft.warmupSetsText), warmupCount >= 0 else {
                return .invalidWarmupCount(exerciseName: draft.exercise.name)
            }

            if draft.exercise.isRepBased {
                guard let minimum = parsedInteger(from: draft.targetRepsMinText), minimum > 0,
                      let maximum = parsedInteger(from: draft.targetRepsMaxText), maximum >= minimum else {
                    return .invalidReps(exerciseName: draft.exercise.name)
                }

                guard let increment = parsedDecimal(from: draft.loadIncrementKgText), increment > 0 else {
                    return .invalidLoadIncrement(exerciseName: draft.exercise.name)
                }
            } else if draft.exercise.isDurationBased {
                guard let duration = parsedDecimal(from: draft.durationText), duration > 0 else {
                    return .invalidDuration(exerciseName: draft.exercise.name)
                }
            }

            if !draft.restSecondsText.isEmpty {
                guard let rest = parsedInteger(from: draft.restSecondsText), rest >= 0 else {
                    return .invalidRestSeconds(exerciseName: draft.exercise.name)
                }
            }
        }

        return nil
    }

    private func updateDraft(id: UUID, update: (inout WorkoutTemplateExerciseDraft) -> Void) {
        guard let index = exerciseDrafts.firstIndex(where: { $0.id == id }) else {
            return
        }

        update(&exerciseDrafts[index])
    }

    private func renumberDraftOrderIndexes() {
        for index in exerciseDrafts.indices {
            exerciseDrafts[index].orderIndex = index + 1
        }
        normalizeSupersets()
    }

    private func normalizeSupersets() {
        let groupCounts = Dictionary(grouping: exerciseDrafts.compactMap { $0.supersetGroupID }, by: { $0 })
            .mapValues { $0.count }

        for index in exerciseDrafts.indices {
            if let gid = exerciseDrafts[index].supersetGroupID, groupCounts[gid, default: 0] < 2 {
                exerciseDrafts[index].supersetGroupID = nil
            }
        }
    }

    private func makeCreateRequest(
        for draft: WorkoutTemplateExerciseDraft,
        routineID: Int64,
        orderIndex: Int
    ) -> CreateRoutineExerciseRequest {
        CreateRoutineExerciseRequest(
            routine_id: routineID,
            exercise_id: draft.exercise.id,
            order_index: orderIndex,
            target_sets: parsedSetCount(from: draft.workingSetsText),
            target_reps_min: draft.exercise.isRepBased ? parsedInteger(from: draft.targetRepsMinText) : nil,
            target_reps_max: draft.exercise.isRepBased ? parsedInteger(from: draft.targetRepsMaxText) : nil,
            warmup_sets: draft.exercise.isRepBased ? (parsedInteger(from: draft.warmupSetsText) ?? 0) : 0,
            load_increment_kg: draft.exercise.isRepBased ? (parsedDecimal(from: draft.loadIncrementKgText) ?? 2.5) : 2.5,
            rest_seconds: parsedInteger(from: draft.restSecondsText),
            superset_group_id: draft.supersetGroupID,
            duration: draft.exercise.isDurationBased ? parsedDecimal(from: draft.durationText) : nil
        )
    }

    private func makeRoutineExercise(
        for draft: WorkoutTemplateExerciseDraft,
        routineID: Int64,
        orderIndex: Int
    ) -> RoutineExercise {
        RoutineExercise(
            id: draft.routineExerciseID,
            routine_id: routineID,
            exercise_id: draft.exercise.id,
            order_index: orderIndex,
            target_sets: parsedSetCount(from: draft.workingSetsText),
            target_reps_min: draft.exercise.isRepBased ? parsedInteger(from: draft.targetRepsMinText) : nil,
            target_reps_max: draft.exercise.isRepBased ? parsedInteger(from: draft.targetRepsMaxText) : nil,
            warmup_sets: draft.exercise.isRepBased ? (parsedInteger(from: draft.warmupSetsText) ?? 0) : 0,
            load_increment_kg: draft.exercise.isRepBased ? (parsedDecimal(from: draft.loadIncrementKgText) ?? 2.5) : 2.5,
            rest_seconds: parsedInteger(from: draft.restSecondsText),
            superset_group_id: draft.supersetGroupID,
            duration: draft.exercise.isDurationBased ? parsedDecimal(from: draft.durationText) : nil
        )
    }

    private static func makeDrafts(
        from routineExercises: [RoutineExercise],
        exercisesByID: [Int64: ExerciseLibraryItem]
    ) -> [WorkoutTemplateExerciseDraft] {
        routineExercises.enumerated().map { index, routineExercise in
            let exercise = exercisesByID[routineExercise.exercise_id] ?? ExerciseLibraryItem(
                id: routineExercise.exercise_id,
                name: "Exercise \(routineExercise.exercise_id)",
                type: .repBased,
                equipmentID: nil,
                equipmentName: "No equipment"
            )

            return WorkoutTemplateExerciseDraft(
                routineExerciseID: routineExercise.id,
                exercise: exercise,
                orderIndex: index + 1,
                workingSetsText: String(routineExercise.target_sets ?? 1),
                warmupSetsText: String(routineExercise.warmup_sets),
                targetRepsMinText: routineExercise.target_reps_min.map(String.init) ?? "",
                targetRepsMaxText: routineExercise.target_reps_max.map(String.init) ?? "",
                loadIncrementKgText: NumericFormatter.format(routineExercise.load_increment_kg),
                durationText: routineExercise.duration.map { NSDecimalNumber(decimal: $0).stringValue } ?? "",
                restSecondsText: routineExercise.rest_seconds.map(String.init) ?? "",
                supersetGroupID: routineExercise.superset_group_id
            )
        }
    }

    private static func makeNewDraft(for item: ExerciseLibraryItem, orderIndex: Int) -> WorkoutTemplateExerciseDraft {
        WorkoutTemplateExerciseDraft(
            exercise: item,
            orderIndex: orderIndex,
            workingSetsText: "1",
            warmupSetsText: "0",
            targetRepsMinText: "",
            targetRepsMaxText: "",
            loadIncrementKgText: "2.5",
            durationText: "",
            restSecondsText: ""
        )
    }

    private func parsedSetCount(from text: String) -> Int? {
        parsedInteger(from: text)
    }

    private func parsedInteger(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmed)
    }

    private func parsedDecimal(from text: String) -> Decimal? {
        return NumericFormatter.parse(text)
    }

    private func rollbackRoutineExercises(
        originalRows: [RoutineExercise],
        rowsToDelete: [RoutineExercise],
        createdRoutineExerciseIDs: [Int64]
    ) async throws {
        let rowsToRetain = originalRows.filter { row in
            guard let id = row.id else { return false }
            return !rowsToDelete.contains(where: { $0.id == id })
        }

        for createdID in createdRoutineExerciseIDs {
            try await dataManager.deleteRoutineExercise(id: createdID)
        }

        for (index, row) in rowsToRetain.enumerated() {
            try await dataManager.updateRoutineExercise(
                RoutineExercise(
                    id: row.id,
                    routine_id: row.routine_id,
                    exercise_id: row.exercise_id,
                    order_index: -10_000 - index,
                    target_sets: row.target_sets,
                    target_reps_min: row.target_reps_min,
                    target_reps_max: row.target_reps_max,
                    warmup_sets: row.warmup_sets,
                    load_increment_kg: row.load_increment_kg,
                    rest_seconds: row.rest_seconds,
                    superset_group_id: row.superset_group_id,
                    duration: row.duration
                )
            )
        }

        for row in rowsToDelete.sorted(by: { $0.order_index < $1.order_index }) {
            _ = try await dataManager.addRoutineExercise(
                CreateRoutineExerciseRequest(
                    routine_id: row.routine_id,
                    exercise_id: row.exercise_id,
                    order_index: row.order_index,
                    target_sets: row.target_sets,
                    target_reps_min: row.target_reps_min,
                    target_reps_max: row.target_reps_max,
                    warmup_sets: row.warmup_sets,
                    load_increment_kg: row.load_increment_kg,
                    rest_seconds: row.rest_seconds,
                    superset_group_id: row.superset_group_id,
                    duration: row.duration
                )
            )
        }

        for row in rowsToRetain {
            try await dataManager.updateRoutineExercise(row)
        }
    }
}

private enum WorkoutTemplateEditorError: LocalizedError {
    case missingRoutine
    case saveCleanupFailed(originalError: Error, cleanupError: Error)
    case saveRollbackFailed(originalError: Error, rollbackError: Error)

    var errorDescription: String? {
        switch self {
        case .missingRoutine:
            return "Routine could not be found."
        case .saveCleanupFailed(let originalError, let cleanupError):
            return "\(originalError.localizedDescription) Cleanup failed: \(cleanupError.localizedDescription)"
        case .saveRollbackFailed(let originalError, let rollbackError):
            return "\(originalError.localizedDescription) Rollback failed: \(rollbackError.localizedDescription)"
        }
    }
}

private enum WorkoutTemplateEditorValidationError: LocalizedError {
    case missingName
    case missingExercises
    case invalidSetCount(exerciseName: String)
    case invalidWarmupCount(exerciseName: String)
    case invalidReps(exerciseName: String)
    case invalidLoadIncrement(exerciseName: String)
    case invalidDuration(exerciseName: String)
    case invalidRestSeconds(exerciseName: String)

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Enter a routine name."
        case .missingExercises:
            return "Add at least one exercise."
        case .invalidSetCount(let exerciseName):
            return "Enter a valid set count for \(exerciseName)."
        case .invalidWarmupCount(let exerciseName):
            return "Enter a valid warm-up set count for \(exerciseName)."
        case .invalidReps(let exerciseName):
            return "Enter a valid minimum and maximum rep range for \(exerciseName)."
        case .invalidLoadIncrement(let exerciseName):
            return "Enter a positive load increment for \(exerciseName)."
        case .invalidDuration(let exerciseName):
            return "Enter a valid duration for \(exerciseName)."
        case .invalidRestSeconds(let exerciseName):
            return "Enter valid rest seconds for \(exerciseName)."
        }
    }
}
