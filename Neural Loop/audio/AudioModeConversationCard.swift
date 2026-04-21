import SwiftUI

struct AudioModeConversationCard: View, Equatable {
    let state: AudioModeViewState.Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let bannerText = state.bannerText, let tone = state.bannerTone {
                banner(text: bannerText, tone: tone)
            }

            if state.messages.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(state.messages) { message in
                                row(message)
                                    .id(message.id)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .frame(minHeight: 180, maxHeight: 320)
                    .onAppear {
                        scrollToBottom(proxy)
                    }
                    .onChange(of: state.scrollTargetMessageID) { _ in
                        scrollToBottom(proxy)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AudioModeCardBackground())
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AudioModeTheme.messageIconColor(for: .status))

            Text("Codex conversation")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textSecondaryOpacity))

            Spacer(minLength: 8)

            if let badgeText = state.headerBadgeText {
                Text(badgeText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textTertiaryOpacity))
            }
        }
    }

    private func banner(text: String, tone: AudioModeBannerTone) -> some View {
        HStack(spacing: 12) {
            if tone == .info && state.headerBadgeText == "Sending" {
                ProgressView()
                    .tint(AudioModeTheme.bannerIconColor(for: tone))
            } else {
                Image(systemName: tone == .error ? "exclamationmark.triangle.fill" : "bolt.badge.clock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AudioModeTheme.bannerIconColor(for: tone))
            }

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textPrimaryOpacity))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: AudioModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .fill(AudioModeTheme.bannerBackground(for: tone))
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AudioModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .strokeBorder(AudioModeTheme.bannerBorder(for: tone), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.emptyTitle)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textPrimaryOpacity))

            Text(state.emptyDetail)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textSecondaryOpacity))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: AudioModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(AudioModeTheme.Surface.mutedFillOpacity))
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AudioModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .strokeBorder(Color.white.opacity(AudioModeTheme.Surface.secondaryBorderOpacity), lineWidth: 1)
        }
    }

    private func row(_ message: AudioTranscriptMessage) -> some View {
        let playbackState = message.playbackState
        let statusLabel = playbackState.shortLabel
        let statusSystemImage = playbackState.systemImage
        let isSubdued = playbackState.isTerminal && playbackState != .finished

        return HStack {
            if message.role.alignsTrailing {
                Spacer(minLength: 34)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: message.role.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AudioModeTheme.messageIconColor(for: message.role))

                    Text(message.role.displayTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AudioModeTheme.messageLabelColor(for: message.role))

                    Spacer(minLength: 0)
                }

                Text(message.content)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(AudioModeTheme.messageBodyColor(for: message.role))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let statusLabel, let statusSystemImage {
                    HStack(spacing: 6) {
                        Image(systemName: statusSystemImage)
                            .font(.system(size: 11, weight: .semibold))
                        Text(statusLabel)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textSecondaryOpacity))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }
            .opacity(isSubdued ? 0.88 : 1.0)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: AudioModeTheme.Metrics.innerCornerRadius,
                    style: .continuous
                )
                .fill(AudioModeTheme.messageBackground(for: message.role))
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: AudioModeTheme.Metrics.innerCornerRadius,
                    style: .continuous
                )
                .strokeBorder(AudioModeTheme.messageBorder(for: message.role), lineWidth: 1)
            }

            if !message.role.alignsTrailing {
                Spacer(minLength: 34)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.content)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let messageID = state.scrollTargetMessageID else {
            return
        }

        DispatchQueue.main.async {
            proxy.scrollTo(messageID, anchor: .bottom)
        }
    }
}
