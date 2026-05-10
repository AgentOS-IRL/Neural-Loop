import AppIntents
import XCTest
import CodexCore
@testable import Neural_Loop

@MainActor
final class WorkoutSiriUpdateIntentTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WorkoutSiriUpdateIntentTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testShortcutMetadataExposesSiriPhrases() {
        let shortcuts = WorkoutAppShortcutsProvider.appShortcuts
        XCTAssertEqual(shortcuts.count, 1)

        let shortcut = shortcuts[0]
        XCTAssertTrue(String(describing: shortcut.shortTitle).contains("Update Workout"))
        XCTAssertEqual(String(describing: shortcut.systemImageName), "dumbbell.fill")

        let phrases = shortcut.phrases.map { String(describing: $0) }
        XCTAssertTrue(phrases.contains(where: { $0.contains("Take a workout note") }))
        XCTAssertTrue(phrases.contains(where: { $0.contains("Log my workout") }))
        XCTAssertTrue(phrases.contains(where: { $0.contains("Record a workout") }))
        XCTAssertTrue(phrases.contains(where: { $0.contains("Update my workout") }))
    }

    func testIntentMetadataDescribesTheWorkoutFlow() {
        XCTAssertTrue(String(describing: UpdateWorkoutSetIntent.title).contains("Update Workout Set"))
        XCTAssertTrue(String(describing: UpdateWorkoutSetIntent.description).contains("active workout session"))
        XCTAssertFalse(String(describing: UpdateWorkoutSetIntent.parameterSummary).isEmpty)
    }

    func testRepBasedWorkoutUpdateAppliesToFirstIncompleteSet() async {
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        let model = FakeWorkoutSiriCodexModel(
            llmEnabled: true,
            codexAccessToken: "token",
            codexAccountID: "account"
        )
        let client = FakeWorkoutSiriCodexClient(
            result: .callTool(
                name: "update_set",
                arguments: [
                    "weight": 100,
                    "reps": 5
                ]
            )
        )
        let connectivity = FakeWorkoutConnectivityProvider()
        let liveActivity = FakeWorkoutLiveActivityUpdater()

        let draft = makeWorkoutDraft(
            sessionType: "Push Day",
            exercises: [
                workoutExercise(
                    id: 10,
                    name: "Bench Press",
                    type: .repBased,
                    sets: [
                        workoutSet(number: 1, weightText: "90", repsText: "8", isCompleted: true)
                    ]
                ),
                workoutExercise(
                    id: 20,
                    name: "Incline Press",
                    type: .repBased,
                    sets: [
                        workoutSet(number: 1, weightText: "", repsText: "", isCompleted: false),
                        workoutSet(number: 2, weightText: "", repsText: "", isCompleted: false)
                    ]
                )
            ]
        )
        persistenceManager.save(draft: draft)
        persistenceManager.saveActiveSessionPointer(draft.watchSessionPointer)

        let service = WorkoutSiriUpdateService(
            model: model,
            persistenceManager: persistenceManager,
            connectivityProvider: connectivity,
            liveActivityUpdater: liveActivity,
            codexClient: client
        )

        let outcome = await service.updateWorkout(note: "Set it to 100 for 5 reps")

        guard case .updated(let text) = outcome else {
            return XCTFail("Expected an update outcome")
        }

        XCTAssertEqual(text, "Updated set 1 with 100 kg, 5 reps.")
        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertEqual(client.capturedTools.count, 1)
        XCTAssertEqual(client.capturedTools.first?.name, "update_set")
        XCTAssertEqual(client.capturedToolChoices.count, 1)
        if case .object(let choice) = client.capturedToolChoices.first {
            XCTAssertEqual(choice["type"], .string("function"))
            XCTAssertEqual(choice["name"], .string("update_set"))
        } else {
            XCTFail("Expected a forced function tool choice")
        }
        XCTAssertEqual(connectivity.snapshotCount, 1)
        XCTAssertEqual(liveActivity.updateCount, 1)

        let saved = persistenceManager.load(routineID: draft.routineID)
        XCTAssertEqual(saved?.revision, 1)
        XCTAssertEqual(saved?.exercises[0].sets[0].weightText, "90")
        XCTAssertEqual(saved?.exercises[0].sets[0].repsText, "8")
        XCTAssertEqual(saved?.exercises[1].sets[0].weightText, "100")
        XCTAssertEqual(saved?.exercises[1].sets[0].repsText, "5")
        XCTAssertEqual(saved?.exercises[1].sets[1].weightText, "")
        XCTAssertEqual(saved?.exercises[1].sets[1].repsText, "")
    }

    func testCardioWorkoutUpdateAppliesDistanceDurationAndCalories() async {
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        let model = FakeWorkoutSiriCodexModel(
            llmEnabled: true,
            codexAccessToken: "token",
            codexAccountID: "account"
        )
        let client = FakeWorkoutSiriCodexClient(
            result: .callTool(
                name: "update_set",
                arguments: [
                    "distance_meters": 5250,
                    "duration_minutes": 27,
                    "calories": 180
                ]
            )
        )
        let connectivity = FakeWorkoutConnectivityProvider()
        let liveActivity = FakeWorkoutLiveActivityUpdater()

        let draft = makeWorkoutDraft(
            sessionType: "Cardio",
            exercises: [
                workoutExercise(
                    id: 10,
                    name: "Run Warmup",
                    type: .duration,
                    sets: [
                        workoutSet(number: 1, durationText: "10", distanceText: "2", caloriesText: "50", isCompleted: true)
                    ]
                ),
                workoutExercise(
                    id: 20,
                    name: "Treadmill",
                    type: .duration,
                    sets: [
                        workoutSet(number: 1, durationText: "", distanceText: "", caloriesText: "", isCompleted: false)
                    ]
                )
            ]
        )
        persistenceManager.save(draft: draft)
        persistenceManager.saveActiveSessionPointer(draft.watchSessionPointer)

        let service = WorkoutSiriUpdateService(
            model: model,
            persistenceManager: persistenceManager,
            connectivityProvider: connectivity,
            liveActivityUpdater: liveActivity,
            codexClient: client
        )

        let outcome = await service.updateWorkout(note: "I ran 5.25 km in 27 minutes for 180 calories")

        guard case .updated(let text) = outcome else {
            return XCTFail("Expected an update outcome")
        }

        XCTAssertEqual(text, "Updated set 1 with 5.25 km, 27 minutes, 180 calories.")
        XCTAssertEqual(client.capturedTools.first?.name, "update_set")
        XCTAssertEqual(client.capturedToolChoices.count, 1)
        XCTAssertEqual(persistenceManager.load(routineID: draft.routineID)?.exercises[1].sets[0].distanceText, "5.25")
        XCTAssertEqual(persistenceManager.load(routineID: draft.routineID)?.exercises[1].sets[0].durationText, "27")
        XCTAssertEqual(persistenceManager.load(routineID: draft.routineID)?.exercises[1].sets[0].caloriesText, "180")
        XCTAssertEqual(connectivity.snapshotCount, 1)
        XCTAssertEqual(liveActivity.updateCount, 1)
    }

    func testClarificationResponseIsReturnedWhenNoToolCallIsEmitted() async {
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        let model = FakeWorkoutSiriCodexModel(
            llmEnabled: true,
            codexAccessToken: "token",
            codexAccountID: "account"
        )
        let client = FakeWorkoutSiriCodexClient(
            result: .clarify(text: "Which set should I update?")
        )
        let connectivity = FakeWorkoutConnectivityProvider()
        let liveActivity = FakeWorkoutLiveActivityUpdater()

        let draft = makeWorkoutDraft(
            sessionType: "Push Day",
            exercises: [
                workoutExercise(
                    id: 20,
                    name: "Incline Press",
                    type: .repBased,
                    sets: [
                        workoutSet(number: 1, weightText: "", repsText: "", isCompleted: false)
                    ]
                )
            ]
        )
        persistenceManager.save(draft: draft)
        persistenceManager.saveActiveSessionPointer(draft.watchSessionPointer)

        let service = WorkoutSiriUpdateService(
            model: model,
            persistenceManager: persistenceManager,
            connectivityProvider: connectivity,
            liveActivityUpdater: liveActivity,
            codexClient: client
        )

        let outcome = await service.updateWorkout(note: "set it higher")

        guard case .clarify(let text) = outcome else {
            return XCTFail("Expected a clarification outcome")
        }

        XCTAssertEqual(text, "Which set should I update?")
        XCTAssertEqual(client.capturedToolChoices.count, 1)
        XCTAssertEqual(connectivity.snapshotCount, 0)
        XCTAssertEqual(liveActivity.updateCount, 0)

        let saved = persistenceManager.load(routineID: draft.routineID)
        XCTAssertEqual(saved?.exercises[0].sets[0].weightText, "")
        XCTAssertEqual(saved?.exercises[0].sets[0].repsText, "")
    }

    func testNoActiveSessionReturnsClearResponse() async {
        let persistenceManager = WorkoutDraftPersistenceManager(userDefaults: userDefaults)
        let model = FakeWorkoutSiriCodexModel(
            llmEnabled: true,
            codexAccessToken: "token",
            codexAccountID: "account"
        )
        let client = FakeWorkoutSiriCodexClient(
            result: .clarify(text: "Should I update the first set?")
        )
        let service = WorkoutSiriUpdateService(
            model: model,
            persistenceManager: persistenceManager,
            connectivityProvider: FakeWorkoutConnectivityProvider(),
            liveActivityUpdater: FakeWorkoutLiveActivityUpdater(),
            codexClient: client
        )

        let outcome = await service.updateWorkout(note: "set it to 100")

        guard case .noActiveSession(let text) = outcome else {
            return XCTFail("Expected a no-active-session outcome")
        }

        XCTAssertEqual(text, "I can't find an active workout session. Start one first.")
        XCTAssertEqual(client.converseCallCount, 0)
    }

    private func makeWorkoutDraft(
        sessionType: String,
        exercises: [WorkoutExerciseCardState]
    ) -> ActiveWorkoutDraft {
        ActiveWorkoutDraft(
            routineID: 101,
            session: WorkoutSession(
                id: 202,
                date: Date(),
                start_time: nil,
                end_time: nil,
                session_type: sessionType,
                notes: nil
            ),
            exercises: exercises
        )
    }

    private func workoutExercise(
        id: Int64,
        name: String,
        type: ExerciseType,
        sets: [WorkoutSetDraft]
    ) -> WorkoutExerciseCardState {
        WorkoutExerciseCardState(
            id: id,
            exercise: ExerciseLibraryItem(
                id: id,
                name: name,
                type: type,
                equipmentID: nil,
                equipmentName: "None"
            ),
            sets: sets
        )
    }

    private func workoutSet(
        number: Int,
        weightText: String = "",
        repsText: String = "",
        durationText: String = "",
        distanceText: String = "",
        caloriesText: String = "",
        isCompleted: Bool
    ) -> WorkoutSetDraft {
        WorkoutSetDraft(
            setNumber: number,
            weightText: weightText,
            repsText: repsText,
            durationText: durationText,
            distanceText: distanceText,
            caloriesText: caloriesText,
            isCompleted: isCompleted
        )
    }
}

