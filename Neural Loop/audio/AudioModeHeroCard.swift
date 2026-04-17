import SwiftUI

struct AudioModeHeroCard: View, Equatable {
    let state: AudioModeViewState.Hero
    let isReduceMotionEnabled: Bool
    let isPulsing: Bool
    let onTapMic: () -> Void

    static func == (lhs: AudioModeHeroCard, rhs: AudioModeHeroCard) -> Bool {
        lhs.state == rhs.state
        && lhs.isReduceMotionEnabled == rhs.isReduceMotionEnabled
        && lhs.isPulsing == rhs.isPulsing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AudioModeTheme.Metrics.cardSpacing) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio Mode")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textTertiaryOpacity))

                    Text(state.title)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textPrimaryOpacity))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(state.detail)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
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

            Button(action: onTapMic) {
                ZStack {
                    if !isReduceMotionEnabled {
                        Circle()
                            .strokeBorder(
                                AudioModeTheme.statusTint(for: state.tintState).opacity(0.62),
                                lineWidth: 2
                            )
                            .frame(
                                width: AudioModeTheme.Metrics.heroOrbitSize,
                                height: AudioModeTheme.Metrics.heroOrbitSize
                            )
                            .scaleEffect(isPulsing ? 1.12 : 0.94)
                            .opacity(isPulsing ? 0.18 : 0.76)

                        Circle()
                            .strokeBorder(
                                AudioModeTheme.statusTint(for: state.tintState).opacity(0.44),
                                lineWidth: 10
                            )
                            .frame(
                                width: AudioModeTheme.Metrics.heroSecondaryOrbitSize,
                                height: AudioModeTheme.Metrics.heroSecondaryOrbitSize
                            )
                            .scaleEffect(isPulsing ? 1.10 : 0.98)
                            .opacity(isPulsing ? 0.28 : 0.80)
                    }

                    Circle()
                        .fill(AudioModeTheme.heroCardFill)
                        .overlay {
                            Circle()
                                .fill(AudioModeTheme.actionGradient)
                                .opacity(0.08)
                                .blur(radius: 18)
                        }
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    AudioModeTheme.highlightBorder,
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: AudioModeTheme.heroGlow, radius: 18, y: 12)
                        .frame(
                            width: AudioModeTheme.Metrics.heroMicSize,
                            height: AudioModeTheme.Metrics.heroMicSize
                        )

                    Image(systemName: state.microphoneSystemImage)
                        .font(.system(size: state.isRecording ? 56 : 68, weight: .bold))
                        .foregroundStyle(.white.opacity(0.96))
                        .shadow(color: .black.opacity(0.30), radius: 8, y: 3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: AudioModeTheme.Metrics.heroOrbitSize + 16)
            }
            .buttonStyle(.plain)
            .disabled(state.isActionDisabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.micButtonLabel)
            .accessibilityHint(
                state.isRecording
                ? "Stops the current session and clears saved transcript history."
                : "Starts a new continuous voice session."
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AudioModeCardBackground(isHero: true))
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
