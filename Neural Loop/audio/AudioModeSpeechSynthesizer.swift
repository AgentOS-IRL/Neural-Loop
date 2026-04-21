import AVFoundation
import Foundation
import OSLog

@MainActor
protocol AudioModeSpeechSynthesizing: AnyObject {
    func speak(_ request: AudioSpeechRequest, onEvent: @escaping (AudioSpeechEvent) -> Void)
    func stop(reason: AudioSpeechStopReason)
    func reset()
}

@MainActor
final class AudioModeSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, AudioModeSpeechSynthesizing {
    private let logger = Logger(subsystem: "NeuralLoop", category: "AudioModeSpeechSynthesizer")
    private let synthesizer = AVSpeechSynthesizer()
    private var activeRequest: AudioSpeechRequest?
    private var activeUtteranceID: ObjectIdentifier?
    private var eventHandler: ((AudioSpeechEvent) -> Void)?
    private var pendingStopReason: AudioSpeechStopReason?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, completion: ((Bool) -> Void)? = nil) {
        let request = AudioSpeechRequest(messageID: UUID(), text: text)
        speak(request) { event in
            if case .ended(_, let reason) = event {
                completion?(reason == .finished)
            }
        }
    }

    func speak(_ request: AudioSpeechRequest, onEvent: @escaping (AudioSpeechEvent) -> Void) {
        let trimmedText = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            onEvent(.ended(request, .canceled))
            return
        }

        reset()
        activeRequest = request
        eventHandler = onEvent
        pendingStopReason = nil

        let utterance = AVSpeechUtterance(string: trimmedText)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        activeUtteranceID = ObjectIdentifier(utterance)
        configureAudioSessionForPlayback()
        synthesizer.speak(utterance)
    }

    func stop() {
        stop(reason: .reset)
    }

    func stop(reason: AudioSpeechStopReason) {
        cancelCurrentSpeech(reporting: reason)
    }

    func reset() {
        cancelCurrentSpeech(reporting: .reset)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.handleDidStart(utteranceID: utteranceID)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.finishSpeech(utteranceID: utteranceID, reason: .finished)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            let reason = self?.speechEndReasonForCurrentStop() ?? .canceled
            self?.finishSpeech(utteranceID: utteranceID, reason: reason)
        }
    }

    private func finishSpeech(utteranceID: ObjectIdentifier, reason: AudioSpeechEndReason) {
        guard activeUtteranceID == utteranceID, let request = activeRequest else {
            return
        }

        let handler = eventHandler
        activeRequest = nil
        activeUtteranceID = nil
        eventHandler = nil
        pendingStopReason = nil
        handler?(.ended(request, reason))
    }

    private func handleDidStart(utteranceID: ObjectIdentifier) {
        guard activeUtteranceID == utteranceID, let request = activeRequest else {
            return
        }

        eventHandler?(.started(request))
    }

    private func cancelCurrentSpeech(reporting reason: AudioSpeechStopReason) {
        guard activeRequest != nil else {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }

        pendingStopReason = reason
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func configureAudioSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            logger.error("Failed to configure audio session for TTS playback: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func speechEndReasonForCurrentStop() -> AudioSpeechEndReason {
        switch pendingStopReason {
        case .interrupted:
            return .interrupted
        case .muted:
            return .muted
        case .reset:
            return .canceled
        case .teardown:
            return .teardown
        case .skipped:
            return .skipped
        case nil:
            return .canceled
        }
    }
}
