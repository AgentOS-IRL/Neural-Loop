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

struct WatchSetEntryView: View {
    let exerciseID: String
    let setID: String
    @EnvironmentObject var store: WatchWorkoutStore
    @Environment(\.dismiss) var dismiss
    
    @State private var kg: Double?
    @State private var reps: Int?
    @State private var isCompleted: Bool = false
    @State private var hasInitialized = false
    
    private var exerciseSet: SetSnapshot? {
        store.currentSnapshot?.exercises
            .first(where: { $0.id == exerciseID })?
            .sets.first(where: { $0.id == setID })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Weight (kg)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Stepper(value: Binding(get: { self.kg ?? 0 }, set: { self.kg = $0 }), in: 0...500, step: 0.5) {
                        Text(kg != nil ? String(format: "%.1f", kg!) : "--")
                            .font(.title3)
                            .bold()
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Reps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Stepper(value: Binding(get: { self.reps ?? 0 }, set: { self.reps = $0 }), in: 0...100) {
                        Text(reps != nil ? "\(reps!)" : "--")
                            .font(.title3)
                            .bold()
                    }
                }

                Toggle("Completed", isOn: $isCompleted)
                    .padding(.vertical, 4)
                
                Button("Update") {
                    store.updateSetValues(
                        exerciseID: exerciseID,
                        setID: setID,
                        kg: kg.map { Decimal($0) },
                        reps: reps
                    )
                    store.toggleSetCompletion(
                        exerciseID: exerciseID,
                        setID: setID,
                        isCompleted: isCompleted
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationTitle("Set \(exerciseSet?.setNumber ?? 0)")
        .onAppear {
            if !hasInitialized, let exerciseSet = exerciseSet {
                kg = (exerciseSet.values.kg as NSDecimalNumber?)?.doubleValue
                reps = exerciseSet.values.reps
                isCompleted = exerciseSet.isCompleted
                hasInitialized = true
            }
        }
    }
}
