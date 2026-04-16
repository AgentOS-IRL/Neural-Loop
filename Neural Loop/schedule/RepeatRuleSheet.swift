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

    let onSave: (Calendar.RecurrenceRule) -> Void
    let initialRule: Calendar.RecurrenceRule?
    init(
        initialRule: Calendar.RecurrenceRule? = nil,
        onSave: @escaping (Calendar.RecurrenceRule) -> Void
    ) {
        self.initialRule = initialRule
        self.onSave = onSave

        if let rule = initialRule {
            switch rule.frequency {
            case .weekly:
                _frequency = State(initialValue: .weekly)
            case .monthly:
                _frequency = State(initialValue: .monthly)
            case .yearly:
                _frequency = State(initialValue: .yearly)
            default:
                _frequency = State(initialValue: .weekly)
            }

            _interval = State(initialValue: max(rule.interval, 1))

            let weekdays = rule.weekdays
            if !weekdays.isEmpty {
                let mapped = weekdays.compactMap { weekday -> WeekdayUI? in
                    switch weekday {
                    case .every(let w), .nth(_, let w):
                        switch w {
                        case .monday: return .monday
                        case .tuesday: return .tuesday
                        case .wednesday: return .wednesday
                        case .thursday: return .thursday
                        case .friday: return .friday
                        case .saturday: return .saturday
                        case .sunday: return .sunday
                        @unknown default:
                            return nil
                        }
                    @unknown default:
                        return nil
                    }
                }
                _selectedWeekdays = State(initialValue: Set(mapped))
            }

            let days = rule.daysOfTheMonth
            if !days.isEmpty {
                _monthlyMode = State(initialValue: .dates)
                _selectedMonthDays = State(initialValue: Set(days))
            } else if let first = rule.weekdays.first,
                      case let .nth(nth, _) = first {
                _monthlyMode = State(initialValue: .ordinal)
                _ordinal = State(initialValue: OrdinalUI(rawValue: nth) ?? .first)

                switch first {
                case .every(let w), .nth(_, let w):
                    switch w {
                    case .monday: _ordinalWeekday = State(initialValue: .monday)
                    case .tuesday: _ordinalWeekday = State(initialValue: .tuesday)
                    case .wednesday: _ordinalWeekday = State(initialValue: .wednesday)
                    case .thursday: _ordinalWeekday = State(initialValue: .thursday)
                    case .friday: _ordinalWeekday = State(initialValue: .friday)
                    case .saturday: _ordinalWeekday = State(initialValue: .saturday)
                    case .sunday: _ordinalWeekday = State(initialValue: .sunday)
                    @unknown default:
                        break
                    }
                @unknown default:
                    break
                }
            }

            let months = rule.months
            if let firstMonth = months.first {
                _selectedMonth = State(initialValue: firstMonth.index)
            }
            
            
            if rule.end != .never {
                if rule.end.occurrences != nil {
                    _endType = State(initialValue: .after)
                    _occurrenceCount = State(initialValue: rule.end.occurrences!)
                    
                }
                else if rule.end.date != nil {
                    _endType = State(initialValue: .onDate)
                    _endDate = State(initialValue: (rule.end.date!))
                }
            }
            else{
                _endType = State(initialValue: .never)
            }
            
        
        }
    }

    enum FrequencyUI: String, CaseIterable {
        case weekly, monthly, yearly
    }

    @State private var frequency: FrequencyUI = .weekly
    @State private var interval: Int = 1

    @State private var selectedWeekdays: Set<WeekdayUI> = Set(WeekdayUI.allCases)
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
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        
                        // Frequency & Interval
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Frequency")
                            ThemedCard {
                                Picker("Frequency", selection: $frequency) {
                                    Text("Weekly").tag(FrequencyUI.weekly)
                                    Text("Monthly").tag(FrequencyUI.monthly)
                                    Text("Yearly").tag(FrequencyUI.yearly)
                                }
                                .pickerStyle(.segmented)

                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                Stepper(value: $interval, in: 1...30) {
                                    HStack {
                                        Text("Interval")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Text("Every \(interval) \(frequencyLabel)")
                                            .font(.body.bold())
                                            .foregroundColor(AppTheme.accentColor)
                                    }
                                }
                            }
                        }

                        if frequency == .weekly {
                            VStack(alignment: .leading, spacing: 4) {
                                themedSectionHeader("Repeat on")
                                ThemedCard {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(WeekdayUI.allCases, id: \.self) { day in
                                                weekdayChip(for: day)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }

                        if frequency == .monthly {
                            VStack(alignment: .leading, spacing: 4) {
                                themedSectionHeader("Repeat on")
                                ThemedCard {
                                    Picker("", selection: $monthlyMode) {
                                        Text("Dates").tag(MonthlyMode.dates)
                                        Text("Weekday").tag(MonthlyMode.ordinal)
                                    }
                                    .pickerStyle(.segmented)

                                    if monthlyMode == .dates {
                                        Divider()
                                            .background(AppTheme.textSecondary.opacity(0.1))
                                        
                                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7), spacing: 10) {
                                            ForEach(1...31, id: \.self) { day in
                                                monthDayChip(day)
                                            }
                                            monthDayChip(-1)
                                        }
                                        .padding(.vertical, 8)
                                    } else {
                                        Divider()
                                            .background(AppTheme.textSecondary.opacity(0.1))
                                        
                                        HStack {
                                            Text("Ordinal")
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            Picker("Ordinal", selection: $ordinal) {
                                                ForEach(OrdinalUI.allCases, id: \.self) { value in
                                                    Text(ordinalLabel(value)).tag(value)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                        }

                                        Divider()
                                            .background(AppTheme.textSecondary.opacity(0.1))

                                        HStack {
                                            Text("Weekday")
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            Picker("Weekday", selection: $ordinalWeekday) {
                                                ForEach(WeekdayUI.allCases, id: \.self) {
                                                    Text($0.short).tag($0)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                        }
                                    }
                                }
                            }
                        }

                        if frequency == .yearly {
                            VStack(alignment: .leading, spacing: 4) {
                                themedSectionHeader("Repeat on")
                                ThemedCard {
                                    HStack {
                                        Text("Ordinal")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Picker("Ordinal", selection: $ordinal) {
                                            ForEach(OrdinalUI.allCases, id: \.self) { value in
                                                Text(ordinalLabel(value)).tag(value)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }

                                    Divider()
                                        .background(AppTheme.textSecondary.opacity(0.1))

                                    HStack {
                                        Text("Weekday")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Picker("Weekday", selection: $ordinalWeekday) {
                                            ForEach(WeekdayUI.allCases, id: \.self) {
                                                Text($0.short).tag($0)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }

                                    Divider()
                                        .background(AppTheme.textSecondary.opacity(0.1))

                                    HStack {
                                        Text("Month")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Picker("Month", selection: $selectedMonth) {
                                            ForEach(1...12, id: \.self) {
                                                Text(Calendar.current.monthSymbols[$0 - 1]).tag($0)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("End")
                            ThemedCard {
                                Picker("End", selection: $endType) {
                                    Text("Never").tag(EndType.never)
                                    Text("On Date").tag(EndType.onDate)
                                    Text("After").tag(EndType.after)
                                }
                                .pickerStyle(.segmented)

                                if endType == .onDate {
                                    Divider()
                                        .background(AppTheme.textSecondary.opacity(0.1))
                                    
                                    DatePicker(
                                        "End Date",
                                        selection: $endDate,
                                        displayedComponents: .date
                                    )
                                    .tint(AppTheme.accentColor)
                                }

                                if endType == .after {
                                    Divider()
                                        .background(AppTheme.textSecondary.opacity(0.1))
                                    
                                    Stepper(value: $occurrenceCount, in: 1...999) {
                                        HStack {
                                            Text("Occurrences")
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            Text("\(occurrenceCount)")
                                                .font(.body.bold())
                                                .foregroundColor(AppTheme.accentColor)
                                        }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(buildRule())
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                    .foregroundColor(AppTheme.accentColor)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func ordinalLabel(_ ordinal: OrdinalUI) -> String {
        switch ordinal {
        case .first: return "First"
        case .second: return "Second"
        case .third: return "Third"
        case .fourth: return "Fourth"
        case .fifth: return "Fifth"
        case .secondLast: return "Second Last"
        case .last: return "Last"
        }
    }

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
        case .weekly: return interval > 1 ? "weeks" : "week"
        case .monthly: return interval > 1 ? "months" : "month"
        case .yearly: return interval > 1 ? "years" : "year"
        }
    }

    @ViewBuilder
    private func weekdayChip(for day: WeekdayUI) -> some View {
        let isSelected = selectedWeekdays.contains(day)

        Text(day.short)
            .font(.subheadline.bold())
            .frame(width: 44, height: 44)
            .background(isSelected ? AppTheme.accentGradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
            .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.clear : AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
            )
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
        let label = day == -1 ? "Last" : "\(day)"

        Text(label)
            .font(.system(size: day == -1 ? 10 : 14, weight: .bold))
            .frame(width: 40, height: 40)
            .background(isSelected ? AppTheme.accentGradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
            .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.clear : AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
            )
            .onTapGesture {
                if isSelected {
                    selectedMonthDays.remove(day)
                } else {
                    selectedMonthDays.insert(day)
                }
            }
    }
}
