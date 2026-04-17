//
//  ModeBackdropView.swift
//  Neural Loop
//
//  Created by Codex on 14/04/2026.
//

import SwiftUI

struct ModeBackdropView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            AudioModeTheme.baseBackground

            RadialGradient(
                colors: [
                    AudioModeTheme.backdropPrimaryGlow.opacity(reduceTransparency ? 0.12 : 0.22),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 18,
                endRadius: 310
            )
            .offset(x: -120, y: -180)
            .blur(radius: 28)

            RadialGradient(
                colors: [
                    AudioModeTheme.backdropSecondaryGlow.opacity(reduceTransparency ? 0.10 : 0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 340
            )
            .offset(x: 140, y: -20)
            .blur(radius: 34)

            RadialGradient(
                colors: [
                    AudioModeTheme.backdropTertiaryGlow.opacity(reduceTransparency ? 0.08 : 0.14),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 320
            )
            .offset(x: 110, y: 210)
            .blur(radius: 38)

            if !reduceTransparency {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.clear,
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)

                Circle()
                    .fill(AudioModeTheme.backdropHighlightGlow.opacity(0.06))
                    .frame(width: 340, height: 340)
                    .blur(radius: 74)
                    .offset(x: 0, y: -240)
                    .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
    }
}
