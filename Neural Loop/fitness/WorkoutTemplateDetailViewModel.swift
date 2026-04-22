import Combine
import Foundation

@MainActor
final class WorkoutTemplateDetailViewModel: ObservableObject {
    @Published private(set) var rows: [WorkoutTemplateExerciseRow] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let summary: WorkoutTemplateSummary

    private let dataManager: any WorkoutDataManaging & FitnessTemplateDataManaging
    private var hasLoaded = false

    init(
        summary: WorkoutTemplateSummary,
        dataManager: (any WorkoutDataManaging & FitnessTemplateDataManaging)? = nil
    ) {
        self.summary = summary
        self.dataManager = dataManager ?? DBManager.newInstance()
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else {
            return
        }

        await load()
    }

    func reload() async {
        hasLoaded = false
        await load()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let equipmentRows = dataManager.fetchAllEquipment()
            async let exerciseRows = dataManager.fetchAllExercises()
            async let routineExerciseRows = dataManager.fetchRoutineExercises(routineId: summary.id)

            let (equipment, exercises, routineExercises) = try await (
                equipmentRows,
                exerciseRows,
                routineExerciseRows
            )

            let equipmentNamesByID = Dictionary(
                uniqueKeysWithValues: equipment.compactMap { equipment -> (Int64, String)? in
                    guard let id = equipment.id else { return nil }
                    return (id, equipment.name)
                }
            )

            let exercisesByID = Dictionary(
                uniqueKeysWithValues: exercises.compactMap { exercise -> (Int64, Exercise)? in
                    guard let id = exercise.id else { return nil }
                    return (id, exercise)
                }
            )

            rows = routineExercises
                .sorted { lhs, rhs in
                    if lhs.order_index == rhs.order_index {
                        return (lhs.id ?? lhs.exercise_id) < (rhs.id ?? rhs.exercise_id)
                    }
                    return lhs.order_index < rhs.order_index
                }
                .map { routineExercise in
                    let exercise = exercisesByID[routineExercise.exercise_id]
                    let equipmentName = exercise?.equipment_id.flatMap { equipmentNamesByID[$0] } ?? "No equipment"
                    let exerciseName = exercise?.name ?? "Exercise \(routineExercise.exercise_id)"

                    return WorkoutTemplateExerciseRow(
                        id: routineExercise.id ?? (routineExercise.exercise_id &* 1_000 &+ Int64(routineExercise.order_index)),
                        exerciseName: exerciseName,
                        equipmentName: equipmentName,
                        setCount: routineExercise.target_sets ?? 1,
                        orderIndex: routineExercise.order_index
                    )
                }

            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
