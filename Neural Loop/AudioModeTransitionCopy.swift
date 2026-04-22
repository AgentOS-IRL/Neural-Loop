import Foundation

enum AudioModeTransitionCopy {
    static let pageTitle = "AI"
    static let activeStatusTitle = "AI ready"
    static let activeStatusDetail = "Voice capture can send committed segments to Codex."

    static func availabilityMessage(
        secretsLoaded: Bool,
        canUseAudioMode: Bool
    ) -> String {
        if !secretsLoaded {
            return "AI stays unavailable until secrets finish loading."
        }

        if canUseAudioMode {
            return "AI is ready for voice capture and Codex actions."
        }

        return "AI requires both the \(codexAuthTokenSecretKey) and \(chatgptAccountIDSecretKey) secrets in public.secrets."
    }
}
