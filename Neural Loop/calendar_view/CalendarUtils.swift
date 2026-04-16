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
            return Color.adaptive(
                light: Color(red: 0.14, green: 0.49, blue: 0.53),
                dark: Color(red: 0.22, green: 0.67, blue: 0.60)
            )
        case .task:
            return Color.adaptive(
                light: Color(red: 0.95, green: 0.60, blue: 0.10),
                dark: Color(red: 0.99, green: 0.80, blue: 0.45)
            )
        case .habit:
            return Color.adaptive(
                light: Color(red: 0.30, green: 0.70, blue: 0.30),
                dark: Color(red: 0.40, green: 0.80, blue: 0.40)
            )
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
