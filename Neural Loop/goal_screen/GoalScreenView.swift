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

                    Divider()

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

//                // Floating add button
//                VStack {
//                    Spacer()
//                    HStack {
//                        Spacer()
//                        Button {
//                            if selectedTab == .lifeAreas {
//                                showAddLifeArea = true
//                            } else {
//                                hydrateGoal = nil
//                                showAddGoal = true
//                            }
//                        } label: {
//                            Image(systemName: "plus")
//                                .font(.system(size: 22, weight: .bold))
//                                .foregroundColor(.black)
//                                .padding()
//                                .background(Color.white)
//                                .clipShape(Circle())
//                                .shadow(radius: 8)
//                        }
//                        .padding()
//                    }
//                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear.frame(height: SAFE_AREA_INSET)
                    }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Goals")
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)  // don’t compress horizontally
                        .layoutPriority(1)                             // fight for space
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
                            .foregroundStyle(.secondary)
                    }
                }
            }
//            .navigationTitle("Goals")
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
//            .onAppear {
//                Task {
//                    await load()
//                }
//            }
        }
    }

    // MARK: - Subviews
    private func getLifeAreas() -> [LifeAreas] {
        return model.lifeAreas
    }

    @ViewBuilder
    private func inProgressView() -> some View {

        ScrollView {
            VStack {
                ForEach(model.lifeAreas)  { lifeArea in
                    
                    HStack {
                        NavigationLink {
                            LifeAreaDetailView(
                                area: lifeArea,
                                goals: model.getGoals(lifeAreaId: lifeArea.id!),
                                tasks: model.getTasks(lifeAreaId:lifeArea.id!) ,
                                
                            )
                        } label: {

                            // Icon container
                            iconTitle(icon: lifeArea.icon, name: lifeArea.name)

                            // Chevron
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary).rotationEffect(
                                .degrees(model.isExpanded(for: lifeArea.id!) ? 180 : 0)
                            )
                            .onTapGesture {
                                withAnimation {
                                    model.toggleExpansion(for: lifeArea.id!)
                                }
                            }

                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if model.lifeAreaExpandedIds.contains(lifeArea.id!) {
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
                        }
                    }
                }
            }.padding(.horizontal, 4).padding(.top, 16)
        }
    }

    @ViewBuilder
    private func roadmapView() -> some View {
        VStack {
            Spacer()
            ScrollView {
                VStack {
                    ForEach(model.getGoalDateBucket()) { bucket in
                        VStack(alignment: .leading, spacing: 8) {

                            bucket.title
                            // Goals for this date bucket
                            ForEach(bucket.ids, id: \.self) { goalId in
                                if let goal = model.getGoal(by: goalId) {
                                    Text(goal.title)
                                }
                            }

                            Spacer()

                            HStack(spacing: 16) {

                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            Color.gray.opacity(0.7),
                                            style: StrokeStyle(
                                                lineWidth: 2,
                                                lineCap: .round,  // makes dashes look like dots
                                                dash: [1, 4]  // dot length, gap
                                            )
                                        )
                                        .frame(width: 28, height: 28)

                                    Image(systemName: "scope")  // looks closer to your screenshot than "target"
                                        .font(
                                            .system(size: 14, weight: .semibold)
                                        )
                                        .foregroundColor(.gray)
                                }

                                Text("Add Goal")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }.onTapGesture {

                                hydrateGoal = nil
                                hydrateGoalDeadline = TaskTiming(
                                    start: bucket.end,
                                    duration: 0
                                )
                                addGoalSheetID = UUID()
                                showAddGoal = true
                            }

                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
            }
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

            // Icon container

            iconTitle(
                icon: area.icon,
                name: area.name,
                size: 44,
                subText: subText
            )
            //            ZStack {
            //                RoundedRectangle(cornerRadius: 16)
            //                    .fill(Color(.systemGray5))
            //                    .frame(width: 56, height: 56)
            //
            //                Image(systemName: area.icon)
            //                    .font(.system(size: 22, weight: .semibold))
            //                    .foregroundColor(.gray)
            //            }
            //
            //            // Text content
            //            VStack(alignment: .leading, spacing: 6) {
            //                Text(area.name)
            //                    .font(.headline)
            //                    .foregroundColor(.primary)
            //                Text(
            //                    (lifeGoalsMapping[area.id!]?.count ?? 0) > 0
            //                        ? "\(lifeGoalsMapping[area.id!]?.count ?? 0) goals"
            //                        : "No active goals"
            //                )
            //                .font(.subheadline)
            //                .foregroundColor(.secondary)
            //
            //            }
            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }


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
                model.getGoalProgressBar(goalId: goal.id!, goalTracking: model.getGoalTracking(goalId: goal.id!), goalTasks: model.getTasks(goalId:goal.id!))
            }
            Spacer()

        }
        .padding(.horizontal)
        .padding(.vertical, 12)

    }

}
