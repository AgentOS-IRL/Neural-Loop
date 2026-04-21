import AVFoundation
import Foundation

protocol AudioInterruptionDetectingSession: AnyObject {
    func currentPermissionState() -> AudioTranscriptionPermissionState
    func requestPermissions() async -> AudioTranscriptionPermissionState
    func start(resultHandler: @escaping (AudioInterruptionDetectionEvent) -> Void) async throws
    func stop()
}

@MainActor
final class AudioInterruptionDetectionSession: AudioInterruptionDetectingSession {
    private static let inputTapBufferSize: AVAudioFrameCount = 256

    private let audioSession: AudioSessionControlling
    private let audioEngine: AudioEngineControlling
    private let detector: AudioInterruptionDetector
    private var activeResultHandler: ((AudioInterruptionDetectionEvent) -> Void)?
    private var isRunning = false

    init(
        audioSession: AudioSessionControlling = LiveAudioSessionAdapter(),
        audioEngine: AudioEngineControlling = LiveAudioEngineAdapter(),
        detector: AudioInterruptionDetector = AudioInterruptionDetector()
    ) {
        self.audioSession = audioSession
        self.audioEngine = audioEngine
        self.detector = detector

        self.detector.onEvent = { [weak self] event in
            self?.handleDetectorEvent(event)
        }
    }

    func currentPermissionState() -> AudioTranscriptionPermissionState {
        let recordPermission = audioSession.recordPermission
        if recordPermission == .denied {
            return .microphoneDenied
        }

        if recordPermission == .undetermined {
            return .unknown
        }

        return recordPermission == .granted ? .authorized : .unavailable
    }

    func requestPermissions() async -> AudioTranscriptionPermissionState {
        let granted = await audioSession.requestRecordPermission()
        return granted ? .authorized : .microphoneDenied
    }

    func start(resultHandler: @escaping (AudioInterruptionDetectionEvent) -> Void) async throws {
        guard !isRunning else {
            throw AudioInterruptionDetectionError.sessionAlreadyActive
        }

        guard currentPermissionState().isAuthorized else {
            throw AudioInterruptionDetectionError.permissionDenied(currentPermissionState())
        }

        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.mixWithOthers, .defaultToSpeaker]
        )
        try audioSession.setActive(true)

        activeResultHandler = resultHandler
        detector.reset()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: Self.inputTapBufferSize,
            format: inputFormat
        ) { [weak self] buffer, _ in
            self?.detector.process(buffer)
        }

        audioEngine.prepare()
        isRunning = true

        do {
            try audioEngine.start()
        } catch {
            cleanupAfterFailedStart()
            throw AudioInterruptionDetectionError.failedToStartAudioEngine
        }
    }

    func stop() {
        guard isRunning || activeResultHandler != nil else {
            return
        }

        cleanup()
    }

    private func handleDetectorEvent(_ event: AudioInterruptionDetectionEvent) {
        Task { @MainActor [weak self] in
            guard let self, self.isRunning else {
                return
            }

            self.activeResultHandler?(event)
        }
    }

    private func cleanupAfterFailedStart() {
        audioEngine.inputNode.removeTap(onBus: 0)
        detector.reset()
        activeResultHandler = nil
        try? audioSession.setActive(false)
        isRunning = false
    }

    private func cleanup() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        detector.reset()
        activeResultHandler = nil
        isRunning = false
        try? audioSession.setActive(false)
    }
}

private enum AudioInterruptionDetectionError: LocalizedError {
    case sessionAlreadyActive
    case permissionDenied(AudioTranscriptionPermissionState)
    case failedToStartAudioEngine

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "An interruption detection session is already active."
        case .permissionDenied(let state):
            return audioTranscriptionPermissionMessage(for: state)
        case .failedToStartAudioEngine:
            return "Unable to start the interruption detection audio engine."
        }
    }
}
