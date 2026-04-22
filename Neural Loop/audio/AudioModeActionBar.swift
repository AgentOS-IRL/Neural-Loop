import SwiftUI

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
