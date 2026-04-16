//
//  AppThemeTests.swift
//  Neural LoopTests
//
//  Created by Codex on 16/04/2026.
//

import XCTest
import SwiftUI
@testable import Neural_Loop

final class AppThemeTests: XCTestCase {
    
    func testAppThemeMetrics() {
        XCTAssertEqual(AppTheme.Metrics.screenPadding, 20)
        XCTAssertEqual(AppTheme.Metrics.sectionSpacing, 18)
        XCTAssertEqual(AppTheme.Metrics.heroCornerRadius, 30)
        XCTAssertEqual(AppTheme.Metrics.cardCornerRadius, 26)
        XCTAssertEqual(AppTheme.Metrics.cardSpacing, 14)
        XCTAssertEqual(AppTheme.Metrics.heroIconSize, 58)
    }
    
    func testAppThemeGradients() {
        // Asserting gradients are not nil/constructible
        XCTAssertNotNil(AppTheme.backgroundGradient)
        XCTAssertNotNil(AppTheme.heroGradient)
        XCTAssertNotNil(AppTheme.cardGradient)
        XCTAssertNotNil(AppTheme.sectionGradient)
        XCTAssertNotNil(AppTheme.borderGradient)
        XCTAssertNotNil(AppTheme.accentGradient)
    }
    
    func testAppThemeColors() {
        XCTAssertNotNil(AppTheme.accentColor)
        XCTAssertNotNil(AppTheme.glowColor)
        XCTAssertNotNil(AppTheme.textPrimary)
        XCTAssertNotNil(AppTheme.textSecondary)
        XCTAssertNotNil(AppTheme.errorTint)
    }
    
    func testAppThemeSemanticColors() {
        XCTAssertNotNil(AppTheme.workEventTint)
        XCTAssertNotNil(AppTheme.taskEventTint)
        XCTAssertNotNil(AppTheme.habitEventTint)
        XCTAssertNotNil(AppTheme.warningTint)
        XCTAssertNotNil(AppTheme.successTint)
        XCTAssertEqual(AppTheme.workEventGradientColors.count, 2)
    }
    
    func testMaterialFallback() {
        let styleWithTransparency = AppTheme.materialFallback(false)
        let styleWithoutTransparency = AppTheme.materialFallback(true)
        
        XCTAssertNotNil(styleWithTransparency)
        XCTAssertNotNil(styleWithoutTransparency)
    }
    
    func testCalendarEventTypeColors() {
        XCTAssertEqual(CalendarEventType.workEvent.color, AppTheme.workEventTint)
        XCTAssertEqual(CalendarEventType.task.color, AppTheme.taskEventTint)
        XCTAssertEqual(CalendarEventType.habit.color, AppTheme.habitEventTint)
    }
}
