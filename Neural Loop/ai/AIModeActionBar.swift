import SwiftUI

struct AIModeVoiceInputBar: View, Equatable {
    let micState: AIModeViewState.Hero
    let transcriptState: AIModeViewState.Transcript
    let actionBarState: AIModeViewState.ActionBar
    let isReduceMotionEnabled: Bool
    let isPulsing: Bool
    let onTapMic: () -> Void
    let onTapCamera: () -> Void

    static func == (lhs: AIModeVoiceInputBar, rhs: AIModeVoiceInputBar) -> Bool {
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

            HStack(spacing: 20) {
                Spacer(minLength: 0)

                cameraButton

                microphoneButton

                Color.clear
                    .frame(width: 50, height: 50)
                    .accessibilityHidden(true)

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(
                cornerRadius: AIModeTheme.Metrics.bottomComposerCornerRadius,
                style: .continuous
            )
            .fill(AIModeTheme.cardFill)
            .background(
                RoundedRectangle(
                    cornerRadius: AIModeTheme.Metrics.bottomComposerCornerRadius,
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: AIModeTheme.Metrics.bottomComposerCornerRadius,
                    style: .continuous
                )
                .strokeBorder(AIModeTheme.highlightBorder, lineWidth: 1)
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
                        .foregroundStyle(.white.opacity(AIModeTheme.Surface.textSecondaryOpacity))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AIModeTheme.chipFill)
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(AIModeTheme.chipBorder, lineWidth: 1)
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
                    .foregroundStyle(AIModeTheme.statusTint(for: micState.tintState))

                Text(transcriptTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(AIModeTheme.Surface.textPrimaryOpacity))
                    .lineLimit(1)

                if let badgeText = transcriptState.badgeText {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(AIModeTheme.Surface.textTertiaryOpacity))
                        .lineLimit(1)
                }
            }

            Text(transcriptBody)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(AIModeTheme.Surface.textSecondaryOpacity))
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

    private var cameraButton: some View {
        Button(action: onTapCamera) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(Color.white.opacity(actionBarState.isCameraDisabled ? 0.03 : 0.08))
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(AIModeTheme.highlightBorder, lineWidth: 1)
                    }
                    .frame(width: 50, height: 50)

                Image(systemName: "camera.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white.opacity(actionBarState.isCameraDisabled ? 0.42 : 0.88))
            }
            .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
        .disabled(actionBarState.isCameraDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capture image")
        .accessibilityHint("Opens the camera and sends the captured image to Codex.")
    }

    private var microphoneButton: some View {
        Button(action: onTapMic) {
            ZStack {
                if !isReduceMotionEnabled {
                    Circle()
                        .strokeBorder(
                            AIModeTheme.statusTint(for: micState.tintState).opacity(0.52),
                            lineWidth: 2
                        )
                        .frame(
                            width: AIModeTheme.Metrics.bottomMicPulseSize,
                            height: AIModeTheme.Metrics.bottomMicPulseSize
                        )
                        .scaleEffect(isPulsing ? 1.06 : 0.94)
                        .opacity(isPulsing ? 0.18 : 0.62)
                }

                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(AIModeTheme.actionGradient)
                            .opacity(micState.isActionDisabled ? 0.04 : 0.16)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(AIModeTheme.highlightBorder, lineWidth: 1)
                    }
                    .shadow(color: AIModeTheme.heroGlow, radius: micState.isActionDisabled ? 8 : 16, y: 8)
                    .frame(
                        width: AIModeTheme.Metrics.bottomMicSize,
                        height: AIModeTheme.Metrics.bottomMicSize
                    )

                Image(systemName: micState.microphoneSystemImage)
                    .font(.system(size: micState.isRecording ? 25 : 29, weight: .bold))
                    .foregroundStyle(.white.opacity(micState.isActionDisabled ? 0.48 : 0.96))
                    .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
            }
            .frame(
                width: AIModeTheme.Metrics.bottomMicPulseSize,
                height: AIModeTheme.Metrics.bottomMicPulseSize
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
}

struct AIModeActionBar: View, Equatable {
    let state: AIModeViewState.ActionBar

    static func == (lhs: AIModeActionBar, rhs: AIModeActionBar) -> Bool {
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
                                .foregroundStyle(.white.opacity(AIModeTheme.Surface.textPrimaryOpacity))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(AIModeTheme.chipFill)
                                )
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(AIModeTheme.chipBorder, lineWidth: 1)
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
                        .foregroundStyle(.white.opacity(AIModeTheme.Surface.textPrimaryOpacity))

                    Text(state.modeStatusDetail)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(AIModeTheme.Surface.textSecondaryOpacity))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(AIModeCardBackground())
    }
}
