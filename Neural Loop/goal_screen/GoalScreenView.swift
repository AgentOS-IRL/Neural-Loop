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

struct GoalScreenView: View {

    enum TopTab {
        case inProgress
        case roadmap
        case lifeAreas
    }

    @State private var selectedTab: TopTab = .lifeAreas
    @State private var lifeAreas: [LifeAreas] = []
    @State private var lifeGoalsMapping: [Int64: [Goals]] = [:]
    @State private var lifeTaskMapping: [Int64: [Tasks]] = [:]
    @State private var goalMapping: [Int64: Goals] = [:]
    @State private var goalTaskMapping: [Int64: [Tasks]] = [:]
    @State private var goalTrackingMapping: [Int64: GoalsTracking] = [:]
    @State private var showAddLifeArea = false
    @State private var showAddGoal = false
    @State private var error: String?
    @State private var dateBuckets: [DateBucket] = buildLongRangeDateBuckets()
    @State private var hydrateGoal: Goals? = nil
    @State private var hydrateGoalDeadline: TaskTiming? = nil
    @State private var addGoalSheetID = UUID()

    @State private var expandedIDs: Set<Int64> = []

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

                // Floating add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            if selectedTab == .lifeAreas {
                                showAddLifeArea = true
                            } else {
                                hydrateGoal = nil
                                showAddGoal = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 8)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Goals")
            .sheet(isPresented: $showAddLifeArea) {
                AddLifeAreas {
                    Task {
                        await loadLifeAreas()
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddEditGoal(
                    lifeAreas: lifeAreas,
                    goal: hydrateGoal,
                    deadline: hydrateGoalDeadline
                ) {

                }
            }.id(addGoalSheetID)
            .onAppear {
                Task {
                    await loadLifeAreas()
                    for lifeArea in lifeAreas {
                        expandedIDs.insert(lifeArea.id!)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func inProgressView() -> some View {

        ScrollView {
            VStack {
                ForEach(Array(lifeAreas), id: \.id) { lifeArea in
                    let isExpanded = expandedIDs.contains(lifeArea.id!)
                    HStack {
                        NavigationLink {
                            LifeAreaDetailView(
                                area: lifeArea,
                                goals: lifeGoalsMapping[lifeArea.id!] ?? [],
                                tasks: lifeTaskMapping[lifeArea.id!] ?? [],
                                goalTrackingMapping: goalTrackingMapping
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
                                    if isExpanded {
                                        expandedIDs.remove(lifeArea.id!)
                                    } else {
                                        expandedIDs.insert(lifeArea.id!)
                                    }
                                }
                            }

                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if isExpanded {
                        ForEach(lifeGoalsMapping[lifeArea.id!] ?? []) { goal in

                            NavigationLink {
                                GoalDetailView(
                                    lifeAreaName: lifeArea.name,
                                    goal: goal,
                                    tasks: goalTaskMapping[goal.id!] ?? []
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
                    ForEach(dateBuckets) { bucket in
                        VStack(alignment: .leading, spacing: 8) {

                            bucket.title
                            // Goals for this date bucket
                            ForEach(bucket.ids, id: \.self) { goalId in
                                if let goal = goalMapping[goalId] {
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
                ForEach(lifeAreas) { area in
                    NavigationLink {
                        LifeAreaDetailView(
                            area: area,
                            goals: lifeGoalsMapping[area.id!] ?? [],
                            tasks: lifeTaskMapping[area.id!] ?? [],
                            goalTrackingMapping: goalTrackingMapping
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
        let goalCount = lifeGoalsMapping[area.id!]?.count ?? 0
        if goalCount > 0 {
            subText = "\(lifeGoalsMapping[area.id!]?.count ?? 0) goals"
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

    // MARK: - Data

    private func loadLifeAreas() async {
        do {
            let manager = DBManager.newInstance()
            lifeAreas = try await manager.fetchAllLifeAreas()
            for lifeArea in lifeAreas {
                let goals = try await manager.fetchGoalsForLifeArea(
                    forLifeArea: lifeArea.id!
                )
                lifeGoalsMapping[lifeArea.id!] = goals
                lifeTaskMapping[lifeArea.id!] =
                    try await manager.fetchTasksforLifeArea(
                        lifeAreaId: lifeArea.id!
                    )

                for goal in goals {
                    goalMapping[goal.id!] = goal
                    goalTaskMapping[goal.id!] =
                        try await manager.fetchTasksforGoal(goalId: goal.id!)
                    let goaltracking = try await manager.fetchGoalsTracking(
                        forGoal: goal.id!
                    )
                    goalTrackingMapping[goal.id!] = goaltracking

                }

            }
        } catch {
            self.error = error.localizedDescription
            print("Failed to load life areas:", error)
        }
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
                getGoalProgressBar(goalId: goal.id!, goalTracking: goalTrackingMapping[goal.id!], goalTasks: goalTaskMapping[goal.id!])
            }
            Spacer()

        }
        .padding(.horizontal)
        .padding(.vertical, 12)

    }

}
