//
//  AppTab.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case todo = "To do"
    case calendar = "Calendar"
    case habits = "Habits"
    case goals = "Goals"
    case insights = "Insights"

    var systemImage: String {
        switch self {
        case .todo: return "checkmark.circle"
        case .calendar: return "calendar"
        case .habits: return "arrow.triangle.2.circlepath"
        case .goals: return "target"
        case .insights: return "chart.line.uptrend.xyaxis"
        }
    }
}
