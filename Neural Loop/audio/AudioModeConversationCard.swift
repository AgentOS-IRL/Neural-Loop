import SwiftUI

struct AudioModeConversationCard: View {
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
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(state.messages) { message in
                            row(message)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .frame(minHeight: 180, maxHeight: 320)
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
                .foregroundStyle(.white.opacity(0.76))

            Text("Codex conversation")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))

            Spacer(minLength: 8)

            if let badgeText = state.headerBadgeText {
                Text(badgeText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
            }
        }
    }

    private func banner(text: String, tone: AudioModeBannerTone) -> some View {
        HStack(spacing: 12) {
            if tone == .info && state.headerBadgeText == "Sending" {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: tone == .error ? "exclamationmark.triangle.fill" : "bolt.badge.clock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AudioModeTheme.bannerIconColor(for: tone))
            }

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
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
            .fill(Color.white.opacity(0.07))
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
                .foregroundStyle(.white)

            Text(state.emptyDetail)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: AudioModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AudioModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func row(_ message: AudioTranscriptMessage) -> some View {
        HStack {
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
                        .foregroundStyle(.white.opacity(message.role == .error ? 0.86 : 0.70))

                    Spacer(minLength: 0)
                }

                Text(message.content)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(message.role == .status ? 0.88 : 1.0))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
}
