import Foundation
import AVFoundation
import Combine
import Speech

enum AudioTranscriptionPermissionState: Equatable {
    case unknown
    case requesting
    case authorized
    case microphoneDenied
    case speechDenied
    case restricted
    case unavailable

    var isAuthorized: Bool {
        self == .authorized
    }
}

enum AudioTranscriptionSessionState: Equatable {
    case inactive
    case checking
    case listening
    case transcribing
    case cooldownPending
}

struct AudioTranscriptionUpdate: Equatable {
    let transcript: String
    let isFinal: Bool
}

enum AudioTranscriptionEvent: Equatable {
    case speechDetected
    case speechEnded
    case update(AudioTranscriptionUpdate)
    case failure(String)
}

enum AudioTranscriptionError: LocalizedError, Equatable {
    case sessionAlreadyActive
    case recognizerUnavailable
    case audioSessionUnavailable
    case permissionDenied(AudioTranscriptionPermissionState)
    case failedToStartAudioEngine
    case failedToStartRecognitionTask

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "A transcription session is already active."
        case .recognizerUnavailable:
            return "Speech recognition is unavailable on this device."
        case .audioSessionUnavailable:
            return "Audio recording is unavailable."
        case .permissionDenied(let state):
            return audioTranscriptionPermissionMessage(for: state)
        case .failedToStartAudioEngine:
            return "Unable to start the audio engine."
        case .failedToStartRecognitionTask:
            return "Unable to start speech recognition."
        }
    }
}

protocol AudioTranscribingSession {
    func currentPermissionState() -> AudioTranscriptionPermissionState
    func requestPermissions() async -> AudioTranscriptionPermissionState
    func start(
        onDeviceRecognition: Bool,
        resultHandler: @escaping (AudioTranscriptionEvent) -> Void
    ) async throws
    func rolloverSegment()
    func stop()
}

protocol AudioCooldownTimerControlling {
    func cancel()
}

protocol AudioCooldownTimerScheduling {
    func schedule(after delay: TimeInterval, _ handler: @escaping () -> Void) -> any AudioCooldownTimerControlling
}

@MainActor
final class AudioTranscriptionManager: ObservableObject {
    @Published private(set) var permissionState: AudioTranscriptionPermissionState
    @Published private(set) var sessionState: AudioTranscriptionSessionState = .inactive
    @Published private(set) var isRecording = false
    @Published private(set) var transcriptText = ""
    @Published private(set) var isTranscriptFinal = false
    @Published private(set) var transcriptHistory: [AudioTranscriptMessage] = []
    @Published private(set) var errorMessage: String?

    private let session: any AudioTranscribingSession
    private let preferOnDeviceRecognition: Bool
    private let cooldownScheduler: any AudioCooldownTimerScheduling
    private var cooldownTimer: (any AudioCooldownTimerControlling)?
    private var activeSession = false
    private var isStartingSession = false
    private var isAwaitingSegmentCommit = false
    private var isSegmentOpen = false

    init(
        session: (any AudioTranscribingSession)? = nil,
        preferOnDeviceRecognition: Bool = false,
        cooldownScheduler: (any AudioCooldownTimerScheduling)? = nil
    ) {
        self.session = session ?? LiveAudioTranscriptionSession()
        self.preferOnDeviceRecognition = preferOnDeviceRecognition
        self.cooldownScheduler = cooldownScheduler ?? MainQueueAudioCooldownTimerScheduler()
        self.permissionState = self.session.currentPermissionState()
    }

    var canInteractWithMic: Bool {
        permissionState.isAuthorized || permissionState == .unknown
    }

    var micButtonLabel: String {
        switch permissionState {
        case .authorized, .unknown:
            switch sessionState {
            case .inactive:
                return "Start Voice Detection"
        case .checking:
            return "Checking for speech"
        case .listening:
            return transcriptHistory.isEmpty ? "Listening for speech" : "Listening for more speech"
        case .transcribing:
            return "Transcribing speech"
        case .cooldownPending:
            return "Listening for more speech"
            }
        case .requesting:
            return "Checking Permissions"
        case .microphoneDenied, .speechDenied, .restricted, .unavailable:
            return "Mic Unavailable"
        }
    }

