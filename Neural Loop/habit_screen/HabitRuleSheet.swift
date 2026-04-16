//
//  HabitRuleSheet.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 10/01/2026.
//
import SwiftUI

struct HabitRuleSheet: View {

    let onSave: (Calendar.RecurrenceRule?) -> Void

    enum FrequencyUI: String, CaseIterable, Identifiable {
        case daily
        case weekly
        case monthly

        var id: String { rawValue }

        var calendarFrequency: Calendar.RecurrenceRule.Frequency {
            switch self {
            case .daily: return .daily
            case .weekly: return .weekly
            case .monthly: return .monthly
            }
        }

        var label: String {
            rawValue.capitalized
        }
    }

    @State private var frequency: FrequencyUI = .daily
    @State private var interval: Int = 1

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Frequency")
                            ThemedCard {
                                Picker("Frequency", selection: $frequency) {
                                    ForEach(FrequencyUI.allCases) { freq in
                                        Text(freq.label).tag(freq)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                Stepper(
                                    value: $interval,
                                    in: 1...30
                                ) {
                                    HStack {
                                        Text("Interval")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Text("Every \(interval) \(frequency.label.lowercased())\(interval > 1 ? "s" : "")")
                                            .font(.body.bold())
                                            .foregroundColor(AppTheme.accentColor)
                                    }
                                }
                            }
                        }
                    }
                    .padding(AppTheme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSave(nil)
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(buildRule())
                    }
                    .font(.body.weight(.bold))
                    .foregroundColor(AppTheme.accentColor)
                }
            }
        }
    }

    private func buildRule() -> Calendar.RecurrenceRule {
        var rule = Calendar.RecurrenceRule(
            calendar: .current,
            frequency: frequency.calendarFrequency
        )

        rule.interval = interval
        return rule
    }
}
