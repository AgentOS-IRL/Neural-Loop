//
//  TaskScheduleSheet.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import SwiftUI
import Foundation
import RRuleKit

// MARK: - Models

extension Calendar.RecurrenceRule {
    func summary() -> String {
        var parts: [String] = []
        if interval > 1 {
            parts.append("Every \(interval)")
        }

        switch frequency {
        case .daily: parts.append("Days")
        case .weekly: parts.append("Weeks")
        case .monthly: parts.append("Months")
        case .yearly: parts.append("Years")
        case .minutely: parts.append("Minutes")
        case .hourly: parts.append("Hours")
        @unknown default: break
        }

        
        
        let occurrences = end.occurrences ?? 0
        if occurrences > 1 {
            parts.append("for \(occurrences) times")
        }
        
        
        if end.date != nil {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium   // e.g. "Jan 10, 2026"
            formatter.timeStyle = .none

            parts.append("until \(formatter.string(from: end.date!))")
        }
        


        return parts.joined(separator: " ")
    }
}


struct TaskScheduleDraft {
    let timing: TaskTiming?
    let recurrence: Calendar.RecurrenceRule?
}

// MARK: - Sheet

struct TaskScheduleSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onSave: (TaskScheduleDraft) -> Void

    @State private var timing: TaskTiming?
    @State private var recurrenceRule: Calendar.RecurrenceRule?

    @State private var showTimeSheet = false
    @State private var showRepeatSheet = false

    var body: some View {
        NavigationStack {
            Form {

                // TIME ROW
                Button {
                    showTimeSheet = true
                } label: {
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(timeSummary)
                            .foregroundStyle(.secondary)
                    }
                }

                // REPEAT ROW
                Button {
                    showRepeatSheet = true
                } label: {
                    HStack {
                        Text("Repeat")
                        Spacer()
                        Text(repeatSummary)
                            .foregroundStyle(.secondary)
                    }
                }

                // MERGED PREVIEW
                if timing != nil || recurrenceRule != nil {
                    Section("Summary") {
                        if let timing {
                            Label(timeSummary, systemImage: "clock")
                        }
                        if let recurrenceRule {
                            Label(repeatSummary, systemImage: "repeat")
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            TaskScheduleDraft(
                                timing: timing,
                                recurrence: recurrenceRule
                            )
                        )
                        dismiss()
                    }
                    .disabled(timing == nil && recurrenceRule == nil)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTimeSheet) {
                TimeRuleSheet { result in
                    timing = result
                }
            }
            .sheet(isPresented: $showRepeatSheet) {
                RepeatRuleSheet { rule in
                    recurrenceRule = rule
                }
            }
        }
    }

    // MARK: - Summaries

    private var timeSummary: String {
        timing?.summary() ?? "Not set"
    }

    private var repeatSummary: String {
        recurrenceRule?.summary() ?? "Never"
    }
}


