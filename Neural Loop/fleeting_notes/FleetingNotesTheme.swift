//
//  FleetingNotesTheme.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import SwiftUI

/// DEPRECATED: Use `AppTheme` instead.
/// This shim is maintained for backward compatibility during migration.
enum FleetingNotesTheme {
    enum Metrics {
        static let screenPadding = AppTheme.Metrics.screenPadding
        static let sectionSpacing = AppTheme.Metrics.sectionSpacing
        static let heroCornerRadius = AppTheme.Metrics.heroCornerRadius
        static let cardCornerRadius = AppTheme.Metrics.cardCornerRadius
        static let cardSpacing = AppTheme.Metrics.cardSpacing
        static let heroIconSize = AppTheme.Metrics.heroIconSize
    }

    static let backgroundGradient = AppTheme.backgroundGradient
    static let heroGradient = AppTheme.heroGradient
    static let cardGradient = AppTheme.cardGradient
    static let sectionGradient = AppTheme.sectionGradient
    static let borderGradient = AppTheme.borderGradient
    static let accentGradient = AppTheme.accentGradient

    static let accentColor = AppTheme.accentColor
    static let glowColor = AppTheme.glowColor
    static let textPrimary = AppTheme.textPrimary
    static let textSecondary = AppTheme.textSecondary
    static let errorTint = AppTheme.errorTint

    static func materialFallback(_ reduceTransparency: Bool) -> AnyShapeStyle {
        AppTheme.materialFallback(reduceTransparency)
    }
}
