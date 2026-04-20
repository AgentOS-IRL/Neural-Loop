import AVFoundation
import Foundation

@MainActor
final class AudioModeSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: ((Bool) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, completion: ((Bool) -> Void)? = nil) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            completion?(false)
            return
        }

        reset()
        self.completion = completion

        let utterance = AVSpeechUtterance(string: trimmedText)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        synthesizer.speak(utterance)
    }

    func stop() {
        cancelCurrentSpeech()
    }

    func reset() {
        cancelCurrentSpeech()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.finishSpeech(success: true)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.finishSpeech(success: false)
        }
    }

    private func finishSpeech(success: Bool) {
        let completion = completion
        self.completion = nil
        completion?(success)
    }

    private func cancelCurrentSpeech() {
        completion = nil
        synthesizer.stopSpeaking(at: .immediate)
    }
}
