//
//  AddGoalProgress.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 13/01/2026.
//

import SwiftUI

struct AddGoalProgressView: View {
    let goalTracking: GoalsTracking
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: UnifiedDataModel

//    @State private var mode: Mode = .add
    @State private var latestTotal: Int = 0
    @State private var inputValue: Int = 0
    @State private var error: String?
    
    @State private var selectedDate: Date = Date()
    
    @State private var showProgressHistory: Bool = false
    @State private var recordsForDate: [GoalsTrackingRecord] = []
    
    private var unitLabel: String {
        goalTracking.label ?? "Times"
    }
    

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .onChange(of: selectedDate) { _ in
                    Task {
                        await fetchProgress()
                        await loadLatestTotal()
                    }
                }

                VStack(spacing: 6) {
                    Text("\(inputValue)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))

                    Text("Total for selected date: \(latestTotal) \(unitLabel)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Stepper(
                    value: $inputValue,
                    in: 0...100000
                ) {
                    Text("Add amount")
                }
                Button {
                    showProgressHistory = true
                } label: {
                    HStack {
                        Text("View earlier records")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.secondary)
                }
                   
                Spacer()
                

                Button("Add progress") {
                    Task { await save() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputValue == 0)
            }
            .padding()
            .navigationTitle("Add Progress")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    await fetchProgress()
                    await loadLatestTotal()
                }
            }
            .sheet(isPresented: $showProgressHistory) {
                ProgressHistoryView(
                    habitId: goalTracking.id!,
                    label: unitLabel
                )
            }
        }
    }
    
    private func fetchProgress() async {
        guard let trackingId = goalTracking.id else { return }

        do {
            
            let allRecords =  await model.fetchGoalsTrackingRecords(forTracking: trackingId, type: goalTracking.type)

            let calendar = Calendar.current
            recordsForDate = allRecords.filter {
                guard let createdAt = $0.created_at else { return false }
                return calendar.isDate(createdAt, inSameDayAs: selectedDate)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }


    private func loadLatestTotal() async {
        let total = recordsForDate.reduce(0) { $0 + Int($1.value) }
        latestTotal = total
        inputValue = 0
    }

    private func save() async {
        
        guard let trackingId = goalTracking.id else { return }
        
        
        let record = GoalsTrackingRecord(
            id: nil,
            goals_tracking_id: trackingId,
            type: goalTracking.type,
            value: Double(inputValue),
            label: unitLabel,
            created_at: selectedDate
        )
        await model.createGoalsTrackingRecord(record:record)
        
        
        onSaved()
        dismiss()
        
    }
}
