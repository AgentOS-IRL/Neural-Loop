import XCTest
@testable import Neural_Loop

final class WorkoutWatchSnapshotMapperTests: XCTestCase {
    func testActiveWorkoutDraftMapsToWatchSnapshot() {
        let createdAt = Date(timeIntervalSince1970: 1_774_080_000)
        let now = createdAt.addingTimeInterval(125)
        let firstSetID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondSetID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let draft = makeDraft(
            routineID: 44,
            session: makeSession(id: 123, title: "Lower Body Strength"),
            exercises: [
                makeExerciseState(
                    id: 7001,
                    exercise: makeExercise(id: 501, name: "Back Squat"),
                    sets: [
                        makeSet(id: firstSetID, setNumber: 1, weightText: "102.5", repsText: "8", isCompleted: true),
                        makeSet(id: secondSetID, setNumber: 2, weightText: "105", repsText: "6")
                    ],
                    restSeconds: 180
                ),
                makeExerciseState(
                    id: 0,
                    exercise: makeExercise(id: 502, name: "Romanian Deadlift"),
                    sets: [
                        makeSet(setNumber: 1, weightText: "80", repsText: "10")
                    ]
                )
            ],
            createdAt: createdAt,
            updatedAt: createdAt
        )

        let snapshot = draft.watchSnapshot(now: now)

        XCTAssertEqual(snapshot.title, "Lower Body Strength")
        XCTAssertEqual(snapshot.session.routineID, 44)
        XCTAssertEqual(snapshot.session.workoutSessionID, 123)
        XCTAssertEqual(snapshot.id, snapshot.session.id)
        XCTAssertEqual(snapshot.id, "active-workout-44-\(createdAt.timeIntervalSince1970)")
        XCTAssertEqual(snapshot.startedAt, createdAt)
        XCTAssertEqual(snapshot.elapsedSeconds, 125)

        XCTAssertEqual(snapshot.exercises.count, 2)
        XCTAssertEqual(snapshot.exercises[0].id, "routine-exercise-7001")
        XCTAssertEqual(snapshot.exercises[0].sourceExerciseID, 501)
        XCTAssertEqual(snapshot.exercises[0].name, "Back Squat")
        XCTAssertEqual(snapshot.exercises[0].orderIndex, 0)
        XCTAssertEqual(snapshot.exercises[0].restDurationSeconds, 180)

        XCTAssertEqual(snapshot.exercises[0].sets.count, 2)
        XCTAssertEqual(snapshot.exercises[0].sets[0].id, firstSetID.uuidString)
        XCTAssertEqual(snapshot.exercises[0].sets[0].sourceSetID, firstSetID.uuidString)
        XCTAssertEqual(snapshot.exercises[0].sets[0].setNumber, 1)
        XCTAssertEqual(snapshot.exercises[0].sets[0].values.kg, Decimal(string: "102.5"))
        XCTAssertEqual(snapshot.exercises[0].sets[0].values.reps, 8)
        XCTAssertTrue(snapshot.exercises[0].sets[0].isCompleted)
        XCTAssertEqual(snapshot.exercises[0].sets[1].id, secondSetID.uuidString)
        XCTAssertEqual(snapshot.exercises[0].sets[1].values.kg, Decimal(string: "105"))
        XCTAssertEqual(snapshot.exercises[0].sets[1].values.reps, 6)

        XCTAssertEqual(snapshot.exercises[1].id, "exercise-502-1")
        XCTAssertEqual(snapshot.exercises[1].sourceExerciseID, 502)
        XCTAssertEqual(snapshot.exercises[1].name, "Romanian Deadlift")
        XCTAssertEqual(snapshot.exercises[1].orderIndex, 1)
    }

    func testEmptyWorkoutMapsToSnapshotWithNoExercises() {
        let createdAt = Date(timeIntervalSince1970: 1_774_080_100)
        let draft = makeDraft(
            routineID: 55,
            session: makeSession(id: nil, title: "Empty Workout"),
            exercises: [],
            createdAt: createdAt,
            updatedAt: createdAt
        )

        let snapshot = draft.watchSnapshot(now: createdAt)

        XCTAssertEqual(snapshot.title, "Empty Workout")
        XCTAssertEqual(snapshot.session.routineID, 55)
        XCTAssertNil(snapshot.session.workoutSessionID)
        XCTAssertEqual(snapshot.startedAt, createdAt)
        XCTAssertEqual(snapshot.elapsedSeconds, 0)
        XCTAssertTrue(snapshot.exercises.isEmpty)
    }

