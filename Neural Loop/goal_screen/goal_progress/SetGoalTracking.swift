//
//  SetGoalTracking.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 12/01/2026.
//



import SwiftUI

struct SetGoalTracking: View {

    let goalId: Int64
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: GoalTrackingType?
    @State private var value: String = ""
    @State private var target: String = ""
    @State private var label: String = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    
    @State private var goalTracking: GoalsTracking
    
    let onSave: (GoalsTracking) -> Void
    
    init(goalId: Int64, goalTracking: GoalsTracking?, onSave: @escaping (GoalsTracking) -> Void) {
        self.goalId = goalId
        self.onSave = onSave
        
        
        if goalTracking == nil {
            _goalTracking = State(initialValue: GoalsTracking(
                id: nil,
                goal_id: goalId,
                type: .sub_goal,
                value: nil,
                target: nil,
                label: nil,
                created_at: nil,
                updated_at: nil
            ))
        }
        else {
            _goalTracking = State(initialValue: goalTracking!)
        }
        _selectedType = State(initialValue: self.goalTracking.type)
        _label = State(initialValue: self.goalTracking.label ?? "Times")
        _value = State(initialValue: self.goalTracking.value==nil ? "" : String(self.goalTracking.value!))
        _target = State(initialValue: self.goalTracking.target==nil ? "" : String(self.goalTracking.target!))
    }

    var body: some View {
        NavigationStack {
            SwiftUI.Form {
                Section("Tracking Type") {
                    ForEach([GoalTrackingType.task, .sub_goal, .custom], id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack {
                                Text(type.rawValue
                                    .replacingOccurrences(of: "_", with: " ")
                                    .capitalized
                                )
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                if selectedType == .custom {
                    Section("Custom Tracking") {
                        TextField("Label", text: $label)
                        TextField("Value", text: $value)
                            .keyboardType(.decimalPad)
                        TextField("Target", text: $target)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button("Save") {
                        Task {
                            if selectedType == .custom {
                                if value.isEmpty || target.isEmpty {
                                    errorMessage = "Please enter both a value and a target."
                                    return
                                }
                                await saveCustom()
                            } else if let selectedType {
                                await saveSimple(type: selectedType)
                            }
                        }
                    }
                    .disabled(isSaving)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Set Tracking")
            .disabled(isSaving)
        }
    }

    // MARK: - Save Logic

    private func saveSimple(type: GoalTrackingType) async {
        await upsertTracking(
            type: type,
            value: nil,
            target: nil,
            label: nil
        )
    }

    private func saveCustom() async {
        let valueDouble = Double(value)
        let targetDouble = Double(target)

        await upsertTracking(
            type: .custom,
            value: valueDouble,
            target: targetDouble,
            label: label.isEmpty ? nil : label
        )
    }

    private func upsertTracking(
        type: GoalTrackingType,
        value: Double?,
        target: Double?,
        label: String?
    ) async {
        isSaving = true
        errorMessage = nil

        do {
            let db = DBManager.newInstance()

            // Ensure 1-to-1 by deleting existing tracking first
            try await db.deleteGoalsTracking(forGoal: goalId)

            let tracking = GoalsTracking(
                id: nil,
                goal_id: goalId,
                type: type,
                value: value,
                target: target,
                label: label,
                created_at: nil,
                updated_at: nil
            )

            try await db.createGoalsTracking(tracking)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
