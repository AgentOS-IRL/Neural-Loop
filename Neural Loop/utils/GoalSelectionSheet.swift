//
//  GoalSelectionSheet.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 09/01/2026.
//
import SwiftUI

enum GoalSelectionResult {
    case goal(id: Int64, title: String)
    case lifeArea(id: Int64, name: String)
}

struct GoalSelectionSheet: View {

    @Environment(\.dismiss) private var dismiss

    /// Returns selected goal or life area (nil if cancelled)
    let onSelect: (GoalSelectionResult?) -> Void

    enum DetailTab: String, CaseIterable {
        case goals = "Goals"
        case lifeArea = "Life Area"
    }

    @State private var selectedTab: DetailTab = .goals

    @State private var goals: [Int64: Goals] = [:]
    @State private var lifeAreas: [Int64: LifeAreas] = [:]
    @State private var isLoading = true

    @State private var selectedGoalId: Int64?
    @State private var selectedLifeAreaId: Int64?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    VStack(spacing: 0) {

                        Picker("View", selection: $selectedTab) {
                            ForEach(DetailTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .onChange(of: selectedTab) { _ in
                            clearSelection()
                        }

                        Divider()

                        if selectedTab == .goals {
                            goalsView()
                        } else {
                            lifeAreaView()
                        }
                    }
                }
            }
            .navigationTitle("Select")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSelect(nil)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: handleDone)
                        .disabled(!hasSelection)
                }
            }
            .task {
                await loadGoals()
                await loadLifeAreas()
                isLoading = false
            }
        }
    }

    // MARK: - Views

    private func goalsView() -> some View {
        List(Array(goals.values), id: \.id) { goal in
            selectableRow(
                title: goal.title,
                isSelected: selectedGoalId == goal.id
            ) {
                selectedGoalId = goal.id
            }
        }
    }

    private func lifeAreaView() -> some View {
        List(Array(lifeAreas.values), id: \.id) { lifeArea in
            selectableRow(
                title: lifeArea.name,
                isSelected: selectedLifeAreaId == lifeArea.id
            ) {
                selectedLifeAreaId = lifeArea.id
            }
        }
    }

    private func selectableRow(
        title: String,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Actions

    private var hasSelection: Bool {
        selectedGoalId != nil || selectedLifeAreaId != nil
    }

    private func clearSelection() {
        selectedGoalId = nil
        selectedLifeAreaId = nil
    }

    private func handleDone() {
        switch selectedTab {
        case .goals:
            if let id = selectedGoalId,
               let goal = goals[id] {
                onSelect(.goal(id: id, title: goal.title))
            }
        case .lifeArea:
            if let id = selectedLifeAreaId,
               let area = lifeAreas[id] {
                onSelect(.lifeArea(id: id, name: area.name))
            }
        }
        dismiss()
    }

    // MARK: - Data

    private func loadGoals() async {
        do {
            let db = DBManager.newInstance()
            goals = try await db.fetchAllGoals()
                .reduce(into: [:]) { $0[$1.id!] = $1 }
        } catch {
            print("❌ fetchAllGoals failed:", error)
            goals = [:]
        }
    }

    private func loadLifeAreas() async {
        do {
            let db = DBManager.newInstance()
            lifeAreas = try await db.fetchAllLifeAreas()
                .reduce(into: [:]) { $0[$1.id!] = $1 }
        } catch {
            print("❌ fetchAllLifeAreas failed:", error)
            lifeAreas = [:]
        }
    }
}
