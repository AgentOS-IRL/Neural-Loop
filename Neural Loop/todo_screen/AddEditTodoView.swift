//
//  EditTodoView.swift
//  Neural Loop
//
//  Created by Codex on 07/01/2026.
//

import SwiftUI
import RRuleKit

struct AddEditTodoView: View {
    let task: Tasks?
    let onSave: (Tasks) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: UnifiedDataModel

    @State private var title: String
    @State private var description: String
    @State private var priority: Int
    @State private var isDeadline: Bool
    @State private var scheduleDraft: TaskScheduleDraft
    @State private var goalId: Int64? = nil
    @State private var lifeAreaId: Int64? = nil
    
    @State private var GoalOrLifeAreadName: String? = nil

    @State private var showAreaGoalSheet = false
    @State private var showTimeSheet = false       // clock (time only)
    @State private var showScheduleSheet = false
    
    @State private var showUnsetConfirmation = false


    init(task: Tasks?, initialTiming: TaskTiming? = nil, goalId: Int64? = nil, lifeAreaId: Int64? = nil,  onSave: @escaping (Tasks) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _description = State(initialValue: task?.description ?? "")
        _priority = State(initialValue: task?.priority ?? 0)
        _isDeadline = State(initialValue: task?.is_deadline ?? false)
        var _draftSchedule: TaskScheduleDraft = .init(timing: nil, recurrence: nil)
        
        if task == nil {
            _draftSchedule.timing = initialTiming
        }
        else{
            if let start = task?.start_date, let duration = task?.duration {
                _draftSchedule.timing = TaskTiming(start: start, duration: duration)
            } else {
                _draftSchedule.timing = nil
            }
        }
        
        let rule = task?.recursion_rule ?? nil
        

        let parser = RecurrenceRuleRFC5545FormatStyle(calendar: .neuralLoopDisplay)
        
        let rrule: Calendar.RecurrenceRule? = {
            do {
                if rule == nil { return nil }
                let rrule =  try parser.parse(rule!)
                return rrule
            } catch {
                print("Failed to parse rule")
                return nil
            }
        }()
        _draftSchedule.recurrence = rrule
        _scheduleDraft = State(initialValue: _draftSchedule)
        
        if task?.goal_id != nil {
            _goalId = State(initialValue: task?.goal_id)
            
        }
        else {
            _goalId = State(initialValue: goalId)
            
        }
        if task?.lifearea_id != nil {
            _lifeAreaId = State(initialValue: task?.lifearea_id)
        }
        else {
            _lifeAreaId = State(initialValue: lifeAreaId)
        }
        
        
    }
    
    @ViewBuilder
    private func scheduleSummary() -> some View {
        let timeText = scheduleDraft.timing?.summary() ?? "No Time"
        let repeatText = scheduleDraft.recurrence?.summary() ?? "No Repeat"

        Text("\(timeText) • \(repeatText)")
            .onTapGesture {
                // Only ask if there’s something to unset
                if scheduleDraft.timing != nil || scheduleDraft.recurrence != nil {
                    showUnsetConfirmation = true
                }
            }
            .confirmationDialog(
                "Remove Schedule?",
                isPresented: $showUnsetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Unset Schedule", role: .destructive) {
                    scheduleDraft.timing = nil
                    scheduleDraft.recurrence = nil
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the time and repeat settings.")
            }
    }
    
    private var priorityIcon: String {
        switch priority {
        case 1: return "exclamationmark.circle"
        case 2: return "exclamationmark.circle.fill"
        case 3: return "exclamationmark.triangle.fill"
        default: return "minus.circle"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        
                        // MARK: Title & Description
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Task Details")
                            ThemedCard {
                                ThemedTextField(placeholder: "Task title", text: $title, isTitle: true)
                                
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))
                                
                                TextEditor(text: $description)
                                    .frame(minHeight: 100)
                                    .scrollContentBackground(.hidden)
                                    .font(.body)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }

