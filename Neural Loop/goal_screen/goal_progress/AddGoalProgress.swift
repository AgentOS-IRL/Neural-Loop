//
//  AddGoalProgress.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 13/01/2026.
//

import SwiftUI

struct AddGoalProgressView: View {
    let goalTracking: GoalsTracking
    let onSaved: (GoalTrackingBundle) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: UnifiedDataModel

    @State private var latestTotal: Double = 0
    @State private var inputValueText: String = ""
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
                        loadLatestTotal()
                    }
                }

                VStack(spacing: 6) {
                    TextField("Amount", text: $inputValueText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 56, weight: .bold, design: .rounded))

                    Text("Total for selected date: \(formattedProgressValue(latestTotal)) \(unitLabel)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
                .disabled(parsedInputValue == nil)

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
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
                    loadLatestTotal()
                }
            }
            .sheet(isPresented: $showProgressHistory) {
                GoalProgressHistoryView(
                    goalsTrackingId: goalTracking.id!,
                    type: goalTracking.type,
                    label: unitLabel,
                    onChanged: handleHistoryChange
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


    private func loadLatestTotal() {
        let total = recordsForDate.reduce(0.0) { $0 + $1.value }
        latestTotal = total
        inputValueText = ""
    }

    private func handleHistoryChange(_ records: [GoalsTrackingRecord]) {
        let calendar = Calendar.current
        recordsForDate = records.filter {
            guard let createdAt = $0.created_at else { return false }
            return calendar.isDate(createdAt, inSameDayAs: selectedDate)
        }
        loadLatestTotal()
        onSaved(GoalTrackingBundle(tracking: goalTracking, records: records))
    }

    private func save() async {
        
        guard let trackingId = goalTracking.id else { return }
        guard let inputValue = parsedInputValue else {
            error = "Enter a valid amount greater than zero."
            return
        }
        
        let bundle = await model.createGoalsTrackingRecordAndReturnBundle(
            goalsTrackingId: trackingId,
            type: goalTracking.type.rawValue,
            value: inputValue,
            label: unitLabel,
            createdDate: selectedDate
        )
        
        if let bundle = bundle {
            onSaved(bundle)
            dismiss()
        } else {
            error = "Failed to save progress."
        }
    }

    private var parsedInputValue: Double? {
        let trimmedValue = inputValueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmedValue), value > 0 else {
            return nil
        }
        return value
    }

    private func formattedProgressValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