@MainActor
private final class FakeWorkoutSiriCodexModel: WorkoutSiriCodexModel {
    let llm_enabled: Bool
    let codexAccessToken: String?
    let codexAccountID: String?

    init(llmEnabled: Bool, codexAccessToken: String?, codexAccountID: String?) {
        self.llm_enabled = llmEnabled
        self.codexAccessToken = codexAccessToken
        self.codexAccountID = codexAccountID
    }

    func validCodexCredentials() async -> CodexCredentials? {
        guard let codexAccessToken,
              let codexAccountID else {
            return nil
        }

        return CodexCredentials(accessToken: codexAccessToken, accountID: codexAccountID)
    }
}

private final class FakeWorkoutSiriCodexClient: WorkoutSiriCodexExecuting {
    let result: CodexIntentResult
    private(set) var converseCallCount = 0
    private(set) var capturedMessages: [[CodexInputMessage]] = []
    private(set) var capturedTools: [CodexTool] = []
    private(set) var capturedInstructions: [String] = []
    private(set) var capturedToolChoices: [JSONValue] = []

    init(result: CodexIntentResult) {
        self.result = result
    }

    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String,
        toolChoice: JSONValue
    ) async throws -> CodexIntentResult {
        converseCallCount += 1
        capturedMessages.append(messages)
        capturedTools = tools
        capturedInstructions.append(instructions)
        capturedToolChoices.append(toolChoice)
        return result
    }
}

private final class FakeWorkoutConnectivityProvider: WorkoutConnectivityProviding {
    private(set) var snapshotCount = 0

    func sendWorkoutSnapshot(_ snapshot: ActiveWorkoutSnapshot, completion: ((Result<Void, Error>) -> Void)?) {
        snapshotCount += 1
        completion?(.success(()))
    }

    func sendWorkoutAction(_ action: WorkoutWatchAction, completion: ((Result<Void, Error>) -> Void)?) {
        completion?(.success(()))
    }

    func sendWorkoutFinalizedResult(_ result: WorkoutFinalizedResult, completion: ((Result<Void, Error>) -> Void)?) {
        completion?(.success(()))
    }

    func clearWorkoutSnapshot(sessionID: String, reason: ClearReason) {}
}

private final class FakeWorkoutLiveActivityUpdater: WorkoutSiriLiveActivityUpdating {
    private(set) var updateCount = 0

    func update(snapshot: ActiveWorkoutSnapshot) {
        updateCount += 1
    }
}
