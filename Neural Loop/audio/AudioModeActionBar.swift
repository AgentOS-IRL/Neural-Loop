import SwiftUI

struct AudioModeActionBar: View {
    let state: AudioModeViewState.ActionBar
    let onSwitchToManualMode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !state.primaryStatusChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(state.primaryStatusChips, id: \.self) { chip in
                            Text(chip)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.80))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            Button(action: onSwitchToManualMode) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.system(size: 18, weight: .semibold))
                    Text(state.switchButtonTitle)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .foregroundStyle(.black)
                .background(AudioModeTheme.actionGradient)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: AudioModeTheme.Metrics.cardCornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(AudioModeTheme.highlightBorder, lineWidth: 1)
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AudioModeTheme.Metrics.cardCornerRadius,
                        style: .continuous
                    )
                )
                .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.switchButtonTitle)
        }
        .padding(16)
        .background(AudioModeCardBackground())
    }
}
