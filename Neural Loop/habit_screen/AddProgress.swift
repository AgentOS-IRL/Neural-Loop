import SwiftUI


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
    
    @State private var habitWindow = HabitWindow(start: Calendar.current.startOfDay(for: .now), end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!, label: "Times", frequency: .daily)
    
    @State private var trendFrequency: TrendFrequency = .weekly
    @State private var trendsData: [Date: Float] = [:]


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
                    if !trendsData.isEmpty {
                        TrendsBarChart(
                            data: trendsData,
                            frequency: trendFrequency
                        )
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } header: {
                    HStack {
                        Text("Trends")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer()

                        Menu {
                            Button("Weekly") {
                                trendFrequency = .weekly
                                Task { await loadTrends() }
                            }

                            Button("Monthly") {
                                trendFrequency = .monthly
                                Task { await loadTrends() }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .rotationEffect(.degrees(90))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }
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
                    await loadTrends()
                }
            }
            .sheet(isPresented: $showProgressHistory) {
                ProgressHistoryView(habitId: habit.id!, label: habit.label ?? "Times")
            }
        }
    }
    
    private func getTrendsData(frequency: Calendar.RecurrenceRule.Frequency) async -> [Date: Float]{
        await model.getTrendsData(forHabitWithId: habit.id!, frequency: frequency)
    }
    
    private func loadTrends() async {
        trendsData = await getTrendsData(frequency: trendFrequency.get_frequency())
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
