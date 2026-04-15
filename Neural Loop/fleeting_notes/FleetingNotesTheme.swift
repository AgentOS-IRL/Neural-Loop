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
            Color(red: 0.97, green: 0.96, blue: 0.91),
            Color(red: 0.87, green: 0.93, blue: 0.96),
            Color(red: 0.72, green: 0.85, blue: 0.86)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.78),
            Color(red: 0.83, green: 0.94, blue: 0.92).opacity(0.72),
            Color(red: 0.98, green: 0.88, blue: 0.72).opacity(0.70)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.72),
            Color(red: 0.91, green: 0.97, blue: 0.95).opacity(0.64)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sectionGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.50),
            Color.white.opacity(0.24)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let borderGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.88),
            Color.black.opacity(0.07)
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

    static let glowColor = Color(red: 0.97, green: 0.77, blue: 0.42)
    static let textPrimary = Color(red: 0.12, green: 0.16, blue: 0.18)
    static let textSecondary = Color(red: 0.27, green: 0.34, blue: 0.35)
    static let errorTint = Color(red: 0.72, green: 0.27, blue: 0.20)

    static func materialFallback(_ reduceTransparency: Bool) -> AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.systemBackground))
        }

        return AnyShapeStyle(.ultraThinMaterial)
    }
}
