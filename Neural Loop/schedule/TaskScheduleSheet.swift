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

        switch frequency {
        case .daily: parts.append("Daily")
        case .weekly: parts.append("Weekly")
        case .monthly: parts.append("Monthly")
        case .yearly: parts.append("Yearly")
        case .minutely: parts.append("Minutely")
        case .hourly: parts.append("Hourly")
        @unknown default: break
        }

        if interval > 1 {
            parts.append("every \(interval)")
        }
        
        let occurrences = end.occurrences ?? 0
        if occurrences > 1 {
            parts.append("for \(occurrences) times")
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
                            Label(recurrenceRule.summary(), systemImage: "repeat")
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
                TaskScheduleTimeSheet { result in
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
        guard let timing else { return "Not set" }
        if timing.start == .distantFuture {
            return "Anytime"
        }
        let df = DateFormatter()
        df.timeStyle = .short
        let time = df.string(from: timing.start)

        if timing.duration > 0 {
            let mins = Int(timing.duration / 60)
            return "\(time) • \(mins) min"
        }
        return time
    }

    private var repeatSummary: String {
        recurrenceRule?.summary() ?? "Never"
    }
}

// MARK: - Repeat Sheet (RRuleKit)

struct RepeatRuleSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onSave: (Calendar.RecurrenceRule?) -> Void

    @State private var frequency: Calendar.RecurrenceRule.Frequency = .daily
    @State private var interval: Int = 1

    @State private var endType: EndType = .never
    @State private var endDate: Date = Date()
    @State private var occurrenceCount: Int = 1

    enum EndType: Int {
        case never
        case onDate
        case after
    }

    var body: some View {
        NavigationStack {
            Form {

                Picker("Frequency", selection: $frequency) {
                    Text("Daily").tag(Calendar.RecurrenceRule.Frequency.daily)
                    Text("Weekly").tag(Calendar.RecurrenceRule.Frequency.weekly)
                    Text("Monthly").tag(Calendar.RecurrenceRule.Frequency.monthly)
                    Text("Yearly").tag(Calendar.RecurrenceRule.Frequency.yearly)
                }

                Stepper(
                    "Every \(interval) \(frequencyLabel)",
                    value: $interval,
                    in: 1...30
                )

                Section("End") {
                    Picker("End", selection: $endType) {
                        Text("Never").tag(EndType.never)
                        Text("On Date").tag(EndType.onDate)
                        Text("After").tag(EndType.after)
                    }

                    if endType == .onDate {
                        DatePicker(
                            "End Date",
                            selection: $endDate,
                            displayedComponents: .date
                        )
                    }

                    if endType == .after {
                        Stepper(
                            "After \(occurrenceCount) occurrences",
                            value: $occurrenceCount,
                            in: 1...999
                        )
                    }
                }
            }
            .navigationTitle("Repeat")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(buildRule())
                        dismiss()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func buildRule() -> Calendar.RecurrenceRule {
        var rule = Calendar.RecurrenceRule(
            calendar: Calendar.current,
            frequency: frequency
        )

        rule.interval = interval

        switch endType {
        case .never:
            rule.end = .never
        case .onDate:
            rule.end = .afterDate(endDate)
        case .after:
            rule.end = .afterOccurrences(occurrenceCount)
        }

        return rule
    }

    private var frequencyLabel: String {
        switch frequency {
        case .daily: return "day(s)"
        case .weekly: return "week(s)"
        case .monthly: return "month(s)"
        case .yearly: return "year(s)"
        case .hourly: return "hour(s)"
        case .minutely: return "minute(s)"
        @unknown default: return ""
        }
    }
}

