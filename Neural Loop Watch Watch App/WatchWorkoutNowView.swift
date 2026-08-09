import SwiftUI

private struct WatchWorkoutNowTarget {
    let exercise: ExerciseSnapshot
    let set: SetSnapshot

    var id: String { "\(exercise.id):\(set.id)" }
    var isCardio: Bool { exercise.isDurationBased == true }
}

private enum WatchWorkoutMetric: String, CaseIterable, Hashable {
    case weight
    case reps
    case duration
    case distance
    case calories

    var shortLabel: String {
        switch self {
        case .weight: return "kg"
        case .reps: return "reps"
        case .duration: return "min"
        case .distance: return "km"
        case .calories: return "kcal"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .weight: return "Weight"
        case .reps: return "Repetitions"
        case .duration: return "Duration"
        case .distance: return "Distance"
        case .calories: return "Calories"
        }
    }

    var tint: Color {
        switch self {
        case .weight: return .blue
        case .reps: return .orange
        case .duration: return .blue
        case .distance: return .green
        case .calories: return .orange
        }
    }

    var maximum: Double {
        switch self {
        case .weight, .distance: return 500
        case .reps: return 100
        case .duration: return 600
        case .calories: return 10_000
        }
    }

    var step: Double {
        switch self {
        case .weight: return 0.5
        case .distance: return 0.1
        case .reps, .duration, .calories: return 1
        }
    }
}

/// The glanceable, one-screen control surface for the first incomplete set.
struct WatchWorkoutNowView: View {
    let snapshot: ActiveWorkoutSnapshot

    @EnvironmentObject private var store: WatchWorkoutStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @FocusState private var crownFocused: Bool

    @State private var activeMetric: WatchWorkoutMetric = .weight
    @State private var loadedTargetID: String?
    @State private var loadedExerciseID: String?
    @State private var loadedSetID: String?
    @State private var weight = 0.0
    @State private var reps = 0.0
    @State private var duration = 0.0
    @State private var distance = 0.0
    @State private var calories = 0.0
    @State private var dirtyMetrics: Set<WatchWorkoutMetric> = []
    @State private var validationMessage: String?

    var body: some View {
        Group {
            if let target = currentTarget {
                cockpit(target)
            } else if snapshot.exercises.isEmpty {
                emptyWorkout
            } else {
                workoutComplete
            }
        }
        .onAppear {
            loadCurrentTarget(force: true)
            focusCrown()
        }
        .onChange(of: currentTarget?.id) { _, _ in
            commitPendingValues()
            loadCurrentTarget(force: true)
            focusCrown()
        }
        .onDisappear {
            commitPendingValues()
        }
    }

