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
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.06, blue: 0.09),
                    Color(red: 0.02, green: 0.02, blue: 0.04),
                    Color(red: 0.00, green: 0.00, blue: 0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.24),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 260
            )
            .offset(x: -120, y: -180)
            .blur(radius: 30)

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.18),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 280
            )
            .offset(x: 140, y: 180)
            .blur(radius: 36)

            if !reduceTransparency {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        Color.clear,
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
    }
}
