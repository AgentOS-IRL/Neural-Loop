import XCTest
import CodexCore
@testable import Neural_Loop

@MainActor
final class WorkoutRoutineGenerationCodexCoordinatorTests: XCTestCase {
    func testToolCallReturnsFilteredRoutinePayload() async {
        let dataManager = FakeWorkoutRoutineGenerationDataManager(
            equipment: [
                equipment(id: 1, name: "Barbell"),
                equipment(id: 2, name: "Cable")
            ],
            exercises: [
                exercise(id: 10, name: "Bench Press", equipmentID: 1),
                exercise(id: 20, name: "Cable Row", equipmentID: 2)
            ]
        )
        let client = FakeWorkoutRoutineGenerationCodexClient(
            result: .callTool(
                name: "generate_workout_routine",
                arguments: [
                    "routine_name": "Push Day",
                    "notes": "Upper body focus",
                    "exercises": [
                        [
                            "name": "Bench Press",
                            "equipment": "Barbell"
                        ],
                        [
                            "name": "Bench Press",
                            "equipment": "Dumbbell"
                        ],
                        [
                            "name": "Cable Row",
                            "equipment": "Cable"
                        ]
                    ]
                ]
            )
        )
        let coordinator = WorkoutRoutineGenerationCodexCoordinator(
            model: FakeWorkoutRoutineGenerationCodexModel(),
            dataManager: dataManager,
            codexClient: client
        )

        let result = await coordinator.generateRoutine(prompt: "Build me a push day")

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(result?.routineName, "Push Day")
        XCTAssertEqual(result?.notes, "Upper body focus")
        XCTAssertEqual(result?.exercises.map { $0.name }, ["Bench Press", "Cable Row"])
        XCTAssertEqual(result?.exercises.map { $0.equipment }, ["Barbell", "Cable"])
        XCTAssertNil(coordinator.errorMessage)
        XCTAssertNil(coordinator.statusMessage)
    }

    func testMalformedToolArgumentsAreRejectedWithReadableError() async {
        let dataManager = FakeWorkoutRoutineGenerationDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [exercise(id: 10, name: "Bench Press", equipmentID: 1)]
        )
        let client = FakeWorkoutRoutineGenerationCodexClient(
            result: .callTool(
                name: "generate_workout_routine",
                arguments: [
                    "routine_name": "Push Day",
                    "notes": "Upper body focus",
                    "exercises": [
                        [
                            "name": 123,
                            "equipment": "Barbell"
                        ]
                    ]
                ]
            )
        )
        let coordinator = WorkoutRoutineGenerationCodexCoordinator(
            model: FakeWorkoutRoutineGenerationCodexModel(),
            dataManager: dataManager,
            codexClient: client
        )

        let result = await coordinator.generateRoutine(prompt: "Build me a push day")

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertNil(result)
        XCTAssertEqual(coordinator.errorMessage, "Codex returned an invalid workout routine payload.")
        XCTAssertNil(coordinator.statusMessage)
    }

    func testUnexpectedToolNameDoesNotProduceRoutine() async {
        let dataManager = FakeWorkoutRoutineGenerationDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [exercise(id: 10, name: "Bench Press", equipmentID: 1)]
        )
        let client = FakeWorkoutRoutineGenerationCodexClient(
            result: .callTool(
                name: "create_task",
                arguments: [
                    "title": "Not a routine"
                ]
            )
        )
        let coordinator = WorkoutRoutineGenerationCodexCoordinator(
            model: FakeWorkoutRoutineGenerationCodexModel(),
            dataManager: dataManager,
            codexClient: client
        )

        let result = await coordinator.generateRoutine(prompt: "Build me a push day")

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertNil(result)
        XCTAssertEqual(coordinator.errorMessage, "Unexpected Codex tool call: create_task")
        XCTAssertNil(coordinator.statusMessage)
    }

    func testClarificationResponseDoesNotProduceRoutine() async {
        let dataManager = FakeWorkoutRoutineGenerationDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [exercise(id: 10, name: "Bench Press", equipmentID: 1)]
        )
        let client = FakeWorkoutRoutineGenerationCodexClient(
            result: .clarify(text: "Do you want a push, pull, or full-body routine?")
        )
        let coordinator = WorkoutRoutineGenerationCodexCoordinator(
            model: FakeWorkoutRoutineGenerationCodexModel(),
            dataManager: dataManager,
            codexClient: client
        )

        let result = await coordinator.generateRoutine(prompt: "Build me a routine")

        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertNil(result)
        XCTAssertEqual(coordinator.errorMessage, "Do you want a push, pull, or full-body routine?")
        XCTAssertNil(coordinator.statusMessage)
    }

    private func equipment(id: Int64, name: String) -> Equipment {
        Equipment(id: id, name: name)
    }

    private func exercise(id: Int64, name: String, equipmentID: Int64?) -> Exercise {
        Exercise(id: id, name: name, type: .repBased, equipment_id: equipmentID, notes: nil)
    }
}

private final class FakeWorkoutRoutineGenerationCodexModel: WorkoutRoutineGenerationCodexModel {
    var llm_enabled: Bool = true
    var codexAccessToken: String? = "token"
    var codexAccountID: String? = "account"
}

private final class FakeWorkoutRoutineGenerationCodexClient: WorkoutRoutineGenerationCodexExecuting {
    private let result: CodexAction
    private(set) var converseCallCount = 0

    init(result: CodexAction) {
        self.result = result
    }

    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult {
        _ = messages
        _ = state
        _ = tools
        _ = instructions
        converseCallCount += 1
        return CodexIntentResult(action: result, state: state)
    }
}

private final class FakeWorkoutRoutineGenerationDataManager: WorkoutTemplateReadingDataManaging {
    let equipment: [Equipment]
    let exercises: [Exercise]

    init(equipment: [Equipment], exercises: [Exercise]) {
        self.equipment = equipment
        self.exercises = exercises
    }

    func fetchAllEquipment() async throws -> [Equipment] {
        equipment
    }

    func fetchAllExercises() async throws -> [Exercise] {
        exercises
    }

    func fetchRoutine(by id: Int64) async throws -> Routine? {
        nil
    }

    func fetchAllRoutines() async throws -> [Routine] {
        []
    }

    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] {
        []
    }
}
