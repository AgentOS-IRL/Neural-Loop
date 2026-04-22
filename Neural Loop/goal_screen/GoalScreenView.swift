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

enum GoalScreenSection: String, CaseIterable, Identifiable {
    case inProgress = "In Progress"
    case roadmap = "Roadmap"
    case lifeAreas = "Life Areas"

    var id: String { rawValue }
}

@MainActor
final class GoalScreenNavigationModel: ObservableObject {
    @Published var selectedSection: GoalScreenSection = .inProgress

    func select(_ section: GoalScreenSection) {
        selectedSection = section
    }
}

struct GoalScreenView: View {

    // MARK: - UI State
    @StateObject private var navigationModel = GoalScreenNavigationModel()
    @State var error: String?
    @EnvironmentObject var model: UnifiedDataModel

    @State private var showAddLifeArea = false
    @State private var showAddGoal = false
    @State private var hydrateGoal: Goals? = nil
    @State private var hydrateGoalDeadline: TaskTiming? = nil
    @State private var addGoalSheetID = UUID()
    @State private var editingLifeArea: LifeAreas? = nil
    @State private var selectedGoalForDelete: Goals? = nil
    @State private var selectedLifeAreaForDelete: LifeAreas? = nil
    @State private var showDeleteGoalConfirmation = false
    @State private var showDeleteLifeAreaConfirmation = false
    @State private var addLifeAreaSheetID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Content
                    Group {
                        switch navigationModel.selectedSection {
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
            .safeAreaInset(edge: .top, spacing: 0) {
                GoalScreenSectionBar(
                    selectedSection: $navigationModel.selectedSection,
                    selectAction: navigationModel.select
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
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
                        if navigationModel.selectedSection == .lifeAreas {
                            startAddLifeArea()
                        } else {
                            startAddGoal()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showAddLifeArea, onDismiss: {
                editingLifeArea = nil
            }) {
                AddLifeAreas(lifeArea: editingLifeArea) {
                    editingLifeArea = nil
                }
                .id(addLifeAreaSheetID)
            }
            .sheet(isPresented: $showAddGoal) {
                AddEditGoal(
                    lifeAreas: model.lifeAreas,
                    goal: hydrateGoal,
                    deadline: hydrateGoalDeadline
                ) {
                }
                .id(addGoalSheetID)
            }
            .confirmationDialog(
                "Delete this goal?",
                isPresented: $showDeleteGoalConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Goal", role: .destructive) {
                    guard let goal = selectedGoalForDelete else { return }
                    Task {
                        await model.deleteGoal(goal)
                        selectedGoalForDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    selectedGoalForDelete = nil
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .confirmationDialog(
                "Delete this life area?",
                isPresented: $showDeleteLifeAreaConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Life Area", role: .destructive) {
                    guard let area = selectedLifeAreaForDelete else { return }
                    Task {
                        await model.deleteLifeArea(area)
                        selectedLifeAreaForDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    selectedLifeAreaForDelete = nil
                }
            } message: {
                Text("This will also remove goals in this life area. This action cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func startAddGoal(deadline: TaskTiming? = nil) {
        hydrateGoal = nil
        hydrateGoalDeadline = deadline
        addGoalSheetID = UUID()
        showAddGoal = true
    }

    private func editGoal(_ goal: Goals) {
        hydrateGoal = goal
        hydrateGoalDeadline = goal.deadline.map { TaskTiming(start: $0, duration: 0) }
        addGoalSheetID = UUID()
        showAddGoal = true
    }

    private func requestDeleteGoal(_ goal: Goals) {
        selectedGoalForDelete = goal
        showDeleteGoalConfirmation = true
    }

    private func startAddLifeArea() {
        editingLifeArea = nil
        addLifeAreaSheetID = UUID()
        showAddLifeArea = true
    }

    private func editLifeArea(_ area: LifeAreas) {
        editingLifeArea = area
        addLifeAreaSheetID = UUID()
        showAddLifeArea = true
    }

    private func requestDeleteLifeArea(_ area: LifeAreas) {
        selectedLifeAreaForDelete = area
        showDeleteLifeAreaConfirmation = true
    }

    @ViewBuilder
    private func goalContextMenu(for goal: Goals) -> some View {
        Button {
            editGoal(goal)
        } label: {
            Label("Edit Goal", systemImage: "pencil")
        }

        Button(role: .destructive) {
            requestDeleteGoal(goal)
        } label: {
            Label("Delete Goal", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func lifeAreaContextMenu(for area: LifeAreas) -> some View {
        Button {
            editLifeArea(area)
        } label: {
            Label("Edit Life Area", systemImage: "pencil")
        }

        Button(role: .destructive) {
            requestDeleteLifeArea(area)
        } label: {
            Label("Delete Life Area", systemImage: "trash")
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
                        .contentShape(Rectangle())
                        .contextMenu {
                            lifeAreaContextMenu(for: lifeArea)
                        }
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
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        goalContextMenu(for: goal)
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
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    goalContextMenu(for: goal)
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
                                startAddGoal(deadline: TaskTiming(
                                    start: bucket.end,
                                    duration: 0
                                ))
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
                    .contentShape(Rectangle())
                    .contextMenu {
                        lifeAreaContextMenu(for: area)
                    }
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

private struct GoalScreenSectionBar: View {
    @Binding var selectedSection: GoalScreenSection
    let selectAction: (GoalScreenSection) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 8) {
            ForEach(GoalScreenSection.allCases) { section in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectAction(section)
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(sectionForeground(isSelected: selectedSection == section))
                        .background {
                            if selectedSection == section {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(sectionFill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(backgroundFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }

    private var backgroundFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.secondarySystemBackground).opacity(0.96))
        }

        return AnyShapeStyle(AppTheme.sectionGradient)
    }

    private var sectionFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.tertiarySystemBackground))
        }

        return AnyShapeStyle(AppTheme.heroGradient)
    }

    private func sectionForeground(isSelected: Bool) -> Color {
        if isSelected {
            return AppTheme.textPrimary
        }

        return AppTheme.textSecondary
    }
}
