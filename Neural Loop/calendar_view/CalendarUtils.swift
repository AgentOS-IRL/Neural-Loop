//
//  Utils.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 22/01/2026.
//
import Foundation
import EventKit
import SwiftUI

enum CalendarEventType: String, Codable {
    case workEvent
    case task
    case habit
}

extension CalendarEventType {
    var color: Color {
        switch self {
        case .workEvent:
            return AppTheme.workEventTint
        case .task:
            return AppTheme.taskEventTint
        case .habit:
            return AppTheme.habitEventTint
        }
    }
}

struct SimpleEvent {
    let title: String
    let start: Date
    let end: Date
    let acceptanceStatus: EKParticipantStatus?
    let event_type: CalendarEventType
    let isCompleted: Bool

    init(
        title: String,
        start: Date,
        end: Date,
        acceptanceStatus: EKParticipantStatus?,
        event_type: CalendarEventType,
        isCompleted: Bool = false
    ) {
        self.title = title
        self.start = start
        self.end = end
        self.acceptanceStatus = acceptanceStatus
        self.event_type = event_type
        self.isCompleted = isCompleted
    }
}
