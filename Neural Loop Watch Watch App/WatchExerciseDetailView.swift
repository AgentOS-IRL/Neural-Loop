import SwiftUI

struct WatchExerciseDetailView: View {
    let exerciseID: String
    @EnvironmentObject var store: WatchWorkoutStore
    
    private var exercise: ExerciseSnapshot? {
        store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID })
    }
    
    var body: some View {
        Group {
            if let exercise = exercise {
                List {
                    Section {
                        ForEach(exercise.sets) { set in
                            NavigationLink(value: set) {
                                WatchSetRow(set: set)
                            }
                            .disabled(exercise.isCompleted)
                        }
                    } header: {
                        Text("Sets")
                    }
                    
                    if !exercise.isCompleted {
                        Button(action: {
                            store.addSet(exerciseID: exerciseID)
                        }) {
                            Label("Add Set", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    
                    Button(action: {
                        store.toggleExerciseCompletion(exerciseID: exerciseID, isCompleted: !exercise.isCompleted)
                    }) {
                        Text(exercise.isCompleted ? "Resume Exercise" : "Done Exercise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(exercise.isCompleted ? .orange : .green)
                    .controlSize(.large)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .navigationTitle(exercise.name)
                .navigationDestination(for: SetSnapshot.self) { set in
                    WatchSetEntryView(exerciseID: exerciseID, setID: set.id)
                }
            } else {
                Text("Exercise not found")
            }
        }
    }
}

struct WatchSetRow: View {
    let set: SetSnapshot
    
    var body: some View {
        HStack {
            Text("\(set.setNumber)")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .leading)
            
            VStack(alignment: .leading) {
                Text("\(set.values.kg?.description ?? "--") kg")
                Text("\(set.values.reps?.description ?? "--") reps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if set.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}
