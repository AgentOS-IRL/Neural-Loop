//
//  RepeatRuleSheet.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 06/01/2026.
//


import SwiftUI
import Foundation



// MARK: - Repeat Sheet (RRuleKit)

struct RepeatRuleSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onSave: (Calendar.RecurrenceRule?) -> Void

    enum FrequencyUI: String, CaseIterable {
        case weekly, monthly, yearly
    }

    @State private var frequency: FrequencyUI = .weekly
    @State private var interval: Int = 1

    @State private var selectedWeekdays: Set<WeekdayUI> = []
    @State private var monthlyMode: MonthlyMode = .dates
    @State private var selectedMonthDays: Set<Int> = []
    @State private var ordinal: OrdinalUI = .first
    @State private var ordinalWeekday: WeekdayUI = .monday
    @State private var selectedMonth: Int = 1

    @State private var endType: EndType = .never
    @State private var endDate: Date = Date()
    @State private var occurrenceCount: Int = 1

    enum EndType: Int {
        case never
        case onDate
        case after
    }

    enum WeekdayUI: CaseIterable {
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday

        var short: String {
            switch self {
            case .monday: return "Mo"
            case .tuesday: return "Tu"
            case .wednesday: return "We"
            case .thursday: return "Th"
            case .friday: return "Fr"
            case .saturday: return "Sa"
            case .sunday: return "Su"
            }
        }

        var localeWeekday: Locale.Weekday {
            switch self {
            case .monday: return .monday
            case .tuesday: return .tuesday
            case .wednesday: return .wednesday
            case .thursday: return .thursday
            case .friday: return .friday
            case .saturday: return .saturday
            case .sunday: return .sunday
            }
        }

        var calendarWeekday: Calendar.RecurrenceRule.Weekday {
            .every(localeWeekday)
        }
    }

    enum OrdinalUI: Int, CaseIterable {
        case first = 1, second = 2, third = 3, fourth = 4, fifth = 5
        case secondLast = -2, last = -1
    }

    enum MonthlyMode {
        case dates, ordinal
    }

    var body: some View {
        NavigationStack {
            Form {

                Picker("Frequency", selection: $frequency) {
                    Text("Weekly").tag(FrequencyUI.weekly)
                    Text("Monthly").tag(FrequencyUI.monthly)
                    Text("Yearly").tag(FrequencyUI.yearly)
                }

                Stepper(
                    "Every \(interval) \(frequencyLabel)",
                    value: $interval,
                    in: 1...30
                )

                if frequency == .weekly {
                    Section("Repeat every week on") {
                        HStack(spacing: 12) {
                            ForEach(WeekdayUI.allCases, id: \.self) { day in
                                weekdayChip(for: day)
                            }
                        }
                    }
                }

                if frequency == .monthly {
                    Section("Repeat every month on") {

                        Picker("", selection: $monthlyMode) {
                            Text("Dates").tag(MonthlyMode.dates)
                            Text("Weekday").tag(MonthlyMode.ordinal)
                        }
                        .pickerStyle(.segmented)

                        if monthlyMode == .dates {
                            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7)) {
                                ForEach(1...31, id: \.self) { day in
                                    monthDayChip(day)
                                }

                                monthDayChip(-1).overlay(
                                    Text("Last")
                                )
                            }
                        } else {
                            Picker("Ordinal", selection: $ordinal) {
                                ForEach(OrdinalUI.allCases, id: \.self) {
                                    Text("\($0)").tag($0)
                                }
                            }

                            Picker("Weekday", selection: $ordinalWeekday) {
                                ForEach(WeekdayUI.allCases, id: \.self) {
                                    Text($0.short).tag($0)
                                }
                            }
                        }
                    }
                }

                if frequency == .yearly {
                    Section("Repeat every year on") {
                        Picker("Ordinal", selection: $ordinal) {
                            ForEach(OrdinalUI.allCases, id: \.self) {
                                Text("\($0)").tag($0)
                            }
                        }

                        Picker("Weekday", selection: $ordinalWeekday) {
                            ForEach(WeekdayUI.allCases, id: \.self) {
                                Text($0.short).tag($0)
                            }
                        }

                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) {
                                Text(Calendar.current.monthSymbols[$0 - 1]).tag($0)
                            }
                        }
                    }
                }

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
            calendar: .current,
            frequency: frequency == .weekly ? .weekly :
                       frequency == .monthly ? .monthly : .yearly
        )

        rule.interval = interval

        switch frequency {
        case .weekly:
            rule.weekdays = selectedWeekdays.map {
                Calendar.RecurrenceRule.Weekday.every($0.localeWeekday)
            }

        case .monthly:
            if monthlyMode == .dates {
                rule.daysOfTheMonth = selectedMonthDays.sorted()
            } else {
                rule.weekdays = [
                    Calendar.RecurrenceRule.Weekday.nth(
                        ordinal.rawValue,
                        ordinalWeekday.localeWeekday
                    )
                ]
            }

        case .yearly:
            rule.months = [.init(selectedMonth)]
            rule.weekdays = [
                Calendar.RecurrenceRule.Weekday.nth(
                    ordinal.rawValue,
                    ordinalWeekday.localeWeekday
                )
            ]
        }

        switch endType {
        case .never:
            rule.end = .never
        case .onDate:
            let calendar = Calendar.current
            let endOfDay = calendar.date(
                bySettingHour: 23,
                minute: 59,
                second: 59,
                of: endDate
            ) ?? endDate

            rule.end = .afterDate(endOfDay)
        case .after:
            rule.end = .afterOccurrences(occurrenceCount)
        }

        return rule
    }

    private var frequencyLabel: String {
        switch frequency {
        case .weekly: return "week(s)"
        case .monthly: return "month(s)"
        case .yearly: return "year(s)"
        }
    }

    @ViewBuilder
    private func weekdayChip(for day: WeekdayUI) -> some View {
        let isSelected = selectedWeekdays.contains(day)

        Text(day.short)
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.purple : Color.clear)
            .overlay(Circle().stroke(Color.gray))
            .clipShape(Circle())
            .onTapGesture {
                if isSelected {
                    selectedWeekdays.remove(day)
                } else {
                    selectedWeekdays.insert(day)
                }
            }
    }

    @ViewBuilder
    private func monthDayChip(_ day: Int) -> some View {
        let isSelected = selectedMonthDays.contains(day)

        Text("\(day)")
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.purple : Color.clear)
            .overlay(Circle().stroke(Color.gray))
            .clipShape(Circle())
            .onTapGesture {
                if isSelected {
                    selectedMonthDays.remove(day)
                } else {
                    selectedMonthDays.insert(day)
                }
            }
    }
}
