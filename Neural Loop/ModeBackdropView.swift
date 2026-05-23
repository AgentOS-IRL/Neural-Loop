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
            AIModeTheme.baseBackground

            // Top-edge luminous wash — lifts the status bar region
            // from pitch-black to a subtle teal/cyan warmth.
            LinearGradient(
                colors: [
                    AIModeTheme.backdropPrimaryGlow.opacity(reduceTransparency ? 0.08 : 0.16),
                    AIModeTheme.backdropSecondaryGlow.opacity(reduceTransparency ? 0.04 : 0.09),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.28)
            )

            RadialGradient(
                colors: [
                    AIModeTheme.backdropPrimaryGlow.opacity(reduceTransparency ? 0.12 : 0.22),
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
                    AIModeTheme.backdropSecondaryGlow.opacity(reduceTransparency ? 0.10 : 0.18),
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
                    AIModeTheme.backdropTertiaryGlow.opacity(reduceTransparency ? 0.08 : 0.14),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 320
            )
            .offset(x: 110, y: 210)
            .blur(radius: 38)

            if !reduceTransparency {
                // Diagonal glass sheen
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

                // Top highlight orb — adds depth behind the status bar
                Circle()
                    .fill(AIModeTheme.backdropHighlightGlow.opacity(0.08))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: 0, y: -220)
                    .blendMode(.screen)

                // Subtle secondary glow at the very top-center
                Ellipse()
                    .fill(AIModeTheme.backdropPrimaryGlow.opacity(0.06))
                    .frame(width: 280, height: 120)
                    .blur(radius: 40)
                    .offset(x: 0, y: -300)
                    .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
    }
}