    var microphoneSystemImage: String {
        isRecording ? "stop.fill" : "mic.fill"
    }

    var promptText: String {
        if let errorMessage {
            return errorMessage
        }

        switch sessionState {
        case .inactive:
            switch permissionState {
            case .authorized, .unknown:
                return "Tap the mic to start speaking."
            case .requesting:
                return "Requesting access..."
            case .microphoneDenied:
                return "Microphone access is required to record speech."
            case .speechDenied:
                return "Speech recognition access is required to transcribe text."
            case .restricted:
                return "Speech and microphone access are restricted on this device."
            case .unavailable:
                return "Speech transcription is unavailable on this device."
            }
        case .checking:
            return "Checking for speech..."
        case .listening:
            return transcriptHistory.isEmpty ? "Listening for speech..." : "Listening for more speech..."
        case .transcribing:
            return "Transcribing speech..."
        case .cooldownPending:
            return "Listening for more speech..."
        }
    }

    var isActionDisabled: Bool {
        switch permissionState {
        case .authorized, .unknown:
            return false
        case .requesting, .microphoneDenied, .speechDenied, .restricted, .unavailable:
            return true
        }
    }

    func refreshPermissionState() {
        permissionState = session.currentPermissionState()
    }

    func toggleRecording() async {
        if isRecording {
            stopRecording()
            return
        }

        await startRecording()
    }

