//
//  RecurrenceOption.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import EventKit

enum RecurrenceOption: CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly

    var id: Self { self }

    var title: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var rule: EKRecurrenceRule? {
        switch self {
        case .none:
            return nil
        case .daily:
            return EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: 1,
                end: nil
            )
        case .weekly:
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: nil
            )
        case .monthly:
            return EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 1,
                end: nil
            )
        }
    }
}
