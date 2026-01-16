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

    // MARK: - Data
    @Published var lifeAreas: [LifeAreas] = []
    @Published private(set) var lifeGoalsMapping: [Int64: [Goals]] = [:]
    @Published private(set) var lifeTaskMapping: [Int64: [Tasks]] = [:]
    @Published private(set) var goalMapping: [Int64: Goals] = [:]
    @Published private(set) var goalTaskMapping: [Int64: [Tasks]] = [:]
    @Published private(set) var goalTrackingMapping: [Int64: GoalsTracking] = [:]

    @Published var dateBuckets: [DateBucket] = buildLongRangeDateBuckets()

    // MARK: - Expansion State
    @Published var expandedIDs: Set<Int64> = []

    // MARK: - Public API
    func load() async {
        await loadLifeAreas()
        expandAllLifeAreas()
    }

    func toggleExpansion(for id: Int64) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    // MARK: - Private
    private func expandAllLifeAreas() {
        expandedIDs = Set(lifeAreas.compactMap { $0.id })
    }

    private func loadLifeAreas() async {
        do {
            let manager = DBManager.newInstance()

            let areas = try await manager.fetchAllLifeAreas()
            lifeAreas = areas

            // Reset mappings to avoid stale data
            lifeGoalsMapping = [:]
            lifeTaskMapping = [:]
            goalMapping = [:]
            goalTaskMapping = [:]
            goalTrackingMapping = [:]

            for lifeArea in areas {
                let lifeAreaId = lifeArea.id!

                let goals = try await manager.fetchGoalsForLifeArea(
                    forLifeArea: lifeAreaId
                )
                lifeGoalsMapping[lifeAreaId] = goals

                lifeTaskMapping[lifeAreaId] =
                    try await manager.fetchTasksforLifeArea(
                        lifeAreaId: lifeAreaId
                    )

                for goal in goals {
                    let goalId = goal.id!
                    goalMapping[goalId] = goal

                    goalTaskMapping[goalId] =
                        try await manager.fetchTasksforGoal(goalId: goalId)

                    let goaltracking = try await manager.fetchGoalsTracking(
                        forGoal: goalId
                    )
                    goalTrackingMapping[goalId] = goaltracking
                }
            }
        } catch {
            self.error = error.localizedDescription
            print("Failed to load life areas:", error)
        }
    }
}

struct GoalScreenView: View {

    @StateObject private var vm = GoalScreenViewModel()

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
                            isSelected: vm.selectedTab == .inProgress
                        ) {
                            vm.selectedTab = .inProgress
                        }

                        topButton(
                            title: "Roadmap",
                            isSelected: vm.selectedTab == .roadmap
                        ) {
                            vm.selectedTab = .roadmap
                        }

                        topButton(
                            title: "Life Areas",
                            isSelected: vm.selectedTab == .lifeAreas
                        ) {
                            vm.selectedTab = .lifeAreas
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Content
                    Group {
                        switch vm.selectedTab {
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
//                            if vm.selectedTab == .lifeAreas {
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
                        if vm.selectedTab == .lifeAreas {
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
                    Task {
                        await vm.load()
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddEditGoal(
                    lifeAreas: vm.lifeAreas,
                    goal: hydrateGoal,
                    deadline: hydrateGoalDeadline
                ) {
                    Task {
                        await vm.load()
                    }
                }
            }.id(addGoalSheetID)
            .onAppear {
                Task {
                    await vm.load()
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func inProgressView() -> some View {

        ScrollView {
            VStack {
                ForEach(Array(vm.lifeAreas), id: \.id) { lifeArea in
                    let isExpanded = vm.expandedIDs.contains(lifeArea.id!)
                    HStack {
                        NavigationLink {
                            LifeAreaDetailView(
                                area: lifeArea,
                                goals: vm.lifeGoalsMapping[lifeArea.id!] ?? [],
                                tasks: vm.lifeTaskMapping[lifeArea.id!] ?? [],
                                goalTrackingMapping: vm.goalTrackingMapping
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
                                .degrees(isExpanded ? 180 : 0)
                            )
                            .onTapGesture {
                                withAnimation {
                                    vm.toggleExpansion(for: lifeArea.id!)
                                }
                            }

                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if isExpanded {
                        ForEach(vm.lifeGoalsMapping[lifeArea.id!] ?? []) { goal in

                            NavigationLink {
                                GoalDetailView(
                                    lifeAreaName: lifeArea.name,
                                    goal: goal,
                                    tasks: vm.goalTaskMapping[goal.id!] ?? []
                                )
                            } label: {
                                goalRow(goal)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func roadmapView() -> some View {
        VStack {
            Spacer()
            ScrollView {
                VStack {
                    ForEach(vm.dateBuckets) { bucket in
                        VStack(alignment: .leading, spacing: 8) {

                            bucket.title
                            // Goals for this date bucket
                            ForEach(bucket.ids, id: \.self) { goalId in
                                if let goal = vm.goalMapping[goalId] {
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
                ForEach(vm.lifeAreas) { area in
                    NavigationLink {
                        LifeAreaDetailView(
                            area: area,
                            goals: vm.lifeGoalsMapping[area.id!] ?? [],
                            tasks: vm.lifeTaskMapping[area.id!] ?? [],
                            goalTrackingMapping: vm.goalTrackingMapping
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
        let goalCount = vm.lifeGoalsMapping[area.id!]?.count ?? 0
        if goalCount > 0 {
            subText = "\(vm.lifeGoalsMapping[area.id!]?.count ?? 0) goals"
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
                getGoalProgressBar(goalId: goal.id!, goalTracking: vm.goalTrackingMapping[goal.id!], goalTasks: vm.goalTaskMapping[goal.id!])
            }
            Spacer()

        }
        .padding(.horizontal)
        .padding(.vertical, 12)

    }

}
