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

enum AudioTranscriptionDisplayState: Equatable {
    case inactive
    case checkingPermissions
    case listening
    case transcribing
    case cooldown
    case unavailable
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
    var onCommittedTranscript: ((String) -> Void)?

    private let session: any AudioTranscribingSession
    private let preferOnDeviceRecognition: Bool
    private let cooldownScheduler: any AudioCooldownTimerScheduling
    private let segmentCommitCooldownDuration: TimeInterval
    private var cooldownTimer: (any AudioCooldownTimerControlling)?
    private var activeSession = false
    private var isStartingSession = false
    private var isAwaitingSegmentCommit = false
    private var isSegmentOpen = false

    init(
        session: (any AudioTranscribingSession)? = nil,
        preferOnDeviceRecognition: Bool = false,
        cooldownScheduler: (any AudioCooldownTimerScheduling)? = nil,
        segmentCommitCooldownDuration: TimeInterval = 3.0
    ) {
        self.session = session ?? LiveAudioTranscriptionSession()
        self.preferOnDeviceRecognition = preferOnDeviceRecognition
        self.cooldownScheduler = cooldownScheduler ?? MainQueueAudioCooldownTimerScheduler()
        self.segmentCommitCooldownDuration = segmentCommitCooldownDuration
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
            return "Transcribing speech"
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

    var displayState: AudioTranscriptionDisplayState {
        switch permissionState {
        case .requesting:
            return .checkingPermissions
        case .microphoneDenied, .speechDenied, .restricted, .unavailable:
            return .unavailable
        case .unknown, .authorized:
            switch sessionState {
            case .inactive:
                return .inactive
            case .checking, .listening:
                return .listening
            case .transcribing:
                return .transcribing
            case .cooldownPending:
                return .transcribing
            }
        }
    }

    var primaryStatusTitle: String {
        if errorMessage != nil {
            return "Microphone unavailable"
        }

        switch displayState {
        case .inactive:
            return "Audio Mode"
        case .checkingPermissions:
            return "Checking permissions"
        case .listening:
            return sessionState == .checking ? "Stand by for speech" : "Listening for your next phrase"
        case .transcribing:
            return "Transcribing live speech"
        case .cooldown:
            return "Holding the floor open"
        case .unavailable:
            return "Microphone unavailable"
        }
    }

    var secondaryStatusText: String {
        if let errorMessage {
            return errorMessage
        }

        switch sessionState {
        case .inactive:
            switch permissionState {
            case .authorized, .unknown:
                return "Voice stays active across pauses until you stop the session."
            case .requesting:
                return "Requesting audio permissions so the session can begin."
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
            return "Waiting for the first phrase before speech is committed."
        case .listening:
            return transcriptHistory.isEmpty
            ? "Speak naturally. The session remains open across pauses."
            : "The session is still live and ready for the next segment."
        case .transcribing:
            return "Speech is being converted into text and prepared for Codex."
        case .cooldownPending:
            return "Keep talking to continue this sentence. Codex waits for a longer pause."
        }
    }

    var statusBadgeText: String? {
        switch displayState {
        case .inactive:
            return transcriptHistory.isEmpty ? "Ready" : "Reset to start again"
        case .checkingPermissions:
            return "Checking"
        case .listening:
            return transcriptHistory.isEmpty ? "Listening" : "Open session"
        case .transcribing:
            return "Transcribing"
        case .cooldown:
            return "Listening"
        case .unavailable:
            return "Mic unavailable"
        }
    }

    var transcriptStatusTitle: String {
        switch sessionState {
        case .inactive:
            return "Live transcript"
        case .checking:
            return "Waiting for speech"
        case .listening:
            return transcriptHistory.isEmpty ? "Listening" : "Listening for more"
        case .transcribing:
            return "Transcribing"
        case .cooldownPending:
            return "Transcribing"
        }
    }

    var transcriptStatusIconName: String {
        switch sessionState {
        case .inactive:
            return "text.quote"
        case .checking, .listening:
            return "waveform"
        case .transcribing, .cooldownPending:
            return "waveform.and.mic"
        }
    }

    var transcriptStatusBadgeText: String? {
        if errorMessage != nil {
            return "Issue"
        }
        if isTranscriptFinal {
            return "Final"
        }
        if sessionState == .cooldownPending {
            return "Live"
        }
        if transcriptText.isEmpty {
            return statusBadgeText
        }
        return "Live"
    }

    var viewData: AudioModeTranscriptionViewData {
        AudioModeTranscriptionViewData(
            displayState: displayState,
            title: primaryStatusTitle,
            detail: secondaryStatusText,
            badgeText: statusBadgeText,
            transcriptTitle: transcriptStatusTitle,
            transcriptIconName: transcriptStatusIconName,
            transcriptBadgeText: transcriptStatusBadgeText,
            transcriptBody: transcriptCardText,
            microphoneSystemImage: microphoneSystemImage,
            micButtonLabel: micButtonLabel,
            isActionDisabled: isActionDisabled,
            isRecording: isRecording,
            transcriptHistoryCount: transcriptHistory.count
        )
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
            return "Transcribing speech..."
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
        await beginRecording(resetTranscript: true, requestPermissions: true)
    }

    func resumeRecording() async {
        await beginRecording(resetTranscript: false, requestPermissions: false)
    }

    func pauseRecording() {
        if isAwaitingSegmentCommit || isSegmentOpen {
            invalidateCooldownTimer()
            session.rolloverSegment()
            commitCurrentTranscriptIfNeeded()
            isAwaitingSegmentCommit = false
            isSegmentOpen = false
        }
        stopRecording(clearTranscript: false, clearHistory: false)
    }

    private func beginRecording(resetTranscript: Bool, requestPermissions: Bool) async {
        guard !activeSession, !isStartingSession else {
            return
        }

        if resetTranscript {
            self.resetTranscript()
        }
        isAwaitingSegmentCommit = false
        isSegmentOpen = false
        if requestPermissions {
            setSessionState(.checking)
            permissionState = .requesting
        }
        isStartingSession = true
        defer {
            isStartingSession = false
        }

        let permission: AudioTranscriptionPermissionState
        if requestPermissions {
            permission = await session.requestPermissions()
            permissionState = permission
        } else {
            permission = session.currentPermissionState()
        }

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
        if !transcriptText.isEmpty {
            transcriptText = ""
        }
        if isTranscriptFinal {
            isTranscriptFinal = false
        }
        if errorMessage != nil {
            errorMessage = nil
        }
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

        if clearHistory, !transcriptHistory.isEmpty {
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

            if transcriptText != update.transcript {
                transcriptText = update.transcript
            }
            if isTranscriptFinal != update.isFinal {
                isTranscriptFinal = update.isFinal
            }
            if errorMessage != nil {
                errorMessage = nil
            }
        case .failure(let message):
            if errorMessage != message {
                errorMessage = message
            }
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
        if errorMessage != nil {
            errorMessage = nil
        }
        setSessionState(.transcribing)
    }

    private func handleSpeechEnded() {
        guard activeSession, isSegmentOpen, !isAwaitingSegmentCommit else {
            return
        }

        invalidateCooldownTimer()
        isAwaitingSegmentCommit = true
        setSessionState(.cooldownPending)
        cooldownTimer = cooldownScheduler.schedule(after: segmentCommitCooldownDuration) { [weak self] in
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
        onCommittedTranscript?(trimmedTranscript)
        resetTranscript()
    }

    private func setSessionState(_ state: AudioTranscriptionSessionState) {
        if sessionState != state {
            sessionState = state
        }

        let shouldRecord = state != .inactive
        if isRecording != shouldRecord {
            isRecording = shouldRecord
        }
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
    private static let inputTapBufferSize: AVAudioFrameCount = 256
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
    private var isSpeechActive = false
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
        isSpeechActive = false
        hasFlushedPreRoll = false
        preRollHistory.reset()
        detector.reset()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: Self.inputTapBufferSize,
            format: inputFormat
        ) { [weak self] buffer, _ in
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
        isSpeechActive = false
        hasFlushedPreRoll = false
        preRollHistory.reset()
        detector.reset()
    }

    private func handleSpeechDetected() {
        guard isRunning, !isSpeechActive else {
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
        isSpeechActive = true
        emit(.speechDetected)
    }

    private func handleSpeechEnded() {
        guard isRunning, isSpeechActive else {
            return
        }

        isSpeechActive = false
        emit(.speechEnded)
    }

    private func cleanupAfterFailedStart() {
        audioEngine.inputNode.removeTap(onBus: 0)
        activeRequest = nil
        activeTask = nil
        activeRecognizer = nil
        isCapturingAudio = false
        isSpeechActive = false
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
        isSpeechActive = false
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
    private var buffers: [(buffer: AVAudioPCMBuffer, duration: TimeInterval)] = []
    private var startIndex = 0
    private var accumulatedDuration: TimeInterval = 0

    init(maxDuration: TimeInterval) {
        self.maxDuration = maxDuration
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let copy = buffer.deepCopy(), let duration = bufferDuration(for: copy), duration > 0 else {
            return
        }

        buffers.append((copy, duration))
        accumulatedDuration += duration
        trimToWindow()
    }

    func drain() -> [AVAudioPCMBuffer] {
        defer { reset() }
        return buffers[startIndex...].map { $0.buffer }
    }

    func reset() {
        buffers.removeAll()
        startIndex = 0
        accumulatedDuration = 0
    }

    private func trimToWindow() {
        guard maxDuration > 0 else {
            return
        }

        while accumulatedDuration > maxDuration, startIndex < buffers.count {
            accumulatedDuration -= buffers[startIndex].duration
            startIndex += 1
        }

        compactStorageIfNeeded()
    }

    private func compactStorageIfNeeded() {
        guard startIndex > 32, startIndex * 2 > buffers.count else {
            return
        }

        buffers.removeFirst(startIndex)
        startIndex = 0
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
