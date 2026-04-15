import AVFoundation
import Speech
import XCTest
@testable import Neural_Loop

@MainActor
final class AudioTranscriptionTests: XCTestCase {
    func testStartRecordingRequestsPermissionsAndBeginsSession() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()

        XCTAssertEqual(session.requestPermissionsCallCount, 1)
        XCTAssertEqual(session.startCallCount, 1)
        XCTAssertEqual(manager.sessionState, .listening)
        XCTAssertTrue(manager.isRecording)
        XCTAssertEqual(manager.permissionState, .authorized)
        XCTAssertEqual(manager.promptText, "Listening for speech...")
    }

    func testStartRecordingClearsPreviousTranscriptBeforeNewSession() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()
        session.emit(.speechDetected)
        session.emit(.update(AudioTranscriptionUpdate(transcript: "first pass", isFinal: false)))

        manager.stopRecording()
        XCTAssertEqual(manager.transcriptText, "first pass")
        XCTAssertTrue(manager.isTranscriptFinal)

        await manager.startRecording()

        XCTAssertEqual(manager.transcriptText, "")
        XCTAssertEqual(manager.transcriptCardText, "Listening for speech...")
        XCTAssertEqual(session.requestPermissionsCallCount, 2)
    }

    func testDeniedPermissionPreventsStartAndSurfacesExplanation() async {
        let session = FakeTranscribingSession(permissionState: .microphoneDenied)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()

        XCTAssertEqual(session.requestPermissionsCallCount, 1)
        XCTAssertEqual(session.startCallCount, 0)
        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(manager.permissionState, .microphoneDenied)
        XCTAssertEqual(manager.promptText, "Microphone access is required to record speech.")
        XCTAssertTrue(manager.isActionDisabled)
    }

    func testTranscriptCardTextPrioritizesErrorsOverStaleTranscript() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()
        session.emit(.speechDetected)
        session.emit(.update(AudioTranscriptionUpdate(transcript: "old transcript", isFinal: false)))

        XCTAssertEqual(manager.transcriptCardText, "old transcript")

        session.emit(.failure("Speech recognition access is required to transcribe text."))

        XCTAssertEqual(
            manager.transcriptCardText,
            "Speech recognition access is required to transcribe text."
        )
    }

    func testPartialRecognitionUpdatesTranscriptString() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()
        session.emit(.speechDetected)
        session.emit(.update(AudioTranscriptionUpdate(transcript: "hello", isFinal: false)))

        XCTAssertEqual(manager.transcriptText, "hello")
        XCTAssertFalse(manager.isTranscriptFinal)
        XCTAssertEqual(manager.sessionState, .transcribing)
        XCTAssertEqual(manager.promptText, "Transcribing speech...")
    }

    func testSpeechDetectedCancelsCooldownAndStartsTranscribing() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()
        session.emit(.speechDetected)
        session.emit(.speechEnded)

        XCTAssertEqual(manager.sessionState, .cooldownPending)
        XCTAssertEqual(scheduler.scheduleCallCount, 1)
        XCTAssertFalse(scheduler.lastToken?.isCancelled ?? true)

        session.emit(.speechDetected)

        XCTAssertEqual(manager.sessionState, .transcribing)
        XCTAssertEqual(scheduler.cancelCallCount, 1)
        XCTAssertTrue(scheduler.lastToken?.isCancelled ?? false)
    }

    func testSpeechEndedStartsFiveSecondCooldownBeforeStopping() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()
        session.emit(.speechDetected)
        session.emit(.update(AudioTranscriptionUpdate(transcript: "hello world", isFinal: false)))
        session.emit(.speechEnded)

        XCTAssertEqual(manager.sessionState, .cooldownPending)
        XCTAssertEqual(scheduler.scheduleCallCount, 1)
        XCTAssertEqual(session.stopCallCount, 0)

        scheduler.fireLast()
        await Task.yield()

        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertEqual(manager.sessionState, .inactive)
        XCTAssertFalse(manager.isRecording)
        XCTAssertTrue(manager.isTranscriptFinal)
        XCTAssertEqual(manager.transcriptText, "hello world")
    }

    func testSpeechDetectedDuringCooldownKeepsSessionAlive() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()
        session.emit(.speechDetected)
        session.emit(.speechEnded)
        XCTAssertEqual(manager.sessionState, .cooldownPending)

        session.emit(.speechDetected)

        XCTAssertEqual(manager.sessionState, .transcribing)
        XCTAssertEqual(scheduler.cancelCallCount, 1)
        XCTAssertEqual(session.stopCallCount, 0)

        scheduler.fireLast()
        XCTAssertEqual(session.stopCallCount, 0)
    }

    func testFinalRecognitionDoesNotStopSessionImmediately() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()
        session.emit(.speechDetected)
        session.emit(.update(AudioTranscriptionUpdate(transcript: "hello world", isFinal: true)))

        XCTAssertEqual(manager.transcriptText, "hello world")
        XCTAssertFalse(manager.isTranscriptFinal)
        XCTAssertEqual(manager.sessionState, .transcribing)
        XCTAssertEqual(session.stopCallCount, 0)

        session.emit(.speechEnded)
        scheduler.fireLast()
        await Task.yield()

        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertTrue(manager.isTranscriptFinal)
        XCTAssertEqual(manager.sessionState, .inactive)
    }

    func testManualStopTearsDownRunningSessionButKeepsTranscriptVisible() async {
        let session = FakeTranscribingSession(permissionState: .authorized)
        let scheduler = FakeCooldownTimerScheduler()
        let manager = AudioTranscriptionManager(session: session, cooldownScheduler: scheduler)

        await manager.startRecording()
        session.emit(.speechDetected)
        session.emit(.update(AudioTranscriptionUpdate(transcript: "keep this text", isFinal: false)))

        manager.stopRecording()

        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(manager.sessionState, .inactive)
        XCTAssertEqual(manager.transcriptText, "keep this text")
        XCTAssertTrue(manager.isTranscriptFinal)
    }

    func testLiveSessionStartsRecognitionOnlyAfterSpeechDetected() async throws {
        let audioSession = FakeAudioSession(recordPermission: .granted)
        let engine = FakeAudioEngine()
        let speechAuthorization = FakeSpeechAuthorization(status: .authorized)
        let recognizer = FakeSpeechRecognizer(isAvailable: true)
        let detector = FakeSpeechDetector()
        let session = LiveAudioTranscriptionSession(
            audioSession: audioSession,
            audioEngine: engine,
            speechAuthorization: speechAuthorization,
            recognizerFactory: { recognizer },
            detector: detector
        )

        let permission = await session.requestPermissions()
        XCTAssertEqual(permission, .authorized)

        try await session.start(onDeviceRecognition: true) { _ in }
        XCTAssertEqual(recognizer.recognitionTaskCallCount, 0)

        detector.emitSpeechDetected()
        XCTAssertEqual(recognizer.recognitionTaskCallCount, 1)

        let buffer = makeBuffer(amplitude: 0.4)
        engine.inputNodeBox.installedBlock?(buffer, nil)

        XCTAssertEqual(
            (recognizer.capturedRequest as? LiveSpeechRecognitionRequestAdapter)?.appendCallCount,
            1
        )

        session.stop()

        XCTAssertEqual(audioSession.setCategoryCallCount, 1)
        XCTAssertEqual(audioSession.setActiveValues, [true, false])
        XCTAssertEqual(engine.prepareCallCount, 1)
        XCTAssertEqual(engine.startCallCount, 1)
        XCTAssertEqual(engine.stopCallCount, 1)
        XCTAssertEqual(engine.inputNodeBox.installTapCallCount, 1)
        XCTAssertEqual(engine.inputNodeBox.removeTapCallCount, 1)
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

private final class FakeCooldownTimerScheduler: AudioCooldownTimerScheduling {
    private(set) var scheduleCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var tokens: [FakeCooldownTimerToken] = []

    var lastToken: FakeCooldownTimerToken? {
        tokens.last
    }

    func schedule(after delay: TimeInterval, _ handler: @escaping () -> Void) -> any AudioCooldownTimerControlling {
        scheduleCallCount += 1
        let token = FakeCooldownTimerToken(
            onCancel: { [weak self] in
                self?.cancelCallCount += 1
            },
            handler: handler
        )
        tokens.append(token)
        return token
    }

    func fireLast() {
        lastToken?.fire()
    }
}

private final class FakeCooldownTimerToken: AudioCooldownTimerControlling {
    private let onCancel: () -> Void
    private let handler: () -> Void
    private(set) var isCancelled = false
    private(set) var cancelCallCount = 0

    init(onCancel: @escaping () -> Void, handler: @escaping () -> Void) {
        self.onCancel = onCancel
        self.handler = handler
    }

    func cancel() {
        isCancelled = true
        cancelCallCount += 1
        onCancel()
    }

    func fire() {
        guard !isCancelled else {
            return
        }

        handler()
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

private final class FakeSpeechDetector: SpeechDetecting {
    var onSpeechDetected: (() -> Void)?
    var onSpeechEnded: (() -> Void)?

    func process(_ buffer: AVAudioPCMBuffer) {
        // The live session tests drive the detector directly through the emit helpers.
    }

    func reset() {}

    func emitSpeechDetected() {
        onSpeechDetected?()
    }

    func emitSpeechEnded() {
        onSpeechEnded?()
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

private func makeBuffer(
    amplitude: Float = 0,
    frameCount: AVAudioFrameCount = 160,
    sampleRate: Double = 16_000
) -> AVAudioPCMBuffer {
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount

    if let data = buffer.floatChannelData {
        let samples = data[0]
        for index in 0..<Int(frameCount) {
            samples[index] = amplitude
        }
    }

    return buffer
}
