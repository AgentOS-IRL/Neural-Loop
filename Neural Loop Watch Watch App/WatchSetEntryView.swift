import SwiftUI

struct WatchSetEntryView: View {
    let exerciseID: String
    let setID: String
    @EnvironmentObject var store: WatchWorkoutStore
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel: WatchSetEntryViewModel
    @FocusState private var isCrownFocused: Bool
    
    enum EntryStep {
        case weight
        case reps
        case summary
    }
    
    @State private var currentStep: EntryStep = .weight
    
    init(exerciseID: String, setID: String) {
        self.exerciseID = exerciseID
        self.setID = setID
        _viewModel = StateObject(wrappedValue: WatchSetEntryViewModel(
            exerciseID: exerciseID,
            setID: setID,
            store: WatchWorkoutStore.shared,
            set: nil
        ))
    }
    
    private var exerciseSet: SetSnapshot? {
        store.currentSnapshot?.exercises
            .first(where: { $0.id == exerciseID })?
            .sets.first(where: { $0.id == setID })
    }
    
    var body: some View {
        VStack {
            if currentStep == .summary {
                ScrollView {
                    summaryScreen
                        .padding(.bottom, 20)
                }
            } else {
                VStack(spacing: 4) {
                    if currentStep == .weight {
                        weightScreen
                    } else {
                        repsScreen
                    }
                }
                .frame(maxHeight: .infinity)
                .focusable()
                .focused($isCrownFocused)
                .digitalCrownRotation(
                    crownBinding,
                    from: 0,
                    through: currentStep == .weight ? 500 : 100,
                    by: currentStep == .weight ? 0.5 : 1,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
            }
        }
        .navigationTitle("Set \(exerciseSet?.setNumber ?? 0)")
        .onAppear {
            viewModel.reinitialize(with: store, set: exerciseSet)
            isCrownFocused = true
        }
        .onChange(of: currentStep) { _ in
            if currentStep != .summary {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isCrownFocused = true
                }
            }
        }
    }
    
    // MARK: - Screens
    
    private var weightScreen: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 4)
            
            CircularDial(
                value: viewModel.kg,
                maxValue: 100.0,
                label: "kg",
                valueFormatted: String(format: "%.1f", viewModel.kg),
                color: .blue
            )
            
            Text("Rotate Crown to adjust")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer(minLength: 8)
            
            Button {
                withAnimation { currentStep = .reps }
            } label: {
                Label("OK", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(.horizontal)
    }
    
    private var repsScreen: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 4)
            
            CircularDial(
                value: Double(viewModel.reps),
                maxValue: 30.0,
                label: "reps",
                valueFormatted: "\(viewModel.reps)",
                color: .orange
            )
            
            Text("Rotate Crown to adjust")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer(minLength: 8)
            
            Button {
                withAnimation { currentStep = .summary }
            } label: {
                Label("OK", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.horizontal)
    }
    
    private var summaryScreen: some View {
        VStack(spacing: 12) {
            // Edit row
            HStack(spacing: 16) {
                Button {
                    withAnimation { currentStep = .weight }
                } label: {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", viewModel.kg))
                            .font(.title3.bold())
                            .foregroundColor(.blue)
                        Text("kg")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 30)
                
                Button {
                    withAnimation { currentStep = .reps }
                } label: {
                    VStack(spacing: 2) {
                        Text("\(viewModel.reps)")
                            .font(.title3.bold())
                            .foregroundColor(.orange)
                        Text("reps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // Action Buttons
            if !viewModel.isCompleted {
                Button {
                    viewModel.commitAndComplete()
                    checkRestTimerAndDismiss()
                } label: {
                    Text("Complete Set")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button {
                    viewModel.undoComplete()
                } label: {
                    Text("Mark Incomplete")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            
            Button {
                viewModel.commitValues()
                dismiss()
            } label: {
                Text("Save")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private func checkRestTimerAndDismiss() {
        dismiss()
    }
    
    private var crownBinding: Binding<Double> {
        Binding(
            get: {
                currentStep == .weight ? viewModel.kg : Double(viewModel.reps)
            },
            set: { newValue in
                if currentStep == .weight {
                    viewModel.setKg(newValue)
                } else if currentStep == .reps {
                    viewModel.setReps(Int(newValue))
                }
            }
        )
    }
}

struct CircularDial: View {
    let value: Double
    let maxValue: Double
    let label: String
    let valueFormatted: String
    let color: Color
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 6)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: min(CGFloat(value / maxValue), 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: value)
            
            // Inner text
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(valueFormatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: 85, height: 85)
    }
}
