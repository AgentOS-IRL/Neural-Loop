import XCTest
@testable import Neural_Loop

final class AudioModeTransitionCopyTests: XCTestCase {
    func testAvailabilityMessageExplainsLoadingState() {
        XCTAssertEqual(
            AudioModeTransitionCopy.availabilityMessage(secretsLoaded: false, canUseAudioMode: false),
            "AI stays unavailable until secrets finish loading."
        )
    }

    func testAvailabilityMessageExplainsMissingSecretsState() {
        XCTAssertEqual(
            AudioModeTransitionCopy.availabilityMessage(secretsLoaded: true, canUseAudioMode: false),
            "AI requires both the \(codexAuthTokenSecretKey) and \(chatgptAccountIDSecretKey) secrets in public.secrets."
        )
    }

    func testAvailabilityMessageExplainsReadyState() {
        XCTAssertEqual(
            AudioModeTransitionCopy.availabilityMessage(secretsLoaded: true, canUseAudioMode: true),
            "AI is ready for voice capture and Codex actions."
        )
    }
}
