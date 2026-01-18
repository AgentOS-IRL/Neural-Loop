import SwiftUI



struct HabitProgress {
    let current: Int
    let target: Int
    let targetLabel: String
    let windowLabel: String

    var ratio: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
}

struct HabitWindow {
    let start: Date
    let end: Date
    let label: String
    
    static func get_frequency(for habit: Habits) -> Calendar.RecurrenceRule.Frequency {
        guard
            let ruleString = habit.target_recursion_rule,
            let rule = try? parse_rrule(rruleString: ruleString)
        else {
            return Calendar.RecurrenceRule.Frequency.daily
        }
        return rule.frequency
        
    }

    static func window(for habit: Habits, reference: Date) -> HabitWindow {
        let frequency = HabitWindow.get_frequency(for: habit)

        switch frequency {
        case .daily:
            return _day(reference)
        case .weekly:
            return _week(reference)
        case .monthly:
            return _month(reference)
        default:
            return _day(reference)
        }
    }

    private static func _day(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        return HabitWindow(
            start: cal.startOfDay(for: date),
            end: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date))!,
            label: "Today"
        )
    }
    
    static func longWindow(for date: Date) -> HabitWindow {
        return _week(date)
    }

    private static func _week(_ date: Date) -> HabitWindow {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday

        let startOfDay = calendar.startOfDay(for: date)

        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)
        )!

        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        return HabitWindow(
            start: weekStart,
            end: weekEnd,
            label: "This Week"
        )
    }

    private static func _month(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        return HabitWindow(start: start, end: end, label: "This Month")
    }
}



struct AddProgressView: View {
    let habit: Habits
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: UnifiedDataModel

    @State private var latestTotal: Int = 0
    @State private var inputValue: Int = 0
    @State private var error: String?
    
    @State private var selectedDate: Date = Date()
    
    @State private var showProgressHistory: Bool = false
    @State private var isAddProgressExpanded = true
    
    @State private var habitWindow = HabitWindow(start: Calendar.current.startOfDay(for: .now), end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!, label: "Times")


    var body: some View {
        NavigationView {
            VStack(spacing: 14) {

                Section {
                    if isAddProgressExpanded {
                        VStack(spacing: 10) {
                            
                            // Top row: Date + Value
                            HStack(alignment: .center) {
                                DatePicker(
                                    "",
                                    selection: $selectedDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .onChange(of: selectedDate) {
                                    Task { await loadLatestTotal() }
                                }
                                
                                Spacer()
                                
                                Text(displayValue)
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                            }
                            
                            // Total label
                            Text("Total: \(latestTotal) \(habit.label ?? "Times")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Stepper row
                            HStack {
                                Stepper(value: $inputValue, in: 0...100000) {
                                    Text("+\(inputValue)")
                                        .font(.body.weight(.medium))
                                }
                            }
                            
                            // Primary action
                            Button {
                                Task { await save() }
                            } label: {
                                Label("Add Progress", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                        }
                        .padding(14)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        // History link
                        Button {
                            showProgressHistory = true
                        } label: {
                            HStack {
                                Text("View earlier records")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    }
                } header: {
                    DisclosureGroup(
                        isExpanded: $isAddProgressExpanded
                    ) {
                        EmptyView() // required, content lives in Section body
                    } label: {
                        Text("Add Progress")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary)   // keeps default (white in dark mode)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Divider()
                Section {
                    EmptyView()
                } header: {
                    Text("Trends")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)   // keeps default (white in dark mode)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                   
                Spacer()
                
            }
            .padding()
            .navigationTitle(habit.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    
                    await loadLatestTotal()
                }
            }
            .sheet(isPresented: $showProgressHistory) {
                ProgressHistoryView(habitId: habit.id!, label: habit.label ?? "Times")
            }
        }
    }
    

    private var displayValue: String {
        return "\(inputValue)"
    }

    private func loadLatestTotal() async {
        habitWindow = HabitWindow.window(for: habit, reference: selectedDate)
        let entries = await model.fetchHabitTrackingEntries(by: habit.id!, window: habitWindow)
        var total = 0
        entries.forEach { total += Int($0.value) }
        latestTotal = total
        inputValue = 0
    
    }

    private func save() async {
    
        await model.incrementHabit(habit, value: inputValue, date: selectedDate)
        onSaved()
        dismiss()
        
    }
}
