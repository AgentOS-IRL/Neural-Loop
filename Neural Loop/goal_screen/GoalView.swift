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


struct GoalView: View {

    enum TopTab {
        case inProgress
        case lifeAreas
    }

    @State private var selectedTab: TopTab = .inProgress
    @State private var lifeAreas: [LifeAreas] = []
    @State private var lifeGoalsMapping: [Int64: [Goals]] = [:]
    @State private var lifeTaskMapping: [Int64: [Tasks]] = [:]
    @State private var showAddLifeArea = false
    @State private var showAddGoal = false
    @State private var error: String?

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

                        case .lifeAreas:
                            lifeAreasView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }

                // Floating add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            if selectedTab == .lifeAreas {
                                showAddLifeArea = true
                            }
                            else {
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
                AddGoal(lifeAreas: lifeAreas) {
                    
                }
            }
            .onAppear {
                Task {
                    await loadLifeAreas()
                }
            }
        }
    }

    // MARK: - Subviews

    private func topButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .darkGray : .primary)
                .padding(.horizontal, 12)     // ⬅ control width here
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.primary : Color(.secondarySystemBackground))
                )
        }
    }

    @ViewBuilder
    private func inProgressView() -> some View {
        VStack {
            Spacer()
            Text("In Progress")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private func lifeAreasView() -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(lifeAreas) { area in
                    NavigationLink {
                        LifeAreaDetailView(area: area, goals: lifeGoalsMapping[area.id!]!,
                                           tasks: lifeTaskMapping[area.id!]!)
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
        HStack(spacing: 16) {

            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)

                Image(systemName: area.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.gray)
            }

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(area.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    Text(
                        (lifeGoalsMapping[area.id!]?.count ?? 0) > 0
                        ? "\(lifeGoalsMapping[area.id!]?.count ?? 0) goals"
                        : "No active goals"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                }
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
                lifeGoalsMapping[lifeArea.id!] = try await manager.fetchGoals(forLifeArea: lifeArea.id!)
                lifeTaskMapping[lifeArea.id!] = try await manager.fetchTasks(forLifeArea: lifeArea.id!)
            }
        } catch {
            self.error = error.localizedDescription
            print("Failed to load life areas:", error)
        }
    }
}
