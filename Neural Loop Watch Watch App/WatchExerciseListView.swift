import SwiftUI

struct WatchExerciseListView: View {
    let snapshot: ActiveWorkoutSnapshot
    
    var body: some View {
        if snapshot.exercises.isEmpty {
            VStack {
                Text("No exercises added yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        } else {
            ForEach(snapshot.exercises) { exercise in
                NavigationLink(value: exercise) {
                    ExerciseRowView(exercise: exercise)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens sets for \(exercise.name)")
            }
        }
    }
}

struct ExerciseRowView: View {
    let exercise: ExerciseSnapshot
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .strikethrough(exercise.isCompleted)
                    .foregroundColor(exercise.isCompleted ? .secondary : .primary)
                
                HStack(spacing: 4) {
                    ProgressView(
                        value: exercise.sets.isEmpty ? 0 : Double(exercise.completedSetsCount) / Double(exercise.sets.count)
                    )
                    .frame(width: 40)
                    .tint(exercise.isCompleted ? .green : .blue)
                    
                    Text("\(exercise.completedSetsCount)/\(exercise.sets.count)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if exercise.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .opacity(exercise.isCompleted ? 0.6 : 1.0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exercise.name)
        .accessibilityValue(
            "\(exercise.isCompleted ? "Complete" : "Incomplete"), \(exercise.completedSetsCount) of \(exercise.sets.count) sets"
        )
    }
}

#Preview {
    List {
        WatchExerciseListView(snapshot: ActiveWorkoutSnapshot(
            session: WorkoutSessionPointer(id: "1"),
            title: "Morning Workout",
            exercises: [
                ExerciseSnapshot(id: "e1", name: "Bench Press", orderIndex: 0, isCompleted: false, sets: [
                    SetSnapshot(id: "s1", setNumber: 1, values: WorkoutSetValuesSnapshot(kg: 60, reps: 10), isCompleted: true),
                    SetSnapshot(id: "s2", setNumber: 2, values: WorkoutSetValuesSnapshot(kg: 60, reps: 10), isCompleted: false)
                ]),
                ExerciseSnapshot(id: "e2", name: "Squats", orderIndex: 1, isCompleted: true, sets: [
                    SetSnapshot(id: "s3", setNumber: 1, values: WorkoutSetValuesSnapshot(kg: 80, reps: 10), isCompleted: true)
                ])
            ]
        ))
    }
}
