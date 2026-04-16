//
//  GoalView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 08/01/2026.
//

//
//  GoalView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 08/01/2026.
//
import Foundation
import SwiftUI
import Combine

@MainActor
final class GoalScreenViewModel: ObservableObject {

    enum TopTab {
        case inProgress
        case roadmap
        case lifeAreas
    }

    // MARK: - UI State
    @Published var selectedTab: TopTab = .inProgress
    @Published var error: String?
    
}

struct GoalScreenView: View {

//    @StateObject private var vm = GoalScreenViewModel()
    enum TopTab {
        case inProgress
        case roadmap
        case lifeAreas
    }

    // MARK: - UI State
    @State var selectedTab: TopTab = .inProgress
    @State var error: String?
    @EnvironmentObject var model: UnifiedDataModel

    @State private var showAddLifeArea = false
    @State private var showAddGoal = false
    @State private var hydrateGoal: Goals? = nil
    @State private var hydrateGoalDeadline: TaskTiming? = nil
    @State private var addGoalSheetID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // Top segmented buttons
                    HStack(spacing: 8) {
                        topButton(
                            title: "In Progress",
                            isSelected: selectedTab == .inProgress
                        ) {
                            selectedTab = .inProgress
                        }

                        topButton(
                            title: "Roadmap",
                            isSelected: selectedTab == .roadmap
                        ) {
                            selectedTab = .roadmap
                        }

                        topButton(
                            title: "Life Areas",
                            isSelected: selectedTab == .lifeAreas
                        ) {
                            selectedTab = .lifeAreas
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Content
                    Group {
                        switch selectedTab {
                        case .inProgress:
                            inProgressView()

                        case .roadmap:
                            roadmapView()

                        case .lifeAreas:
                            lifeAreasView()
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .leading
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear.frame(height: SAFE_AREA_INSET)
                    }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Goals")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                        .padding(.horizontal, 12)
                    
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if selectedTab == .lifeAreas {
                            showAddLifeArea = true
                        } else {
                            hydrateGoal = nil
                            showAddGoal = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showAddLifeArea) {
                AddLifeAreas {
                    
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddEditGoal(
                    lifeAreas: model.lifeAreas,
                    goal: hydrateGoal,
                    deadline: hydrateGoalDeadline
                ) {
                }
            }.id(addGoalSheetID)
        }
    }

    // MARK: - Subviews
    private func getLifeAreas() -> [LifeAreas] {
        return model.lifeAreas
    }

    @ViewBuilder
    private func inProgressView() -> some View {

        ScrollView {
            VStack(spacing: 12) {
                ForEach(model.lifeAreas)  { lifeArea in
                    
                    VStack(spacing: 0) {
                        HStack {
                            NavigationLink {
                                LifeAreaDetailView(
                                    area: lifeArea,
                                    goals: model.getGoals(lifeAreaId: lifeArea.id!),
                                    tasks: model.getTasks(lifeAreaId:lifeArea.id!)
                                )
                            } label: {
                                // Icon container
                                iconTitle(icon: lifeArea.icon, name: lifeArea.name)

                                // Chevron
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.textSecondary).rotationEffect(
                                    .degrees(model.isExpanded(for: lifeArea.id!) ? 180 : 0)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        model.toggleExpansion(for: lifeArea.id!)
                                    }
                                }

                        }
                        .padding()
                        .background(AppTheme.sectionGradient)
                        .cornerRadius(AppTheme.Metrics.cardCornerRadius, corners: model.lifeAreaExpandedIds.contains(lifeArea.id!) && !model.getGoals(lifeAreaId: lifeArea.id!).isEmpty ? [.topLeft, .topRight] : .allCorners)

                        if model.lifeAreaExpandedIds.contains(lifeArea.id!) {
                            VStack(spacing: 0) {
                                ForEach(model.getGoals(lifeAreaId: lifeArea.id!)) { goal in
                                    NavigationLink {
                                        GoalDetailView(
                                            lifeAreaName: lifeArea.name,
                                            goal: goal,
                                            tasks: model.getTasks(goalId: goal.id!),
                                            habits: model.getHabits(goalId: goal.id!)
                                        )
                                    } label: {
                                        goalRow(goal)
                                    }
                                    
                                    if goal.id != model.getGoals(lifeAreaId: lifeArea.id!).last?.id {
                                        Divider()
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                            .background(AppTheme.cardGradient)
                            .cornerRadius(AppTheme.Metrics.cardCornerRadius, corners: [.bottomLeft, .bottomRight])
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                            .stroke(AppTheme.borderGradient, lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private func roadmapView() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(model.getGoalDateBucket()) { bucket in
                    VStack(alignment: .leading, spacing: 12) {
                        bucket.title
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            // Goals for this date bucket
                            let bucketGoals = bucket.ids.compactMap { model.getGoal(by: $0) }
                            
                            ForEach(bucketGoals) { goal in
                                NavigationLink {
                                    GoalDetailView(
                                        lifeAreaName: "Roadmap", // Fallback
                                        goal: goal,
                                        tasks: model.getTasks(goalId: goal.id!),
                                        habits: model.getHabits(goalId: goal.id!)
                                    )
                                } label: {
                                    goalRow(goal)
                                }
                                
                                if goal.id != bucketGoals.last?.id {
                                    Divider()
                                        .padding(.leading, 70)
                                }
                            }

                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            AppTheme.textSecondary.opacity(0.4),
                                            style: StrokeStyle(
                                                lineWidth: 1.5,
                                                lineCap: .round,
                                                dash: [4, 4]
                                            )
                                        )
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppTheme.textSecondary)
                                }

                                Text("Add Goal")
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)
                                
                                Spacer()
                            }
                            .padding()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hydrateGoal = nil
                                hydrateGoalDeadline = TaskTiming(
                                    start: bucket.end,
                                    duration: 0
                                )
                                addGoalSheetID = UUID()
                                showAddGoal = true
                            }
                        }
                        .background(AppTheme.cardGradient)
                        .cornerRadius(AppTheme.Metrics.cardCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                                .stroke(AppTheme.borderGradient, lineWidth: 1)
                        )
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func lifeAreasView() -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(model.lifeAreas) { area in
                    NavigationLink {
                        LifeAreaDetailView(
                            area: area,
                            goals: model.getGoals(lifeAreaId: area.id!),
                            tasks: model.getTasks(lifeAreaId: area.id!),
                        )
                    } label: {
                        lifeAreaRow(area)
                    }
                    .buttonStyle(.plain)
                    .background(AppTheme.cardGradient)
                    .cornerRadius(AppTheme.Metrics.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                            .stroke(AppTheme.borderGradient, lineWidth: 1)
                    )
                }
            }
            .padding()
        }
    }

    private func lifeAreaRow(_ area: LifeAreas) -> some View {
        var subText = "No active goals"
        let goalCount = model.getGoals(lifeAreaId: area.id!).count
        if goalCount > 0 {
            subText = "\(goalCount) goals"
        }

        return HStack(spacing: 16) {
            iconTitle(
                icon: area.icon,
                name: area.name,
                size: 32,
                subText: subText
            )
            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }


    func goalRow(_ goal: Goals) -> some View {
        return HStack(spacing: 16) {
            iconTitle(
                icon: goal.icon,
                name: goal.title,
                size: 32
            ) {
                model.getGoalProgressBar(goalId: goal.id!, goalTracking: model.getGoalTracking(goalId: goal.id!), goalTasks: model.getTasks(goalId:goal.id!))
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }


}
