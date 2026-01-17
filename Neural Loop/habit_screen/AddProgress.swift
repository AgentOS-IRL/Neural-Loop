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

    static func window(for habit: Habits, reference: Date) -> HabitWindow {
        guard
            let ruleString = habit.target_recursion_rule,
            let rule = try? parse_rrule(rruleString: ruleString)
        else {
            return day(reference)
        }

        switch rule.frequency {
        case .daily:
            return day(reference)
        case .weekly:
            return week(reference)
        case .monthly:
            return month(reference)
        default:
            return day(reference)
        }
    }

    private static func day(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        return HabitWindow(
            start: cal.startOfDay(for: date),
            end: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date))!,
            label: "Today"
        )
    }

    private static func week(_ date: Date) -> HabitWindow {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        return HabitWindow(start: start, end: end, label: "This Week")
    }

    private static func month(_ date: Date) -> HabitWindow {
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
    
    @State private var habitWindow = HabitWindow(start: Calendar.current.startOfDay(for: .now), end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!, label: "Times")


    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .onChange(of: selectedDate) {
                    Task {
                        await loadLatestTotal()
                    }
                }

                VStack(spacing: 8) {
                    Text(displayValue)
                        .font(.system(size: 48, weight: .bold))

                    Text("Total: \(latestTotal) \(habit.label ?? "Times")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Stepper(
                    value: $inputValue,
                    in: 0...100000
                ) {
                    Text("Value: \(inputValue)")
                }
                Button {
                    showProgressHistory = true
                } label: {
                    HStack {
                        Text("View earlier records")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.secondary)
                }
                   
                Spacer()
                

                Button("Add progress") {
                    Task { await save() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Add Progress")
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
