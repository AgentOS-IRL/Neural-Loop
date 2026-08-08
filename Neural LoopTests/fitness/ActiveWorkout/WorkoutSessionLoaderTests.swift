import XCTest
@testable import Neural_Loop

final class WorkoutSessionLoaderTests: XCTestCase {
    func testNoHistoryLeavesDraftValuesUntouched() async {
        let dataManager = MockWorkoutSessionLoaderDataManager()
        let loader = WorkoutSessionLoader(db: dataManager)
        let exercise = makeExerciseState()

        let result = await loader.loadHistory(for: [exercise], routineID: 7)

        XCTAssertEqual(result[0].sets[0].weightText, "")
        XCTAssertEqual(result[0].sets[0].repsText, "")
        XCTAssertNil(result[0].sets[0].previousValues)
        XCTAssertNil(result[0].sets[0].suggestedValues)
    }

    func testStrengthHistoryProducesExplicitProgressionSuggestion() async {
        let dataManager = MockWorkoutSessionLoaderDataManager()
        dataManager.snapshots = [
            WorkoutLaunchHistorySnapshot(
                routine_exercise_id: 11,
                exercise_id: 101,
                source_scope: .sameRoutine,
                source_date: "2026-08-01",
                source_session_id: 42,
                strength_sets: [
                    WorkoutLaunchHistoryStrengthSet(
                        routine_exercise_id: 11,
                        set_type: .working,
                        set_number: 1,
                        reps: 12,
                        weight: 100
                    )
                ],
                cardio_logs: []
            )
        ]
        let loader = WorkoutSessionLoader(db: dataManager)

        let result = await loader.loadHistory(for: [makeExerciseState()], routineID: 7)
        let set = result[0].sets[0]

        XCTAssertEqual(set.weightText, "")
        XCTAssertEqual(set.repsText, "")
        XCTAssertEqual(set.previousValues, WorkoutDraftValues(weight: 100, reps: 12))
        XCTAssertEqual(set.suggestedValues, WorkoutDraftValues(weight: 102.5, reps: 8))
        XCTAssertEqual(set.suggestionReason, .rangeCeilingLoadIncrease)
        XCTAssertEqual(result[0].historySource?.scope, .sameRoutine)
    }

    func testCardioHistoryRepeatsPreviousValuesAsSuggestion() async {
        let dataManager = MockWorkoutSessionLoaderDataManager()
        dataManager.snapshots = [
            WorkoutLaunchHistorySnapshot(
                routine_exercise_id: 21,
                exercise_id: 202,
                source_scope: .global,
                source_date: "2026-08-02",
                source_session_id: 43,
                strength_sets: [],
                cardio_logs: [
                    WorkoutLaunchHistoryCardioLog(
                        routine_exercise_id: 21,
                        set_number: 1,
                        duration_minutes: 30,
                        distance_meters: 5_000,
                        calories: 250
                    )
                ]
            )
        ]
        let cardio = WorkoutExerciseCardState(
            id: 21,
            exercise: ExerciseLibraryItem(
                id: 202,
                name: "Run",
                type: .duration,
                equipmentID: nil,
                equipmentName: "Treadmill"
            ),
            sets: [WorkoutSetDraft(setNumber: 1)]
        )

        let result = await WorkoutSessionLoader(db: dataManager)
            .loadHistory(for: [cardio], routineID: nil)

        XCTAssertEqual(result[0].sets[0].previousValues?.durationMinutes, 30)
        XCTAssertEqual(result[0].sets[0].suggestedValues?.distanceKilometers, 5)
        XCTAssertEqual(result[0].sets[0].suggestionReason, .cardioRepeat)
        XCTAssertEqual(result[0].sets[0].durationText, "")
    }

    func testHistoryFailureKeepsWorkoutUsable() async {
        let dataManager = MockWorkoutSessionLoaderDataManager()
        dataManager.error = MockWorkoutSessionLoaderError.failed

        let result = await WorkoutSessionLoader(db: dataManager)
            .loadHistory(for: [makeExerciseState()], routineID: 7)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].historyUnavailable, true)
        XCTAssertEqual(result[0].historicalHint, "History unavailable")
    }

    private func makeExerciseState() -> WorkoutExerciseCardState {
        WorkoutExerciseCardState(
            id: 11,
            exercise: ExerciseLibraryItem(
                id: 101,
                name: "Squat",
                type: .repBased,
                equipmentID: nil,
                equipmentName: "None"
            ),
            sets: [WorkoutSetDraft(setNumber: 1)],
            targetSets: 1,
            targetRepRange: WorkoutRepRange(minimum: 8, maximum: 12),
            loadIncrementKg: 2.5
        )
    }
}

private final class MockWorkoutSessionLoaderDataManager: WorkoutLaunchHistoryReading {
    var snapshots: [WorkoutLaunchHistorySnapshot] = []
    var error: Error?

    func fetchWorkoutLaunchHistory(
        routineID: Int64?,
        lookupItems: [WorkoutLaunchHistoryLookupItem]
    ) async throws -> [WorkoutLaunchHistorySnapshot] {
        if let error {
            throw error
        }
        return snapshots
    }
}

private enum MockWorkoutSessionLoaderError: Error {
    case failed
}

