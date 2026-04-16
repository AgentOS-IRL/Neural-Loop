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
    var timing: TaskTiming?
    var recurrence: Calendar.RecurrenceRule?
}


// MARK: - Sheet

struct TaskScheduleSheet: View {

    @Environment(\.dismiss) private var dismiss

    let initialTiming: TaskTiming?
    let initialRule: Calendar.RecurrenceRule?

    let onSave: (TaskScheduleDraft) -> Void

    @State private var timing: TaskTiming?
    @State private var recurrenceRule: Calendar.RecurrenceRule?

    @State private var showTimeSheet = false
    @State private var showRepeatSheet = false

    init(
        initialTiming: TaskTiming? = nil,
        initialRule: Calendar.RecurrenceRule? = nil,
        onSave: @escaping (TaskScheduleDraft) -> Void
    ) {
        self.initialTiming = initialTiming
        self.initialRule = initialRule
        self.onSave = onSave
        _timing = State(initialValue: initialTiming)
        _recurrenceRule = State(initialValue: initialRule)

    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Settings")
                            ThemedCard {
                                // TIME ROW
                                Button {
                                    showTimeSheet = true
                                } label: {
                                    ThemedRow {
                                        Text("Time")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Text(timeSummary)
                                            .font(.subheadline)
                                            .foregroundColor(AppTheme.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }

                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                // REPEAT ROW
                                Button {
                                    showRepeatSheet = true
                                } label: {
                                    ThemedRow {
                                        Text("Repeat")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Text(repeatSummary)
                                            .font(.subheadline)
                                            .foregroundColor(AppTheme.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }

                        // MERGED PREVIEW
                        if timing != nil || recurrenceRule != nil {
                            VStack(alignment: .leading, spacing: 4) {
                                themedSectionHeader("Summary")
                                ThemedCard(gradient: AppTheme.sectionGradient) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(timeSummary, systemImage: "clock")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(AppTheme.textPrimary)
                                        
                                        Divider()
                                            .background(AppTheme.textSecondary.opacity(0.1))

                                        Label(repeatSummary, systemImage: "repeat")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(AppTheme.textPrimary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(AppTheme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
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
                    .font(.body.weight(.bold))
                    .foregroundColor((timing == nil && recurrenceRule == nil) ? AppTheme.textSecondary : AppTheme.accentColor)
                    .disabled(timing == nil && recurrenceRule == nil)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }
            }
            .sheet(isPresented: $showTimeSheet) {
                TimeRuleSheet(initialTiming: timing) { result in
                    timing = result
                }
            }
            .sheet(isPresented: $showRepeatSheet) {
                RepeatRuleSheet(initialRule: initialRule) { rule in
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

