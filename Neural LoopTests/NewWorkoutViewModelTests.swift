import XCTest
@testable import Neural_Loop

@MainActor
final class NewWorkoutViewModelTests: XCTestCase {
    func testInitialStateCannotSave() {
        let viewModel = NewWorkoutViewModel(dataManager: FakeWorkoutDataManager())

        XCTAssertEqual(viewModel.subtitleText, "0 exercises, 0 sets")
        XCTAssertFalse(viewModel.canSave)
    }

    func testAddingExercisesCreatesOneSetPerExercise() {
        let viewModel = NewWorkoutViewModel(dataManager: FakeWorkoutDataManager())

        viewModel.addExercises([exercise(id: 1, name: "Bench Press"), exercise(id: 2, name: "Squat")])

        XCTAssertEqual(viewModel.exerciseCards.count, 2)
        XCTAssertEqual(viewModel.exerciseCards.map { $0.sets.count }, [1, 1])
        XCTAssertEqual(viewModel.subtitleText, "2 exercises, 2 sets")
    }

    func testAddingDuplicateExerciseDoesNotCreateDuplicateCard() {
        let viewModel = NewWorkoutViewModel(dataManager: FakeWorkoutDataManager())
        let benchPress = exercise(id: 1, name: "Bench Press")

        viewModel.addExercises([benchPress])
        viewModel.addExercises([benchPress])

        XCTAssertEqual(viewModel.exerciseCards.count, 1)
    }

    func testSyncExercisesRemovesDeselectedCardsAndPreservesRetainedDrafts() {
        let viewModel = NewWorkoutViewModel(dataManager: FakeWorkoutDataManager())
        let benchPress = exercise(id: 1, name: "Bench Press")
        let squat = exercise(id: 2, name: "Squat")
        let row = exercise(id: 3, name: "Cable Row")

        viewModel.addExercises([benchPress, squat])
        let retainedCardID = viewModel.exerciseCards[0].id
        let retainedSetID = viewModel.exerciseCards[0].sets[0].id
        viewModel.updateWeight(cardID: retainedCardID, setID: retainedSetID, value: "80.5")
        viewModel.updateReps(cardID: retainedCardID, setID: retainedSetID, value: "8")

        viewModel.syncExercises(with: [benchPress, row])

        XCTAssertEqual(viewModel.exerciseCards.map(\.id), [1, 3])
        XCTAssertEqual(viewModel.exerciseCards[0].sets.count, 1)
        XCTAssertEqual(viewModel.exerciseCards[0].sets[0].weightText, "80.5")
        XCTAssertEqual(viewModel.exerciseCards[0].sets[0].repsText, "8")
        XCTAssertEqual(viewModel.exerciseCards[1].sets.count, 1)
    }

    func testAddSetDuplicatesPreviousWeightAndReps() {
        let viewModel = NewWorkoutViewModel(dataManager: FakeWorkoutDataManager())
        viewModel.addExercises([exercise(id: 1, name: "Bench Press")])
        let cardID = viewModel.exerciseCards[0].id
        let firstSetID = viewModel.exerciseCards[0].sets[0].id

        viewModel.updateWeight(cardID: cardID, setID: firstSetID, value: "80.5")
        viewModel.updateReps(cardID: cardID, setID: firstSetID, value: "8")
        viewModel.addSet(to: cardID)

        let secondSet = viewModel.exerciseCards[0].sets[1]
        XCTAssertEqual(secondSet.setNumber, 2)
        XCTAssertEqual(secondSet.weightText, "80.5")
        XCTAssertEqual(secondSet.repsText, "8")
    }

    func testCanSaveRequiresValidRepsAndWeight() {
        let viewModel = NewWorkoutViewModel(dataManager: FakeWorkoutDataManager())
        viewModel.addExercises([exercise(id: 1, name: "Bench Press")])
        let cardID = viewModel.exerciseCards[0].id
        let setID = viewModel.exerciseCards[0].sets[0].id

        XCTAssertFalse(viewModel.canSave)

        viewModel.updateReps(cardID: cardID, setID: setID, value: "abc")
        XCTAssertFalse(viewModel.canSave)

        viewModel.updateReps(cardID: cardID, setID: setID, value: "8")
        XCTAssertTrue(viewModel.canSave)

        viewModel.updateWeight(cardID: cardID, setID: setID, value: "heavy")
        XCTAssertFalse(viewModel.canSave)

        viewModel.updateWeight(cardID: cardID, setID: setID, value: "80.5")
        XCTAssertTrue(viewModel.canSave)
    }

