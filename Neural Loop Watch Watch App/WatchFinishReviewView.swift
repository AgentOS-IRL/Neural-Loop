import SwiftUI

/// Review screen shown before confirming workout finish.
/// Displays completed/skipped sets, duration, and final confirmation.
struct WatchFinishReviewView: View {
    @EnvironmentObject var store: WatchWorkoutStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    private var snapshot: ActiveWorkoutSnapshot? {
        store.currentSnapshot
    }
    
    private var totalSets: Int {
        snapshot?.exercises.reduce(0) { $0 + $1.sets.count } ?? 0
    }
    
    private var completedSets: Int {
        snapshot?.exercises.reduce(0) { $0 + $1.completedSetsCount } ?? 0
    }
    
    private var skippedSets: Int {
        totalSets - completedSets
    }
    
    private var durationText: String {
        guard let startedAt = snapshot?.startedAt else { return "--:--" }
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
    
    private var completedExercises: [ExerciseSnapshot] {
        snapshot?.exercises.filter(\.isCompleted) ?? []
    }
    
    private var incompleteExercises: [ExerciseSnapshot] {
        snapshot?.exercises.filter { !$0.isCompleted } ?? []
    }
    
    var body: some View {
        List {
            // MARK: - Summary Stats
            Section {
                VStack(spacing: 12) {
                    // Duration
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(durationText)
                            .font(.headline)
                            .monospacedDigit()
                    }
                    
                    Divider()
                    
                    // Sets progress
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("Sets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(completedSets)/\(totalSets)")
                            .font(.headline)
                            .monospacedDigit()
                    }
                    
                    if skippedSets > 0 {
                        Divider()
                        HStack {
                            Image(systemName: "forward.fill")
                                .foregroundColor(.orange)
                            Text("Skipped")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(skippedSets)")
                                .font(.headline)
                                .foregroundColor(.orange)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // MARK: - Incomplete Exercises Warning
            if !incompleteExercises.isEmpty {
                Section {
                    ForEach(incompleteExercises) { exercise in
                        HStack {
                            Text(exercise.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("\(exercise.completedSetsCount)/\(exercise.sets.count)")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("Incomplete")
                    }
                }
            }
            
            // MARK: - Finish Button
            Section {
                Button(action: {
                    store.finishWorkout()
                    dismiss()
                }) {
                    Label("Finish Workout", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(store.isFinishing)
                
                Button(action: {
                    dismiss()
                }) {
                    Label("Go Back", systemImage: "arrow.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Review")
        .navigationBarBackButtonHidden(store.isFinishing)
        .onChange(of: store.currentSnapshot?.session.id) { _, sessionID in
            guard sessionID == nil else { return }
            dismiss()
        }
        .overlay {
            if store.isFinishing {
                Color.black.opacity(reduceTransparency ? 0.92 : 0.6)
                    .ignoresSafeArea()
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Finishing…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Finishing workout")
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchFinishReviewView()
            .environmentObject(WatchWorkoutStore.shared)
    }
}