    func startRecording() async {
        guard !activeSession, !isStartingSession else {
            return
        }

        resetTranscript()
        isAwaitingSegmentCommit = false
        isSegmentOpen = false
        setSessionState(.checking)
        permissionState = .requesting
        isStartingSession = true
        defer {
            isStartingSession = false
        }

        let permission = await session.requestPermissions()
        permissionState = permission

        guard isStartingSession else {
            return
        }

        guard permission.isAuthorized else {
            errorMessage = audioTranscriptionPermissionMessage(for: permission)
            setSessionState(.inactive)
            return
        }

        do {
            activeSession = true
            try await session.start(
                onDeviceRecognition: preferOnDeviceRecognition,
                resultHandler: handleEvent
            )

            guard isStartingSession else {
                activeSession = false
                session.stop()
                return
            }

            setSessionState(.listening)
        } catch {
            activeSession = false
            session.stop()

            if !isStartingSession {
                setSessionState(.inactive)
                return
            }

            setSessionState(.inactive)
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() {
        stopRecording(clearTranscript: true, clearHistory: true)
    }

    func resetTranscript() {
        transcriptText = ""
        isTranscriptFinal = false
        errorMessage = nil
    }

    var transcriptCardText: String {
        if let errorMessage {
            return errorMessage
        }

        if transcriptText.isEmpty {
            return promptText
        }

        return transcriptText
    }

    private func stopRecording(clearTranscript: Bool, clearHistory: Bool) {
        guard activeSession || isStartingSession || sessionState != .inactive else {
            return
        }

        invalidateCooldownTimer()
        session.stop()
        activeSession = false
        isStartingSession = false
        isAwaitingSegmentCommit = false
        isSegmentOpen = false
        setSessionState(.inactive)

        if clearHistory {
            transcriptHistory.removeAll()
        }

        if clearTranscript {
            resetTranscript()
        } else {
            isTranscriptFinal = false
        }
    }

    private func handleEvent(_ event: AudioTranscriptionEvent) {
        switch event {
        case .speechDetected:
            handleSpeechDetected()
        case .speechEnded:
            handleSpeechEnded()
        case .update(let update):
            guard isSegmentOpen || isAwaitingSegmentCommit else {
                return
            }

            transcriptText = update.transcript
            isTranscriptFinal = update.isFinal
            errorMessage = nil
        case .failure(let message):
            errorMessage = message
            stopRecording(clearTranscript: false, clearHistory: false)
        }
    }

    private func handleSpeechDetected() {
        guard activeSession else {
            return
        }

        invalidateCooldownTimer()
        isAwaitingSegmentCommit = false
        isSegmentOpen = true
        errorMessage = nil
        setSessionState(.transcribing)
    }

    private func handleSpeechEnded() {
        guard activeSession else {
            return
        }

        invalidateCooldownTimer()
        isAwaitingSegmentCommit = true
        setSessionState(.cooldownPending)
        cooldownTimer = cooldownScheduler.schedule(after: 5) { [weak self] in
            Task { @MainActor in
                self?.completeCooldown()
            }
        }
    }

    private func completeCooldown() {
        guard activeSession, isAwaitingSegmentCommit else {
            return
        }

        isAwaitingSegmentCommit = false
        session.rolloverSegment()
        commitCurrentTranscriptIfNeeded()
        isSegmentOpen = false
        setSessionState(.listening)
    }

    private func invalidateCooldownTimer() {
        cooldownTimer?.cancel()
        cooldownTimer = nil
    }

    private func commitCurrentTranscriptIfNeeded() {
        let trimmedTranscript = transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            resetTranscript()
            return
        }

        transcriptHistory.append(AudioTranscriptMessage(content: trimmedTranscript))
        resetTranscript()
    }

    private func setSessionState(_ state: AudioTranscriptionSessionState) {
        sessionState = state
        isRecording = state != .inactive
    }
}

func audioTranscriptionPermissionMessage(for state: AudioTranscriptionPermissionState) -> String {
    switch state {
    case .unknown, .requesting, .authorized:
        return "Tap the mic to start speaking."
    case .microphoneDenied:
        return "Microphone access is required to record speech."
    case .speechDenied:
        return "Speech recognition access is required to transcribe text."
    case .restricted:
        return "Speech and microphone access are restricted on this device."
    case .unavailable:
        return "Speech transcription is unavailable on this device."
    }
}

final class MainQueueAudioCooldownTimerScheduler: AudioCooldownTimerScheduling {
    func schedule(after delay: TimeInterval, _ handler: @escaping () -> Void) -> any AudioCooldownTimerControlling {
        let token = DispatchAudioCooldownTimerToken()
        let workItem = DispatchWorkItem {
            Task { @MainActor in
                handler()
            }
        }

        token.workItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        return token
    }
}

final class DispatchAudioCooldownTimerToken: AudioCooldownTimerControlling {
    fileprivate var workItem: DispatchWorkItem?

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

final class LiveAudioTranscriptionSession: AudioTranscribingSession {
    private let audioSession: AudioSessionControlling
    private let audioEngine: AudioEngineControlling
    private let recognizerFactory: () -> (any SpeechRecognizerControlling)?
    private let speechAuthorization: SpeechAuthorizationControlling
    private let detector: any SpeechDetecting
    private let preRollHistory = AudioPCMBufferHistory(maxDuration: 0.45)
    private var activeRequest: (any SpeechRecognitionRequestControlling)?
    private var activeTask: (any SpeechRecognitionTaskControlling)?
    private var activeRecognizer: (any SpeechRecognizerControlling)?
    private var activeResultHandler: ((AudioTranscriptionEvent) -> Void)?
    private var isRunning = false
    private var isCapturingAudio = false
    private var requiresOnDeviceRecognition = false
    private var hasFlushedPreRoll = false
    private var activeTaskIdentifier: UUID?
    private var pendingCancellationTaskIdentifier: UUID?

    init(
        audioSession: AudioSessionControlling = LiveAudioSessionAdapter(),
        audioEngine: AudioEngineControlling = LiveAudioEngineAdapter(),
        speechAuthorization: SpeechAuthorizationControlling = LiveSpeechAuthorizationAdapter(),
        recognizerFactory: @escaping () -> (any SpeechRecognizerControlling)? = {
            LiveSpeechRecognizerAdapter(locale: nil)
        },
        detector: any SpeechDetecting = SpeechDetector()
    ) {
        self.audioSession = audioSession
        self.audioEngine = audioEngine
        self.speechAuthorization = speechAuthorization
        self.recognizerFactory = recognizerFactory
        self.detector = detector

        self.detector.onSpeechDetected = { [weak self] in
            self?.handleSpeechDetected()
        }

        self.detector.onSpeechEnded = { [weak self] in
            self?.handleSpeechEnded()
        }
    }

