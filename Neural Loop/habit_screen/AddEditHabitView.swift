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
    @EnvironmentObject var model: UnifiedDataModel

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
    @State private var showGoalSheet = false
    @State private var GoalOrLifeAreadName: String = "Select Goal or Life Area"

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
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        
                        // MARK: Title & Goal/Area
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Habit Info")
                            ThemedCard {
                                ThemedTextField(placeholder: "Habit title", text: $title, isTitle: true)
                                
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                Button {
                                    showGoalSheet = true
                                } label: {
                                    ThemedRow {
                                        Label(GoalOrLifeAreadName, systemImage: "scope")
                                            .foregroundColor(GoalOrLifeAreadName == "Select Goal or Life Area" ? AppTheme.textSecondary : AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }

                        // MARK: Description
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Description")
                            ThemedCard {
                                TextEditor(text: $description)
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)
                                    .font(.body)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }

                        // MARK: Target
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Target")
                            ThemedCard {
                                Stepper(value: $target, in: 1...100) {
                                    HStack {
                                        Text("Daily Target")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Text("\(target)")
                                            .font(.body.bold())
                                            .foregroundColor(AppTheme.accentColor)
                                    }
                                }
                            }
                        }

                        // MARK: Recurrence
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Repeat")
                            ThemedCard {
                                Button {
                                    showRuleSheet = true
                                } label: {
                                    ThemedRow {
                                        Text("Schedule")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Text(recurrenceSummary)
                                            .font(.subheadline)
                                            .foregroundColor(AppTheme.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }

                                if recurrenceRule != nil {
                                    Divider()
                                        .background(AppTheme.textSecondary.opacity(0.1))
                                    
                                    Button(role: .destructive) {
                                        recurrenceRule = nil
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Text("Remove schedule")
                                                .font(.subheadline.bold())
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }

                        // MARK: Priority & Label
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Details")
                            ThemedCard {
                                Picker("Priority", selection: $priority) {
                                    Text("Low").tag(0)
                                    Text("Medium").tag(1)
                                    Text("High").tag(2)
                                }
                                .pickerStyle(.segmented)
                                
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                HStack {
                                    Text("Label")
                                        .foregroundColor(AppTheme.textPrimary)
                                    TextField("Optional label", text: $label)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(AppTheme.Metrics.screenPadding)
                    .padding(.bottom, SAFE_AREA_INSET + 20)
                }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(habit == nil ? "Add" : "Save") {
                        saveHabit()
                    }
                    .font(.body.weight(.bold))
                    .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty ? AppTheme.textSecondary : AppTheme.accentColor)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showRuleSheet) {
                HabitRuleSheet { rule in
                    recurrenceRule = rule
                    showRuleSheet = false
                }
            }.sheet(isPresented: $showGoalSheet) {
                GoalSelectionSheet { result in
                    guard let result else {
                            return
                        }
                    goalId = nil
                    lifeAreaId = nil

                        switch result {

                        case .goal(let id, let title):
                            GoalOrLifeAreadName = "Goal: \(title)"
                            goalId = id

                        case .lifeArea(let id, let name):
                            GoalOrLifeAreadName = "Life Area: \(name)"
                            lifeAreaId = id
                        }
                }
            }.task {
                GoalOrLifeAreadName = await model.getGoalName(goal_id: habit?.goal_id) ?? "Select Goal or Life Area"
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

        let ruleString: String? = recurrenceRule != nil ? rrule_to_string(rule: recurrenceRule!) : nil

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
