import Combine
import Foundation

@MainActor
final class FitnessViewModel: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplateSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let dataManager: FitnessTemplateDataManaging
    private var hasLoaded = false

    init(dataManager: FitnessTemplateDataManaging? = nil) {
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
            let routines = try await dataManager.fetchAllRoutines()
            let sortedRoutines = routines.compactMap { routine -> (id: Int64, routine: Routine)? in
                guard let id = routine.id else {
                    return nil
                }

                return (id: id, routine: routine)
            }
            .sorted { lhs, rhs in
                switch lhs.routine.name.localizedCaseInsensitiveCompare(rhs.routine.name) {
                case .orderedAscending:
                    return true
                case .orderedDescending:
                    return false
                case .orderedSame:
                    return lhs.id < rhs.id
                @unknown default:
                    return lhs.id < rhs.id
                }
            }

            var loadedTemplates: [WorkoutTemplateSummary] = []
            loadedTemplates.reserveCapacity(sortedRoutines.count)

            for entry in sortedRoutines {
                let routineExercises = try await dataManager.fetchRoutineExercises(routineId: entry.id)
                loadedTemplates.append(Self.makeSummary(for: entry.routine, routineExercises: routineExercises))
            }

            templates = loadedTemplates
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func makeSummary(
        for routine: Routine,
        routineExercises: [RoutineExercise]
    ) -> WorkoutTemplateSummary {
        let exerciseCount = routineExercises.count
        let setCount = routineExercises.reduce(0) { partialResult, routineExercise in
            partialResult + (routineExercise.target_sets ?? 1)
        }

        return WorkoutTemplateSummary(
            id: routine.id ?? 0,
            title: routine.name,
            exerciseCount: exerciseCount,
            setCount: setCount
        )
    }
}
