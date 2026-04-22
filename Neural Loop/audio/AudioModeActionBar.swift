import SwiftUI

struct AudioModeVoiceInputBar: View, Equatable {
    let micState: AudioModeViewState.Hero
    let transcriptState: AudioModeViewState.Transcript
    let actionBarState: AudioModeViewState.ActionBar
    let isReduceMotionEnabled: Bool
    let isPulsing: Bool
    let onTapMic: () -> Void

    static func == (lhs: AudioModeVoiceInputBar, rhs: AudioModeVoiceInputBar) -> Bool {
        lhs.micState == rhs.micState
        && lhs.transcriptState == rhs.transcriptState
        && lhs.actionBarState == rhs.actionBarState
        && lhs.isReduceMotionEnabled == rhs.isReduceMotionEnabled
        && lhs.isPulsing == rhs.isPulsing
    }

    var body: some View {
        VStack(spacing: 12) {
            statusChips

            transcriptPreview

            Button(action: onTapMic) {
                ZStack {
                    if !isReduceMotionEnabled {
                        Circle()
                            .strokeBorder(
                                AudioModeTheme.statusTint(for: micState.tintState).opacity(0.52),
                                lineWidth: 2
                            )
                            .frame(
                                width: AudioModeTheme.Metrics.bottomMicPulseSize,
                                height: AudioModeTheme.Metrics.bottomMicPulseSize
                            )
                            .scaleEffect(isPulsing ? 1.06 : 0.94)
                            .opacity(isPulsing ? 0.18 : 0.62)
                    }

                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .fill(AudioModeTheme.actionGradient)
                                .opacity(micState.isActionDisabled ? 0.04 : 0.16)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(AudioModeTheme.highlightBorder, lineWidth: 1)
                        }
                        .shadow(color: AudioModeTheme.heroGlow, radius: micState.isActionDisabled ? 8 : 16, y: 8)
                        .frame(
                            width: AudioModeTheme.Metrics.bottomMicSize,
                            height: AudioModeTheme.Metrics.bottomMicSize
                        )

                    Image(systemName: micState.microphoneSystemImage)
                        .font(.system(size: micState.isRecording ? 25 : 29, weight: .bold))
                        .foregroundStyle(.white.opacity(micState.isActionDisabled ? 0.48 : 0.96))
                        .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
                }
                .frame(
                    width: AudioModeTheme.Metrics.bottomMicPulseSize,
                    height: AudioModeTheme.Metrics.bottomMicPulseSize
                )
            }
            .buttonStyle(.plain)
            .disabled(micState.isActionDisabled)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(micState.micButtonLabel)
            .accessibilityHint(
                micState.isRecording
                ? "Stops the current session and clears saved transcript history."
                : "Starts a new continuous voice session."
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(
                cornerRadius: AudioModeTheme.Metrics.bottomComposerCornerRadius,
                style: .continuous
            )
            .fill(AudioModeTheme.cardFill)
            .background(
                RoundedRectangle(
                    cornerRadius: AudioModeTheme.Metrics.bottomComposerCornerRadius,
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: AudioModeTheme.Metrics.bottomComposerCornerRadius,
                    style: .continuous
                )
                .strokeBorder(AudioModeTheme.highlightBorder, lineWidth: 1)
            }
        )
    }

    @ViewBuilder
    private var statusChips: some View {
        if !actionBarState.primaryStatusChips.isEmpty {
            HStack(spacing: 8) {
                ForEach(actionBarState.primaryStatusChips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textSecondaryOpacity))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AudioModeTheme.chipFill)
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(AudioModeTheme.chipBorder, lineWidth: 1)
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var transcriptPreview: some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: transcriptState.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AudioModeTheme.statusTint(for: micState.tintState))

                Text(transcriptTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textPrimaryOpacity))
                    .lineLimit(1)

                if let badgeText = transcriptState.badgeText {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textTertiaryOpacity))
                        .lineLimit(1)
                }
            }

            Text(transcriptBody)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textSecondaryOpacity))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var transcriptTitle: String {
        micState.isActionDisabled ? actionBarState.modeStatusTitle : transcriptState.title
    }

    private var transcriptBody: String {
        micState.isActionDisabled ? actionBarState.modeStatusDetail : transcriptState.body
    }
}

struct AudioModeActionBar: View, Equatable {
    let state: AudioModeViewState.ActionBar

    static func == (lhs: AudioModeActionBar, rhs: AudioModeActionBar) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !state.primaryStatusChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(state.primaryStatusChips, id: \.self) { chip in
                            Text(chip)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textPrimaryOpacity))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(AudioModeTheme.chipFill)
                                )
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(AudioModeTheme.chipBorder, lineWidth: 1)
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.modeStatusTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textPrimaryOpacity))

                    Text(state.modeStatusDetail)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textSecondaryOpacity))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(AudioModeCardBackground())
    }
}
