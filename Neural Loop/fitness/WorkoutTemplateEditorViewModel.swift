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

    private let dataManager: any WorkoutTemplateEditingDataManaging
    private let generatedRoutine: WorkoutRoutineGenerationPayload?
    private var hasLoaded = false

    init(
        mode: WorkoutTemplateEditorMode,
        dataManager: any WorkoutTemplateEditingDataManaging,
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
            partialResult + max(parsedSetCount(from: draft.targetSetsText) ?? 1, 1)
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
            draft.targetSetsText = value
        }
    }

    func updateTargetReps(id: UUID, value: String) {
        updateDraft(id: id) { draft in
            draft.targetRepsText = value
        }
    }

    func updateDuration(id: UUID, value: String) {
        updateDraft(id: id) { draft in
            draft.durationText = value
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
            async let exerciseRows = dataManager.fetchAllExercises()

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
            guard let setCount = parsedSetCount(from: draft.targetSetsText), setCount > 0 else {
                return .invalidSetCount(exerciseName: draft.exercise.name)
            }

            if draft.exercise.isRepBased {
                guard let reps = parsedInteger(from: draft.targetRepsText), reps > 0 else {
                    return .invalidReps(exerciseName: draft.exercise.name)
                }
            } else if draft.exercise.isDurationBased {
                guard let duration = parsedDecimal(from: draft.durationText), duration > 0 else {
                    return .invalidDuration(exerciseName: draft.exercise.name)
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
            target_sets: parsedSetCount(from: draft.targetSetsText),
            target_reps: draft.exercise.isRepBased ? parsedInteger(from: draft.targetRepsText) : nil,
            rest_seconds: nil,
            superset_group_id: nil,
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
            target_sets: parsedSetCount(from: draft.targetSetsText),
            target_reps: draft.exercise.isRepBased ? parsedInteger(from: draft.targetRepsText) : nil,
            rest_seconds: nil,
            superset_group_id: nil,
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
                targetSetsText: String(routineExercise.target_sets ?? 1),
                targetRepsText: routineExercise.target_reps.map(String.init) ?? "",
                durationText: routineExercise.duration.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
            )
        }
    }

    private static func makeNewDraft(for item: ExerciseLibraryItem, orderIndex: Int) -> WorkoutTemplateExerciseDraft {
        WorkoutTemplateExerciseDraft(
            exercise: item,
            orderIndex: orderIndex,
            targetSetsText: "1",
            targetRepsText: item.isRepBased ? "" : "",
            durationText: ""
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
                    target_reps: row.target_reps,
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
                    target_reps: row.target_reps,
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
    case invalidReps(exerciseName: String)
    case invalidDuration(exerciseName: String)

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Enter a routine name."
        case .missingExercises:
            return "Add at least one exercise."
        case .invalidSetCount(let exerciseName):
            return "Enter a valid set count for \(exerciseName)."
        case .invalidReps(let exerciseName):
            return "Enter valid reps for \(exerciseName)."
        case .invalidDuration(let exerciseName):
            return "Enter a valid duration for \(exerciseName)."
        }
    }
}
