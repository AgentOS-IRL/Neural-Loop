import SwiftUI

struct ProgressHistoryView: View {
    let habitId: Int64
    let label: String

    @State private var entries: [HabitTracking] = []
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    Task { await deleteAll() }
                } label: {
                    Text("Delete all progress")
                }
            }

            Section {
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.entry_date, style: .date)

                        Spacer()

                        Text("\(entry.value) \(label)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Progress history")
        .onAppear {
            Task { await load() }
        }
    }

    private func load() async {
        do {
            let manager = DBManager.newInstance()
            entries = try await manager.fetchHabitEntries(forTask: habitId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteAll() async {
        do {
            let manager = DBManager.newInstance()
            try await manager.deleteHabitEntries(forTask: habitId)
            entries.removeAll()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
