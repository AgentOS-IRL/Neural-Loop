import Combine
import CodexCore
import XCTest
@testable import Neural_Loop

@MainActor
final class AudioTurnCoordinatorTests: XCTestCase {
    func testStartingMicEntersListeningAndWiresTranscriptCommits() async {
        let session = TurnFakeTranscribingSession(permissionState: .authorized)
        let scheduler = TurnFakeCooldownTimerScheduler()
        let transcriptionManager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)
        let client = TurnFakeCodexClient(result: .clarify(text: "Reply"))
        let codexCoordinator = AudioModeCodexCoordinator(model: TurnFakeCodexModel(), codexClient: client)
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: TurnFakeSpeechSynthesizer(),
            interruptionDetectionSession: interruptionSession
        )

        await coordinator.startListening()
        session.emit(.speechDetected)
        session.emit(.update(AudioTranscriptionUpdate(transcript: "hello", isFinal: false)))
        session.emit(.speechEnded)
        scheduler.fireLast()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(coordinator.turnState, .listening)
        XCTAssertEqual(codexCoordinator.conversationFeed.first?.content, "hello")
        XCTAssertEqual(client.converseCallCount, 1)
    }

    func testSpeakableReplyStartsSpeechAndPausesRecording() async {
        let session = TurnFakeTranscribingSession(permissionState: .authorized)
        let scheduler = TurnFakeCooldownTimerScheduler()
        let transcriptionManager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)
        let speech = TurnFakeSpeechSynthesizer()
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let client = TurnFakeCodexClient(result: .clarify(text: "Assistant reply"))
        let codexCoordinator = AudioModeCodexCoordinator(model: TurnFakeCodexModel(), codexClient: client)
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(speech.spokenRequests.map(\.text), ["Assistant reply"])
        XCTAssertFalse(transcriptionManager.isRecording)
        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertEqual(interruptionSession.startCallCount, 1)
        XCTAssertEqual(coordinator.turnState, .speaking(speech.spokenRequests[0].messageID))
    }

    func testNormalSpeechFinishResumesRecordingExactlyOnce() async {
        let session = TurnFakeTranscribingSession(permissionState: .authorized)
        let transcriptionManager = AudioTranscriptionManager(
            session: session,
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let speech = TurnFakeSpeechSynthesizer()
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let codexCoordinator = AudioModeCodexCoordinator(
            model: TurnFakeCodexModel(),
            codexClient: TurnFakeCodexClient(result: .clarify(text: "Reply"))
        )
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()
        speech.finishLast(reason: .finished)
        await Task.yield()

        XCTAssertTrue(transcriptionManager.isRecording)
        XCTAssertEqual(session.startCallCount, 2)
        XCTAssertEqual(interruptionSession.stopCallCount, 1)
        XCTAssertEqual(coordinator.turnState, .listening)

        speech.finishLast(reason: .finished)
        await Task.yield()

        XCTAssertEqual(session.startCallCount, 2)
    }

    func testManualInterruptionStopsSpeechAndResumesListening() async {
        let session = TurnFakeTranscribingSession(permissionState: .authorized)
        let transcriptionManager = AudioTranscriptionManager(
            session: session,
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let speech = TurnFakeSpeechSynthesizer()
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let codexCoordinator = AudioModeCodexCoordinator(
            model: TurnFakeCodexModel(),
            codexClient: TurnFakeCodexClient(result: .clarify(text: "Reply"))
        )
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()

        coordinator.interruptAssistantSpeech()
        await Task.yield()

        XCTAssertEqual(speech.stopReasons, [.interrupted])
        XCTAssertEqual(interruptionSession.stopCallCount, 1)
        XCTAssertTrue(transcriptionManager.isRecording)
        XCTAssertEqual(coordinator.turnState, .listening)
    }

    func testDetectorConfirmationWhileSpeakingInterruptsSpeech() async {
        let transcriptionManager = AudioTranscriptionManager(
            session: TurnFakeTranscribingSession(permissionState: .authorized),
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let speech = TurnFakeSpeechSynthesizer()
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let codexCoordinator = AudioModeCodexCoordinator(
            model: TurnFakeCodexModel(),
            codexClient: TurnFakeCodexClient(result: .clarify(text: "Reply"))
        )
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()

        interruptionSession.emit(.confirmed)
        await Task.yield()

        XCTAssertEqual(speech.stopReasons, [.interrupted])
        XCTAssertEqual(coordinator.turnState, .listening)
    }

    func testDetectorConfirmationWhileListeningIsIgnored() async {
        let speech = TurnFakeSpeechSynthesizer()
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession
        )

        interruptionSession.emit(.confirmed)
        await Task.yield()

        XCTAssertTrue(speech.stopReasons.isEmpty)
        XCTAssertEqual(coordinator.turnState, .idle)
    }

    func testDetectorPossibleEventAloneDoesNotStopTTS() async {
        let transcriptionManager = AudioTranscriptionManager(
            session: TurnFakeTranscribingSession(permissionState: .authorized),
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let speech = TurnFakeSpeechSynthesizer()
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let codexCoordinator = AudioModeCodexCoordinator(
            model: TurnFakeCodexModel(),
            codexClient: TurnFakeCodexClient(result: .clarify(text: "Reply"))
        )
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()

        interruptionSession.emit(.possible)
        await Task.yield()

        XCTAssertTrue(speech.stopReasons.isEmpty)
        XCTAssertEqual(coordinator.turnState, .speaking(speech.spokenRequests[0].messageID))
    }

    func testNormalTTSFinishDisarmsDetection() async {
        let transcriptionManager = AudioTranscriptionManager(
            session: TurnFakeTranscribingSession(permissionState: .authorized),
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let speech = TurnFakeSpeechSynthesizer()
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let codexCoordinator = AudioModeCodexCoordinator(
            model: TurnFakeCodexModel(),
            codexClient: TurnFakeCodexClient(result: .clarify(text: "Reply"))
        )
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()
        speech.finishLast(reason: .finished)
        await Task.yield()

        XCTAssertEqual(interruptionSession.stopCallCount, 1)
        XCTAssertEqual(coordinator.turnState, .listening)
    }

    func testMuteWhileSpeakingDisarmsDetection() async {
        let transcriptionManager = AudioTranscriptionManager(
            session: TurnFakeTranscribingSession(permissionState: .authorized),
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let speech = TurnFakeSpeechSynthesizer()
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let codexCoordinator = AudioModeCodexCoordinator(
            model: TurnFakeCodexModel(),
            codexClient: TurnFakeCodexClient(result: .clarify(text: "Reply"))
        )
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()

        coordinator.setSpeechMuted(true)
        await Task.yield()

        XCTAssertEqual(interruptionSession.stopCallCount, 1)
        XCTAssertEqual(speech.stopReasons, [.muted])
        XCTAssertEqual(coordinator.turnState, .idle)
    }

    func testDetectionSessionStartupFailureDoesNotBreakNormalTTSCompletion() async {
        let transcriptionManager = AudioTranscriptionManager(
            session: TurnFakeTranscribingSession(permissionState: .authorized),
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let speech = TurnFakeSpeechSynthesizer()
        let interruptionSession = TurnFakeFailingInterruptionDetectionSession()
        let codexCoordinator = AudioModeCodexCoordinator(
            model: TurnFakeCodexModel(),
            codexClient: TurnFakeCodexClient(result: .clarify(text: "Reply"))
        )
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()
        speech.finishLast(reason: .finished)
        await Task.yield()

        XCTAssertEqual(interruptionSession.startCallCount, 1)
        XCTAssertEqual(interruptionSession.stopCallCount, 0)
        XCTAssertEqual(coordinator.turnState, .listening)
    }

    func testInterruptedMessageIsNotReplayedOnLaterFeedChanges() async {
        let transcriptionManager = AudioTranscriptionManager(
            session: TurnFakeTranscribingSession(permissionState: .authorized),
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let speech = TurnFakeSpeechSynthesizer()
        let client = TurnFakeCodexClient(results: [
            .clarify(text: "First reply"),
            .clarify(text: "Second reply")
        ])
        let codexCoordinator = AudioModeCodexCoordinator(model: TurnFakeCodexModel(), codexClient: client)
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("first")
        await Task.yield()
        await Task.yield()
        coordinator.interruptAssistantSpeech()
        await Task.yield()

        codexCoordinator.handleCommittedTranscript("second")
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(speech.spokenRequests.map(\.text), ["First reply", "Second reply"])
    }

    func testMutedSpeechDoesNotStartTTS() async {
        let speech = TurnFakeSpeechSynthesizer()
        let codexCoordinator = AudioModeCodexCoordinator(
            model: TurnFakeCodexModel(),
            codexClient: TurnFakeCodexClient(result: .clarify(text: "Muted reply"))
        )
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        _ = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: true
        )

        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(speech.spokenRequests.isEmpty)
    }

    func testResetTearsDownTranscriptionSpeechQueueAndDeliveryState() async {
        let session = TurnFakeTranscribingSession(permissionState: .authorized)
        let transcriptionManager = AudioTranscriptionManager(
            session: session,
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let speech = TurnFakeSpeechSynthesizer()
        let codexCoordinator = AudioModeCodexCoordinator(
            model: TurnFakeCodexModel(),
            codexClient: TurnFakeCodexClient(result: .clarify(text: "Reply"))
        )
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            codexCoordinator: codexCoordinator,
            speechSynthesizer: speech,
            interruptionDetectionSession: interruptionSession,
            isSpeechMuted: false
        )

        await coordinator.startListening()
        codexCoordinator.handleCommittedTranscript("question")
        await Task.yield()
        await Task.yield()

        coordinator.tearDown()

        XCTAssertFalse(transcriptionManager.isRecording)
        XCTAssertNil(transcriptionManager.onCommittedTranscript)
        XCTAssertTrue(codexCoordinator.conversationFeed.isEmpty)
        XCTAssertEqual(speech.resetCallCount, 3)
        XCTAssertEqual(coordinator.turnState, .idle)
    }

    func testTranscriptionUpdatesInvalidateCoordinator() async {
        let session = TurnFakeTranscribingSession(permissionState: .authorized)
        let transcriptionManager = AudioTranscriptionManager(
            session: session,
            cooldownScheduler: TurnFakeCooldownTimerScheduler()
        )
        let interruptionSession = TurnFakeInterruptionDetectionSession()
        let coordinator = AudioTurnCoordinator(
            model: TurnFakeCodexModel(),
            transcriptionManager: transcriptionManager,
            speechSynthesizer: TurnFakeSpeechSynthesizer(),
            interruptionDetectionSession: interruptionSession
        )

        await coordinator.startListening()

        let expectation = expectation(description: "Coordinator should forward child changes")
        let cancellable = coordinator.objectWillChange.sink {
            expectation.fulfill()
        }

        session.emit(.update(AudioTranscriptionUpdate(transcript: "live text", isFinal: false)))

        await fulfillment(of: [expectation], timeout: 1.0)
        _ = cancellable
    }
}

@MainActor
private final class TurnFakeSpeechSynthesizer: AudioModeSpeechSynthesizing {
    private var activeHandler: ((AudioSpeechEvent) -> Void)?
    private var activeRequest: AudioSpeechRequest?
    private(set) var spokenRequests: [AudioSpeechRequest] = []
    private(set) var stopReasons: [AudioSpeechStopReason] = []
    private(set) var resetCallCount = 0

    func speak(_ request: AudioSpeechRequest, onEvent: @escaping (AudioSpeechEvent) -> Void) {
        activeRequest = request
        activeHandler = onEvent
        spokenRequests.append(request)
        onEvent(.started(request))
    }

    func stop(reason: AudioSpeechStopReason) {
        stopReasons.append(reason)
        if let activeRequest {
            activeHandler?(.ended(activeRequest, reason == .interrupted ? .interrupted : .canceled))
        }
        activeRequest = nil
        activeHandler = nil
    }

    func reset() {
        resetCallCount += 1
        activeRequest = nil
        activeHandler = nil
    }

    func finishLast(reason: AudioSpeechEndReason) {
        guard let activeRequest else {
            return
        }

        activeHandler?(.ended(activeRequest, reason))
        self.activeRequest = nil
        activeHandler = nil
    }
}

@MainActor
private final class TurnFakeInterruptionDetectionSession: AudioInterruptionDetectingSession {
    private var activeHandler: ((AudioInterruptionDetectionEvent) -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func currentPermissionState() -> AudioTranscriptionPermissionState {
        .authorized
    }

    func requestPermissions() async -> AudioTranscriptionPermissionState {
        .authorized
    }

    func start(resultHandler: @escaping (AudioInterruptionDetectionEvent) -> Void) async throws {
        startCallCount += 1
        activeHandler = resultHandler
    }

    func stop() {
        stopCallCount += 1
        activeHandler = nil
    }

    func emit(_ event: AudioInterruptionDetectionEvent) {
        activeHandler?(event)
    }
}

@MainActor
private final class TurnFakeFailingInterruptionDetectionSession: AudioInterruptionDetectingSession {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func currentPermissionState() -> AudioTranscriptionPermissionState {
        .authorized
    }

    func requestPermissions() async -> AudioTranscriptionPermissionState {
        .authorized
    }

    func start(resultHandler: @escaping (AudioInterruptionDetectionEvent) -> Void) async throws {
        startCallCount += 1
        throw NSError(domain: "TurnFakeFailingInterruptionDetectionSession", code: 1)
    }

    func stop() {
        stopCallCount += 1
    }
}

private final class TurnFakeCodexClient: AudioModeCodexExecuting {
    private var results: [CodexAction]
    private(set) var converseCallCount = 0

    init(result: CodexAction) {
        self.results = [result]
    }

    init(results: [CodexAction]) {
        self.results = results
    }

    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult {
        converseCallCount += 1
        let action = results.isEmpty ? .clarify(text: "Reply") : results.removeFirst()
        return CodexIntentResult(action: action, state: state)
    }
}

private final class TurnFakeCodexModel: AudioModeCodexModel {
    var llm_enabled = true
    var codexAccessToken: String? = "token"
    var codexAccountID: String? = "account"

    func getTask(by id: Int64) -> Tasks? {
        nil
    }

    func saveTask(_ task: Tasks) async -> Tasks? {
        task
    }

    func addSubTask(_ title: String, taskId: Int64) async -> SubTasks? {
        nil
    }

    func saveFleetingNote(_ request: CreateFleetingNoteRequest) async -> FleetingNote? {
        nil
    }
}

private final class TurnFakeTranscribingSession: AudioTranscribingSession {
    private(set) var requestPermissionsCallCount = 0
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var rolloverSegmentCallCount = 0
    private let permissionState: AudioTranscriptionPermissionState
    private var resultHandler: ((AudioTranscriptionEvent) -> Void)?

    init(permissionState: AudioTranscriptionPermissionState) {
        self.permissionState = permissionState
    }

    func currentPermissionState() -> AudioTranscriptionPermissionState {
        permissionState
    }

    func requestPermissions() async -> AudioTranscriptionPermissionState {
        requestPermissionsCallCount += 1
        return permissionState
    }

    func start(
        onDeviceRecognition: Bool,
        resultHandler: @escaping (AudioTranscriptionEvent) -> Void
    ) async throws {
        startCallCount += 1
        self.resultHandler = resultHandler
    }

    func rolloverSegment() {
        rolloverSegmentCallCount += 1
    }

    func stop() {
        stopCallCount += 1
        resultHandler = nil
    }

    func emit(_ event: AudioTranscriptionEvent) {
        resultHandler?(event)
    }
}

private final class TurnFakeCooldownTimerScheduler: AudioCooldownTimerScheduling {
    private var lastHandler: (() -> Void)?

    func schedule(after delay: TimeInterval, _ handler: @escaping () -> Void) -> any AudioCooldownTimerControlling {
        lastHandler = handler
        return TurnFakeCooldownTimerToken()
    }

    func fireLast() {
        lastHandler?()
    }
}

private final class TurnFakeCooldownTimerToken: AudioCooldownTimerControlling {
    func cancel() {}
}
