import SwiftUI

enum AIModeTheme {
    enum Metrics {
        static let screenPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 18
        static let cardSpacing: CGFloat = 16
        static let cardCornerRadius: CGFloat = 28
        static let innerCornerRadius: CGFloat = 20
        static let heroMicSize: CGFloat = 176
        static let heroOrbitSize: CGFloat = 222
        static let heroSecondaryOrbitSize: CGFloat = 148
        static let bottomMicSize: CGFloat = 70
        static let bottomMicPulseSize: CGFloat = 94
        static let bottomComposerCornerRadius: CGFloat = 24
        static let chatMaxWidth: CGFloat = 840
    }

    enum Surface {
        static let primaryFillOpacity: Double = 0.10
        static let secondaryFillOpacity: Double = 0.07
        static let mutedFillOpacity: Double = 0.05
        static let primaryBorderOpacity: Double = 0.14
        static let secondaryBorderOpacity: Double = 0.10
        static let textPrimaryOpacity: Double = 0.94
        static let textSecondaryOpacity: Double = 0.78
        static let textTertiaryOpacity: Double = 0.62
        static let textMutedOpacity: Double = 0.54
    }

    static let baseBackground = LinearGradient(
        colors: [
            Color(red: 0.03, green: 0.06, blue: 0.11),
            Color(red: 0.02, green: 0.04, blue: 0.08),
            Color(red: 0.01, green: 0.02, blue: 0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backdropPrimaryGlow = Color(red: 0.36, green: 0.82, blue: 0.98)
    static let backdropSecondaryGlow = AppTheme.accentColor
    static let backdropTertiaryGlow = Color(red: 0.26, green: 0.91, blue: 0.76)
    static let backdropHighlightGlow = Color.white

    static let heroCardFill = LinearGradient(
        colors: [
            Color.white.opacity(0.13),
            Color.white.opacity(Surface.secondaryFillOpacity)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = LinearGradient(
        colors: [
            Color.white.opacity(Surface.primaryFillOpacity),
            Color.white.opacity(Surface.secondaryFillOpacity - 0.02)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let highlightBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.24),
            Color.white.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let actionGradient = AppTheme.accentGradient

    static let chipFill = Color.white.opacity(0.08)
    static let chipBorder = Color.white.opacity(0.10)
    static let badgeFill = Color.white.opacity(0.09)
    static let badgeBorder = Color.white.opacity(0.12)
    static let heroGlow = AppTheme.accentColor.opacity(0.22)

    static func statusTint(for state: AITranscriptionDisplayState) -> Color {
        switch state {
        case .inactive:
            return Color(red: 0.68, green: 0.83, blue: 0.99)
        case .checkingPermissions:
            return AppTheme.warningTint
        case .listening:
            return AppTheme.accentColor
        case .transcribing:
            return AppTheme.successTint
        case .cooldown:
            return Color(red: 0.54, green: 0.80, blue: 0.98)
        case .unavailable:
            return AppTheme.errorTint
        }
    }

    static func messageBackground(for role: AITranscriptMessageRole) -> LinearGradient {
        let colors: [Color]
        switch role {
        case .user:
            colors = [
                Color.white.opacity(0.12),
                Color.white.opacity(0.06)
            ]
        case .assistant:
            colors = [
                AppTheme.accentColor.opacity(0.28),
                Color(red: 0.07, green: 0.16, blue: 0.23).opacity(0.94)
            ]
        case .toolResult:
            colors = [
                AppTheme.successTint.opacity(0.22),
                Color(red: 0.05, green: 0.17, blue: 0.14).opacity(0.94)
            ]
        case .status:
            colors = [
                AppTheme.accentColor.opacity(0.22),
                Color(red: 0.08, green: 0.13, blue: 0.22).opacity(0.94)
            ]
        case .error:
            colors = [
                AppTheme.errorTint.opacity(0.26),
                Color(red: 0.20, green: 0.07, blue: 0.10).opacity(0.96)
            ]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func messageBorder(for role: AITranscriptMessageRole) -> Color {
        switch role {
        case .user:
            return Color.white.opacity(0.12)
        case .assistant:
            return AppTheme.accentColor.opacity(0.30)
        case .toolResult:
            return AppTheme.successTint.opacity(0.32)
        case .status:
            return AppTheme.accentColor.opacity(0.24)
        case .error:
            return AppTheme.errorTint.opacity(0.34)
        }
    }

    static func messageIconColor(for role: AITranscriptMessageRole) -> Color {
        switch role {
        case .user:
            return Color.white.opacity(0.90)
        case .assistant:
            return AppTheme.accentColor.opacity(0.96)
        case .toolResult:
            return AppTheme.successTint.opacity(0.96)
        case .status:
            return AppTheme.accentColor.opacity(0.92)
        case .error:
            return AppTheme.errorTint.opacity(0.96)
        }
    }

    static func messageLabelColor(for role: AITranscriptMessageRole) -> Color {
        switch role {
        case .user:
            return Color.white.opacity(Surface.textSecondaryOpacity)
        case .assistant:
            return AppTheme.accentColor.opacity(0.96)
        case .toolResult:
            return AppTheme.successTint.opacity(0.96)
        case .status:
            return AppTheme.accentColor.opacity(0.92)
        case .error:
            return AppTheme.errorTint.opacity(0.96)
        }
    }

    static func messageBodyColor(for role: AITranscriptMessageRole) -> Color {
        switch role {
        case .status:
            return Color.white.opacity(0.90)
        case .error:
            return Color.white.opacity(0.92)
        default:
            return Color.white.opacity(Surface.textPrimaryOpacity)
        }
    }

    static func bannerBackground(for tone: AIModeBannerTone) -> LinearGradient {
        switch tone {
        case .info:
            return LinearGradient(
                colors: [
                    AppTheme.accentColor.opacity(0.18),
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .warning:
            return LinearGradient(
                colors: [
                    AppTheme.warningTint.opacity(0.18),
                    Color(red: 0.18, green: 0.16, blue: 0.10).opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .error:
            return LinearGradient(
                colors: [
                    AppTheme.errorTint.opacity(0.22),
                    Color(red: 0.22, green: 0.08, blue: 0.11).opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func bannerBorder(for tone: AIModeBannerTone) -> Color {
        switch tone {
        case .info:
            return AppTheme.accentColor.opacity(0.22)
        case .warning:
            return AppTheme.warningTint.opacity(0.26)
        case .error:
            return AppTheme.errorTint.opacity(0.30)
        }
    }

    static func bannerIconColor(for tone: AIModeBannerTone) -> Color {
        switch tone {
        case .info:
            return AppTheme.accentColor.opacity(0.95)
        case .warning:
            return AppTheme.warningTint.opacity(0.95)
        case .error:
            return AppTheme.errorTint.opacity(0.96)
        }
    }
}