    func testCompletedSetsMapCompletionState() {
        let draft = makeDraft(
            exercises: [
                makeExerciseState(
                    sets: [
                        makeSet(setNumber: 1, isCompleted: true),
                        makeSet(setNumber: 2, isCompleted: false)
                    ]
                )
            ]
        )

        let sets = draft.watchSnapshot().exercises[0].sets

        XCTAssertTrue(sets[0].isCompleted)
        XCTAssertFalse(sets[1].isCompleted)
    }

    func testCompletedExerciseDerivedFromAllSets() {
        let draft = makeDraft(
            exercises: [
                makeExerciseState(
                    id: 10,
                    sets: [
                        makeSet(setNumber: 1, isCompleted: true),
                        makeSet(setNumber: 2, isCompleted: true)
                    ]
                ),
                makeExerciseState(
                    id: 11,
                    sets: [
                        makeSet(setNumber: 1, isCompleted: true),
                        makeSet(setNumber: 2, isCompleted: false)
                    ]
                ),
                makeExerciseState(id: 12, sets: [])
            ]
        )

        let exercises = draft.watchSnapshot().exercises

        XCTAssertTrue(exercises[0].isCompleted)
        XCTAssertFalse(exercises[1].isCompleted)
        XCTAssertFalse(exercises[2].isCompleted)
    }

    func testDefaultRestDurationMapsToNil() {
        let draft = makeDraft(
            exercises: [
                makeExerciseState(id: 10, restSeconds: nil),
                makeExerciseState(id: 11, restSeconds: 0),
                makeExerciseState(id: 12, restSeconds: -30),
                makeExerciseState(id: 13, restSeconds: 90)
            ]
        )

        let exercises = draft.watchSnapshot().exercises

        XCTAssertNil(exercises[0].restDurationSeconds)
        XCTAssertNil(exercises[1].restDurationSeconds)
        XCTAssertNil(exercises[2].restDurationSeconds)
        XCTAssertEqual(exercises[3].restDurationSeconds, 90)
    }

    func testOptionalKgAndRepsMapping() {
        let draft = makeDraft(
            exercises: [
                makeExerciseState(
                    sets: [
                        makeSet(setNumber: 1, weightText: " ", repsText: ""),
                        makeSet(setNumber: 2, weightText: "102.5", repsText: " "),
                        makeSet(setNumber: 3, weightText: "", repsText: "8"),
                        makeSet(setNumber: 4, weightText: "abc", repsText: "eight")
                    ]
                )
            ]
        )

        let values = draft.watchSnapshot().exercises[0].sets.map(\.values)

        XCTAssertNil(values[0].kg)
        XCTAssertNil(values[0].reps)
        XCTAssertEqual(values[1].kg, Decimal(string: "102.5"))
        XCTAssertNil(values[1].reps)
        XCTAssertNil(values[2].kg)
        XCTAssertEqual(values[2].reps, 8)
        XCTAssertNil(values[3].kg)
        XCTAssertNil(values[3].reps)
    }

    func testSnapshotIDsAreStableForSameDraft() {
        let createdAt = Date(timeIntervalSince1970: 1_774_080_200)
        var draft = makeDraft(
            routineID: 77,
            exercises: [
                makeExerciseState(
                    id: 0,
                    exercise: makeExercise(id: 601),
                    sets: [
                        makeSet(
                            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                            setNumber: 1,
                            weightText: "100",
                            repsText: "5"
                        )
                    ]
                )
            ],
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let now = createdAt.addingTimeInterval(30)

        let first = draft.watchSnapshot(now: now)
        let second = draft.watchSnapshot(now: now)
        draft.exercises[0].sets[0].weightText = "120"
        draft.exercises[0].sets[0].isCompleted = true
        let mutated = draft.watchSnapshot(now: now)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.exercises[0].id, second.exercises[0].id)
        XCTAssertEqual(first.exercises[0].sets[0].id, second.exercises[0].sets[0].id)
        XCTAssertEqual(first.id, mutated.id)
        XCTAssertEqual(first.exercises[0].id, mutated.exercises[0].id)
        XCTAssertEqual(first.exercises[0].sets[0].id, mutated.exercises[0].sets[0].id)
        XCTAssertNotEqual(first.exercises[0].sets[0].values.kg, mutated.exercises[0].sets[0].values.kg)
        XCTAssertNotEqual(first.exercises[0].sets[0].isCompleted, mutated.exercises[0].sets[0].isCompleted)
    }

