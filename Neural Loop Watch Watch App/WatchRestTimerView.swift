import SwiftUI
import WatchKit

struct WatchRestTimerView: View {
    let exerciseID: String
    var onComplete: ((String?) -> Void)?

    @EnvironmentObject var store: WatchWorkoutStore
    @StateObject private var viewModel: WatchRestTimerViewModel
    @Environment(\.dismiss) var dismiss

    init(exerciseID: String, store: WatchWorkoutStore, onComplete: ((String?) -> Void)? = nil) {
        self.exerciseID = exerciseID
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: WatchRestTimerViewModel(
            exerciseID: exerciseID,
            store: store
        ))
    }

    private var exercise: ExerciseSnapshot? {
        store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID })
    }

    var body: some View {
        VStack(spacing: 10) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: viewModel.progress)

                VStack(spacing: 2) {
                    Text(timeString(from: viewModel.remainingSeconds))
                        .font(.system(.title2, design: .rounded))
                        .bold()
                        .monospacedDigit()

                    Text("Rest")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            // Next set info
            if let nextSetID = viewModel.nextSetID,
               let nextSet = exercise?.sets.first(where: { $0.id == nextSetID }) {
                Text("Next: Set \(nextSet.setNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("All sets done")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            // Skip button
            Button {
                WKInterfaceDevice.current().play(.click)
                viewModel.cancel()
            } label: {
                Text("Skip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
        .padding(.horizontal)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.startTicking()
        }
        .onDisappear {
            viewModel.stopTicking()
        }
        .onChange(of: viewModel.timerState) { newState in
            guard newState == .finished || newState == .cancelled else { return }

            if newState == .finished {
                WKInterfaceDevice.current().play(.success)
                let nextSet = viewModel.nextSetID
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onComplete?(nextSet)
                    dismiss()
                }
            } else {
                // Cancelled or cleared remotely — dismiss without haptic or auto-nav
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onComplete?(nil)
                    dismiss()
                }
            }
        }
    }

    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