    private func cockpit(_ target: WatchWorkoutNowTarget) -> some View {
        VStack(spacing: 10) {
            currentSetHeader(target)

            metricPicker(for: target)

            metricDial
                .focusable()
                .focused($crownFocused)
                .digitalCrownRotation(
                    detent: crownValue,
                    from: 0,
                    through: activeMetric.maximum,
                    by: activeMetric.step,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true,
                    onIdle: {
                        commitPendingValues()
                    }
                )

            if let suggestion = target.set.suggestedValues {
                suggestionCard(target: target, suggestion: suggestion)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                complete(target)
            } label: {
                Label("Complete Set", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .handGestureShortcut(.primaryAction)
            .accessibilityHint("Saves these values and advances to the next incomplete set")

            HStack(spacing: 8) {
                NavigationLink {
                    WatchSetEntryView(exerciseID: target.exercise.id, setID: target.set.id)
                } label: {
                    Label("Details", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityHint("Opens all editable values for this set")

                NavigationLink {
                    List {
                        WatchExerciseListView(snapshot: snapshot)
                    }
                    .navigationTitle("Exercises")
                } label: {
                    Label("Exercises", systemImage: "list.bullet")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityHint("Shows every exercise and set")
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding(10)
        .background(
            Color.secondary.opacity(reduceTransparency ? 0.26 : 0.12),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .accessibilityAction(named: "Complete Set") {
            complete(target)
        }
    }

    private func currentSetHeader(_ target: WatchWorkoutNowTarget) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text("NOW")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Spacer()
                Text(setLabel(target.set))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(target.exercise.name)
                .font(.title3.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current exercise, \(target.exercise.name), \(setLabel(target.set))")
    }

    private func metricPicker(for target: WatchWorkoutNowTarget) -> some View {
        HStack(spacing: 5) {
            ForEach(metrics(for: target), id: \.self) { metric in
                Button {
                    commitPendingValues()
                    activeMetric = metric
                    validationMessage = nil
                    focusCrown()
                } label: {
                    Text(metric.shortLabel)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            activeMetric == metric ? metric.tint.opacity(0.28) : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(activeMetric == metric ? metric.tint : .secondary)
                .accessibilityLabel(metric.accessibilityLabel)
                .accessibilityValue(activeMetric == metric ? "Selected" : "Not selected")
            }
        }
    }

    private var metricDial: some View {
        VStack(spacing: 3) {
            Text(formattedActiveValue)
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(activeMetric.tint)
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            Text(activeMetric.shortLabel)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text("Turn the Digital Crown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(activeMetric.accessibilityLabel)
        .accessibilityValue("\(formattedActiveValue) \(activeMetric.shortLabel)")
        .accessibilityHint("Turn the Digital Crown to adjust")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setActiveValue(activeValue + activeMetric.step)
            case .decrement:
                setActiveValue(activeValue - activeMetric.step)
            @unknown default:
                return
            }
            dirtyMetrics.insert(activeMetric)
            validationMessage = nil
        }
    }

    private func suggestionCard(
        target: WatchWorkoutNowTarget,
        suggestion: WorkoutSetValuesSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    if let previous = target.set.previousValues {
                        Text("Previous: \(valuesText(previous, cardio: target.isCardio))")
                            .foregroundStyle(.secondary)
                    }
                    Text("Try: \(valuesText(suggestion, cardio: target.isCardio))")
                        .foregroundStyle(.blue)
                }
                .font(.caption)
                .lineLimit(2)

                Spacer(minLength: 2)

                Button("Apply") {
                    apply(suggestion, to: target)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Apply suggested set values")
            }

            if let reason = target.set.suggestionReason {
                Text(reason.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(
            Color.blue.opacity(reduceTransparency ? 0.24 : 0.1),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityElement(children: .contain)
    }

    private var workoutComplete: some View {
        VStack(spacing: 9) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            Text("All Sets Complete")
                .font(.headline)
            Text("Review the workout, or reopen a set from the exercise list.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                List {
                    WatchExerciseListView(snapshot: snapshot)
                }
                .navigationTitle("Exercises")
            } label: {
                Label("Review Exercises", systemImage: "list.bullet")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            Color.secondary.opacity(reduceTransparency ? 0.26 : 0.12),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .accessibilityElement(children: .contain)
    }

    private var emptyWorkout: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No Exercises Yet")
                .font(.headline)
            Text("Add exercises on iPhone and they’ll appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            Color.secondary.opacity(reduceTransparency ? 0.26 : 0.12),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .accessibilityElement(children: .combine)
    }

    private var currentTarget: WatchWorkoutNowTarget? {
        snapshot.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .lazy
            .compactMap { exercise in
                guard !exercise.isCompleted,
                      let set = exercise.sets.first(where: { !$0.isCompleted }) else { return nil }
                return WatchWorkoutNowTarget(exercise: exercise, set: set)
            }
            .first
    }

    private func metrics(for target: WatchWorkoutNowTarget) -> [WatchWorkoutMetric] {
        target.isCardio ? [.duration, .distance, .calories] : [.weight, .reps]
    }

    private var crownValue: Binding<Double> {
        Binding(
            get: { activeValue },
            set: { newValue in
                setActiveValue(newValue)
                validationMessage = nil
                dirtyMetrics.insert(activeMetric)
            }
        )
    }

    private var activeValue: Double {
        switch activeMetric {
        case .weight: return weight
        case .reps: return reps
        case .duration: return duration
        case .distance: return distance
        case .calories: return calories
        }
    }

    private var formattedActiveValue: String {
        switch activeMetric {
        case .weight: return String(format: "%.1f", weight)
        case .distance: return String(format: "%.1f", distance)
        case .reps: return String(Int(reps.rounded()))
        case .duration, .calories: return String(Int(activeValue.rounded()))
        }
    }

    private func setActiveValue(_ newValue: Double) {
        let clamped = min(max(newValue, 0), activeMetric.maximum)
        switch activeMetric {
        case .weight: weight = clamped
        case .reps: reps = clamped.rounded()
        case .duration: duration = clamped.rounded()
        case .distance: distance = clamped
        case .calories: calories = clamped.rounded()
        }
    }

    private func loadCurrentTarget(force: Bool) {
        guard let target = currentTarget else {
            loadedTargetID = nil
            loadedExerciseID = nil
            loadedSetID = nil
            return
        }
        guard force || loadedTargetID != target.id else { return }

        loadedTargetID = target.id
        loadedExerciseID = target.exercise.id
        loadedSetID = target.set.id
        weight = decimalDouble(target.set.values.kg)
        reps = Double(target.set.values.reps ?? 0)
        duration = decimalDouble(target.set.values.durationMinutes)
        distance = decimalDouble(target.set.values.distanceKilometers)
        calories = decimalDouble(target.set.values.calories)
        dirtyMetrics.removeAll()
        validationMessage = nil

        if target.isCardio {
            if target.set.values.durationMinutes != nil { activeMetric = .duration }
            else if target.set.values.distanceKilometers != nil { activeMetric = .distance }
            else if target.set.values.calories != nil { activeMetric = .calories }
            else { activeMetric = .duration }
        } else {
            activeMetric = target.set.values.kg != nil ? .weight : .reps
        }
    }

    private func apply(
        _ suggestion: WorkoutSetValuesSnapshot,
        to target: WatchWorkoutNowTarget
    ) {
        if let value = suggestion.kg {
            weight = decimalDouble(value)
            dirtyMetrics.insert(.weight)
        }
        if let value = suggestion.reps {
            reps = Double(value)
            dirtyMetrics.insert(.reps)
        }
        if let value = suggestion.durationMinutes {
            duration = decimalDouble(value)
            dirtyMetrics.insert(.duration)
        }
        if let value = suggestion.distanceKilometers {
            distance = decimalDouble(value)
            dirtyMetrics.insert(.distance)
        }
        if let value = suggestion.calories {
            calories = decimalDouble(value)
            dirtyMetrics.insert(.calories)
        }
        activeMetric = target.isCardio ? firstSuggestedCardioMetric(suggestion) : (suggestion.kg == nil ? .reps : .weight)
        commitPendingValues()
        focusCrown()
    }

    private func complete(_ target: WatchWorkoutNowTarget) {
        guard canComplete(target) else {
            validationMessage = target.isCardio
                ? "Enter duration, distance, or calories first."
                : "Enter at least one rep first."
            return
        }

        commitPendingValues()
        store.toggleSetCompletion(
            exerciseID: target.exercise.id,
            setID: target.set.id,
            isCompleted: true
        )
    }

    private func canComplete(_ target: WatchWorkoutNowTarget) -> Bool {
        target.isCardio ? duration > 0 || distance > 0 || calories > 0 : reps > 0
    }

    private func commitPendingValues() {
        guard !dirtyMetrics.isEmpty,
              let exerciseID = loadedExerciseID,
              let setID = loadedSetID else { return }

        let metrics = dirtyMetrics
        dirtyMetrics.removeAll()

        store.updateSetValues(
            exerciseID: exerciseID,
            setID: setID,
            kg: metrics.contains(.weight) ? Decimal(weight) : nil,
            reps: metrics.contains(.reps) ? Int(reps.rounded()) : nil,
            durationMinutes: metrics.contains(.duration) ? Decimal(duration) : nil,
            distanceKilometers: metrics.contains(.distance) ? Decimal(distance) : nil,
            calories: metrics.contains(.calories) ? Decimal(calories) : nil
        )
    }

    private func focusCrown() {
        Task { @MainActor in
            await Task.yield()
            crownFocused = true
        }
    }

    private func firstSuggestedCardioMetric(_ suggestion: WorkoutSetValuesSnapshot) -> WatchWorkoutMetric {
        if suggestion.durationMinutes != nil { return .duration }
        if suggestion.distanceKilometers != nil { return .distance }
        return .calories
    }

    private func decimalDouble(_ value: Decimal?) -> Double {
        guard let value else { return 0 }
        return NSDecimalNumber(decimal: value).doubleValue
    }

    private func setLabel(_ set: SetSnapshot) -> String {
        set.setType == .warmup ? "Warm-up \(set.setNumber)" : "Set \(set.setNumber)"
    }

    private func valuesText(_ values: WorkoutSetValuesSnapshot, cardio: Bool) -> String {
        if cardio {
            let parts = [
                values.durationMinutes.map { "\($0) min" },
                values.distanceKilometers.map { "\($0) km" },
                values.calories.map { "\($0) kcal" }
            ].compactMap { $0 }
            return parts.isEmpty ? "No values" : parts.joined(separator: " • ")
        }

        let repText = values.reps.map { "\($0) reps" } ?? "No reps"
        guard let kg = values.kg else { return repText }
        return "\(kg) kg × \(repText)"
    }
}