                        // MARK: Priority & Deadline
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Priority & Deadline")
                            ThemedCard {
                                Picker("Priority", selection: $priority) {
                                    Text("Low").tag(0)
                                    Text("Medium").tag(1)
                                    Text("High").tag(2)
                                    Text("Critical").tag(3)
                                }
                                .pickerStyle(.segmented)
                                
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                Toggle(isOn: $isDeadline) {
                                    Label("Deadline", systemImage: "timer")
                                        .font(.body.weight(.medium))
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                .tint(AppTheme.accentColor)
                            }
                        }

                        // MARK: Schedule
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Schedule")
                            ThemedCard {
                                scheduleSummary()
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(AppTheme.textSecondary)
                                
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                Button {
                                    showTimeSheet = true
                                } label: {
                                    ThemedRow {
                                        Label("Set Time", systemImage: "clock")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }

                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                Button {
                                    showScheduleSheet = true
                                } label: {
                                    ThemedRow {
                                        Label("Repeat", systemImage: "arrow.2.circlepath")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }

                        // MARK: Goal / Life Area
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Goal or Life Area")
                            ThemedCard {
                                Button {
                                    showAreaGoalSheet = true
                                } label: {
                                    ThemedRow {
                                        Label(
                                            GoalOrLifeAreadName ?? "Select goal or life area",
                                            systemImage: "scope"
                                        )
                                        .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(AppTheme.Metrics.screenPadding)
                    .padding(.bottom, SAFE_AREA_INSET + 20)
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Close
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }

                // Save
                ToolbarItem(placement: .topBarTrailing) {
                    Button(task == nil ? "Save" : "Update") {
                        saveTask()
                    }
                    .font(.body.weight(.bold))
                    .foregroundColor(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.textSecondary : AppTheme.accentColor)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showScheduleSheet) {
                TaskScheduleSheet(
                    initialTiming: TaskTiming(
                        start: scheduleDraft.timing?.start ?? .now,
                        duration: scheduleDraft.timing?.duration ?? 900
                    ),
                    initialRule: scheduleDraft.recurrence
                ) { draft in
                    scheduleDraft = draft
                }
            }
            .sheet(isPresented: $showTimeSheet) {
                TimeRuleSheet(initialTiming: scheduleDraft.timing) { timing in
                    scheduleDraft = TaskScheduleDraft(
                        timing: timing,
                        recurrence: nil
                    )
                }
            }
            .sheet(isPresented: $showAreaGoalSheet) {
                GoalSelectionSheet { result in
                    guard let result else { return }

                    switch result {
                    case .goal(let id, let title):
                        GoalOrLifeAreadName = "Goal: \(title)"
                        goalId = id
                        lifeAreaId = nil

                    case .lifeArea(let id, let name):
                        GoalOrLifeAreadName = "Life Area: \(name)"
                        goalId = nil
                        lifeAreaId = id
                    }
                }
            }
            .task {
                GoalOrLifeAreadName = await model.getGoalName(goal_id: goalId)
                if GoalOrLifeAreadName == nil {
                    GoalOrLifeAreadName = await model.getLifeAreaName(lifeArea_id: lifeAreaId)
                }
            }
        }
    }
    
    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)

        var recursion_rule: String? = nil
        if let rule = scheduleDraft.recurrence {
            recursion_rule = rrule_to_string(rule: rule)
        }

        let updatedTask = Tasks(
            id: task?.id ?? nil,
            title: trimmedTitle,
            description: trimmedDesc,
            priority: priority,
            goal_id: goalId,
            lifearea_id: lifeAreaId,
            is_completed: task?.is_completed ?? false,
            is_deadline: isDeadline,
            completed_at: task?.completed_at ?? nil,
            recursion_rule: recursion_rule,
            start_date: scheduleDraft.timing?.start ?? nil,
            duration: scheduleDraft.timing?.duration ?? nil
        )

        onSave(updatedTask)
        dismiss()
    }
    
}
