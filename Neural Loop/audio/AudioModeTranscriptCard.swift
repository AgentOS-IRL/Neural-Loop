import SwiftUI

struct AudioModeTranscriptCard: View, Equatable {
    let state: AudioModeViewState.Transcript

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: state.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AudioModeTheme.messageIconColor(for: .status))

                Text(state.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textSecondaryOpacity))

                Spacer(minLength: 8)

                if let badgeText = state.badgeText {
                    Text(badgeText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textTertiaryOpacity))
                }
            }

            Text(state.body)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textPrimaryOpacity))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if let footnote = state.footnote {
                Text(footnote)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(AudioModeTheme.Surface.textMutedOpacity))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AudioModeCardBackground())
    }
}
