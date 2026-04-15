import AVFoundation
import Speech
import XCTest
@testable import Neural_Loop

@MainActor
final class AudioTranscriptionTests: XCTestCase {
    func testStartRecordingRequestsPermissionsAndBeginsSession() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let manager = AudioTranscriptionManager(session: session)

        await manager.startRecording()

        XCTAssertEqual(session.requestPermissionsCallCount, 1)
        XCTAssertEqual(session.startCallCount, 1)
        XCTAssertTrue(manager.isRecording)
        XCTAssertEqual(manager.permissionState, .authorized)
        XCTAssertEqual(manager.promptText, "Listening...")
    }

    func testDeniedPermissionPreventsStartAndSurfacesExplanation() async {
        let session = FakeTranscribingSession(permissionState: .microphoneDenied)
        let manager = AudioTranscriptionManager(session: session)

        await manager.startRecording()

        XCTAssertEqual(session.requestPermissionsCallCount, 1)
        XCTAssertEqual(session.startCallCount, 0)
        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(manager.permissionState, .microphoneDenied)
        XCTAssertEqual(manager.promptText, "Microphone access is required to record speech.")
        XCTAssertTrue(manager.isActionDisabled)
    }

    func testPartialRecognitionUpdatesTranscriptString() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let manager = AudioTranscriptionManager(session: session)

        await manager.startRecording()
        session.emit(.update(AudioTranscriptionUpdate(transcript: "hello", isFinal: false)))
        await Task.yield()

        XCTAssertEqual(manager.transcriptText, "hello")
        XCTAssertFalse(manager.isTranscriptFinal)
        XCTAssertEqual(manager.promptText, "Listening...")
    }

    func testFinalRecognitionMarksTranscriptAsCompleteAndStopsSession() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let manager = AudioTranscriptionManager(session: session)

        await manager.startRecording()
        session.emit(.update(AudioTranscriptionUpdate(transcript: "hello world", isFinal: true)))
        await Task.yield()

        XCTAssertEqual(manager.transcriptText, "hello world")
        XCTAssertTrue(manager.isTranscriptFinal)
        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertEqual(manager.promptText, "Transcript ready.")
    }

    func testManualStopTearsDownRunningSessionButKeepsTranscriptVisible() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let manager = AudioTranscriptionManager(session: session)

        await manager.startRecording()
        session.emit(.update(AudioTranscriptionUpdate(transcript: "keep this text", isFinal: false)))
        await Task.yield()

        manager.stopRecording()

        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(manager.transcriptText, "keep this text")
    }

    func testLiveSessionStopsEngineTapRequestAndTask() async throws {
        let audioSession = FakeAudioSession(recordPermission: .granted)
        let engine = FakeAudioEngine()
        let speechAuthorization = FakeSpeechAuthorization(status: .authorized)
        let recognizer = FakeSpeechRecognizer(isAvailable: true)
        let session = LiveAudioTranscriptionSession(
            audioSession: audioSession,
            audioEngine: engine,
            speechAuthorization: speechAuthorization,
            recognizerFactory: { recognizer }
        )

        let permission = await session.requestPermissions()
        XCTAssertEqual(permission, .authorized)

        try await session.start(onDeviceRecognition: true) { _ in }
        session.stop()

        XCTAssertEqual(audioSession.setCategoryCallCount, 1)
        XCTAssertEqual(audioSession.setActiveValues, [true, false])
        XCTAssertEqual(engine.prepareCallCount, 1)
        XCTAssertEqual(engine.startCallCount, 1)
        XCTAssertEqual(engine.stopCallCount, 1)
        XCTAssertEqual(engine.inputNodeBox.installTapCallCount, 1)
        XCTAssertEqual(engine.inputNodeBox.removeTapCallCount, 1)
        XCTAssertEqual(recognizer.recognitionTaskCallCount, 1)
        XCTAssertEqual(recognizer.task.cancelCallCount, 1)
        XCTAssertEqual(recognizer.capturedRequest?.shouldReportPartialResults, true)
        XCTAssertEqual(recognizer.capturedRequest?.requiresOnDeviceRecognition, true)
        XCTAssertEqual((recognizer.capturedRequest as? LiveSpeechRecognitionRequestAdapter)?.endAudioCallCount, 1)
    }
}

@MainActor
private final class FakeTranscribingSession: AudioTranscribingSession {
    var permissionState: AudioTranscriptionPermissionState
    var requestPermissionsCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0
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

    func stop() {
        stopCallCount += 1
        resultHandler = nil
    }

    func emit(_ event: AudioTranscriptionEvent) {
        resultHandler?(event)
    }
}

private final class FakeAudioSession: AudioSessionControlling {
    var recordPermission: AVAudioSession.RecordPermission
    var setCategoryCallCount = 0
    var setActiveValues: [Bool] = []

    init(recordPermission: AVAudioSession.RecordPermission) {
        self.recordPermission = recordPermission
    }

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        setCategoryCallCount += 1
    }

    func setActive(_ active: Bool) throws {
        setActiveValues.append(active)
    }

    func requestRecordPermission() async -> Bool {
        recordPermission == .granted
    }
}

private final class FakeAudioEngine: AudioEngineControlling {
    let inputNodeBox = FakeAudioInputNode()
    var inputNode: any AudioInputNodeControlling { inputNodeBox }
    var prepareCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0

    func prepare() {
        prepareCallCount += 1
    }

    func start() throws {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }
}

private final class FakeAudioInputNode: AudioInputNodeControlling {
    var installTapCallCount = 0
    var removeTapCallCount = 0
    private(set) var installedBlock: ((AVAudioPCMBuffer, AVAudioTime?) -> Void)?

    func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    }

    func installTap(
        onBus bus: AVAudioNodeBus,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping (AVAudioPCMBuffer, AVAudioTime?) -> Void
    ) {
        installTapCallCount += 1
        installedBlock = block
    }

    func removeTap(onBus bus: AVAudioNodeBus) {
        removeTapCallCount += 1
        installedBlock = nil
    }
}

private final class FakeSpeechRecognizer: SpeechRecognizerControlling {
    let isAvailable: Bool
    let task = FakeSpeechRecognitionTask()
    var recognitionTaskCallCount = 0
    private(set) var capturedRequest: (any SpeechRecognitionRequestControlling)?

    init(isAvailable: Bool) {
        self.isAvailable = isAvailable
    }

    func recognitionTask(
        with request: any SpeechRecognitionRequestControlling,
        resultHandler: @escaping (SpeechRecognitionResult?, Error?) -> Void
    ) -> (any SpeechRecognitionTaskControlling)? {
        recognitionTaskCallCount += 1
        capturedRequest = request
        task.resultHandler = resultHandler
        return task
    }
}

private final class FakeSpeechRecognitionTask: SpeechRecognitionTaskControlling {
    var cancelCallCount = 0
    var resultHandler: ((SpeechRecognitionResult?, Error?) -> Void)?

    func cancel() {
        cancelCallCount += 1
    }
}

private final class FakeSpeechAuthorization: SpeechAuthorizationControlling {
    let status: SFSpeechRecognizerAuthorizationStatus

    init(status: SFSpeechRecognizerAuthorizationStatus) {
        self.status = status
    }

    func currentAuthorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        status
    }
}
