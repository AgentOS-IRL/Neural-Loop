import Foundation

enum AudioModeTransitionCopy {
    static let modeTitle = "Audio Mode"
    static let manualModeTitle = "Manual Mode"
    static let enterActionTitle = "Enter Audio Mode"
    static let returnActionTitle = "Return to Manual Mode"

    static let settingsSummary = "Voice-first capture for hands-free dictation, Codex replies, and a quick return to manual mode."
    static let idleStatusTitle = "Ready to listen"
    static let idleStatusDetail = "Tap the mic to start a new voice session."
    static let idleStatusBadge = "Idle"

    static let listeningStatusTitle = "Listening for your next phrase"
    static let listeningStatusDetail = "Voice capture is live and ready for the next segment."
    static let listeningStatusBadge = "Listening"

    static let processingStatusTitle = "Processing your transcript"
    static let processingStatusDetail = "Committed speech is being sent to Codex."
    static let processingStatusBadge = "Processing"

    static let speakingStatusTitle = "Speaking a reply aloud"
    static let speakingStatusDetail = "Codex is reading the latest response and listening will pause until it ends."
    static let speakingStatusBadge = "Speaking"

    static let interruptingStatusTitle = "Stopping the current reply"
    static let interruptingStatusDetail = "The active response is being cut short so listening can recover."
    static let interruptingStatusBadge = "Interrupted"

    static let recoveringStatusTitle = "Recovering after interruption"
    static let recoveringStatusDetail = "Speech has stopped and the mic is settling back into listening."
    static let recoveringStatusBadge = "Recovering"

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