    func testPersistenceSnapshotReturnsNilForMissingDraft() {
        let manager = makePersistenceManager("WorkoutWatchSnapshotMapperTestsMissing")

        XCTAssertNil(manager.watchSnapshot(routineID: 404, now: Date(timeIntervalSince1970: 1_774_080_000)))
    }

    func testPersistenceSnapshotReturnsNilForStaleDraft() {
        let manager = makePersistenceManager("WorkoutWatchSnapshotMapperTestsStale")
        let staleDate = Date(timeIntervalSinceNow: -90_000)
        let draft = makeDraft(routineID: 88, createdAt: staleDate, updatedAt: staleDate)
        manager.save(draft: draft)

        XCTAssertNil(manager.watchSnapshot(routineID: 88, now: Date()))
        XCTAssertNil(manager.load(routineID: 88))
    }

    func testPersistenceSnapshotMapsValidDraft() {
        let manager = makePersistenceManager("WorkoutWatchSnapshotMapperTestsValid")
        let createdAt = Date()
        let draft = makeDraft(
            routineID: 99,
            session: makeSession(id: 321, title: "Persisted Workout"),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        manager.save(draft: draft)

        let snapshot = manager.watchSnapshot(routineID: 99, now: createdAt.addingTimeInterval(45))

        XCTAssertEqual(snapshot?.title, "Persisted Workout")
        XCTAssertEqual(snapshot?.session.routineID, 99)
        XCTAssertEqual(snapshot?.session.workoutSessionID, 321)
        XCTAssertEqual(snapshot?.elapsedSeconds, 45)
    }

    private func makeDraft(
        routineID: Int64 = 44,
        session: WorkoutSession = WorkoutSession(
            id: nil,
            date: Date(timeIntervalSince1970: 1_774_080_000),
            start_time: "10:00",
            end_time: nil,
            session_type: "Test Workout",
            notes: nil
        ),
        exercises: [WorkoutExerciseCardState] = [],
        createdAt: Date = Date(timeIntervalSince1970: 1_774_080_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_774_080_000)
    ) -> ActiveWorkoutDraft {
        ActiveWorkoutDraft(
            routineID: routineID,
            session: session,
            exercises: exercises,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func makeSession(
        id: Int64?,
        title: String,
        date: Date = Date(timeIntervalSince1970: 1_774_080_000)
    ) -> WorkoutSession {
        WorkoutSession(
            id: id,
            date: date,
            start_time: "10:00",
            end_time: nil,
            session_type: title,
            notes: "Notes"
        )
    }

    private func makeExerciseState(
        id: Int64 = 7001,
        exercise: ExerciseLibraryItem = ExerciseLibraryItem(
            id: 501,
            name: "Back Squat",
            type: .repBased,
            equipmentID: 1,
            equipmentName: "Barbell"
        ),
        sets: [WorkoutSetDraft] = [WorkoutSetDraft(setNumber: 1)],
        restSeconds: Int? = nil
    ) -> WorkoutExerciseCardState {
        WorkoutExerciseCardState(
            id: id,
            exercise: exercise,
            sets: sets,
            targetSets: nil,
            targetReps: nil,
            restSeconds: restSeconds,
            targetDuration: nil
        )
    }

    private func makeExercise(
        id: Int64,
        name: String = "Exercise"
    ) -> ExerciseLibraryItem {
        ExerciseLibraryItem(
            id: id,
            name: name,
            type: .repBased,
            equipmentID: nil,
            equipmentName: "No Equipment"
        )
    }

    private func makeSet(
        id: UUID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        setNumber: Int,
        weightText: String = "",
        repsText: String = "",
        isCompleted: Bool = false
    ) -> WorkoutSetDraft {
        WorkoutSetDraft(
            id: id,
            setNumber: setNumber,
            weightText: weightText,
            repsText: repsText,
            isCompleted: isCompleted
        )
    }

    private func makePersistenceManager(_ suiteName: String) -> WorkoutDraftPersistenceManager {
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return WorkoutDraftPersistenceManager(userDefaults: userDefaults)
    }
}
