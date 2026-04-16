//
//  LifeAreaDetailView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 09/01/2026.
//
import SwiftUI

struct LifeAreaDetailView: View {

    enum Section {
        case overview
        case vision
        case goals
        case tasks
    }

    let area: LifeAreas
    let goals: [Goals]
    let tasks: [Tasks]

    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var model: UnifiedDataModel
    
    @State private var selectedSection: Section = .overview
    @State private var visionText: String = ""
    @State private var enableSaveVisionButton: Bool = false
    
    init(area: LifeAreas, goals: [Goals], tasks: [Tasks]) {
        self.area = area
        self.goals = goals
        self.tasks = tasks
        
    }

    var body: some View {
        ZStack {
            FleetingNotesTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(FleetingNotesTheme.textSecondary)
                    }

                    Text(area.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(FleetingNotesTheme.textPrimary)

                    Spacer()
                }
                .padding()

                // Section buttons
                HStack(spacing: 8) {
                    sectionButton("Overview", .overview)
                    sectionButton("Vision", .vision)
                    if goals.isEmpty == false {
                        sectionButton("Goals", .goals)
                    }
                    if tasks.isEmpty == false {
                        sectionButton("Tasks", .tasks)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Content
                Group {
                    switch selectedSection {
                    case .overview:
                        overviewView()

                    case .vision:
                        visionView()

                    case .goals:
                        goalsView()

                    case .tasks:
                        tasksView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            visionText = area.vision ?? ""
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: SAFE_AREA_INSET)
                }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Section Button

    private func sectionButton(_ title: String, _ section: Section) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedSection = section
            }
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(selectedSection == section ? .white : FleetingNotesTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            selectedSection == section
                            ? AnyShapeStyle(FleetingNotesTheme.accentGradient)
                            : AnyShapeStyle(FleetingNotesTheme.sectionGradient)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FleetingNotesTheme.borderGradient, lineWidth: 1)
                        .opacity(selectedSection == section ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sections
    
    func goalRow(_ goal: Goals) -> some View {
        return HStack(spacing: 16) {
            iconTitle(
                icon: goal.icon,
                name: goal.title,
                size: 32
            ) {
                model.getGoalProgressBar(goalId: goal.id!, goalTracking: model.getGoalTracking(goalId: goal.id!), goalTasks: tasks.filter{$0.goal_id == goal.id})
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }

    private func overviewView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 12) {
                    Text("Vision")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(FleetingNotesTheme.textPrimary)
                    
                    Text(visionText.isEmpty ? "No vision added yet." : visionText)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(FleetingNotesTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                        .padding(20)
                        .background(FleetingNotesTheme.cardGradient)
                        .cornerRadius(FleetingNotesTheme.Metrics.cardCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius)
                                .stroke(FleetingNotesTheme.borderGradient, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Goals")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(FleetingNotesTheme.textPrimary)
                    
                    VStack(spacing: 0) {
                        if goals.isEmpty {
                            Text("No goals added yet.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(FleetingNotesTheme.textSecondary)
                                .padding(24)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(goals) { goal in
                                NavigationLink {
                                    GoalDetailView(
                                        lifeAreaName: area.name,
                                        goal: goal,
                                        tasks: tasks.filter({$0.goal_id == goal.id}),
                                        habits: model.getHabits(goalId: goal.id!)
                                    )
                                } label: {
                                    goalRow(goal)
                                }
                                
                                if goal.id != goals.last?.id {
                                    Divider()
                                        .padding(.leading, 70)
                                }
                            }
                        }
                    }
                    .background(FleetingNotesTheme.cardGradient)
                    .cornerRadius(FleetingNotesTheme.Metrics.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius)
                            .stroke(FleetingNotesTheme.borderGradient, lineWidth: 1)
                    )
                }
            }
            .padding()
        }
    }

    private func visionView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Vision")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(FleetingNotesTheme.textPrimary)

            TextEditor(text: $visionText)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(FleetingNotesTheme.textPrimary)
                .frame(maxHeight: 150)
                .padding(16)
                .background(FleetingNotesTheme.sectionGradient)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(FleetingNotesTheme.borderGradient, lineWidth: 1)
                )
                .onChange(of: visionText) {
                    enableSaveVisionButton = !visionText.isEmpty
                }

            if enableSaveVisionButton {
                Button {
                    Task {
                        let success = await model.updateLifeAreaVision(id: area.id!, vision: visionText)
                        if success {
                            withAnimation {
                                enableSaveVisionButton = false
                            }
                        }
                    }
                } label: {
                    Text("Save Vision")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(FleetingNotesTheme.accentGradient)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .padding()
    }

    private func goalsView() -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(goals) { goal in
                    NavigationLink {
                        GoalDetailView(
                            lifeAreaName: area.name,
                            goal: goal,
                            tasks: tasks.filter({$0.goal_id == goal.id}),
                            habits: model.getHabits(goalId: goal.id!)
                        )
                    } label: {
                        goalRow(goal)
                    }
                    
                    if goal.id != goals.last?.id {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
            .background(FleetingNotesTheme.cardGradient)
            .cornerRadius(FleetingNotesTheme.Metrics.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius)
                    .stroke(FleetingNotesTheme.borderGradient, lineWidth: 1)
            )
            .padding()
        }
    }

    private func tasksView() -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(tasks) { task in
                    taskView(task:task)
                }
            }
            .padding()
        }
    }
    
    
    @ViewBuilder
    private func taskView(task: Tasks) -> some View {
        taskRowView(task: task, strikeThrough: task.is_completed)
    }
    
}
