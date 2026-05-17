import XCTest
@testable import Neural_Loop

final class AIModeTransitionCopyTests: XCTestCase {
    func testAvailabilityMessageExplainsLoadingState() {
        XCTAssertEqual(
            AIModeTransitionCopy.availabilityMessage(secretsLoaded: false, canUseAIMode: false),
            "AI stays unavailable until secrets finish loading."
        )
    }

    func testAvailabilityMessageExplainsMissingSecretsState() {
        XCTAssertEqual(
            AIModeTransitionCopy.availabilityMessage(secretsLoaded: true, canUseAIMode: false),
            "AI requires both the \(codexAuthTokenSecretKey) and \(chatgptAccountIDSecretKey) secrets in public.secrets."
        )
    }

    func testAvailabilityMessageExplainsReadyState() {
        XCTAssertEqual(
            AIModeTransitionCopy.availabilityMessage(secretsLoaded: true, canUseAIMode: true),
            "AI is ready for voice capture and Codex actions."
        )
    }
}
