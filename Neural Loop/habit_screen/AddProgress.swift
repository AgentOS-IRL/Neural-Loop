import SwiftUI

struct AddProgressView: View {
    let habit: Habits
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

//    @State private var mode: Mode = .add
    @State private var latestTotal: Int = 0
    @State private var inputValue: Int = 0
    @State private var error: String?
    
    @State private var selectedDate: Date = Date()
    
    @State private var showProgressHistory: Bool = false
    
    @State private var habitWindow = HabitWindow(start: Calendar.current.startOfDay(for: .now), end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!, label: "Times")

//    enum Mode: String, CaseIterable {
//        case add = "Add to total"
//        case set = "Enter new total"
//    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
//                Text("Add to total")
//                Picker("", selection: $mode) {
//                    ForEach(Mode.allCases, id: \.self) { mode in
//                        Text(mode.rawValue)
//                    }
//                }
//                .pickerStyle(.segmented)
                
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .onChange(of: selectedDate) {
                    Task {
                        await fetchProgess()
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
                    
                    await fetchProgess()
                    await loadLatestTotal()
                }
            }
            .sheet(isPresented: $showProgressHistory) {
                ProgressHistoryView(habitId: habit.id!, label: habit.label ?? "Times")
            }
        }
    }
    
    private func fetchProgess() async -> Void {
        print("fetchProgess")
        habitWindow = HabitWindow.window(for: habit, reference: selectedDate)
        
    }

    private var displayValue: String {
        return "\(inputValue)"
//        switch mode {
//        case .add:
//            return "\(latestTotal) + \(inputValue)"
//        case .set:
//            return "\(inputValue)"
//        }
    }

    private func loadLatestTotal() async {
        do {
            
            let manager = DBManager.newInstance()
            let entries = try await manager.fetchHabitEntries(forTask: habit.id!, from: habitWindow.start, to: habitWindow.end)
            var total = 0
            entries.forEach { total += Int($0.value) }
            latestTotal = total
            inputValue = 0
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save() async {
        do {
            let manager = DBManager.newInstance()
//            let newValue = mode == .add
//                ? latestTotal + inputValue
//                : inputValue
            
            _ = try await manager.addHabitEntry(
                habitId: habit.id!,
                value: inputValue,
                date: selectedDate
            )

            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
