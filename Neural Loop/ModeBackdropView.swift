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
                    Color(red: 0.43, green: 0.86, blue: 0.96).opacity(reduceTransparency ? 0.16 : 0.28),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 18,
                endRadius: 310
            )
            .offset(x: -110, y: -170)
            .blur(radius: 24)

            RadialGradient(
                colors: [
                    Color(red: 0.32, green: 0.62, blue: 1.0).opacity(reduceTransparency ? 0.12 : 0.22),
                    Color.clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 340
            )
            .offset(x: 150, y: -30)
            .blur(radius: 38)

            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.95, blue: 0.78).opacity(reduceTransparency ? 0.10 : 0.18),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 320
            )
            .offset(x: 120, y: 220)
            .blur(radius: 42)

            if !reduceTransparency {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)

                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 360, height: 360)
                    .blur(radius: 80)
                    .offset(x: 0, y: -250)
                    .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
    }
}
