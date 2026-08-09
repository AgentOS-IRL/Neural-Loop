import SwiftUI
import WatchKit

struct WatchRestTimerView: View {
    let exerciseID: String
    var onComplete: ((String?) -> Void)?

    @EnvironmentObject var store: WatchWorkoutStore
    @StateObject private var viewModel: WatchRestTimerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var didPlayTenSecondHaptic = false
    @State private var didPlayCompletionHaptic = false

    init(exerciseID: String, store: WatchWorkoutStore, onComplete: ((String?) -> Void)? = nil) {
        self.exerciseID = exerciseID
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: WatchRestTimerViewModel(
            exerciseID: exerciseID,
            store: store
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(
                            Color.secondary.opacity(reduceTransparency ? 0.4 : 0.18),
                            lineWidth: 7
                        )

                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            Color.blue,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(
                            reduceMotion ? nil : .linear(duration: 0.2),
                            value: viewModel.progress
                        )

                    VStack(spacing: 1) {
                        Text(timeString(from: viewModel.remainingSeconds))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()

                        Text("Rest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 96, height: 96)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rest timer")
                .accessibilityValue(Text(accessibilityTime(from: viewModel.remainingSeconds)))

                nextTargetView

                HStack(spacing: 6) {
                    adjustmentButton(
                        title: "−15",
                        accessibilityLabel: "Reduce rest by 15 seconds",
                        signedSeconds: -15,
                        tint: .orange
                    )

                    Button {
                        WKInterfaceDevice.current().play(.click)
                        viewModel.cancel()
                    } label: {
                        Text("Skip")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    .accessibilityLabel("Skip rest")
                    .accessibilityHint("Ends rest and returns to the next incomplete set")

                    adjustmentButton(
                        title: "+15",
                        accessibilityLabel: "Add 15 seconds to rest",
                        signedSeconds: 15,
                        tint: .blue
                    )
                    .disabled(viewModel.remainingSeconds >= 900)
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.startTicking()
        }
        .onDisappear {
            viewModel.stopTicking()
        }
        .onChange(of: viewModel.remainingSeconds) { _, seconds in
            if seconds > 10 {
                didPlayTenSecondHaptic = false
            } else if seconds > 0, !didPlayTenSecondHaptic {
                didPlayTenSecondHaptic = true
                WKInterfaceDevice.current().play(.directionDown)
            }

            if seconds == 0, !didPlayCompletionHaptic {
                didPlayCompletionHaptic = true
                WKInterfaceDevice.current().play(.success)
            }
        }
        .onChange(of: viewModel.timerState) { _, newState in
            guard newState == .finished || newState == .cancelled else { return }

            if newState == .finished {
                let nextSet = viewModel.nextSetID
                // Clear an expired timer optimistically so the root workout
                // immediately returns to the next target while iPhone reconciles.
                store.cancelRestTimer()
                DispatchQueue.main.asyncAfter(deadline: .now() + dismissalDelay) {
                    onComplete?(nextSet)
                    dismiss()
                }
            } else {
                // Cancelled or cleared remotely — dismiss without haptic or auto-nav
                DispatchQueue.main.asyncAfter(deadline: .now() + dismissalDelay) {
                    onComplete?(nil)
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var nextTargetView: some View {
        if let target = viewModel.nextTarget {
            VStack(spacing: 1) {
                Text("UP NEXT")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(target.exerciseName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("Set \(target.setNumber)")
                    if let description = target.targetDescription {
                        Text("·")
                        Text(description)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Up next, \(target.exerciseName), set \(target.setNumber)")
            .accessibilityValue(Text(target.targetDescription ?? ""))
        } else {
            Label("Workout complete", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
                .accessibilityLabel("All sets complete")
        }
    }

    private func adjustmentButton(
        title: String,
        accessibilityLabel: String,
        signedSeconds: Int,
        tint: Color
    ) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            viewModel.adjust(by: signedSeconds)
        } label: {
            Text(title)
                .font(.headline)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func accessibilityTime(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes == 0 { return "\(remainingSeconds) seconds remaining" }
        if remainingSeconds == 0 { return "\(minutes) minutes remaining" }
        return "\(minutes) minutes, \(remainingSeconds) seconds remaining"
    }

    private var dismissalDelay: TimeInterval {
        reduceMotion ? 0 : 0.35
    }
}
