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
        case duration
        case distance
        case calories
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

    private var isCardio: Bool {
        store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID })?.isDurationBased == true
    }
    
    var body: some View {
        VStack {
            if let set = exerciseSet,
               let suggestion = set.suggestedValues,
               !set.isCompleted {
                suggestionCard(set: set, suggestion: suggestion)
            }

            if currentStep == .summary {
                ScrollView {
                    summaryScreen
                        .padding(.bottom, 20)
                }
            } else {
                VStack(spacing: 4) {
                    if currentStep == .weight {
                        weightScreen
                    } else if currentStep == .reps {
                        repsScreen
                    } else if currentStep == .duration {
                        cardioScreen(value: viewModel.durationMinutes, label: "min", color: .blue, next: .distance)
                    } else if currentStep == .distance {
                        cardioScreen(value: viewModel.distanceKilometers, label: "km", color: .green, next: .calories)
                    } else {
                        cardioScreen(value: viewModel.calories, label: "kcal", color: .orange, next: .summary)
                    }
                }
                .frame(maxHeight: .infinity)
                .focusable()
                .focused($isCrownFocused)
                .digitalCrownRotation(
                    crownBinding,
                    from: 0,
                    through: crownMaximum,
                    by: crownStep,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
            }
        }
        .navigationTitle("Set \(exerciseSet?.setNumber ?? 0)")
        .onAppear {
            viewModel.reinitialize(with: store, set: exerciseSet)
            currentStep = isCardio ? .duration : .weight
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

    private func cardioScreen(
        value: Double,
        label: String,
        color: Color,
        next: EntryStep
    ) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 4)
            CircularDial(
                value: value,
                maxValue: crownMaximum,
                label: label,
                valueFormatted: String(format: label == "km" ? "%.2f" : "%.0f", value),
                color: color
            )
            Text("Rotate Crown to adjust")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            Button {
                withAnimation { currentStep = next }
            } label: {
                Label("OK", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
        }
        .padding(.horizontal)
    }
    
    private var summaryScreen: some View {
        VStack(spacing: 12) {
            // Edit row
            Group {
                if isCardio {
                    HStack(spacing: 8) {
                        summaryMetric(String(format: "%.0f", viewModel.durationMinutes), label: "min", color: .blue, step: .duration)
                        summaryMetric(String(format: "%.2f", viewModel.distanceKilometers), label: "km", color: .green, step: .distance)
                        summaryMetric(String(format: "%.0f", viewModel.calories), label: "kcal", color: .orange, step: .calories)
                    }
                } else {
                    HStack(spacing: 16) {
                        summaryMetric(String(format: "%.1f", viewModel.kg), label: "kg", color: .blue, step: .weight)
                        Divider().frame(height: 30)
                        summaryMetric("\(viewModel.reps)", label: "reps", color: .orange, step: .reps)
                    }
                }
            }
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // Action Buttons
            if !viewModel.isCompleted {
                Button {
                    if viewModel.commitAndComplete(isCardio: isCardio) {
                        checkRestTimerAndDismiss()
                    }
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

    private func summaryMetric(
        _ value: String,
        label: String,
        color: Color,
        step: EntryStep
    ) -> some View {
        Button {
            withAnimation { currentStep = step }
        } label: {
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline.bold())
                    .foregroundColor(color)
                    .minimumScaleFactor(0.65)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func suggestionCard(
        set: SetSnapshot,
        suggestion: WorkoutSetValuesSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let previous = set.previousValues {
                        Text("Previous \(valuesText(previous))")
                            .foregroundStyle(.secondary)
                    }
                    Text("Suggested \(valuesText(suggestion))")
                        .foregroundStyle(.blue)
                }
                .font(.caption2)

                Spacer()

                Button("Use Suggestion") {
                    viewModel.useSuggestion(suggestion)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            }

            if let reason = set.suggestionReason {
                Text(reason.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func valuesText(_ values: WorkoutSetValuesSnapshot) -> String {
        if isCardio {
            return [
                values.durationMinutes.map { "\($0) min" },
                values.distanceKilometers.map { "\($0) km" },
                values.calories.map { "\($0) kcal" }
            ].compactMap { $0 }.joined(separator: " • ")
        }
        let reps = values.reps.map(String.init) ?? "—"
        guard let kg = values.kg else { return "\(reps) reps" }
        return "\(kg) kg × \(reps)"
    }
    
    private func checkRestTimerAndDismiss() {
        dismiss()
    }
    
    private var crownBinding: Binding<Double> {
        Binding(
            get: {
                switch currentStep {
                case .weight: return viewModel.kg
                case .reps: return Double(viewModel.reps)
                case .duration: return viewModel.durationMinutes
                case .distance: return viewModel.distanceKilometers
                case .calories: return viewModel.calories
                case .summary: return 0
                }
            },
            set: { newValue in
                if currentStep == .weight {
                    viewModel.setKg(newValue)
                } else if currentStep == .reps {
                    viewModel.setReps(Int(newValue))
                } else if currentStep == .duration {
                    viewModel.setDuration(newValue)
                } else if currentStep == .distance {
                    viewModel.setDistance(newValue)
                } else if currentStep == .calories {
                    viewModel.setCalories(newValue)
                }
            }
        )
    }

    private var crownMaximum: Double {
        switch currentStep {
        case .weight, .distance: return 500
        case .reps: return 100
        case .duration: return 600
        case .calories: return 10_000
        case .summary: return 1
        }
    }

    private var crownStep: Double {
        switch currentStep {
        case .weight: return 0.5
        case .distance: return 0.1
        default: return 1
        }
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
