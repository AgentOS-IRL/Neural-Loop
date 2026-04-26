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
    @EnvironmentObject var store: WatchWorkoutStore

    var body: some View {
        ZStack {
            List {
                // MARK: - Header
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.title)
                            .font(.headline)
                        if let startTime = snapshot.startedAt {
                            Text("Started \(startTime, style: .time)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Sync status indicator (Plan 529)
                    WatchSyncStatusView(status: store.syncStatus)
                }
                
                // MARK: - Stale Draft Banner (Plan 529)
                if store.isSnapshotStale {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("Started \(store.staleSnapshotAge ?? "a while ago")")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                            HStack {
                                Button("Resume") {}
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                Button("Discard") {
                                    store.discardStaleWorkout()
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .controlSize(.small)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // MARK: - Finish Error Banner
                if let error = store.finishError {
                    Section {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            Button("Retry") {
                                store.retryFinish()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // MARK: - Exercises
                WatchExerciseListView(snapshot: snapshot)

                // MARK: - All Done Badge (Plan 529)
                if !snapshot.exercises.isEmpty, snapshot.exercises.allSatisfy(\.isCompleted) {
                    Section {
                        VStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.title3)
                                .foregroundColor(.yellow)
                            Text("All exercises done!")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // MARK: - End Workout Button (Plan 528)
                NavigationLink {
                    WatchFinishReviewView()
                } label: {
                    Label("End Workout", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
                .disabled(store.isFinishing)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .navigationDestination(for: ExerciseSnapshot.self) { exercise in
                WatchExerciseDetailView(exerciseID: exercise.id)
            }
            
            // MARK: - Finishing Overlay (Plan 528)
            if store.isFinishing {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Finishing…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct EmptyFitnessView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text("No Active Workout")
                .font(.headline)
            
            Text("Start on iPhone")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    WatchFitnessView()
        .environmentObject(WatchWorkoutStore.shared)
}
