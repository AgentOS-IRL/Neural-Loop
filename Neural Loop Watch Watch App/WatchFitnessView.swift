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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Group {
                if store.isSnapshotStale {
                    staleWorkoutContent
                } else if snapshot.restEndDate != nil {
                    activeRestContent
                } else {
                    workoutContent
                }
            }
            .navigationDestination(for: ExerciseSnapshot.self) { exercise in
                WatchExerciseDetailView(exerciseID: exercise.id)
            }

            if store.isFinishing {
                Color.black.opacity(reduceTransparency ? 0.92 : 0.6)
                    .ignoresSafeArea()
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Finishing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Finishing workout")
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: snapshot.restEndDate != nil
        )
    }

    private var workoutContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                workoutHeader

                if store.syncStatus.shouldDisplay {
                    WatchSyncStatusView(status: store.syncStatus)
                }

                if let error = store.finishError {
                    finishErrorCard(error)
                }

                WatchWorkoutNowView(snapshot: snapshot)

                NavigationLink {
                    WatchFinishReviewView()
                } label: {
                    Label("End Workout", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(store.isFinishing)
                .accessibilityHint("Opens a review before saving the workout")

                Button {
                    connectivity.sendDeepLinkRequest(.fitnessActiveWorkout)
                } label: {
                    Label("Open on iPhone", systemImage: "iphone")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Continues this workout in Neural Loop on iPhone")
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
    }

    private var activeRestContent: some View {
        VStack(spacing: 6) {
            if store.syncStatus.shouldDisplay {
                WatchSyncStatusView(status: store.syncStatus)
                    .padding(.horizontal, 6)
            }

            WatchRestTimerView(
                exerciseID: restContextExerciseID,
                store: store
            )
            .environmentObject(store)
        }
        .transition(.opacity)
    }

    private var staleWorkoutContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                workoutHeader

                if store.syncStatus.shouldDisplay {
                    WatchSyncStatusView(status: store.syncStatus)
                }

                staleWorkoutCard
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
    }

    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.title)
                .font(.headline)
                .lineLimit(1)

            HStack {
                if let startTime = snapshot.startedAt {
                    Text("Started \(startTime, style: .time)")
                }
                Spacer()
                Text("\(completedSetCount) of \(totalSetCount) sets")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var staleWorkoutCard: some View {
        VStack(spacing: 8) {
            Label(
                "Started \(store.staleSnapshotAge ?? "a while ago")",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.yellow)
            .multilineTextAlignment(.center)

            Text("Continue to refresh this workout, or discard only the saved watch copy.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Button("Continue") {
                    store.continueStaleWorkout()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityHint("Keeps this workout and requests the latest state from iPhone")

                Button("Discard", role: .destructive) {
                    store.discardStaleWorkout()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Removes only this saved workout from Apple Watch")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(cardBackground(.yellow), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private func finishErrorCard(_ error: String) -> some View {
        VStack(spacing: 8) {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)

            Button("Retry") {
                store.retryFinish()
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(cardBackground(.red), in: RoundedRectangle(cornerRadius: 12))
    }

    private var completedSetCount: Int {
        snapshot.exercises.reduce(0) { $0 + $1.completedSetsCount }
    }

    private var totalSetCount: Int {
        snapshot.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var restContextExerciseID: String {
        let ordered = snapshot.exercises.sorted { lhs, rhs in
            if lhs.orderIndex == rhs.orderIndex { return lhs.id < rhs.id }
            return lhs.orderIndex < rhs.orderIndex
        }
        return ordered.first(where: { exercise in
            !exercise.isCompleted && exercise.sets.contains(where: { !$0.isCompleted })
        })?.id ?? ordered.first?.id ?? ""
    }

    private func cardBackground(_ color: Color) -> Color {
        color.opacity(reduceTransparency ? 0.28 : 0.12)
    }
}

struct EmptyFitnessView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            Text("No Active Workout")
                .font(.headline)

            Text("Start a workout on iPhone, then control it here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                ConnectivityManager.shared.sendDeepLinkRequest(.fitnessActiveWorkout)
            } label: {
                Label("Open Fitness", systemImage: "iphone")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
}

#Preview {
    WatchFitnessView()
        .environmentObject(WatchWorkoutStore.shared)
}
