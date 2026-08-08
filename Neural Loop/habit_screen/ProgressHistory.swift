import SwiftUI

struct ProgressHistoryView: View {
    let habitId: Int64
    let label: String

    @State private var error: String?
    @EnvironmentObject var model: UnifiedDataModel

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    Task { await model.deleteAllHabitEntires(habitId:habitId) }
                } label: {
                    Text("Delete all progress")
                }
            }

            Section {
                ForEach(model.habitTrackingEntriesMap[habitId, default: []] , id: \.id) { entry in
                    HStack {
                        Text(entry.entry_date.formatted(date: .abbreviated, time: .shortened))

                        Spacer()

                        Text("\(entry.value) \(label)")
                            .foregroundColor(.secondary)
                        
                        Button(role: .destructive) {
                            Task { await model.deleteHabitEntry(entry) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        
                    }
                }
            }
        }
        .navigationTitle("Progress history")
        
    }

    
}
