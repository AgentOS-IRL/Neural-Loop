import Foundation
import AVFoundation
import Combine
import Speech
import SwiftUI

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

struct AudioTranscriptionUpdate: Equatable {
    let transcript: String
    let isFinal: Bool
}

enum AudioTranscriptionEvent: Equatable {
    case update(AudioTranscriptionUpdate)
    case failure(String)
}

enum AudioTranscriptionError: LocalizedError, Equatable {
    case sessionAlreadyActive
    case recognizerUnavailable
    case audioSessionUnavailable
    case permissionDenied(AudioTranscriptionPermissionState)
    case failedToStartAudioEngine

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
    func stop()
}

@MainActor
final class AudioTranscriptionManager: ObservableObject {
    @Published private(set) var permissionState: AudioTranscriptionPermissionState
    @Published private(set) var isRecording = false
    @Published private(set) var transcriptText = ""
    @Published private(set) var isTranscriptFinal = false
    @Published private(set) var errorMessage: String?

    private let session: any AudioTranscribingSession
    private let preferOnDeviceRecognition: Bool
    private var activeSession = false

    init(
        session: (any AudioTranscribingSession)? = nil,
        preferOnDeviceRecognition: Bool = false
    ) {
        self.session = session ?? LiveAudioTranscriptionSession()
        self.preferOnDeviceRecognition = preferOnDeviceRecognition
        self.permissionState = self.session.currentPermissionState()
    }

    var canInteractWithMic: Bool {
        permissionState.isAuthorized || permissionState == .unknown
    }

    var micButtonLabel: String {
        switch permissionState {
        case .authorized, .unknown:
            return isRecording ? "Stop Recording" : "Start Recording"
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

        if isRecording && transcriptText.isEmpty {
            return "Listening..."
        }

        if !transcriptText.isEmpty {
            return isTranscriptFinal ? "Transcript ready." : "Listening..."
        }

        switch permissionState {
        case .authorized:
            return "Tap the mic to start speaking."
        case .unknown:
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
        guard !activeSession else {
            return
        }

        errorMessage = nil
        permissionState = .requesting

        let permission = await session.requestPermissions()
        permissionState = permission

        guard permission.isAuthorized else {
            errorMessage = audioTranscriptionPermissionMessage(for: permission)
            return
        }

        do {
            activeSession = true
            isRecording = true
            isTranscriptFinal = false
            try await session.start(
                onDeviceRecognition: preferOnDeviceRecognition,
                resultHandler: handleEvent
            )
        } catch {
            activeSession = false
            isRecording = false
            errorMessage = error.localizedDescription
            session.stop()
        }
    }

    func stopRecording() {
        guard activeSession || isRecording else {
            return
        }

        session.stop()
        activeSession = false
        isRecording = false
    }

    func resetTranscript() {
        transcriptText = ""
        isTranscriptFinal = false
        errorMessage = nil
    }

    private func handleEvent(_ event: AudioTranscriptionEvent) {
        switch event {
        case .update(let update):
            transcriptText = update.transcript
            isTranscriptFinal = update.isFinal
            errorMessage = nil

            if update.isFinal {
                stopRecording()
            }
        case .failure(let message):
            errorMessage = message
            stopRecording()
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

final class LiveAudioTranscriptionSession: AudioTranscribingSession {
    private let audioSession: AudioSessionControlling
    private let audioEngine: AudioEngineControlling
    private let recognizerFactory: () -> (any SpeechRecognizerControlling)?
    private let speechAuthorization: SpeechAuthorizationControlling
    private var activeRequest: (any SpeechRecognitionRequestControlling)?
    private var activeTask: (any SpeechRecognitionTaskControlling)?
    private var activeResultHandler: ((AudioTranscriptionEvent) -> Void)?
    private var isRunning = false

    init(
        audioSession: AudioSessionControlling = LiveAudioSessionAdapter(),
        audioEngine: AudioEngineControlling = LiveAudioEngineAdapter(),
        speechAuthorization: SpeechAuthorizationControlling = LiveSpeechAuthorizationAdapter(),
        recognizerFactory: @escaping () -> (any SpeechRecognizerControlling)? = {
            LiveSpeechRecognizerAdapter(locale: nil)
        }
    ) {
        self.audioSession = audioSession
        self.audioEngine = audioEngine
        self.speechAuthorization = speechAuthorization
        self.recognizerFactory = recognizerFactory
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

        let request = LiveSpeechRecognitionRequestAdapter()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = onDeviceRecognition
        activeRequest = request
        activeResultHandler = resultHandler

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            activeRequest = nil
            activeResultHandler = nil
            try? audioSession.setActive(false)
            throw AudioTranscriptionError.failedToStartAudioEngine
        }

        let task = recognizer.recognitionTask(with: request) { [weak self] recognitionResult, error in
            guard let self else {
                return
            }

            if let error {
                Task { @MainActor in
                    self.activeResultHandler?(.failure(error.localizedDescription))
                }
                return
            }

            guard let recognitionResult else {
                return
            }

            let update = AudioTranscriptionUpdate(
                transcript: recognitionResult.transcript,
                isFinal: recognitionResult.isFinal
            )

            Task { @MainActor in
                self.activeResultHandler?(.update(update))
            }
        }

        activeTask = task
        isRunning = true
    }

    func stop() {
        guard isRunning || activeRequest != nil || activeTask != nil else {
            return
        }

        activeTask?.cancel()
        activeTask = nil
        activeRequest?.endAudio()
        activeRequest = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? audioSession.setActive(false)
        isRunning = false
        activeResultHandler = nil
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
            if let error {
                resultHandler(nil, error)
                return
            }

            guard let result else {
                resultHandler(nil, nil)
                return
            }

            resultHandler(
                SpeechRecognitionResult(
                    transcript: result.bestTranscription.formattedString,
                    isFinal: result.isFinal
                ),
                nil
            )
        }

        return LiveSpeechRecognitionTaskAdapter(task: task)
    }
}
