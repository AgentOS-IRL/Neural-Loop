import AVFoundation
import XCTest
@testable import Neural_Loop

final class AudioInterruptionDetectorTests: XCTestCase {
    func testSustainedSpeechLikeBuffersEmitPossibleThenConfirmed() {
        let detector = AudioInterruptionDetector(
            configuration: .init(
                speechThreshold: 0.1,
                possibleOnsetThreshold: 0.2,
                possibleOnsetDuration: 0.01,
                confirmedDuration: 0.03,
                silenceDuration: 0.02
            )
        )

        var events: [AudioInterruptionDetectionEvent] = []
        detector.onEvent = { events.append($0) }

        detector.process(makeBuffer(amplitude: 0.25))
        detector.process(makeBuffer(amplitude: 0.25))
        detector.process(makeBuffer(amplitude: 0.25))

        XCTAssertEqual(events, [.possible, .confirmed])
    }

    func testSingleLoudTransientDoesNotConfirmInterruption() {
        let detector = AudioInterruptionDetector(
            configuration: .init(
                speechThreshold: 0.1,
                possibleOnsetThreshold: 0.2,
                possibleOnsetDuration: 0.02,
                confirmedDuration: 0.04,
                silenceDuration: 0.02
            )
        )

        var events: [AudioInterruptionDetectionEvent] = []
        detector.onEvent = { events.append($0) }

        detector.process(makeBuffer(amplitude: 0.25, frameCount: 80))
        detector.process(makeBuffer(amplitude: 0.0, frameCount: 80))

        XCTAssertTrue(events.isEmpty)
    }

    func testSilenceResetsPossibleState() {
        let detector = AudioInterruptionDetector(
            configuration: .init(
                speechThreshold: 0.1,
                possibleOnsetThreshold: 0.2,
                possibleOnsetDuration: 0.01,
                confirmedDuration: 0.03,
                silenceDuration: 0.02
            )
        )

        var events: [AudioInterruptionDetectionEvent] = []
        detector.onEvent = { events.append($0) }

        detector.process(makeBuffer(amplitude: 0.25))
        detector.process(makeBuffer(amplitude: 0.0))
        detector.process(makeBuffer(amplitude: 0.0))
        detector.process(makeBuffer(amplitude: 0.25))
        detector.process(makeBuffer(amplitude: 0.25))

        XCTAssertEqual(events, [.possible, .ended, .possible])
    }

    func testDetectorEmitsOnlyOneConfirmationPerInterval() {
        let detector = AudioInterruptionDetector(
            configuration: .init(
                speechThreshold: 0.1,
                possibleOnsetThreshold: 0.2,
                possibleOnsetDuration: 0.01,
                confirmedDuration: 0.02,
                silenceDuration: 0.02
            )
        )

        var confirmedCount = 0
        detector.onEvent = { event in
            if event == .confirmed {
                confirmedCount += 1
            }
        }

        detector.process(makeBuffer(amplitude: 0.25))
        detector.process(makeBuffer(amplitude: 0.25))
        detector.process(makeBuffer(amplitude: 0.25))
        detector.process(makeBuffer(amplitude: 0.25))

        XCTAssertEqual(confirmedCount, 1)
    }

    func testResetClearsState() {
        let detector = AudioInterruptionDetector(
            configuration: .init(
                speechThreshold: 0.1,
                possibleOnsetThreshold: 0.2,
                possibleOnsetDuration: 0.01,
                confirmedDuration: 0.03,
                silenceDuration: 0.02
            )
        )

        var events: [AudioInterruptionDetectionEvent] = []
        detector.onEvent = { events.append($0) }

        detector.process(makeBuffer(amplitude: 0.25, frameCount: 80))
        detector.reset()
        detector.process(makeBuffer(amplitude: 0.25))
        detector.process(makeBuffer(amplitude: 0.25))

        XCTAssertEqual(events, [.possible])
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
