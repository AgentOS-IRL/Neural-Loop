//
//  AddEditHabitView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 11/01/2026.
//

import SwiftUI

struct AddEditHabitView: View {

    // MARK: - Inputs
    let habit: Habits?
    let onSave: (Habits) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Editable State
    @State private var title: String
    @State private var description: String
    @State private var priority: Int

    @State private var goalId: Int64?
    @State private var lifeAreaId: Int64?

    @State private var target: Int
    @State private var label: String

    // Recurrence
    @State private var recurrenceRule: Calendar.RecurrenceRule?
    @State private var showRuleSheet = false

    // MARK: - Init
    init(habit: Habits?, onSave: @escaping (Habits) -> Void) {
        self.habit = habit
        self.onSave = onSave

        _title = State(initialValue: habit?.title ?? "")
        _description = State(initialValue: habit?.description ?? "")
        _priority = State(initialValue: habit?.priority ?? 0)

        _goalId = State(initialValue: habit?.goal_id)
        _lifeAreaId = State(initialValue: habit?.lifearea_id)

        _target = State(initialValue: habit?.target ?? 1)
        _label = State(initialValue: habit?.label ?? "")

        if let ruleString = habit?.target_recursion_rule {
            _recurrenceRule = State(initialValue: try? parse_rrule(rruleString: ruleString))
        } else {
            _recurrenceRule = State(initialValue: nil)
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {

                // MARK: - Title
                Section {
                    TextField("Habit title", text: $title)
                        .font(.headline)
                }

                // MARK: - Description
                Section(header: Text("Description")) {
                    TextField("Optional description", text: $description, axis: .vertical)
                }

                // MARK: - Target
                Section(header: Text("Target")) {
                    Stepper(value: $target, in: 1...100) {
                        Text("Target: \(target)")
                    }
                }

                // MARK: - Recurrence
                Section(header: Text("Repeat")) {
                    Button {
                        showRuleSheet = true
                    } label: {
                        HStack {
                            Text("Schedule")
                            Spacer()
                            Text(recurrenceSummary)
                                .foregroundColor(.secondary)
                        }
                    }

                    if recurrenceRule != nil {
                        Button(role: .destructive) {
                            recurrenceRule = nil
                        } label: {
                            Text("Remove schedule")
                        }
                    }
                }

                // MARK: - Priority
                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(0)
                        Text("Medium").tag(1)
                        Text("High").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: - Label
                Section(header: Text("Label")) {
                    TextField("Optional label", text: $label)
                }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(habit == nil ? "Add" : "Save") {
                        saveHabit()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showRuleSheet) {
                HabitRuleSheet { rule in
                    recurrenceRule = rule
                    showRuleSheet = false
                }
            }
        }
    }

    // MARK: - Helpers

    private var recurrenceSummary: String {
        guard let rule = recurrenceRule else {
            return "Not set"
        }

        return rrule_to_string(rule: rule)
    }

    private func saveHabit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)

        let ruleString = rrule_to_string(rule: recurrenceRule!)

        let newHabit = Habits(
            id: habit?.id,
            title: trimmedTitle,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            priority: priority,
            goal_id: goalId,
            lifearea_id: lifeAreaId,
            target: target,
            target_recursion_rule: ruleString,
            label: label.isEmpty ? nil : label,
            created_at: habit?.created_at,
            updated_at: Date()
        )

        onSave(newHabit)
        dismiss()
    }
}