    func testSaveCreatesSessionThenSets() async {
        let dataManager = FakeWorkoutDataManager()
        let viewModel = NewWorkoutViewModel(dataManager: dataManager)
        viewModel.addExercises([exercise(id: 11, name: "Bench Press")])
        let cardID = viewModel.exerciseCards[0].id
        let firstSetID = viewModel.exerciseCards[0].sets[0].id
        viewModel.updateWeight(cardID: cardID, setID: firstSetID, value: "80.5")
        viewModel.updateReps(cardID: cardID, setID: firstSetID, value: "8")
        viewModel.addSet(to: cardID)

        let secondSetID = viewModel.exerciseCards[0].sets[1].id
        viewModel.updateWeight(cardID: cardID, setID: secondSetID, value: "82.5")
        viewModel.updateReps(cardID: cardID, setID: secondSetID, value: "6")

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(dataManager.callOrder, ["session", "set", "set"])
        XCTAssertEqual(dataManager.createdSessionRequests.first?.session_type, "Strength")
        XCTAssertEqual(dataManager.createdSetRequests.count, 2)
        XCTAssertEqual(dataManager.createdSetRequests.map(\.workout_session_id), [99, 99])
        XCTAssertEqual(dataManager.createdSetRequests.map(\.exercise_id), [11, 11])
        XCTAssertEqual(dataManager.createdSetRequests.map(\.set_number), [1, 2])
        XCTAssertEqual(dataManager.createdSetRequests.map(\.reps), [8, 6])
        XCTAssertEqual(dataManager.createdSetRequests[0].weight, Decimal(string: "80.5"))
        XCTAssertEqual(dataManager.createdSetRequests[1].weight, Decimal(string: "82.5"))
    }

    func testSaveRollsBackSessionWhenSetCreationFails() async {
        let dataManager = FailingWorkoutDataManager()
        let viewModel = NewWorkoutViewModel(dataManager: dataManager)
        viewModel.addExercises([exercise(id: 11, name: "Bench Press")])
        let cardID = viewModel.exerciseCards[0].id
        let firstSetID = viewModel.exerciseCards[0].sets[0].id
        viewModel.updateWeight(cardID: cardID, setID: firstSetID, value: "80.5")
        viewModel.updateReps(cardID: cardID, setID: firstSetID, value: "8")

        let didSave = await viewModel.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(dataManager.createdSessionRequests.count, 1)
        XCTAssertEqual(dataManager.deletedSessionIDs, [99])
        XCTAssertEqual(dataManager.createdSetRequests.count, 0)
    }

    private func exercise(id: Int64, name: String, equipmentName: String = "Barbell") -> ExerciseLibraryItem {
        ExerciseLibraryItem(
            id: id,
            name: name,
            type: .repBased,
            equipmentID: 1,
            equipmentName: equipmentName
        )
    }
}

private class FakeWorkoutDataManager: WorkoutDataManaging {
    var equipment: [Equipment] = []
    var exercises: [Exercise] = []
    var createdSessionRequests: [CreateWorkoutSessionRequest] = []
    var createdSetRequests: [CreateWorkoutSetRequest] = []
    var deletedSessionIDs: [Int64] = []
    var callOrder: [String] = []

    func fetchAllEquipment() async throws -> [Equipment] {
        equipment
    }

    func fetchAllExercises() async throws -> [Exercise] {
        exercises
    }

    func createWorkoutSession(_ request: CreateWorkoutSessionRequest) async throws -> WorkoutSession {
        callOrder.append("session")
        createdSessionRequests.append(request)
        return WorkoutSession(
            id: 99,
            date: Date(),
            start_time: nil,
            end_time: nil,
            session_type: request.session_type,
            notes: request.notes
        )
    }

    func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        callOrder.append("set")
        createdSetRequests.append(request)
        return WorkoutSet(
            id: Int64(createdSetRequests.count),
            workout_session_id: request.workout_session_id,
            exercise_id: request.exercise_id,
            set_number: request.set_number,
            reps: request.reps,
            weight: request.weight,
            superset_group_id: request.superset_group_id
        )
    }

    func deleteWorkoutSession(id: Int64) async throws {
        deletedSessionIDs.append(id)
    }
}

private final class FailingWorkoutDataManager: FakeWorkoutDataManager {
    override func createWorkoutSet(_ request: CreateWorkoutSetRequest) async throws -> WorkoutSet {
        throw URLError(.cannotConnectToHost)
    }
}
