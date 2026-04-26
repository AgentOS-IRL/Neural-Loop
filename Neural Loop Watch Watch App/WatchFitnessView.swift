import SwiftUI

struct WatchFitnessView: View {
    @EnvironmentObject var store: WatchWorkoutStore
    @ObservedObject var connectivity: ConnectivityManager = .shared

    var body: some View {
        Group {
            if let snapshot = store.currentSnapshot {
                ActiveWorkoutView(snapshot: snapshot, connectivity: connectivity)
            } else {
                EmptyFitnessView()
            }
        }
        .navigationTitle("Fitness")
    }
}

struct ActiveWorkoutView: View {
    let snapshot: ActiveWorkoutSnapshot
    let connectivity: ConnectivityManager

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text(snapshot.title)
                        .font(.headline)
                    if let startTime = snapshot.startedAt {
                        Text("Started at: \(startTime, style: .time)")
                            .font(.caption)
                    }
                    
                    if !connectivity.isReachable {
                        Text("Disconnected from iPhone")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            WatchExerciseListView(snapshot: snapshot)
        }
        .navigationDestination(for: ExerciseSnapshot.self) { exercise in
            WatchExerciseDetailView(exerciseID: exercise.id)
        }
    }
}

struct EmptyFitnessView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Active Workout")
                .font(.headline)
            
            Text("Start a workout on your iPhone to begin tracking on your watch.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview {
    WatchFitnessView()
        .environmentObject(WatchWorkoutStore.shared)
}