    func currentPermissionState() -> AudioTranscriptionPermissionState {
        let speechStatus = speechAuthorization.currentAuthorizationStatus()
        let recordPermission = audioSession.recordPermission

        if speechStatus == .restricted {
            return .restricted
        }

        if speechStatus == .denied {
            return .speechDenied
        }

        if recordPermission == .denied {
            return .microphoneDenied
        }

        if speechStatus == .notDetermined || recordPermission == .undetermined {
            return .unknown
        }

        if speechStatus == .authorized && recordPermission == .granted {
            return .authorized
        }

        return .unavailable
    }

    func requestPermissions() async -> AudioTranscriptionPermissionState {
        let speechStatus = await speechAuthorization.requestAuthorization()

        switch speechStatus {
        case .restricted:
            return .restricted
        case .denied:
            return .speechDenied
        case .notDetermined:
            return .unknown
        case .authorized:
            break
        @unknown default:
            return .unavailable
        }

        let recordPermission = await audioSession.requestRecordPermission()
        return recordPermission ? .authorized : .microphoneDenied
    }

    func start(
        onDeviceRecognition: Bool,
        resultHandler: @escaping (AudioTranscriptionEvent) -> Void
    ) async throws {
        guard !isRunning else {
            throw AudioTranscriptionError.sessionAlreadyActive
        }

        guard let recognizer = recognizerFactory(), recognizer.isAvailable else {
            throw AudioTranscriptionError.recognizerUnavailable
        }

        guard currentPermissionState().isAuthorized else {
            throw AudioTranscriptionError.permissionDenied(currentPermissionState())
        }

        try audioSession.setCategory(
            .record,
            mode: .measurement,
            options: []
        )
        try audioSession.setActive(true)

        activeRecognizer = recognizer
        requiresOnDeviceRecognition = onDeviceRecognition
        activeResultHandler = resultHandler
        activeRequest = nil
        activeTask = nil
        isCapturingAudio = false
        hasFlushedPreRoll = false
        preRollHistory.reset()
        detector.reset()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else {
                return
            }

            self.detector.process(buffer)
            if !self.hasFlushedPreRoll {
                self.preRollHistory.append(buffer)
            }

            guard self.isCapturingAudio else {
                return
            }

            self.activeRequest?.append(buffer)
        }

        audioEngine.prepare()
        isRunning = true

        do {
            try audioEngine.start()
        } catch {
            cleanupAfterFailedStart()
            throw AudioTranscriptionError.failedToStartAudioEngine
        }
    }

    func stop() {
        guard isRunning || activeRequest != nil || activeTask != nil || activeRecognizer != nil else {
            return
        }

        cleanup()
    }

    func rolloverSegment() {
        guard isRunning else {
            return
        }

        cancelActiveRecognitionTask()
        activeTask = nil
        activeRequest?.endAudio()
        activeRequest = nil
        isCapturingAudio = false
        hasFlushedPreRoll = false
        preRollHistory.reset()
        detector.reset()
    }

    private func handleSpeechDetected() {
        guard isRunning else {
            return
        }

        if activeRequest == nil {
            guard let recognizer = activeRecognizer else {
                emit(.failure(AudioTranscriptionError.recognizerUnavailable.localizedDescription))
                return
            }

            let request = LiveSpeechRecognitionRequestAdapter()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = requiresOnDeviceRecognition
            activeRequest = request

            let taskIdentifier = UUID()
            activeTaskIdentifier = taskIdentifier
            let task = recognizer.recognitionTask(with: request) { [weak self] recognitionResult, error in
                guard let self else {
                    return
                }

                guard self.pendingCancellationTaskIdentifier != taskIdentifier else {
                    return
                }

                if let error {
                    self.emit(.failure(error.localizedDescription))
                    return
                }

                guard let recognitionResult else {
                    return
                }

                let update = AudioTranscriptionUpdate(
                    transcript: recognitionResult.transcript,
                    isFinal: recognitionResult.isFinal
                )

                self.emit(.update(update))
            }

            guard let task else {
                activeRequest = nil
                activeTaskIdentifier = nil
                emit(.failure(AudioTranscriptionError.failedToStartRecognitionTask.localizedDescription))
                return
            }

            activeTask = task
        }

        if !hasFlushedPreRoll {
            flushPreRollHistory()
            hasFlushedPreRoll = true
        }

        isCapturingAudio = true
        emit(.speechDetected)
    }

