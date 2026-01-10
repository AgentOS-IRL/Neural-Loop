//
//  AddTodoView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import SwiftUI
import EventKit

struct AddTodoView: View {

    let initialTiming: TaskTiming?

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var priority: Int = 0
    @State private var isDeadline: Bool = false
    
    @State private var showScheduleSheet = false   // circlepath (time + recurrence)
    @State private var showTimeSheet = false       // clock (time only)
    @State private var scheduleDraft: TaskScheduleDraft?

    @State private var isHabit: Bool = false
    @State private var target: Int = 1
    @State private var label: String = "Times"
    @State private var goalId: Int? = nil
    @State private var GoalOrLifeAreadName: String? = nil

    @State private var showGoalSheet = false

    let onSave: (TaskInput) -> Void

    init(
        initialTiming: TaskTiming? = nil,
        onSave: @escaping (TaskInput) -> Void
    ) {
        self.initialTiming = initialTiming
        self.onSave = onSave
        if let timing = initialTiming {
            _scheduleDraft = State(
                initialValue: TaskScheduleDraft(
                    timing: timing,
                    recurrence: nil
                )
            )
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
        VStack(spacing: 0) {

            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                Spacer(minLength:10)

                Text("New Task")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // spacer to balance close button
                Color.clear
                    .frame(width: 34, height: 34)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Content
            VStack(alignment: .leading, spacing: 16) {

                TextField("New task", text: $title)
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
                    Text((scheduleDraft?.timing?.summary() ?? "No Time") + " • " + (scheduleDraft?.recurrence?.summary() ?? "No Repeat"))
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
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .sheet(isPresented: $showScheduleSheet) {
                    TaskScheduleSheet(initialTiming: scheduleDraft?.timing) { draft in
                        scheduleDraft = draft
                        print("📅 TaskScheduleDraft returned:")
                        print("Summary:", draft.timing?.summary() ?? "All Day")
                        print("Summary:", draft.recurrence?.summary() ?? "No Recurrence")
                        if draft.recurrence == nil {
                            isHabit = false
                            target = 1
                            label = ""
                        }
                    }
                }
                .sheet(isPresented: $showTimeSheet) {
                    TimeRuleSheet(initialTiming: scheduleDraft?.timing) { timing in
                        scheduleDraft = TaskScheduleDraft(
                            timing: timing,
                            recurrence: nil
                        )
                    }
                }

                
            }
            .padding()
            VStack(alignment: .leading, spacing: 12) {

                if scheduleDraft?.recurrence != nil {

                    VStack(alignment: .leading, spacing: 12) {

                        // Habit toggle row
                        Toggle(isOn: $isHabit) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Habit")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Track progress over time")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        // Habit configuration
                        if isHabit {
                            Divider()

                            VStack(alignment: .leading, spacing: 10) {

                                // Target row
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Target")
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        Text("Amount to complete each time")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Stepper(value: $target, in: 1...100) {
                                            EmptyView()
                                        }
                                        .labelsHidden()

                                        Text("\(target)")
                                            .font(.headline)
                                            .frame(minWidth: 28, alignment: .trailing)
                                    }
                                }

                                // Unit row
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Unit")
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    TextField(
                                        "e.g. times, pages, minutes",
                                        text: $label
                                    )
                                    .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .animation(.easeInOut(duration: 0.2), value: isHabit)
                }
            }

            Divider()
                .padding(.top, 4)

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
                    onSave(
                        TaskInput(
                            title: title,
                            description: description.isEmpty ? nil : description,
                            priority: priority,
                            schedule: scheduleDraft,
                            is_deadline: isDeadline,
                            target: Int64(target),
                            label:  label,
                            goal_id: goalId
                        )
                    )
                    dismiss()
                } label: {
                    HStack {
                        Text("Create")
                        Image(systemName: "plus")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(
                                title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1
                            ))
                    )
                    .foregroundColor(.white)
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .onChange(of: isHabit) { _ in }
        .sheet(isPresented: $showGoalSheet) {
            GoalSelectionSheet { selectedId, selectedName in
                if let id = selectedId {
                    goalId = Int(id)
                    GoalOrLifeAreadName = selectedName
                } else {
                    goalId = nil
                    GoalOrLifeAreadName = nil
                }
            }
        }
    }
}
