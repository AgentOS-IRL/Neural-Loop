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

            VStack(alignment: .leading, spacing: 4) {
                Text(state.modeStatusTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(state.modeStatusDetail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onSwitchToManualMode) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text(state.switchButtonTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.switchButtonTitle)
            .accessibilityHint(state.switchButtonAccessibilityHint)
        }
        .padding(16)
        .background(AudioModeCardBackground())
    }
}
