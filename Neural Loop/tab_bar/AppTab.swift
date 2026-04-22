//
//  AppTab.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case goals = "Goals"
    case tasks = "Loop"
    case ai = "AI"
    case calendar = "Calendar"
//    case insights = "Insights"
    case settings = "Settings"

    var systemImage: String {
        switch self {
        case .tasks: return "square.grid.2x2"
        case .ai: return "sparkles"
        case .calendar: return "calendar"
        case .goals: return "target"
//        case .insights: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }
}

enum AppShellDestination: Equatable {
    case goals
    case tasks
    case ai
    case calendar
    case settings
}

extension AppTab {
    var shellDestination: AppShellDestination {
        switch self {
        case .goals:
            return .goals
        case .tasks:
            return .tasks
        case .ai:
            return .ai
        case .calendar:
            return .calendar
        case .settings:
            return .settings
        }
    }
}
