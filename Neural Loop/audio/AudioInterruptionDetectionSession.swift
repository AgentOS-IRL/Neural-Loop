import AVFoundation
import Foundation
import OSLog

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
    private let logger = Logger(subsystem: "NeuralLoop", category: "AudioInterruptionDetectionSession")
    private var activeResultHandler: ((AudioInterruptionDetectionEvent) -> Void)?
    private var isRunning = false
    private var isInputTapInstalled = false

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
            guard let self, self.isRunning, self.isInputTapInstalled else {
                return
            }

            self.detector.process(buffer)
        }
        isInputTapInstalled = true

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRunning = true
            logger.debug("Interruption detection armed")
        } catch {
            cleanupAfterFailedStart()
            logger.debug("Interruption detection failed to start: \(error.localizedDescription, privacy: .public)")
            throw AudioInterruptionDetectionError.failedToStartAudioEngine
        }
    }

    func stop() {
        guard isRunning || activeResultHandler != nil || isInputTapInstalled else {
            return
        }

        logger.debug("Interruption detection disarmed")
        cleanup()
    }

    private func handleDetectorEvent(_ event: AudioInterruptionDetectionEvent) {
        Task { @MainActor [weak self] in
            guard let self, self.isRunning, self.activeResultHandler != nil else {
                return
            }

            if event == .confirmed {
                self.logger.debug("Interruption detection confirmed")
            }
            self.activeResultHandler?(event)
        }
    }

    private func cleanupAfterFailedStart() {
        cleanupTapIfNeeded()
        detector.reset()
        activeResultHandler = nil
        try? audioSession.setActive(false)
        isRunning = false
    }

    private func cleanup() {
        cleanupTapIfNeeded()
        if isRunning {
            audioEngine.stop()
        }
        detector.reset()
        activeResultHandler = nil
        isRunning = false
        try? audioSession.setActive(false)
    }

    private func cleanupTapIfNeeded() {
        guard isInputTapInstalled else {
            return
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        isInputTapInstalled = false
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
