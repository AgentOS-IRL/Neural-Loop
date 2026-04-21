import AVFoundation
import Foundation
#if DEBUG
import OSLog
#endif

enum AudioInterruptionDetectionEvent: Equatable {
    case possible
    case confirmed
    case ended
}

final class AudioInterruptionDetector {
    struct Configuration: Equatable {
        var speechThreshold: Float = 0.08
        var possibleOnsetThreshold: Float = 0.14
        var possibleOnsetDuration: TimeInterval = 0.04
        var confirmedDuration: TimeInterval = 0.14
        var silenceDuration: TimeInterval = 0.20
    }

    var onEvent: ((AudioInterruptionDetectionEvent) -> Void)?

    private let configuration: Configuration
    private let levelAnalyzer = AudioLevelAnalyzer()
    private var accumulatedSpeechDuration: TimeInterval = 0
    private var accumulatedOnsetDuration: TimeInterval = 0
    private var accumulatedSilenceDuration: TimeInterval = 0
    private var didEmitPossible = false
    private var didEmitConfirmed = false

    #if DEBUG
    private let isDebugMetricsLoggingEnabled: Bool
    private let logger = Logger(subsystem: "NeuralLoop", category: "AudioInterruptionDetector")
    private var processedBufferCount = 0
    private var accumulatedProcessingNanoseconds: UInt64 = 0
    private(set) var debugMetrics = DebugMetrics()
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
        accumulatedSpeechDuration = 0
        accumulatedOnsetDuration = 0
        accumulatedSilenceDuration = 0
        didEmitPossible = false
        didEmitConfirmed = false
        #if DEBUG
        processedBufferCount = 0
        accumulatedProcessingNanoseconds = 0
        debugMetrics.resetCount += 1
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
        if amplitude >= configuration.speechThreshold {
            handleActiveBuffer(amplitude: amplitude, duration: duration)
        } else {
            handleSilentBuffer(duration: duration)
        }
    }

    private func handleActiveBuffer(amplitude: Float, duration: TimeInterval) {
        accumulatedSilenceDuration = 0
        accumulatedSpeechDuration += duration

        if amplitude >= configuration.possibleOnsetThreshold {
            accumulatedOnsetDuration += duration
        } else {
            accumulatedOnsetDuration = 0
        }

        if !didEmitPossible,
           accumulatedOnsetDuration >= configuration.possibleOnsetDuration
            || accumulatedSpeechDuration >= configuration.possibleOnsetDuration {
            didEmitPossible = true
            #if DEBUG
            debugMetrics.possibleCount += 1
            #endif
            emit(.possible)
        }

        if !didEmitConfirmed,
           (didEmitPossible || accumulatedSpeechDuration >= configuration.possibleOnsetDuration),
           accumulatedSpeechDuration >= configuration.confirmedDuration {
            didEmitConfirmed = true
            #if DEBUG
            debugMetrics.confirmedCount += 1
            logger.debug("Interruption confirmed after \(self.accumulatedSpeechDuration, privacy: .public)s of speech")
            #endif
            emit(.confirmed)
        }
    }

    private func handleSilentBuffer(duration: TimeInterval) {
        guard didEmitPossible || didEmitConfirmed else {
            accumulatedSpeechDuration = 0
            accumulatedOnsetDuration = 0
            accumulatedSilenceDuration = 0
            return
        }

        accumulatedSpeechDuration = 0
        accumulatedOnsetDuration = 0
        accumulatedSilenceDuration += duration

        if accumulatedSilenceDuration >= configuration.silenceDuration {
            reset()
            #if DEBUG
            debugMetrics.endedCount += 1
            #endif
            emit(.ended)
        }
    }

    private func bufferDuration(for buffer: AVAudioPCMBuffer) -> TimeInterval {
        guard buffer.format.sampleRate > 0 else {
            return 0
        }

        return TimeInterval(buffer.frameLength) / buffer.format.sampleRate
    }

    private func emit(_ event: AudioInterruptionDetectionEvent) {
        onEvent?(event)
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
        debugPrint("AudioInterruptionDetector average process(_:) duration: \(averageMilliseconds) ms")
    }

    struct DebugMetrics: Equatable {
        var possibleCount = 0
        var confirmedCount = 0
        var endedCount = 0
        var resetCount = 0
    }
    #endif
}