    private func handleSpeechEnded() {
        guard isRunning else {
            return
        }

        emit(.speechEnded)
    }

    private func cleanupAfterFailedStart() {
        audioEngine.inputNode.removeTap(onBus: 0)
        activeRequest = nil
        activeTask = nil
        activeRecognizer = nil
        isCapturingAudio = false
        hasFlushedPreRoll = false
        preRollHistory.reset()
        detector.reset()
        activeResultHandler = nil
        try? audioSession.setActive(false)
        isRunning = false
    }

    private func cleanup() {
        cancelActiveRecognitionTask()
        activeTask = nil
        activeRequest?.endAudio()
        activeRequest = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        detector.reset()
        isCapturingAudio = false
        hasFlushedPreRoll = false
        preRollHistory.reset()
        activeRecognizer = nil
        isRunning = false
        try? audioSession.setActive(false)
        activeResultHandler = nil
    }

    private func cancelActiveRecognitionTask() {
        guard let task = activeTask else {
            return
        }

        pendingCancellationTaskIdentifier = activeTaskIdentifier
        task.cancel()
        activeTaskIdentifier = nil
    }

    private func flushPreRollHistory() {
        guard let request = activeRequest else {
            return
        }

        for buffer in preRollHistory.drain() {
            request.append(buffer)
        }
    }

    private func emit(_ event: AudioTranscriptionEvent) {
        Task { @MainActor in
            guard self.isRunning else {
                return
            }

            self.activeResultHandler?(event)
        }
    }
}

final class AudioPCMBufferHistory {
    private let maxDuration: TimeInterval
    private var buffers: [AVAudioPCMBuffer] = []
    private var accumulatedDuration: TimeInterval = 0

    init(maxDuration: TimeInterval) {
        self.maxDuration = maxDuration
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let copy = buffer.deepCopy(), let duration = bufferDuration(for: copy), duration > 0 else {
            return
        }

        buffers.append(copy)
        accumulatedDuration += duration
        trimToWindow()
    }

    func drain() -> [AVAudioPCMBuffer] {
        defer { reset() }
        return buffers
    }

    func reset() {
        buffers.removeAll()
        accumulatedDuration = 0
    }

    private func trimToWindow() {
        guard maxDuration > 0 else {
            return
        }

        while accumulatedDuration > maxDuration, let first = buffers.first {
            if let duration = bufferDuration(for: first) {
                accumulatedDuration -= duration
            }
            buffers.removeFirst()
        }
    }

    private func bufferDuration(for buffer: AVAudioPCMBuffer) -> TimeInterval? {
        guard buffer.format.sampleRate > 0 else {
            return nil
        }

        return TimeInterval(buffer.frameLength) / buffer.format.sampleRate
    }
}

private extension AVAudioPCMBuffer {
    func deepCopy() -> AVAudioPCMBuffer? {
        guard frameLength > 0 else {
            return nil
        }

        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }

        copy.frameLength = frameLength

        guard let sourceChannelData = floatChannelData,
              let destinationChannelData = copy.floatChannelData else {
            return nil
        }

        let channelCount = Int(format.channelCount)
        let sampleCount = Int(frameLength)

        for channel in 0..<channelCount {
            let sourceChannel = sourceChannelData[channel]
            let destinationChannel = destinationChannelData[channel]
            destinationChannel.update(from: sourceChannel, count: sampleCount)
        }

        return copy
    }
}

protocol SpeechAuthorizationControlling {
    func currentAuthorizationStatus() -> SFSpeechRecognizerAuthorizationStatus
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus
}

protocol AudioSessionControlling {
    var recordPermission: AVAudioSession.RecordPermission { get }
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws
    func setActive(_ active: Bool) throws
    func requestRecordPermission() async -> Bool
}

protocol AudioEngineControlling {
    var inputNode: AudioInputNodeControlling { get }
    func prepare()
    func start() throws
    func stop()
}

protocol AudioInputNodeControlling {
    func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat
    func installTap(
        onBus bus: AVAudioNodeBus,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping (AVAudioPCMBuffer, AVAudioTime?) -> Void
    )
    func removeTap(onBus bus: AVAudioNodeBus)
}

