import SwiftUI

struct GoalProgressHistoryView: View {
    let goalsTrackingId: Int64
    let type: GoalTrackingType
    let label: String
    let onChanged: ([GoalsTrackingRecord]) -> Void

    @EnvironmentObject private var model: UnifiedDataModel

    @State private var records: [GoalsTrackingRecord] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isConfirmingDeleteAll = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Delete all progress", role: .destructive) {
                        isConfirmingDeleteAll = true
                    }
                    .disabled(records.isEmpty || isLoading)
                }

                Section {
                    if isLoading && records.isEmpty {
                        ProgressView()
                    } else if records.isEmpty {
                        ContentUnavailableView(
                            "No progress records",
                            systemImage: "chart.line.uptrend.xyaxis"
                        )
                    } else {
                        ForEach(records, id: \.id) { record in
                            HStack {
                                Text(formattedDate(record.created_at))

                                Spacer()

                                Text("\(formattedValue(record.value)) \(label)")
                                    .foregroundColor(.secondary)

                                Button(role: .destructive) {
                                    Task { await delete(record) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .disabled(isLoading)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Progress history")
            .task {
                await loadRecords()
            }
            .confirmationDialog(
                "Delete all progress records?",
                isPresented: $isConfirmingDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete all progress", role: .destructive) {
                    Task { await deleteAll() }
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func loadRecords() async {
        isLoading = true
        defer { isLoading = false }

        do {
            records = try await model.loadGoalProgressHistory(
                forTracking: goalsTrackingId,
                type: type
            )
            errorMessage = nil
        } catch {
            errorMessage = "Could not load progress history: \(error.localizedDescription)"
        }
    }

    private func delete(_ record: GoalsTrackingRecord) async {
        guard let recordId = record.id else {
            errorMessage = "This progress record has no database ID."
            return
        }

        isLoading = true
        defer { isLoading = false }

        if await model.deleteGoalProgressRecord(
            recordId: recordId,
            forTracking: goalsTrackingId
        ) {
            records.removeAll { $0.id == recordId }
            errorMessage = nil
            onChanged(records)
        } else {
            errorMessage = "Could not delete the progress record."
        }
    }

    private func deleteAll() async {
        isLoading = true
        defer { isLoading = false }

        if await model.deleteAllGoalProgressRecords(forTracking: goalsTrackingId) {
            records.removeAll()
            errorMessage = nil
            onChanged(records)
        } else {
            errorMessage = "Could not delete the progress records."
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Unknown date" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func formattedValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
