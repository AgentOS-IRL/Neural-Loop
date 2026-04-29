import SwiftUI

struct WatchExerciseDetailView: View {
    let exerciseID: String
    @EnvironmentObject var store: WatchWorkoutStore
    
    // MARK: - Rest Timer State (Plan 527)
    @State private var showRestTimer = false
    @State private var restTimerSetID: String = ""
    @State private var restTimerDuration: Int = 0
    
    // Auto-navigation to next set after rest timer
    @State private var autoNavigateSetID: String?
    @State private var showAutoNavigateSet = false
    
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
                        HStack {
                            Text("Sets")
                            Spacer()
                            // Compact progress (Plan 529)
                            Text("\(exercise.completedSetsCount)/\(exercise.sets.count)")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !exercise.isCompleted {
                        Button(action: {
                            store.addSet(exerciseID: exerciseID)
                        }) {
                            Label("Add", systemImage: "plus.circle.fill")
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
                        Label(
                            exercise.isCompleted ? "Resume" : "Done",
                            systemImage: exercise.isCompleted ? "arrow.counterclockwise" : "checkmark.circle"
                        )
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
                .navigationDestination(isPresented: $showAutoNavigateSet) {
                    if let setID = autoNavigateSetID {
                        WatchSetEntryView(exerciseID: exerciseID, setID: setID)
                    }
                }
            } else {
                Text("Exercise not found")
            }
        }
        // MARK: - Rest Timer Sheet (iPhone Source of Truth)
        .sheet(isPresented: $showRestTimer) {
            WatchRestTimerView(
                exerciseID: exerciseID,
                store: store,
                onComplete: { nextSetID in
                    if let nextSetID {
                        autoNavigateSetID = nextSetID
                        // Delay to let sheet dismiss animation complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showAutoNavigateSet = true
                        }
                    }
                }
            )
            .environmentObject(store)
        }
        .onChange(of: store.currentSnapshot?.restEndDate) { restEndDate in
            // Only show timer if we have an end date and we are NOT currently showing it
            if restEndDate != nil && !showRestTimer {
                // Short delay to allow set entry view to dismiss if it's currently open
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showRestTimer = true
                }
            } else if restEndDate == nil && showRestTimer {
                // If rest timer was cleared on iPhone, dismiss here too
                showRestTimer = false
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
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(set.values.kg?.description ?? "--")
                        .font(.body)
                }
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(set.values.reps?.description ?? "--")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if set.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .opacity(set.isCompleted ? 0.6 : 1.0)
    }
}
