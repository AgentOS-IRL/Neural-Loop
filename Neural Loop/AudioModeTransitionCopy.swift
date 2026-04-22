import Foundation

enum AudioModeTransitionCopy {
    static let modeTitle = "Audio Mode"
    static let manualModeTitle = "Manual Mode"
    static let enterActionTitle = "Enter Audio Mode"
    static let returnActionTitle = "Return to Manual Mode"

    static let settingsSummary = "Voice-first capture for hands-free dictation, Codex replies, and a quick return to manual mode."
    static let activeStatusTitle = "Audio Mode active"
    static let activeStatusDetail = "Leave the audio shell and return to Manual Mode."

    static func availabilityMessage(
        secretsLoaded: Bool,
        canUseAudioMode: Bool
    ) -> String {
        if !secretsLoaded {
            return "Audio Mode stays unavailable until secrets finish loading."
        }

        if canUseAudioMode {
            return "Audio Mode is ready when you want a voice-first shell."
        }

        return "Audio Mode requires both the \(codexAuthTokenSecretKey) and \(chatgptAccountIDSecretKey) secrets in public.secrets."
    }

    static var entryAccessibilityHint: String {
        "Enters Audio Mode and switches the app to the voice-first shell."
    }

    static var returnAccessibilityHint: String {
        "Leaves Audio Mode and returns to the manual app shell."
    }
}
