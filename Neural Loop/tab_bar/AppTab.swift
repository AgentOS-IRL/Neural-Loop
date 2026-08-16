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
    case maps = "Maps"
    case ai = "AI"
    case calendar = "Calendar"
//    case insights = "Insights"
    case fitness = "Fitness"
    case settings = "Settings"

    var systemImage: String {
        switch self {
        case .tasks: return "square.grid.2x2"
        case .maps: return "map"
        case .ai: return "sparkles"
        case .calendar: return "calendar"
        case .goals: return "target"
//        case .insights: return "chart.line.uptrend.xyaxis"
        case .fitness: return "figure.strengthtraining.traditional"
        case .settings: return "gearshape"
        }
    }
}

enum AppShellDestination: Equatable {
    case goals
    case tasks
    case maps
    case ai
    case calendar
    case fitness
    case settings
}

extension AppTab {
    static let contentTabs: [AppTab] = [.goals, .tasks, .fitness, .calendar]

    var shellDestination: AppShellDestination {
        switch self {
        case .goals:
            return .goals
        case .tasks:
            return .tasks
        case .maps:
            return .maps
        case .ai:
            return .ai
        case .calendar:
            return .calendar
        case .fitness:
            return .fitness
        case .settings:
            return .settings
        }
    }
}
