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
    @EnvironmentObject var model: UnifiedDataModel

    /// Returns selected goal or life area (nil if cancelled)
    let onSelect: (GoalSelectionResult?) -> Void

    enum DetailTab: String, CaseIterable {
        case goals = "Goals"
        case lifeArea = "Life Area"
    }

    @State private var selectedTab: DetailTab = .goals


    @State private var selectedGoalId: Int64?
    @State private var selectedLifeAreaId: Int64?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

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
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            if selectedTab == .goals {
                                goalsView()
                            } else {
                                lifeAreaView()
                            }
                        }
                        .padding(AppTheme.Metrics.screenPadding)
                    }
                }
            }
            .navigationTitle("Select")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSelect(nil)
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: handleDone)
                        .font(.body.weight(.bold))
                        .foregroundColor(hasSelection ? AppTheme.accentColor : AppTheme.textSecondary)
                        .disabled(!hasSelection)
                }
            }
        }
    }

    // MARK: - Views

    private func goalsView() -> some View {
        ForEach(Array(model.goals), id: \.id) { goal in
            selectableRow(
                title: goal.title,
                isSelected: selectedGoalId == goal.id
            ) {
                selectedGoalId = goal.id
            }
        }
    }

    private func lifeAreaView() -> some View {
        ForEach(Array(model.lifeAreas), id: \.id) { lifeArea in
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
        ThemedCard(gradient: isSelected ? AppTheme.sectionGradient : AppTheme.cardGradient) {
            HStack {
                Text(title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accentColor)
                } else {
                    Circle()
                        .stroke(AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
        }
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
               let goal = model.goals.first(where: { $0.id == id }) {
                onSelect(.goal(id: id, title: goal.title))
            }
        case .lifeArea:
            if let id = selectedLifeAreaId,
               let area = model.lifeAreas.first(where: { $0.id == id }) {
                onSelect(.lifeArea(id: id, name: area.name))
            }
        }
        dismiss()
    }


}
