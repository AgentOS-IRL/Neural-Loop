import SwiftUI

struct WatchExerciseDetailView: View {
    let exerciseID: String
    @EnvironmentObject var store: WatchWorkoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var exercise: ExerciseSnapshot? {
        store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID })
    }
    
    var body: some View {
        Group {
            if let exercise = exercise {
                List {
                    Section {
                        ForEach(exercise.sets) { set in
                            NavigationLink {
                                WatchSetEntryView(exerciseID: exerciseID, setID: set.id)
                            } label: {
                                WatchSetRow(set: set, isCardio: exercise.isDurationBased == true)
                            }
                            .disabled(exercise.isCompleted)
                        }
                    } header: {
                        HStack {
                            Text("Sets")
                            Spacer()
                            // Compact progress (Plan 529)
                            Text("\(exercise.completedSetsCount)/\(exercise.sets.count)")
                                .font(.caption)
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
                        .accessibilityHint("Adds another set to this exercise")
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
                    .disabled(!exercise.isCompleted && !canComplete(exercise))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .accessibilityHint(
                        exercise.isCompleted
                            ? "Marks every set in this exercise incomplete"
                            : "Marks every set in this exercise complete"
                    )
                }
                .navigationTitle(exercise.name)
            } else {
                ContentUnavailableView(
                    "Exercise Unavailable",
                    systemImage: "dumbbell",
                    description: Text("The workout changed on iPhone. Return to the current set.")
                )
            }
        }
        .onChange(of: store.currentSnapshot?.restEndDate) { _, restEndDate in
            guard restEndDate != nil else { return }
            returnToMainWorkoutForRest()
        }
        .onChange(of: store.currentSnapshot?.session.id) { _, sessionID in
            guard sessionID == nil else { return }
            dismiss()
        }
    }

    private func canComplete(_ exercise: ExerciseSnapshot) -> Bool {
        exercise.sets.allSatisfy { set in
            if exercise.isDurationBased == true {
                return (set.values.durationMinutes ?? 0) > 0
                    || (set.values.distanceKilometers ?? 0) > 0
                    || (set.values.calories ?? 0) > 0
            }
            return (set.values.reps ?? 0) > 0
        }
    }

    private func returnToMainWorkoutForRest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.2)) {
            guard store.currentSnapshot?.restEndDate != nil else { return }
            dismiss()
        }
    }
}

struct WatchSetRow: View {
    let set: SetSnapshot
    let isCardio: Bool
    
    var body: some View {
        HStack {
            Text(set.setType == .warmup ? "W\(set.setNumber)" : "\(set.setNumber)")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                if isCardio {
                    Text(cardioText(set.values))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(set.values.kg?.description ?? "--")
                            .font(.body)
                    }
                }

                if let suggestion = set.suggestedValues {
                    Text("Try \(suggestionText(suggestion))")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                if !isCardio {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(set.values.reps?.description ?? "--")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set \(set.setNumber)")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens the detailed set editor")
    }

    private func suggestionText(_ values: WorkoutSetValuesSnapshot) -> String {
        if isCardio { return cardioText(values) }
        let reps = values.reps.map(String.init) ?? "—"
        guard let kg = values.kg else { return "\(reps) reps" }
        return "\(kg) kg × \(reps)"
    }

    private func cardioText(_ values: WorkoutSetValuesSnapshot) -> String {
        [
            values.durationMinutes.map { "\($0)m" },
            values.distanceKilometers.map { "\($0)km" },
            values.calories.map { "\($0)kcal" }
        ].compactMap { $0 }.joined(separator: " • ")
    }

    private var accessibilityValue: String {
        let values = isCardio
            ? cardioText(set.values)
            : "\(set.values.kg?.description ?? "no weight") kilograms, \(set.values.reps?.description ?? "no") repetitions"
        return "\(set.isCompleted ? "Completed" : "Incomplete"), \(values)"
    }
}
