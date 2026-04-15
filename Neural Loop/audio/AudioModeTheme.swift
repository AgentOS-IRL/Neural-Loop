import SwiftUI

enum AudioModeTheme {
    enum Metrics {
        static let screenPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 18
        static let cardSpacing: CGFloat = 16
        static let cardCornerRadius: CGFloat = 28
        static let innerCornerRadius: CGFloat = 20
        static let heroMicSize: CGFloat = 176
        static let heroOrbitSize: CGFloat = 222
        static let heroSecondaryOrbitSize: CGFloat = 148
    }

    static let baseBackground = LinearGradient(
        colors: [
            Color(red: 0.03, green: 0.06, blue: 0.11),
            Color(red: 0.02, green: 0.03, blue: 0.08),
            Color(red: 0.01, green: 0.01, blue: 0.03)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroCardFill = LinearGradient(
        colors: [
            Color.white.opacity(0.17),
            Color.white.opacity(0.07)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = LinearGradient(
        colors: [
            Color.white.opacity(0.12),
            Color.white.opacity(0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let highlightBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.34),
            Color.white.opacity(0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let actionGradient = LinearGradient(
        colors: [
            Color(red: 0.78, green: 0.93, blue: 1.0),
            Color(red: 0.53, green: 0.83, blue: 0.99)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func statusTint(for state: AudioTranscriptionDisplayState) -> Color {
        switch state {
        case .inactive:
            return Color(red: 0.70, green: 0.84, blue: 1.0)
        case .checkingPermissions:
            return Color(red: 0.93, green: 0.79, blue: 0.43)
        case .listening:
            return .cyan
        case .transcribing:
            return .mint
        case .cooldown:
            return Color(red: 0.60, green: 0.88, blue: 1.0)
        case .unavailable:
            return Color(red: 1.0, green: 0.62, blue: 0.40)
        }
    }

    static func messageBackground(for role: AudioTranscriptMessageRole) -> LinearGradient {
        let colors: [Color]
        switch role {
        case .user:
            colors = [
                Color.white.opacity(0.15),
                Color.white.opacity(0.07)
            ]
        case .assistant:
            colors = [
                Color(red: 0.16, green: 0.36, blue: 0.34).opacity(0.82),
                Color(red: 0.10, green: 0.18, blue: 0.24).opacity(0.90)
            ]
        case .toolResult:
            colors = [
                Color(red: 0.10, green: 0.32, blue: 0.21).opacity(0.84),
                Color(red: 0.06, green: 0.18, blue: 0.14).opacity(0.90)
            ]
        case .status:
            colors = [
                Color(red: 0.15, green: 0.21, blue: 0.31).opacity(0.84),
                Color(red: 0.09, green: 0.14, blue: 0.22).opacity(0.92)
            ]
        case .error:
            colors = [
                Color(red: 0.34, green: 0.12, blue: 0.16).opacity(0.88),
                Color(red: 0.20, green: 0.07, blue: 0.10).opacity(0.94)
            ]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func messageBorder(for role: AudioTranscriptMessageRole) -> Color {
        switch role {
        case .user:
            return Color.white.opacity(0.11)
        case .assistant:
            return .mint.opacity(0.26)
        case .toolResult:
            return .green.opacity(0.28)
        case .status:
            return .cyan.opacity(0.24)
        case .error:
            return .red.opacity(0.30)
        }
    }

    static func messageIconColor(for role: AudioTranscriptMessageRole) -> Color {
        switch role {
        case .user:
            return Color(red: 0.91, green: 0.96, blue: 1.0)
        case .assistant:
            return .mint.opacity(0.95)
        case .toolResult:
            return .green.opacity(0.95)
        case .status:
            return .cyan.opacity(0.92)
        case .error:
            return .orange.opacity(0.96)
        }
    }

    static func bannerBorder(for tone: AudioModeBannerTone) -> Color {
        switch tone {
        case .info:
            return Color.white.opacity(0.16)
        case .warning:
            return .yellow.opacity(0.26)
        case .error:
            return .red.opacity(0.30)
        }
    }

    static func bannerIconColor(for tone: AudioModeBannerTone) -> Color {
        switch tone {
        case .info:
            return .cyan.opacity(0.95)
        case .warning:
            return .yellow.opacity(0.95)
        case .error:
            return .orange.opacity(0.96)
        }
    }
}
