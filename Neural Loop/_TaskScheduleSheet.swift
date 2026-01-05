//import Foundation
//import SwiftUI
//import EventKit
//
//enum RepeatPreset: Identifiable, CaseIterable {
//    case never, daily, weekly, biweekly, monthly, yearly, custom
//
//    var id: String { title }
//
//    var title: String {
//        switch self {
//        case .never: return "Never"
//        case .daily: return "Every Day"
//        case .weekly: return "Every Week"
//        case .biweekly: return "Every 2 Weeks"
//        case .monthly: return "Every Month"
//        case .yearly: return "Every Year"
//        case .custom: return "Custom"
//        }
//    }
//}
//
//struct TaskScheduleDraft {
//    let start: Date
//    let end: Date
//    let isAllDay: Bool
//    let recurrence: RecurrenceConfig?
//}
//
//struct RecurrenceConfig: Equatable {
//    enum MonthYearMode: String, Equatable {
//        case each      // specific dates (e.g. 5th, 10th)
//        case onThe     // positional rules (e.g. first weekday)
//    }
//
//    var frequency: EKRecurrenceFrequency
//    var interval: Int = 1
//
//    // Shared
//    var daysOfWeek: Set<EKWeekday> = []
//
//    // Each
//    var daysOfMonth: Set<Int> = []
//    var monthsOfYear: Set<Int> = []
//
//    // On the
//    var setPositions: Set<Int> = []
//
//    var mode: MonthYearMode = .each
//    var end: RecurrenceEnd = .never
//}
//
//
//enum RecurrenceEnd: Hashable {
//    case never
//    case onDate(Date)
//    case after(Int)
//}
//
//enum OrdinalOption: Int, CaseIterable, Identifiable {
//    case first = 1
//    case second = 2
//    case third = 3
//    case fourth = 4
//    case fifth = 5
//    case secondLast = -2
//    case last = -1
//
//    var id: Int { rawValue }
//
//    var title: String {
//        switch self {
//        case .first: return "First"
//        case .second: return "Second"
//        case .third: return "Third"
//        case .fourth: return "Fourth"
//        case .fifth: return "Fifth"
//        case .secondLast: return "Next to last"
//        case .last: return "Last"
//        }
//    }
//}
//
//enum WeekdayOption: CaseIterable, Identifiable {
//    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
//
//    var id: EKWeekday { ek }
//
//    var title: String {
//        switch self {
//        case .monday: return "Monday"
//        case .tuesday: return "Tuesday"
//        case .wednesday: return "Wednesday"
//        case .thursday: return "Thursday"
//        case .friday: return "Friday"
//        case .saturday: return "Saturday"
//        case .sunday: return "Sunday"
//        }
//    }
//
//    var ek: EKWeekday {
//        switch self {
//        case .monday: return .monday
//        case .tuesday: return .tuesday
//        case .wednesday: return .wednesday
//        case .thursday: return .thursday
//        case .friday: return .friday
//        case .saturday: return .saturday
//        case .sunday: return .sunday
//        }
//    }
//}
//
//struct MonthPickerGrid: View {
//    @Binding var selectedMonths: Set<Int>
//
//    private let months = Calendar.current.monthSymbols.enumerated().map { ($0 + 1, $1.prefix(3)) }
//
//    private let columns = Array(repeating: GridItem(.flexible()), count: 4)
//
//    var body: some View {
//        LazyVGrid(columns: columns, spacing: 10) {
//            ForEach(months, id: \.0) { month, label in
//                Button {
//                    if selectedMonths.contains(month) {
//                        selectedMonths.remove(month)
//                    } else {
//                        selectedMonths.insert(month)
//                    }
//                } label: {
//                    Text(String(label))
//                        .font(.subheadline)
//                        .padding(8)
//                        .frame(maxWidth: .infinity)
//                        .background(
//                            selectedMonths.contains(month)
//                            ? Color.accentColor.opacity(0.2)
//                            : Color.clear
//                        )
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                }
//                .buttonStyle(.plain)
//            }
//        }
//    }
//}
//
//struct MonthDayGrid: View {
//    @Binding var selectedDays: Set<Int>
//
//    private let days = Array(1...31)
//
//    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
//
//    var body: some View {
//        LazyVGrid(columns: columns, spacing: 8) {
//            ForEach(days, id: \.self) { day in
//                Button {
//                    if selectedDays.contains(day) {
//                        selectedDays.remove(day)
//                    } else {
//                        selectedDays.insert(day)
//                    }
//                } label: {
//                    Text("\(day)")
//                        .font(.subheadline)
//                        .frame(width: 30, height: 30)
//                        .background(
//                            selectedDays.contains(day)
//                            ? Color.accentColor.opacity(0.2)
//                            : Color.clear
//                        )
//                        .clipShape(Circle())
//                }
//                .buttonStyle(.plain)
//            }
//        }
//    }
//}
//
//
//struct WeekdayPicker: View {
//    @Binding var selected: Set<EKWeekday>
//
//    private let days: [(EKWeekday, String)] = [
//        (.monday, "M"),
//        (.tuesday, "T"),
//        (.wednesday, "W"),
//        (.thursday, "T"),
//        (.friday, "F"),
//        (.saturday, "S"),
//        (.sunday, "S")
//    ]
//
//    var body: some View {
//        HStack(spacing: 8) {
//            ForEach(days, id: \.0) { day, label in
//                Button {
//                    if selected.contains(day) {
//                        selected.remove(day)
//                    } else {
//                        selected.insert(day)
//                    }
//                } label: {
//                    Text(label)
//                        .font(.subheadline.weight(.medium))
//                        .frame(width: 32, height: 32)
//                        .background(
//                            selected.contains(day)
//                            ? Color.accentColor.opacity(0.2)
//                            : Color.clear
//                        )
//                        .clipShape(Circle())
//                }
//                .buttonStyle(.plain)
//            }
//        }
//    }
//}
//
//struct OrdinalButtonGroup: View {
//    @Binding var selected: Int
//
//    private let columns = [
//        GridItem(.flexible()),
//        GridItem(.flexible()),
//        GridItem(.flexible())
//    ]
//
//    var body: some View {
//        LazyVGrid(columns: columns, spacing: 8) {
//            ForEach(OrdinalOption.allCases) { option in
//                Button {
//                    selected = option.rawValue
//                } label: {
//                    Text(option.title)
//                        .font(.subheadline)
//                        .lineLimit(1)
//                        .minimumScaleFactor(0.8)
//                        .frame(maxWidth: .infinity, minHeight: 32)
//                        .padding(.vertical, 6)
//                        .background(
//                            selected == option.rawValue
//                            ? Color.accentColor.opacity(0.25)
//                            : Color.secondary.opacity(0.15)
//                        )
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                }
//                .buttonStyle(.plain)
//            }
//        }
//    }
//}
//
//struct SingleWeekdayButtonGroup: View {
//    @Binding var selected: EKWeekday
//
//    var body: some View {
//        HStack(spacing: 8) {
//            ForEach(WeekdayOption.allCases) { option in
//                Button {
//                    selected = option.ek
//                } label: {
//                    Text(option.title.prefix(3))
//                        .font(.subheadline.weight(.medium))
//                        .frame(width: 44, height: 32)
//                        .background(
//                            selected == option.ek
//                            ? Color.accentColor.opacity(0.25)
//                            : Color.secondary.opacity(0.15)
//                        )
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                }
//                .buttonStyle(.plain)
//            }
//        }
//    }
//}
//
//struct CustomRecurrenceView: View {
//
//    @Binding var recurrence: RecurrenceConfig
//
//    // New bindings for button groups
//    private var ordinalValueBinding: Binding<Int> {
//        Binding(
//            get: { recurrence.setPositions.first ?? 1 },
//            set: {
//                recurrence.setPositions = [$0]
//            }
//        )
//    }
//
//    private var singleWeekdayBinding: Binding<EKWeekday> {
//        Binding(
//            get: { recurrence.daysOfWeek.first ?? .monday },
//            set: {
//                recurrence.daysOfWeek = [$0]
//            }
//        )
//    }
//
//    // Keep old bindings (not used anymore)
//    private var ordinalBinding: Binding<OrdinalOption> {
//        Binding(
//            get: {
//                OrdinalOption(rawValue: recurrence.setPositions.first ?? 1) ?? .first
//            },
//            set: { newValue in
//                recurrence.setPositions = [newValue.rawValue]
//                recurrence.daysOfMonth.removeAll()
//            }
//        )
//    }
//
//    private var weekdayBinding: Binding<WeekdayOption> {
//        Binding(
//            get: {
//                WeekdayOption.allCases.first {
//                    recurrence.daysOfWeek.contains($0.ek)
//                } ?? .monday
//            },
//            set: { newValue in
//                recurrence.daysOfWeek = [newValue.ek]
//                recurrence.daysOfMonth.removeAll()
//            }
//        )
//    }
//
//    var body: some View {
//        Section("Custom Repeat") {
//
//            Picker("Frequency", selection: $recurrence.frequency) {
//                Text("Daily").tag(EKRecurrenceFrequency.daily)
//                Text("Weekly").tag(EKRecurrenceFrequency.weekly)
//                Text("Monthly").tag(EKRecurrenceFrequency.monthly)
//                Text("Yearly").tag(EKRecurrenceFrequency.yearly)
//            }
//            .pickerStyle(.segmented)
//
//            Stepper(
//                "Every \(recurrence.interval) \(unit)",
//                value: $recurrence.interval,
//                in: 1...30
//            )
//
//            if recurrence.frequency == .weekly {
//                WeekdayPicker(selected: $recurrence.daysOfWeek)
//            }
//
//            if recurrence.frequency == .monthly {
//
//                Picker("", selection: $recurrence.mode) {
//                    Text("Each").tag(RecurrenceConfig.MonthYearMode.each)
//                    Text("On the").tag(RecurrenceConfig.MonthYearMode.onThe)
//                }
//                .pickerStyle(.segmented)
//                .onChange(of: recurrence.mode) { mode in
//                    switch mode {
//                    case .each:
//                        recurrence.setPositions.removeAll()
//                        recurrence.daysOfWeek.removeAll()
//                    case .onThe:
//                        recurrence.daysOfMonth.removeAll()
//                        recurrence.monthsOfYear.removeAll()
//                    }
//                }
//
//                if recurrence.mode == .each {
//                    Text("Each month on:")
//                    MonthDayGrid(selectedDays: $recurrence.daysOfMonth)
//                    .onChange(of: recurrence.daysOfMonth) {
//                        recurrence.setPositions.removeAll()
//                        recurrence.daysOfWeek.removeAll()
//                    }
//                }
//
//                if recurrence.mode == .onThe {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Ordinal")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//
//                        OrdinalButtonGroup(selected: ordinalValueBinding)
//
//                        Text("Weekday")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//
//                        SingleWeekdayButtonGroup(selected: singleWeekdayBinding)
//                    }
//                }
//            }
//
//            if recurrence.frequency == .yearly {
//
//                Picker("", selection: $recurrence.mode) {
//                    Text("Each").tag(RecurrenceConfig.MonthYearMode.each)
//                    Text("On the").tag(RecurrenceConfig.MonthYearMode.onThe)
//                }
//                .pickerStyle(.segmented)
//                .onChange(of: recurrence.mode) { mode in
//                    switch mode {
//                    case .each:
//                        recurrence.setPositions.removeAll()
//                        recurrence.daysOfWeek.removeAll()
//                    case .onThe:
//                        recurrence.daysOfMonth.removeAll()
//                        recurrence.monthsOfYear.removeAll()
//                    }
//                }
//
//                if recurrence.mode == .each {
//                    Text("Select months:")
//                    MonthPickerGrid(selectedMonths: $recurrence.monthsOfYear)
//
//                    Text("Select days of month:")
//                    MonthDayGrid(selectedDays: $recurrence.daysOfMonth)
//                    .onChange(of: recurrence.daysOfMonth) {
//                        recurrence.setPositions.removeAll()
//                        recurrence.daysOfWeek.removeAll()
//                    }
//                }
//
//                if recurrence.mode == .onThe {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Ordinal")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//
//                        OrdinalButtonGroup(selected: ordinalValueBinding)
//
//                        Text("Weekday")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//
//                        SingleWeekdayButtonGroup(selected: singleWeekdayBinding)
//                    }
//                }
//            }
//        }
//    }
//
//    private var unit: String {
//        switch recurrence.frequency {
//        case .daily: "day(s)"
//        case .weekly: "week(s)"
//        case .monthly: "month(s)"
//        case .yearly: "year(s)"
//        @unknown default: ""
//        }
//    }
//}
//
//func buildRule(from config: RecurrenceConfig) -> EKRecurrenceRule {
//    let end: EKRecurrenceEnd? = {
//        switch config.end {
//        case .never:
//            return nil
//        case .onDate(let date):
//            return EKRecurrenceEnd(end: date)
//        case .after(let count):
//            return EKRecurrenceEnd(occurrenceCount: count)
//        }
//    }()
//
//    let daysOfWeek = config.daysOfWeek.isEmpty
//        ? nil
//        : config.daysOfWeek.map { EKRecurrenceDayOfWeek($0) }
//
//    let daysOfMonth = config.daysOfMonth.isEmpty
//        ? nil
//        : config.daysOfMonth.map { NSNumber(value: $0) }
//
//    let monthsOfYear = config.monthsOfYear.isEmpty
//        ? nil
//        : config.monthsOfYear.map { NSNumber(value: $0) }
//
//    let setPositions = config.setPositions.isEmpty
//        ? nil
//        : config.setPositions.map { NSNumber(value: $0) }
//
//    return EKRecurrenceRule(
//        recurrenceWith: config.frequency,
//        interval: config.interval,
//        daysOfTheWeek: daysOfWeek,
//        daysOfTheMonth: daysOfMonth,
//        monthsOfTheYear: monthsOfYear,
//        weeksOfTheYear: nil,
//        daysOfTheYear: nil,
//        setPositions: setPositions,
//        end: end
//    )
//}
//
//func presetToRecurrence(_ preset: RepeatPreset) -> RecurrenceConfig? {
//    switch preset {
//    case .never:
//        return nil
//    case .daily:
//        return .init(frequency: .daily)
//    case .weekly:
//        return .init(frequency: .weekly, daysOfWeek: [.monday])
//    case .biweekly:
//        return .init(frequency: .weekly, interval: 2, daysOfWeek: [.monday])
//    case .monthly:
//        return .init(frequency: .monthly, daysOfMonth: [1])
//    case .yearly:
//        return .init(frequency: .yearly, daysOfMonth: [1], monthsOfYear: [1])
//    case .custom:
//        return .init(frequency: .monthly, daysOfMonth: [1])
//    }
//}
//
//struct TaskScheduleSheet: View {
//
//    @Environment(\.dismiss) private var dismiss
//
//    @State private var startDate = Date()
//    @State private var endDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
//
//    @State private var isAllDay = false
//    @State private var repeatPreset: RepeatPreset = .never
//    @State private var recurrence: RecurrenceConfig?
//
//    let onSave: (TaskScheduleDraft) -> Void
//
//    private var endTypeBinding: Binding<Int> {
//        Binding(
//            get: {
//                switch recurrence!.end {
//                case .never: return 0
//                case .onDate: return 1
//                case .after: return 2
//                }
//            },
//            set: {
//                switch $0 {
//                case 1:
//                    recurrence!.end = .onDate(Date())
//                case 2:
//                    recurrence!.end = .after(1)
//                default:
//                    recurrence!.end = .never
//                }
//            }
//        )
//    }
//
//    private var endRepeatSection: some View {
//        Section("End Repeat") {
//            Picker("End", selection: endTypeBinding) {
//                Text("Never").tag(0)
//                Text("On Date").tag(1)
//                Text("After").tag(2)
//            }
//
//            if case .onDate(let date) = recurrence!.end {
//                DatePicker(
//                    "End Date",
//                    selection: Binding(
//                        get: { date },
//                        set: { recurrence!.end = .onDate($0) }
//                    ),
//                    displayedComponents: [.date]
//                )
//            }
//
//            if case .after(let count) = recurrence!.end {
//                Stepper(
//                    "After \(count) occurrences",
//                    value: Binding(
//                        get: { count },
//                        set: { recurrence!.end = .after($0) }
//                    ),
//                    in: 1...999
//                )
//            }
//        }
//    }
//
//    var body: some View {
//        NavigationStack {
//            Form {
//                timingSection
//                repeatSection
//                if repeatPreset == .custom, let recurrence = recurrence {
//                    CustomRecurrenceView(recurrence: Binding(
//                        get: { recurrence },
//                        set: { self.recurrence = $0 }
//                    ))
//                }
//                if recurrence != nil {
//                    endRepeatSection
//                }
//            }
//            .navigationTitle("Schedule")
//            .toolbar { toolbar }
//        }
//    }
//
//    private var repeatSection: some View {
//        Section {
//            Picker("Repeat", selection: $repeatPreset) {
//                ForEach(RepeatPreset.allCases) {
//                    Text($0.title).tag($0)
//                }
//            }
//            .onChange(of: repeatPreset) {
//                recurrence = presetToRecurrence($0)
//            }
//        }
//    }
//
//    private var timingSection: some View {
//        Section {
//            Toggle("All-day", isOn: $isAllDay)
//
//            DatePicker(
//                "Starts",
//                selection: $startDate,
//                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
//            )
//
//            DatePicker(
//                "Ends",
//                selection: $endDate,
//                in: startDate...,
//                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
//            )
//        }
//    }
//
//    @ToolbarContentBuilder
//    private var toolbar: some ToolbarContent {
//        ToolbarItem(placement: .confirmationAction) {
//            Button("Save") {
//                let draft = TaskScheduleDraft(
//                    start: startDate,
//                    end: endDate,
//                    isAllDay: isAllDay,
//                    recurrence: recurrence
//                )
//                onSave(draft)
//                dismiss()
//            }
//        }
//
//        ToolbarItem(placement: .cancellationAction) {
//            Button("Cancel") {
//                dismiss()
//            }
//        }
//    }
//
//}
