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

    @State private var selectedTab: TopTab = .lifeAreas
    @State private var lifeAreas: [LifeAreas] = []
    @State private var lifeGoalsMapping: [Int64: [Goals]] = [:]
    @State private var lifeTaskMapping: [Int64: [Tasks]] = [:]
    @State private var showAddLifeArea = false
    @State private var error: String?

    var body: some View {
        NavigationView {
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
                    lifeAreaRow(area)
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

// MARK: - Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
