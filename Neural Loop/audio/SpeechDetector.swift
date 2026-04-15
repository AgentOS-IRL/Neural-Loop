import Foundation
import AVFoundation

protocol SpeechDetecting: AnyObject {
    var onSpeechDetected: (() -> Void)? { get set }
    var onSpeechEnded: (() -> Void)? { get set }

    func process(_ buffer: AVAudioPCMBuffer)
    func reset()
}

final class SpeechDetector: SpeechDetecting {
    struct Configuration: Equatable {
        var speechThreshold: Float = 0.02
        var speechOnsetThreshold: Float = 0.05
        var speechOnsetDuration: TimeInterval = 0.03
        var speechStartDuration: TimeInterval = 0.12
        var silenceDuration: TimeInterval = 0.45
    }

    var onSpeechDetected: (() -> Void)?
    var onSpeechEnded: (() -> Void)?

    private let configuration: Configuration
    private var isSpeaking = false
    private var speechAccumulatedDuration: TimeInterval = 0
    private var onsetAccumulatedDuration: TimeInterval = 0
    private var silenceAccumulatedDuration: TimeInterval = 0

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    func reset() {
        isSpeaking = false
        speechAccumulatedDuration = 0
        onsetAccumulatedDuration = 0
        silenceAccumulatedDuration = 0
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        let duration = bufferDuration(for: buffer)
        guard duration > 0 else {
            return
        }

        let amplitude = peakAmplitude(for: buffer)

        if isSpeaking {
            handleSpeakingBuffer(amplitude: amplitude, duration: duration)
            return
        }

        handleListeningBuffer(amplitude: amplitude, duration: duration)
    }

    private func handleListeningBuffer(amplitude: Float, duration: TimeInterval) {
        if amplitude >= configuration.speechThreshold {
            speechAccumulatedDuration += duration
            silenceAccumulatedDuration = 0

            if amplitude >= configuration.speechOnsetThreshold {
                onsetAccumulatedDuration += duration
            } else {
                onsetAccumulatedDuration = 0
            }

            if onsetAccumulatedDuration >= configuration.speechOnsetDuration
                || speechAccumulatedDuration >= configuration.speechStartDuration {
                isSpeaking = true
                speechAccumulatedDuration = 0
                onsetAccumulatedDuration = 0
                onSpeechDetected?()
            }

            return
        }

        speechAccumulatedDuration = 0
        onsetAccumulatedDuration = 0
        silenceAccumulatedDuration = 0
    }

    private func handleSpeakingBuffer(amplitude: Float, duration: TimeInterval) {
        if amplitude >= configuration.speechThreshold {
            silenceAccumulatedDuration = 0
            return
        }

        silenceAccumulatedDuration += duration

        if silenceAccumulatedDuration >= configuration.silenceDuration {
            isSpeaking = false
            silenceAccumulatedDuration = 0
            onSpeechEnded?()
        }
    }

    private func bufferDuration(for buffer: AVAudioPCMBuffer) -> TimeInterval {
        guard buffer.format.sampleRate > 0 else {
            return 0
        }

        return TimeInterval(buffer.frameLength) / buffer.format.sampleRate
    }

    private func peakAmplitude(for buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return 0
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        guard channelCount > 0, frameCount > 0 else {
            return 0
        }

        var peak: Float = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]

            for frame in 0..<frameCount {
                peak = max(peak, abs(samples[frame]))
            }
        }

        return peak
    }
}
