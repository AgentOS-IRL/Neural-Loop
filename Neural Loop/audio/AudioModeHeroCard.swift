import SwiftUI

struct AudioModeHeroCard: View, Equatable {
    let state: AudioModeViewState.Hero

    static func == (lhs: AudioModeHeroCard, rhs: AudioModeHeroCard) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(AudioModeTransitionCopy.pageTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textTertiaryOpacity))

                Text(state.title)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textPrimaryOpacity))
                    .fixedSize(horizontal: false, vertical: true)

                Text(state.detail)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textSecondaryOpacity))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let badgeText = state.badgeText {
                AudioModeStatusBadge(
                    text: badgeText,
                    tint: AudioModeTheme.statusTint(for: state.tintState)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AudioModeCardBackground(isHero: false))
    }
}

private struct AudioModeStatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textPrimaryOpacity))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(AudioModeTheme.badgeFill)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(AudioModeTheme.badgeBorder, lineWidth: 1)
        }
    }
}

struct AudioModeCardBackground: View {
    var isHero = false

    var body: some View {
        RoundedRectangle(
            cornerRadius: AudioModeTheme.Metrics.cardCornerRadius,
            style: .continuous
        )
        .fill(isHero ? AudioModeTheme.heroCardFill : AudioModeTheme.cardFill)
        .background(
            RoundedRectangle(
                cornerRadius: AudioModeTheme.Metrics.cardCornerRadius,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AudioModeTheme.Metrics.cardCornerRadius,
                style: .continuous
            )
            .strokeBorder(AudioModeTheme.highlightBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
    }
}
