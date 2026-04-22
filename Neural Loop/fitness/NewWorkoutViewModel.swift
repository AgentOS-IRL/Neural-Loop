import Combine
import Foundation

@MainActor
final class NewWorkoutViewModel: ObservableObject {
    @Published private(set) var exerciseCards: [WorkoutExerciseCardState] = []
    @Published private(set) var availableExercises: [ExerciseLibraryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let dataManager: WorkoutDataManaging
    private var hasLoaded = false

    init(dataManager: WorkoutDataManaging? = nil) {
        self.dataManager = dataManager ?? DBManager.newInstance()
    }

    var selectedExerciseIDs: Set<Int64> {
        Set(exerciseCards.map(\.id))
    }

    var subtitleText: String {
        let setCount = exerciseCards.reduce(0) { $0 + $1.sets.count }
        return "\(exerciseCards.count) exercises, \(setCount) sets"
    }

    var canSave: Bool {
        guard !isSaving, !exerciseCards.isEmpty else {
            return false
        }

        return exerciseCards.allSatisfy { card in
            card.sets.allSatisfy { set in
                guard let reps = Int(set.repsText.trimmingCharacters(in: .whitespacesAndNewlines)), reps > 0 else {
                    return false
                }

                let weightText = set.weightText.trimmingCharacters(in: .whitespacesAndNewlines)
                return weightText.isEmpty || Decimal(string: weightText) != nil
            }
        }
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let equipmentRows = dataManager.fetchAllEquipment()
            async let exerciseRows = dataManager.fetchAllExercises()
            let (equipment, exercises) = try await (equipmentRows, exerciseRows)
            let equipmentNamesByID = Dictionary(
                uniqueKeysWithValues: equipment.compactMap { equipment -> (Int64, String)? in
                    guard let id = equipment.id else { return nil }
                    return (id, equipment.name)
                }
            )

            availableExercises = exercises.compactMap { exercise in
                guard let id = exercise.id else { return nil }
                let equipmentName = exercise.equipment_id.flatMap { equipmentNamesByID[$0] } ?? "No equipment"
                return ExerciseLibraryItem(
                    id: id,
                    name: exercise.name,
                    type: exercise.type,
                    equipmentID: exercise.equipment_id,
                    equipmentName: equipmentName
                )
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func addExercises(_ selections: [ExerciseLibraryItem]) {
        let existingIDs = selectedExerciseIDs
        let newCards = selections
            .filter { !existingIDs.contains($0.id) }
            .map { item in
                WorkoutExerciseCardState(
                    id: item.id,
                    exercise: item,
                    sets: [WorkoutSetDraft(setNumber: 1)]
                )
            }

        guard !newCards.isEmpty else {
            return
        }

        exerciseCards.append(contentsOf: newCards)
    }

    func addSet(to cardID: WorkoutExerciseCardState.ID) {
        guard let cardIndex = exerciseCards.firstIndex(where: { $0.id == cardID }) else {
            return
        }

        let previousSet = exerciseCards[cardIndex].sets.last
        let nextSetNumber = (previousSet?.setNumber ?? 0) + 1
        let nextSet = WorkoutSetDraft(
            setNumber: nextSetNumber,
            weightText: previousSet?.weightText ?? "",
            repsText: previousSet?.repsText ?? ""
        )

        exerciseCards[cardIndex].sets.append(nextSet)
    }

    func updateWeight(cardID: WorkoutExerciseCardState.ID, setID: WorkoutSetDraft.ID, value: String) {
        updateSet(cardID: cardID, setID: setID) { set in
            set.weightText = value
        }
    }

    func updateReps(cardID: WorkoutExerciseCardState.ID, setID: WorkoutSetDraft.ID, value: String) {
        updateSet(cardID: cardID, setID: setID) { set in
            set.repsText = value
        }
    }

    func save() async -> Bool {
        guard canSave else {
            return false
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let session = try await dataManager.createWorkoutSession(
                CreateWorkoutSessionRequest(date: Date(), session_type: "Strength")
            )

            guard let sessionID = session.id else {
                throw WorkoutDatabaseError.missingIdentifier
            }

            for card in exerciseCards {
                for draftSet in card.sets {
                    let repsText = draftSet.repsText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let reps = Int(repsText), reps > 0 else {
                        throw WorkoutSaveValidationError.invalidReps
                    }

                    let weightText = draftSet.weightText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let weight = weightText.isEmpty ? nil : Decimal(string: weightText)
                    if !weightText.isEmpty, weight == nil {
                        throw WorkoutSaveValidationError.invalidWeight
                    }

                    _ = try await dataManager.createWorkoutSet(
                        CreateWorkoutSetRequest(
                            workout_session_id: sessionID,
                            exercise_id: card.id,
                            set_number: draftSet.setNumber,
                            reps: reps,
                            weight: weight,
                            superset_group_id: nil
                        )
                    )
                }
            }

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func updateSet(
        cardID: WorkoutExerciseCardState.ID,
        setID: WorkoutSetDraft.ID,
        update: (inout WorkoutSetDraft) -> Void
    ) {
        guard
            let cardIndex = exerciseCards.firstIndex(where: { $0.id == cardID }),
            let setIndex = exerciseCards[cardIndex].sets.firstIndex(where: { $0.id == setID })
        else {
            return
        }

        update(&exerciseCards[cardIndex].sets[setIndex])
    }
}

private enum WorkoutSaveValidationError: LocalizedError {
    case invalidReps
    case invalidWeight

    var errorDescription: String? {
        switch self {
        case .invalidReps:
            return "Enter valid reps for every set."
        case .invalidWeight:
            return "Enter a valid weight or leave KG blank."
        }
    }
}
