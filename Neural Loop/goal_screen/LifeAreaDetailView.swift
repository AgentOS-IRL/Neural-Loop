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
    let goalTrackingMapping: [Int64: GoalsTracking]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: Section = .overview
    @State private var visionText: String = ""
    @State private var enableSaveVisionButton: Bool = false
    
    init(area: LifeAreas, goals: [Goals], tasks: [Tasks], goalTrackingMapping: [Int64: GoalsTracking]) {
        self.area = area
        self.goals = goals
        self.tasks = tasks
        self.goalTrackingMapping = goalTrackingMapping
        
    }

    var body: some View {
        VStack(spacing: 0) {

            // Top bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(area.name)
                    .font(.headline)

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // Section buttons
            HStack(spacing: 12) {
                sectionButton("Overview", .overview)
                sectionButton("Vision", .vision)
                sectionButton("Goals", .goals)
                sectionButton("Tasks", .tasks)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            
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
        .onAppear {
            visionText = area.vision ?? ""
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Section Button

    private func sectionButton(_ title: String, _ section: Section) -> some View {
        Button {
            selectedSection = section
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selectedSection == section ? Color(.systemBackground) : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            selectedSection == section
                            ? Color.primary
                            : Color(.secondarySystemBackground)
                        )
                )
        }
    }

    // MARK: - Sections
    
    func goalRow(_ goal: Goals) -> some View {
//        let subText =
//            ((goal.start_date != nil)
//                ? goal.start_date!.formatted() : "") + " -"
//            + ((goal.deadline != nil)
//                ? goal.deadline!.formatted() : " No deadline")
        return HStack(spacing: 16) {

            // Icon container
            iconTitle(
                icon: goal.icon,
                name: goal.title,
                size: 56,
//                subText: subText
            ) {
                getGoalProgressBar(goalId: goal.id!, goalTracking: goalTrackingMapping[goal.id!], goalTasks: tasks.filter{$0.goal_id == goal.id})
            }
            Spacer()

        }
        .padding(.horizontal)
        .padding(.vertical, 12)

    }

    private func overviewView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Vision")
                        .font(.headline)

                    Text(visionText.isEmpty ? "No vision added yet." : visionText)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Goals")
                        .font(.headline)

                    if goals.isEmpty {
                        Text("No goals added yet.")
                            .foregroundColor(.secondary)
                    } else {
                        
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(goals) { goal in
                                    NavigationLink {
                                        GoalDetailView(
                                            lifeAreaName: area.name,
                                            goal: goal,
                                            tasks: tasks.filter({$0.goal_id == goal.id})
                                        )
                                    } label: {
                                        goalRow(goal)
                                    }
//                                    HStack(spacing: 16) {
//                                        
//                                        // Icon container
//                                        ZStack {
//                                            RoundedRectangle(cornerRadius: 16)
//                                                .fill(Color(.systemGray5))
//                                                .frame(width: 56, height: 56)
//                                            
//                                            Image(systemName: goal.icon)
//                                                .font(.system(size: 22, weight: .semibold))
//                                                .foregroundColor(.gray)
//                                        }
//                                    VStack(alignment: .leading, spacing: 4) {
//                                        Text(goal.title)
//                                    }
//                                    .frame(maxWidth: .infinity, alignment: .leading)
//                                    
//                                        Spacer()
//
//                                               // Chevron
//                                               Image(systemName: "chevron.right")
//                                                   .font(.system(size: 14, weight: .semibold))
//                                                   .foregroundColor(.secondary)
//                                           }
//                                           .padding(.horizontal)
//                                           .padding(.vertical, 12)
                                
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func visionView() -> some View {
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Vision")
                .font(.headline)

            TextEditor(text: $visionText)
                .frame(maxHeight: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.4))
                ).onChange(of: visionText) { _ in
                    // Enable the button if text is not empty
                    enableSaveVisionButton = !visionText.isEmpty
                }

            Spacer()
            if enableSaveVisionButton {
                Button {
                    Task {
                        let manager = DBManager.newInstance()
                        try await manager.updateVision(id: area.id!, vision: visionText)
                    }
                } label: {
                    Text("Save")
                        .font(.subheadline)
                        .foregroundColor(.darkGray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary)
                        )
                }
            }
        }
        .padding()
    }

    private func goalsView() -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(goals) { goal in
                    NavigationLink {
                        GoalDetailView(
                            lifeAreaName: area.name,
                            goal: goal,
                            tasks: tasks.filter({$0.goal_id == goal.id})
                        )
                    } label: {
                        goalRow(goal)
                    }
                }
            }
        }.padding(.top, 8)
    }

    private func tasksView() -> some View {
        ScrollView {
            List(tasks) { task in
                VStack{
                    Text(task.title)
                }
            }
        }
    }
}
