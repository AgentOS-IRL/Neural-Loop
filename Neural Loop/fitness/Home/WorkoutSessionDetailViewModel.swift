import Foundation
import SwiftUI
import Combine

struct WorkoutSessionExerciseDraft: Identifiable {
    let id: UUID = UUID()
    let exerciseId: Int64
    let exerciseName: String
    let exerciseType: ExerciseType
    var sets: [WorkoutSetDraft]
}

@MainActor
class WorkoutSessionDetailViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(WorkoutSessionDetail)
        case error(String)
    }

    @Published var state: State = .loading
    @Published var isEditing: Bool = false
    @Published var draftSession: WorkoutSession?
    @Published var draftExercises: [WorkoutSessionExerciseDraft] = []
    
    private var deletedSetIds: [Int64] = []
    private var deletedCardioLogIds: [Int64] = []

    let sessionId: Int64
    private let dataManager: any WorkoutSessionDetailManaging

    init(sessionId: Int64, dataManager: any WorkoutSessionDetailManaging) {
        self.sessionId = sessionId
        self.dataManager = dataManager
    }

    func load() async {
        state = .loading
        do {
            let detail = try await dataManager.fetchWorkoutSessionDetail(sessionId: sessionId)
            state = .loaded(detail)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func startEditing() {
        guard case .loaded(let detail) = state else { return }
        
        draftSession = detail.session
        draftExercises = detail.exercises.map { exerciseDetail in
            let sets: [WorkoutSetDraft]
            if exerciseDetail.exerciseType == .repBased {
                sets = exerciseDetail.sets.map { set in
                    WorkoutSetDraft(
                        dbId: set.id,
                        setNumber: set.set_number,
                        weightText: set.weight != nil ? NumericFormatter.format(set.weight!) : "",
                        repsText: "\(set.reps)",
                        isCompleted: true,
                        superset_group_id: set.superset_group_id,
                        setType: set.set_type,
                        routineExerciseID: set.routine_exercise_id
                    )
                }
            } else {
                sets = exerciseDetail.cardioLogs.enumerated().map { index, log in
                    WorkoutSetDraft(
                        dbId: log.id,
                        setNumber: log.set_number,
                        durationText: log.duration_minutes != nil ? NumericFormatter.format(log.duration_minutes!) : "",
                        distanceText: log.distance_meters != nil ? NumericFormatter.format(log.distance_meters!) : "",
                        caloriesText: log.calories != nil ? NumericFormatter.format(log.calories!) : "",
                        isCompleted: true,
                        routineExerciseID: log.routine_exercise_id
                    )
                }
            }
            
            return WorkoutSessionExerciseDraft(
                exerciseId: exerciseDetail.exerciseId,
                exerciseName: exerciseDetail.exerciseName,
                exerciseType: exerciseDetail.exerciseType,
                sets: sets
            )
        }
        
        deletedSetIds = []
        deletedCardioLogIds = []
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
        draftSession = nil
        draftExercises = []
        deletedSetIds = []
        deletedCardioLogIds = []
    }

    func addSet(to exerciseId: Int64) {
        guard let index = draftExercises.firstIndex(where: { $0.exerciseId == exerciseId }) else { return }
        let newSetNumber = draftExercises[index].sets.count + 1
        draftExercises[index].sets.append(WorkoutSetDraft(setNumber: newSetNumber))
    }

    func removeSet(at index: Int, from exerciseId: Int64) {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.exerciseId == exerciseId }) else { return }
        let removedSet = draftExercises[exerciseIndex].sets.remove(at: index)
        
        if let dbId = removedSet.dbId {
            if draftExercises[exerciseIndex].exerciseType == .repBased {
                deletedSetIds.append(dbId)
            } else {
                deletedCardioLogIds.append(dbId)
            }
        }
        
        // Re-index warm-up and working sets independently.
        for setType in WorkoutSetType.allCases {
            let indices = draftExercises[exerciseIndex].sets.indices.filter {
                draftExercises[exerciseIndex].sets[$0].setType == setType
            }
            for (offset, setIndex) in indices.enumerated() {
                draftExercises[exerciseIndex].sets[setIndex].setNumber = offset + 1
            }
        }
    }

    func saveChanges() async {
        guard var session = draftSession else { return }
        
        // Sanitize times: convert empty/whitespace strings to nil
        if let start = session.start_time, start.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.start_time = nil
        } else {
            session.start_time = WorkoutTimeCoding.normalize(session.start_time)
        }

        if let end = session.end_time, end.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.end_time = nil
        } else {
            session.end_time = WorkoutTimeCoding.normalize(session.end_time)
        }

        do {
            _ = try await dataManager.updateWorkoutSession(session)
            
            for exerciseDraft in draftExercises {
                for draftSet in exerciseDraft.sets {
                    if exerciseDraft.exerciseType == .repBased {
                        let weight = NumericFormatter.parse(draftSet.weightText)
                        let reps = Int(draftSet.repsText) ?? 0
                        
                        if let dbId = draftSet.dbId {
                            let updatedSet = WorkoutSet(
                                id: dbId,
                                workout_session_id: sessionId,
                                exercise_id: exerciseDraft.exerciseId,
                                set_number: draftSet.setNumber,
                                reps: reps,
                                weight: weight,
                                superset_group_id: draftSet.superset_group_id,
                                routine_exercise_id: draftSet.routineExerciseID,
                                set_type: draftSet.setType
                            )
                            _ = try await dataManager.updateWorkoutSet(updatedSet)
                        } else {
                            let request = CreateWorkoutSetRequest(
                                workout_session_id: sessionId,
                                exercise_id: exerciseDraft.exerciseId,
                                set_number: draftSet.setNumber,
                                reps: reps,
                                weight: weight,
                                superset_group_id: draftSet.superset_group_id,
                                routine_exercise_id: draftSet.routineExerciseID,
                                set_type: draftSet.setType
                            )
                            _ = try await dataManager.createWorkoutSet(request)
                        }
                    } else {
                        let duration = NumericFormatter.parse(draftSet.durationText)
                        let distance = NumericFormatter.parse(draftSet.distanceText)
                        let calories = NumericFormatter.parse(draftSet.caloriesText)
                        
                        if let dbId = draftSet.dbId {
                            let updatedLog = CardioLog(
                                id: dbId,
                                workout_session_id: sessionId,
                                exercise_id: exerciseDraft.exerciseId,
                                distance_meters: distance,
                                duration_minutes: duration,
                                calories: calories,
                                routine_exercise_id: draftSet.routineExerciseID,
                                set_number: draftSet.setNumber
                            )
                            _ = try await dataManager.updateCardioLog(updatedLog)
                        } else {
                            let request = CreateCardioLogRequest(
                                workout_session_id: sessionId,
                                exercise_id: exerciseDraft.exerciseId,
                                distance_meters: distance,
                                duration_minutes: duration,
                                calories: calories,
                                routine_exercise_id: draftSet.routineExerciseID,
                                set_number: draftSet.setNumber
                            )
                            _ = try await dataManager.createCardioLog(request)
                        }
                    }
                }
            }
            
            for id in deletedSetIds {
                try await dataManager.deleteWorkoutSet(id: id)
            }
            for id in deletedCardioLogIds {
                try await dataManager.deleteCardioLog(id: id)
            }
            
            await load()
            isEditing = false
        } catch {
            state = .error("Failed to save changes: \(error.localizedDescription)")
        }
    }
}
