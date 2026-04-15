import AVFoundation
import XCTest
@testable import Neural_Loop

final class SpeechDetectorTests: XCTestCase {
    func testSpeechStartDetectionFiresAfterEnoughLoudAudio() {
        let detector = SpeechDetector(
            configuration: .init(
                speechThreshold: 0.1,
                speechOnsetThreshold: 0.2,
                speechOnsetDuration: 0.01,
                speechStartDuration: 0.02,
                silenceDuration: 0.02
            )
        )

        var detectedCount = 0
        detector.onSpeechDetected = {
            detectedCount += 1
        }

        detector.process(makeBuffer(amplitude: 0.2))
        XCTAssertEqual(detectedCount, 0)

        detector.process(makeBuffer(amplitude: 0.2))
        XCTAssertEqual(detectedCount, 1)

        detector.process(makeBuffer(amplitude: 0.2))
        XCTAssertEqual(detectedCount, 1)
    }

    func testSpeechEndDetectionFiresAfterSilenceWindow() {
        let detector = SpeechDetector(
            configuration: .init(
                speechThreshold: 0.1,
                speechOnsetThreshold: 0.2,
                speechOnsetDuration: 0.01,
                speechStartDuration: 0.02,
                silenceDuration: 0.02
            )
        )

        var endedCount = 0
        detector.onSpeechEnded = {
            endedCount += 1
        }

        detector.process(makeBuffer(amplitude: 0.2))
        detector.process(makeBuffer(amplitude: 0.2))
        XCTAssertEqual(endedCount, 0)

        detector.process(makeBuffer(amplitude: 0.0))
        XCTAssertEqual(endedCount, 0)

        detector.process(makeBuffer(amplitude: 0.0))
        XCTAssertEqual(endedCount, 1)
    }

    func testSpeechEndWindowResetsWhenVoiceReturns() {
        let detector = SpeechDetector(
            configuration: .init(
                speechThreshold: 0.1,
                speechOnsetThreshold: 0.2,
                speechOnsetDuration: 0.01,
                speechStartDuration: 0.02,
                silenceDuration: 0.02
            )
        )

        var detectedCount = 0
        var endedCount = 0
        detector.onSpeechDetected = {
            detectedCount += 1
        }
        detector.onSpeechEnded = {
            endedCount += 1
        }

        detector.process(makeBuffer(amplitude: 0.2))
        detector.process(makeBuffer(amplitude: 0.2))
        XCTAssertEqual(detectedCount, 1)

        detector.process(makeBuffer(amplitude: 0.0))
        detector.process(makeBuffer(amplitude: 0.2))
        detector.process(makeBuffer(amplitude: 0.2))

        XCTAssertEqual(endedCount, 0)
        XCTAssertEqual(detectedCount, 1)
    }

    func testSpeechStartDetectionUsesFasterOnsetWindowForStrongSpeech() {
        let detector = SpeechDetector(
            configuration: .init(
                speechThreshold: 0.1,
                speechOnsetThreshold: 0.2,
                speechOnsetDuration: 0.01,
                speechStartDuration: 0.03,
                silenceDuration: 0.02
            )
        )

        var detectedCount = 0
        detector.onSpeechDetected = {
            detectedCount += 1
        }

        detector.process(makeBuffer(amplitude: 0.24))

        XCTAssertEqual(detectedCount, 1)
    }

    func testSpeechStartDetectionDoesNotUseFastOnsetAtThresholdBoundary() {
        let detector = SpeechDetector(
            configuration: .init(
                speechThreshold: 0.1,
                speechOnsetThreshold: 0.2,
                speechOnsetDuration: 0.01,
                speechStartDuration: 0.02,
                silenceDuration: 0.02
            )
        )

        var detectedCount = 0
        detector.onSpeechDetected = {
            detectedCount += 1
        }

        detector.process(makeBuffer(amplitude: 0.2))
        XCTAssertEqual(detectedCount, 0)

        detector.process(makeBuffer(amplitude: 0.2))
        XCTAssertEqual(detectedCount, 1)
    }

    func testSpeechStartDetectionIgnoresSingleTransientAboveOnsetThreshold() {
        let detector = SpeechDetector(
            configuration: .init(
                speechThreshold: 0.1,
                speechOnsetThreshold: 0.2,
                speechOnsetDuration: 0.02,
                speechStartDuration: 0.03,
                silenceDuration: 0.02
            )
        )

        var detectedCount = 0
        detector.onSpeechDetected = {
            detectedCount += 1
        }

        detector.process(makeBuffer(amplitude: 0.3))
        detector.process(makeBuffer(amplitude: 0.0))

        XCTAssertEqual(detectedCount, 0)
    }

    func testResetClearsOnsetProgress() {
        let detector = SpeechDetector(
            configuration: .init(
                speechThreshold: 0.1,
                speechOnsetThreshold: 0.2,
                speechOnsetDuration: 0.02,
                speechStartDuration: 0.03,
                silenceDuration: 0.02
            )
        )

        var detectedCount = 0
        detector.onSpeechDetected = {
            detectedCount += 1
        }

        detector.process(makeBuffer(amplitude: 0.3))
        detector.reset()
        detector.process(makeBuffer(amplitude: 0.3))

        XCTAssertEqual(detectedCount, 0)
    }

    private func makeBuffer(
        amplitude: Float = 0,
        frameCount: AVAudioFrameCount = 160,
        sampleRate: Double = 16_000
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        if let data = buffer.floatChannelData {
            let samples = data[0]
            for index in 0..<Int(frameCount) {
                samples[index] = amplitude
            }
        }

        return buffer
    }
}
