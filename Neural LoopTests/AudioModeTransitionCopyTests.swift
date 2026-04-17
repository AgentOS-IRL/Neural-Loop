import XCTest
@testable import Neural_Loop

final class AudioModeTransitionCopyTests: XCTestCase {
    func testAvailabilityMessageExplainsLoadingState() {
        XCTAssertEqual(
            AudioModeTransitionCopy.availabilityMessage(secretsLoaded: false, canUseAudioMode: false),
            "Audio Mode stays unavailable until secrets finish loading."
        )
    }

    func testAvailabilityMessageExplainsMissingSecretsState() {
        XCTAssertEqual(
            AudioModeTransitionCopy.availabilityMessage(secretsLoaded: true, canUseAudioMode: false),
            "Audio Mode requires both the \(codexAuthTokenSecretKey) and \(chatgptAccountIDSecretKey) secrets in public.secrets."
        )
    }

    func testAvailabilityMessageExplainsReadyState() {
        XCTAssertEqual(
            AudioModeTransitionCopy.availabilityMessage(secretsLoaded: true, canUseAudioMode: true),
            "Audio Mode is ready when you want a voice-first shell."
        )
    }
}
