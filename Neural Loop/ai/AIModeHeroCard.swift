import SwiftUI

struct AIModeHeroCard: View, Equatable {
    let state: AIModeViewState.Hero

    static func == (lhs: AIModeHeroCard, rhs: AIModeHeroCard) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(AIModeTransitionCopy.pageTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(AIModeTheme.Surface.textTertiaryOpacity))

                Text(state.title)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(AIModeTheme.Surface.textPrimaryOpacity))
                    .fixedSize(horizontal: false, vertical: true)

                Text(state.detail)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(AIModeTheme.Surface.textSecondaryOpacity))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let badgeText = state.badgeText {
                AIModeStatusBadge(
                    text: badgeText,
                    tint: AIModeTheme.statusTint(for: state.tintState)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AIModeCardBackground(isHero: false))
    }
}

private struct AIModeStatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(AIModeTheme.Surface.textPrimaryOpacity))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(AIModeTheme.badgeFill)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(AIModeTheme.badgeBorder, lineWidth: 1)
        }
    }
}

struct AIModeCardBackground: View {
    var isHero = false

    var body: some View {
        RoundedRectangle(
            cornerRadius: AIModeTheme.Metrics.cardCornerRadius,
            style: .continuous
        )
        .fill(isHero ? AIModeTheme.heroCardFill : AIModeTheme.cardFill)
        .background(
            RoundedRectangle(
                cornerRadius: AIModeTheme.Metrics.cardCornerRadius,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AIModeTheme.Metrics.cardCornerRadius,
                style: .continuous
            )
            .strokeBorder(AIModeTheme.highlightBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
    }
}
