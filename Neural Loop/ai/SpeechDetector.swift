import Foundation
import AVFoundation
import Accelerate

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
        var speechOnsetDuration: TimeInterval = 0.02
        var speechStartDuration: TimeInterval = 0.07
        var silenceDuration: TimeInterval = 0.45
    }

    var onSpeechDetected: (() -> Void)?
    var onSpeechEnded: (() -> Void)?

    private let configuration: Configuration
    private let levelAnalyzer = AudioLevelAnalyzer()
    private var isSpeaking = false
    private var speechAccumulatedDuration: TimeInterval = 0
    private var onsetAccumulatedDuration: TimeInterval = 0
    private var silenceAccumulatedDuration: TimeInterval = 0

    #if DEBUG
    private let isDebugMetricsLoggingEnabled: Bool
    private var processedBufferCount = 0
    private var accumulatedProcessingNanoseconds: UInt64 = 0
    #endif

    init(
        configuration: Configuration = Configuration(),
        isDebugMetricsLoggingEnabled: Bool = false
    ) {
        self.configuration = configuration
        #if DEBUG
        self.isDebugMetricsLoggingEnabled = isDebugMetricsLoggingEnabled
        #endif
    }

    func reset() {
        isSpeaking = false
        speechAccumulatedDuration = 0
        onsetAccumulatedDuration = 0
        silenceAccumulatedDuration = 0
        #if DEBUG
        processedBufferCount = 0
        accumulatedProcessingNanoseconds = 0
        #endif
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        #if DEBUG
        let metricsStart: UInt64?
        if isDebugMetricsLoggingEnabled {
            metricsStart = DispatchTime.now().uptimeNanoseconds
        } else {
            metricsStart = nil
        }
        defer {
            if let metricsStart {
                recordProcessingDuration(start: metricsStart)
            }
        }
        #endif

        let duration = bufferDuration(for: buffer)
        guard duration > 0 else {
            return
        }

        let amplitude = levelAnalyzer.peakAmplitude(for: buffer)

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

            if amplitude > configuration.speechOnsetThreshold {
                onsetAccumulatedDuration += duration
            } else {
                onsetAccumulatedDuration = 0
            }

            if onsetAccumulatedDuration >= configuration.speechOnsetDuration
                || speechAccumulatedDuration >= configuration.speechStartDuration {
                isSpeaking = true
                speechAccumulatedDuration = 0
                onsetAccumulatedDuration = 0
                emit(.speechStarted)
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
            emit(.speechEnded)
        }
    }

    private func bufferDuration(for buffer: AVAudioPCMBuffer) -> TimeInterval {
        guard buffer.format.sampleRate > 0 else {
            return 0
        }

        return TimeInterval(buffer.frameLength) / buffer.format.sampleRate
    }

    private func emit(_ event: SpeechEvent) {
        switch event {
        case .speechStarted:
            onSpeechDetected?()
        case .speechEnded:
            onSpeechEnded?()
        }
    }

    #if DEBUG
    private func recordProcessingDuration(start: UInt64) {
        let duration = DispatchTime.now().uptimeNanoseconds - start
        processedBufferCount += 1
        accumulatedProcessingNanoseconds += duration

        guard processedBufferCount.isMultiple(of: 500) else {
            return
        }

        let averageMilliseconds = Double(accumulatedProcessingNanoseconds) / Double(processedBufferCount) / 1_000_000
        debugPrint("SpeechDetector average process(_:) duration: \(averageMilliseconds) ms")
    }
    #endif
}

enum SpeechEvent: Equatable {
    case speechStarted
    case speechEnded
}

struct AudioLevelAnalyzer {
    func peakAmplitude(for buffer: AVAudioPCMBuffer) -> Float {
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
            var channelPeak: Float = 0
            vDSP_maxmgv(
                samples,
                vDSP_Stride(1),
                &channelPeak,
                vDSP_Length(frameCount)
            )
            peak = max(peak, channelPeak)
        }

        return peak
    }
}
