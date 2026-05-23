import SwiftUI
import UIKit

enum AIModeConversationLayout: Equatable {
    case card
    case primaryFeed
}

struct AIModeConversationCard: View, Equatable {
    let state: AIModeViewState.Conversation
    var layout: AIModeConversationLayout = .card

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
                                AIModeConversationRow(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .frame(
                        minHeight: layout == .primaryFeed ? 0 : 180,
                        maxHeight: layout == .primaryFeed ? .infinity : 320
                    )
                    .onAppear {
                        scrollToBottom(proxy)
                    }
                    .onChange(of: state.scrollTargetMessageID) { _ in
                        scrollToBottom(proxy)
                    }
                }
            }
        }
        .padding(layout == .primaryFeed ? 18 : 22)
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .leading)
        .background(AIModeCardBackground())
    }

    private var maxHeight: CGFloat? {
        if layout == .primaryFeed {
            return .infinity
        }
        return nil
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AIModeTheme.messageIconColor(for: .status))

            Text("Codex conversation")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(AIModeTheme.Surface.textSecondaryOpacity))

            Spacer(minLength: 8)

            if let badgeText = state.headerBadgeText {
                Text(badgeText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(AIModeTheme.Surface.textTertiaryOpacity))
            }
        }
    }

    private func banner(text: String, tone: AIModeBannerTone) -> some View {
        HStack(spacing: 12) {
            if tone == .info && (state.headerBadgeText == "Sending" || state.headerBadgeText == "Reformatting") {
                ProgressView()
                    .tint(AIModeTheme.bannerIconColor(for: tone))
            } else {
                Image(systemName: tone == .error ? "exclamationmark.triangle.fill" : "bolt.badge.clock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AIModeTheme.bannerIconColor(for: tone))
            }

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(AIModeTheme.Surface.textPrimaryOpacity))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: AIModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .fill(AIModeTheme.bannerBackground(for: tone))
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AIModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .strokeBorder(AIModeTheme.bannerBorder(for: tone), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.emptyTitle)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(AIModeTheme.Surface.textPrimaryOpacity))

            Text(state.emptyDetail)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(AIModeTheme.Surface.textSecondaryOpacity))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            maxHeight: layout == .primaryFeed ? .infinity : nil,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: AIModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(AIModeTheme.Surface.mutedFillOpacity))
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: AIModeTheme.Metrics.innerCornerRadius,
                style: .continuous
            )
            .strokeBorder(Color.white.opacity(AIModeTheme.Surface.secondaryBorderOpacity), lineWidth: 1)
        }
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

private struct AIModeConversationRow: View {
    let message: AITranscriptMessage
    @State private var showingRaw = false

    private var displayContent: String {
        if showingRaw, let raw = message.rawContent {
            return raw
        }
        return message.content
    }

    var body: some View {
        HStack {
            if message.role.alignsTrailing {
                Spacer(minLength: 34)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: message.toolResultKind?.systemImage ?? message.role.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AIModeTheme.messageIconColor(for: message.role))

                    Text(message.role.displayTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AIModeTheme.messageLabelColor(for: message.role))

                    if let badgeText = message.toolResultKind?.badgeText {
                        Text(badgeText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(AIModeTheme.Surface.textPrimaryOpacity))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AIModeTheme.messageIconColor(for: message.role).opacity(0.18))
                            )
                    }

                    Spacer(minLength: 0)
                }

                Text(displayContent)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(AIModeTheme.messageBodyColor(for: message.role))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let imagePreviewData = message.imagePreviewData,
                   let image = UIImage(data: imagePreviewData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: AIModeTheme.Metrics.innerCornerRadius - 6,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: AIModeTheme.Metrics.innerCornerRadius - 6,
                                style: .continuous
                            )
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }

                if message.rawContent != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingRaw.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showingRaw ? "text.badge.checkmark" : "waveform")
                                .font(.system(size: 10, weight: .semibold))
                            Text(showingRaw ? "Show formatted" : "Show raw")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(AIModeTheme.Surface.textMutedOpacity))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: AIModeTheme.Metrics.innerCornerRadius,
                    style: .continuous
                )
                .fill(AIModeTheme.messageBackground(for: message.role))
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: AIModeTheme.Metrics.innerCornerRadius,
                    style: .continuous
                )
                .strokeBorder(AIModeTheme.messageBorder(for: message.role), lineWidth: 1)
            }

            if !message.role.alignsTrailing {
                Spacer(minLength: 34)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayContent)
    }
}
