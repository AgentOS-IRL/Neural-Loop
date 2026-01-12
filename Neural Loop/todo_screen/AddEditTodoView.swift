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

    @State private var title: String
    @State private var description: String
    @State private var priority: Int
    @State private var isDeadline: Bool
    @State private var scheduleDraft: TaskScheduleDraft
    @State private var goalId: Int64? = nil
    
    @State private var GoalOrLifeAreadName: String? = nil

    @State private var showGoalSheet = false
    @State private var showTimeSheet = false       // clock (time only)
    @State private var showScheduleSheet = false
    

    init(task: Tasks?, initialTiming: TaskTiming? = nil, onSave: @escaping (Tasks) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _description = State(initialValue: task?.description ?? "")
        _priority = State(initialValue: task?.priority ?? 0)
        _isDeadline = State(initialValue: task?.is_deadline ?? false)
        var _draftSchedule: TaskScheduleDraft = .init(timing: nil, recurrence: nil)
        
        if task == nil {
            _draftSchedule.timing = initialTiming
            print(_draftSchedule.timing )
        }
        else{
            if let start = task?.start_date, let duration = task?.duration {
                _draftSchedule.timing = TaskTiming(start: start, duration: duration)
            } else {
                _draftSchedule.timing = nil
            }
        }
        
        let rule = task?.recursion_rule ?? nil
        

        let parser = RecurrenceRuleRFC5545FormatStyle(calendar: .current)
        
        let rrule: Calendar.RecurrenceRule? = {
            do {
                if rule == nil { return nil }
                let rrule =  try parser.parse(rule!)
                //            print(rrule)
                return rrule
            } catch {
                print("Failed to parse rule")
                return nil
            }
        }()
        _draftSchedule.recurrence = rrule
        _scheduleDraft = State(initialValue: _draftSchedule)
        
        if task?.goal_id != nil {
            _goalId = State(initialValue: task?.goal_id!)
            
        }
        
        
    }
    
    
    private func scheduleSummary() -> Text {
        let timeText = scheduleDraft.timing?.summary() ?? "No Time"
        let repeatText = scheduleDraft.recurrence?.summary() ?? "No Repeat"

        return Text("\(timeText) • \(repeatText)")
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
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .padding(.horizontal)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                TextField("Task title", text: $title)
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.top, 8)

                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Description")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }

                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .padding(.horizontal, -4)
                }
                
                Spacer(minLength: 16)
                
                // Bottom actions row
                HStack(spacing: 18) {
                    scheduleSummary()
                    Spacer()

                    Image(systemName: "clock")
                        .padding(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showTimeSheet = true
                        }
                    Image(systemName: isDeadline ? "flag.fill" : "flag")
                        .padding(8)
                        .contentShape(Rectangle())
                        .foregroundColor(isDeadline ? .red : .secondary)
                        .onTapGesture {
                            isDeadline.toggle()
                        }
                    Image(systemName: "tag")
                        .padding(8)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red.opacity(0.8)) // Completely transparent fill
                                .background(.ultraThickMaterial)
                                .blendMode(.screen) // Adjust blend mode for a lighter, glass-like effect
                                .opacity(0.8) // Optional: slightly reduce opacity for more transparency
                        )
                    Image(systemName: priorityIcon)
                        .padding(8)
                        .contentShape(Rectangle())
                        .foregroundColor(priority == 0 ? .secondary : .accentColor)
                        .onTapGesture {
                            priority = (priority + 1) % 4
                        }
                    Image(systemName: "arrow.2.circlepath")
                        .padding(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showScheduleSheet = true
                        }

                }

            }
            .padding()

            Divider()

            // Footer
            HStack {
                
                Label(GoalOrLifeAreadName ?? "Select goal or life area", systemImage: "scope")
                                    .foregroundColor(.secondary)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        showGoalSheet = true
                                    }
                
                Spacer()
                Button {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                    var recursion_rule: String? = nil
                    if let rule = scheduleDraft.recurrence {
                        recursion_rule = rrule_to_string(rule: rule)
                    }
                    let updated_task = Tasks(
                        id: task?.id ?? nil,
                        title: trimmedTitle,
                        description: trimmedDesc,
                        priority: priority,
                        goal_id: goalId,
                        is_completed: task?.is_completed ?? false,
                        is_deadline: isDeadline,
                        completed_at: task?.completed_at ?? nil,
                        recursion_rule: recursion_rule,
                        start_date: scheduleDraft.timing?.start ?? nil,
                        duration: scheduleDraft.timing?.duration ?? nil,
                        
                    )
                    onSave(updated_task)
                    dismiss()
                } label: {
                    HStack {
                        Text(task == nil ?  "Save" : "Update")
                        Image(systemName: task == nil ?  "checkmark" : "checkmark.circle.fill")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(
                                title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1
                            ))
                    )
                    .foregroundColor(.white)
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showScheduleSheet) {
            TaskScheduleSheet(initialTiming: TaskTiming(start: scheduleDraft.timing?.start ?? .now, duration: scheduleDraft.timing?.duration ?? 900),
                              initialRule:scheduleDraft.recurrence) { draft in
                print(draft)
                scheduleDraft = draft
                
            }
        }.sheet(isPresented: $showTimeSheet) {
            TimeRuleSheet(initialTiming: scheduleDraft.timing) { timing in
                scheduleDraft = TaskScheduleDraft(
                    timing: timing,
                    recurrence: nil
                )
            }
        }.sheet(isPresented: $showGoalSheet) {
            GoalSelectionSheet { selectedId, selectedName in
                if let id = selectedId {
                    goalId = id
                    GoalOrLifeAreadName = selectedName
                } else {
                    goalId = nil
                    GoalOrLifeAreadName = nil
                }
            }
        }.task {
            GoalOrLifeAreadName = await getGoalName(goal_id: goalId)
        }
    }
    
}
