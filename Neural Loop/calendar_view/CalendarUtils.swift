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
            return .blue
        case .task:
            return .orange
        case .habit:
            return .green
        }
    }
}

struct SimpleEvent {
    let title: String
    let start: Date
    let end: Date
    let acceptanceStatus: EKParticipantStatus?
    let event_type: CalendarEventType
}
