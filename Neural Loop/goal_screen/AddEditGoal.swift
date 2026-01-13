//
//  AddGoal.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 09/01/2026.
//

import SwiftUI

struct AddEditGoal: View {
    @Environment(\.dismiss) private var dismiss
    
    let lifeAreas: [LifeAreas]
    let onSaved: () -> Void
    private let existingGoal: Goals?

    @State private var name: String
    @State private var description: String
    @State private var selectedLifeAreaId: Int64?
    @State private var selectedPatentGoalId: Int64?
    @State private var showTimeSheet = false
    @State private var showIconPicker = false
    @State private var deadline: TaskTiming?
    @State private var startDate: Date

    @State private var color: String
    @State private var icon: String
    
    @State private var fixedLifeAreaName: String? = nil

    init(
        lifeAreas: [LifeAreas],
        goal: Goals? = nil,
        deadline: TaskTiming? = nil,
        parent_goal_id: Int64? = nil,
        fixed_lifearea: Int64? = nil,
        fixed_lifearea_name: String? = nil,
        onSaved: @escaping () -> Void
    ) {
        self.lifeAreas = lifeAreas
        self.onSaved = onSaved
        self.existingGoal = goal
        
        let initialDeadline = (deadline != nil) ? deadline?.start : goal?.deadline
        let initialStartDate = goal?.start_date ?? Date()
        
        _name = State(initialValue: goal?.title ?? "")
        _description = State(initialValue: goal?.description ?? "")
        _selectedLifeAreaId = State(initialValue: goal?.lifearea_id ?? fixed_lifearea)
        _selectedPatentGoalId = State(initialValue: goal?.parent_id ?? parent_goal_id)
        _deadline = State(initialValue: initialDeadline.map { TaskTiming(start: $0, duration: 0) })
        _startDate = State(initialValue: initialStartDate)
        _color = State(initialValue: goal?.color ?? "#4F46E5")
        _icon = State(initialValue: goal?.icon ?? "heart")
        
        _fixedLifeAreaName = State(initialValue: fixed_lifearea_name)
        
        
    }
    
    private let colorOptions: [(name: String, hex: String)] = [
        ("Indigo", "#4F46E5"),
        ("Blue", "#2563EB"),
        ("Green", "#16A34A"),
        ("Yellow", "#EAB308"),
        ("Orange", "#F97316"),
        ("Red", "#DC2626"),
        ("Pink", "#DB2777"),
        ("Purple", "#7C3AED"),
        ("Gray", "#6B7280")
    ]
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedLifeAreaId != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Goal")) {
                    TextField("Goal name", text: $name)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor( text: $description)
                            .frame(minHeight: 80)
                    }
                    Picker(
                        selection: $color,
                        label: HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 14, height: 14)

                            Text(
                                colorOptions.first(where: { $0.hex == color })?.name ?? "Color"
                            )
                        }
                    ) {
                        ForEach(colorOptions, id: \.hex) { option in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: option.hex))
                                    .frame(width: 14, height: 14)

                                Text(option.name)
                            }
                            .tag(option.hex)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    
                    Button {
                        showTimeSheet = true
                    } label: {
                        HStack {
                            Text("Deadline")
                            Spacer()
                            Text(timeSummary)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            Text("Icon")

                            Spacer()

                            Image(systemName: icon)
                                .foregroundStyle(.primary)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.2))
                                )
                        }
                    }
                }
                if (lifeAreas.count > 0 || selectedLifeAreaId != nil) {
                    Section(header: Text("Life Area")) {
                        Picker("Life Area", selection: $selectedLifeAreaId) {
                            
                            if (lifeAreas.count > 0) {
                                ForEach(lifeAreas) { area in
                                    Text(area.name)
                                        .tag(Optional(area.id))
                                }
                            }
                            if selectedLifeAreaId != nil {
                                Text(fixedLifeAreaName!)
                                    .tag(selectedLifeAreaId!)
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingGoal == nil ? "Add Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingGoal == nil ? "Save" : "Update") {
                        Task {
                            try await saveGoal()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showTimeSheet) { TimeRuleSheet(initialTiming: deadline ?? TaskTiming(
                start:  Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
                duration: 0
                
            )) { timing in
                deadline = timing
            }
            }
            .sheet(isPresented: $showIconPicker) {
                IconSelectionSheet(
                    initialIcon: icon
                ) { selectedIcon in
                    icon = selectedIcon
                }
            }
        }
    }
        private var timeSummary: String {
            deadline?.summary() ?? "Not set"
        }
        private func saveGoal() async throws {
            guard let lifeAreaId = selectedLifeAreaId else { return }

            let trimmedTitle = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

            let computedStartDate: Date? = Calendar.current.startOfDay(for: startDate)

            let goalToPersist = Goals(
                id: existingGoal?.id,
                title: trimmedTitle,
                lifearea_id: lifeAreaId,
                start_date: computedStartDate,
                deadline: deadline?.start,
                color: color,
                description: trimmedDescription,
                icon: icon,
                is_completed: existingGoal?.is_completed ?? false
            )

            let dbManager = DBManager.newInstance()
            if existingGoal == nil {
                try await dbManager.addGoal(goalToPersist)
            } else {
                try await dbManager.updateGoal(goalToPersist)
            }

            onSaved()
            dismiss()
        }
    }
    


#Preview {
    AddEditGoal(
        lifeAreas: [
            LifeAreas( name: "Health", color: "green", icon: "heart"),
            LifeAreas(name: "Career", color: "blue", icon: "person.line.dotted.person")
        ],
        onSaved: {}
    )
}
