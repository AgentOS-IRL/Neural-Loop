//
//  GoalSelectionSheet.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 09/01/2026.
//

import SwiftUI

struct GoalSelectionSheet: View {

    @Environment(\.dismiss) private var dismiss

    /// Returns selected goal id (or nil if cancelled)
    let onSelect: (Int64?, String?) -> Void

    @State private var goals: [Int64: Goals] = [:]
    @State private var isLoading: Bool = true
    @State private var selectedGoalId: Int64?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if goals.isEmpty {
                    Text("No goals found")
                        .foregroundColor(.secondary)
                } else {
                    List(Array(goals.values), id: \.id) { goal in
                        HStack(spacing: 12) {
                            Text(goal.title)
                                .foregroundColor(.primary)

                            Spacer()

                            if let gid = goal.id, selectedGoalId == gid {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let gid = goal.id {
                                selectedGoalId = gid
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Goal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSelect(nil, nil)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSelect(selectedGoalId, goals[selectedGoalId!]?.title)
                        dismiss()
                    }
                    .disabled(selectedGoalId == nil)
                }
            }
            .task {
                await loadGoals()
            }
        }
    }

    private func loadGoals() async {
        defer { isLoading = false }
        do {
            let dbmanager = DBManager.newInstance()
            goals = try await dbmanager.fetchAllGoals().reduce(into: [:]) { dict, goal in
                dict[goal.id!] = goal
            }
        } catch {
            print("❌ fetchAllGoals failed:", error)
            goals = [:]
        }
    }
}