protocol SpeechRecognitionRequestControlling {
    var request: SFSpeechAudioBufferRecognitionRequest { get }
    var shouldReportPartialResults: Bool { get set }
    var requiresOnDeviceRecognition: Bool { get set }
    func append(_ buffer: AVAudioPCMBuffer)
    func endAudio()
}

protocol SpeechRecognitionTaskControlling {
    func cancel()
}

protocol SpeechRecognizerControlling {
    var isAvailable: Bool { get }
    func recognitionTask(
        with request: any SpeechRecognitionRequestControlling,
        resultHandler: @escaping (SpeechRecognitionResult?, Error?) -> Void
    ) -> (any SpeechRecognitionTaskControlling)?
}

struct SpeechRecognitionResult {
    let transcript: String
    let isFinal: Bool
}

final class LiveAudioSessionAdapter: AudioSessionControlling {
    private let session = AVAudioSession.sharedInstance()

    var recordPermission: AVAudioSession.RecordPermission {
        session.recordPermission
    }

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        try session.setCategory(category, mode: mode, options: options)
    }

    func setActive(_ active: Bool) throws {
        try session.setActive(active)
    }

    func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

final class LiveSpeechAuthorizationAdapter: SpeechAuthorizationControlling {
    func currentAuthorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

final class LiveAudioEngineAdapter: AudioEngineControlling {
    private let engine = AVAudioEngine()
    private lazy var adapter = LiveAudioInputNodeAdapter(node: engine.inputNode)

    var inputNode: AudioInputNodeControlling {
        adapter
    }

    func prepare() {
        engine.prepare()
    }

    func start() throws {
        try engine.start()
    }

    func stop() {
        engine.stop()
    }
}

final class LiveAudioInputNodeAdapter: AudioInputNodeControlling {
    private let node: AVAudioInputNode

    init(node: AVAudioInputNode) {
        self.node = node
    }

    func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        node.inputFormat(forBus: bus)
    }

    func installTap(
        onBus bus: AVAudioNodeBus,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping (AVAudioPCMBuffer, AVAudioTime?) -> Void
    ) {
        node.installTap(onBus: bus, bufferSize: bufferSize, format: format, block: block)
    }

    func removeTap(onBus bus: AVAudioNodeBus) {
        node.removeTap(onBus: bus)
    }
}

final class LiveSpeechRecognitionRequestAdapter: SpeechRecognitionRequestControlling {
    let request = SFSpeechAudioBufferRecognitionRequest()
    private(set) var appendCallCount = 0
    private(set) var endAudioCallCount = 0

    var shouldReportPartialResults: Bool {
        get { request.shouldReportPartialResults }
        set { request.shouldReportPartialResults = newValue }
    }

    var requiresOnDeviceRecognition: Bool {
        get { request.requiresOnDeviceRecognition }
        set { request.requiresOnDeviceRecognition = newValue }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        appendCallCount += 1
        request.append(buffer)
    }

    func endAudio() {
        endAudioCallCount += 1
        request.endAudio()
    }
}

final class LiveSpeechRecognitionTaskAdapter: SpeechRecognitionTaskControlling {
    private let task: SFSpeechRecognitionTask

    init(task: SFSpeechRecognitionTask) {
        self.task = task
    }

    func cancel() {
        task.cancel()
    }
}

final class LiveSpeechRecognizerAdapter: SpeechRecognizerControlling {
    private let recognizer: SFSpeechRecognizer?

    init(locale: Locale?) {
        if let locale {
            recognizer = SFSpeechRecognizer(locale: locale)
        } else {
            recognizer = SFSpeechRecognizer()
        }
    }

    var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    func recognitionTask(
        with request: any SpeechRecognitionRequestControlling,
        resultHandler: @escaping (SpeechRecognitionResult?, Error?) -> Void
    ) -> (any SpeechRecognitionTaskControlling)? {
        guard let recognizer else {
            return nil
        }

        let task = recognizer.recognitionTask(with: request.request) { result, error in
            let mappedResult = result.map {
                SpeechRecognitionResult(
                    transcript: $0.bestTranscription.formattedString,
                    isFinal: $0.isFinal
                )
            }
            resultHandler(mappedResult, error)
        }

        return LiveSpeechRecognitionTaskAdapter(task: task)
    }
}
