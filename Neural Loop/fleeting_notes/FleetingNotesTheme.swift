//
//  FleetingNotesTheme.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import SwiftUI

enum FleetingNotesTheme {
    enum Metrics {
        static let screenPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 18
        static let heroCornerRadius: CGFloat = 30
        static let cardCornerRadius: CGFloat = 26
        static let cardSpacing: CGFloat = 14
        static let heroIconSize: CGFloat = 58
    }

    static let backgroundGradient = LinearGradient(
        colors: [
            Color.adaptive(light: Color(red: 0.97, green: 0.96, blue: 0.91), dark: Color(red: 0.05, green: 0.07, blue: 0.09)),
            Color.adaptive(light: Color(red: 0.87, green: 0.93, blue: 0.96), dark: Color(red: 0.09, green: 0.11, blue: 0.13)),
            Color.adaptive(light: Color(red: 0.72, green: 0.85, blue: 0.86), dark: Color(red: 0.13, green: 0.15, blue: 0.18))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [
            Color.adaptive(light: Color.white.opacity(0.78), dark: Color.white.opacity(0.15)),
            Color.adaptive(light: Color(red: 0.83, green: 0.94, blue: 0.92).opacity(0.72), dark: Color(red: 0.12, green: 0.16, blue: 0.22).opacity(0.60)),
            Color.adaptive(light: Color(red: 0.98, green: 0.88, blue: 0.72).opacity(0.70), dark: Color(red: 0.22, green: 0.25, blue: 0.32).opacity(0.50))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [
            Color.adaptive(light: Color.white.opacity(0.72), dark: Color.white.opacity(0.10)),
            Color.adaptive(light: Color(red: 0.91, green: 0.97, blue: 0.95).opacity(0.64), dark: Color.white.opacity(0.05))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sectionGradient = LinearGradient(
        colors: [
            Color.adaptive(light: Color.white.opacity(0.50), dark: Color.white.opacity(0.10)),
            Color.adaptive(light: Color.white.opacity(0.24), dark: Color.white.opacity(0.05))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let borderGradient = LinearGradient(
        colors: [
            Color.adaptive(light: Color.white.opacity(0.88), dark: Color.white.opacity(0.20)),
            Color.adaptive(light: Color.black.opacity(0.07), dark: Color.white.opacity(0.05))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.14, green: 0.49, blue: 0.53),
            Color(red: 0.22, green: 0.67, blue: 0.60)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentColor = Color(red: 0.14, green: 0.49, blue: 0.53)

    static let glowColor = Color.adaptive(light: Color(red: 0.97, green: 0.77, blue: 0.42), dark: Color(red: 0.99, green: 0.80, blue: 0.45))
    static let textPrimary = Color.adaptive(light: Color(red: 0.12, green: 0.16, blue: 0.18), dark: Color(red: 0.94, green: 0.96, blue: 0.99))
    static let textSecondary = Color.adaptive(light: Color(red: 0.27, green: 0.34, blue: 0.35), dark: Color(red: 0.55, green: 0.58, blue: 0.62))
    static let errorTint = Color(red: 0.72, green: 0.27, blue: 0.20)

    static func materialFallback(_ reduceTransparency: Bool) -> AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.systemBackground))
        }

        return AnyShapeStyle(.ultraThinMaterial)
    }
}
