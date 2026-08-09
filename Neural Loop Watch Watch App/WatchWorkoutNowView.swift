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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @FocusState private var crownFocused: Bool
    @AppStorage("watchWorkoutHasUsedFocusCrown") private var hasUsedFocusCrown = false

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
        .onChange(of: activeMetric) { _, _ in
            commitPendingValues()
            validationMessage = nil
            focusCrown()
        }
        .onDisappear {
            commitPendingValues()
        }
    }

    private func cockpit(_ target: WatchWorkoutNowTarget) -> some View {
        GeometryReader { geometry in
            let availableMetrics = metrics(for: target)
            let showsSuggestion = target.set.suggestedValues != nil && validationMessage == nil
            let showsMetricPicker = availableMetrics.count > 1 && !showsSuggestion
            let showsCrownHint = !hasUsedFocusCrown && !showsSuggestion && validationMessage == nil
            let valueControlHeight = focusControlHeight(
                availableHeight: geometry.size.height,
                showsMetricPicker: showsMetricPicker,
                showsSuggestion: showsSuggestion,
                showsCrownHint: showsCrownHint,
                showsValidation: validationMessage != nil
            )

            VStack(spacing: 4) {
                currentSetHeader(target)

                if showsMetricPicker {
                    metricPicker(for: target)
                }

                Spacer(minLength: 0)

                metricValueControl(
                    activeMetric,
                    height: valueControlHeight,
                    availableWidth: geometry.size.width,
                    target: target
                )
                    .focusable()
                    .focusEffectDisabled()
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
                    .digitalCrownAccessory(.hidden)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                } else if showsSuggestion, let suggestion = target.set.suggestedValues {
                    suggestionRow(target: target, suggestion: suggestion)
                } else if showsCrownHint {
                    Text("Turn the Digital Crown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)

                completeSetButton(target)
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .top
            )
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 2)
        .accessibilityAction(named: "Complete Set") {
            complete(target)
        }
    }

    private func currentSetHeader(_ target: WatchWorkoutNowTarget) -> some View {
        Text(target.exercise.name)
            .font(.headline)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Current exercise, \(target.exercise.name), \(setLabel(target.set))")
    }

    private func metricPicker(for target: WatchWorkoutNowTarget) -> some View {
        HStack(spacing: 12) {
            ForEach(metrics(for: target), id: \.self) { metric in
                Button {
                    commitPendingValues()
                    setActiveMetric(metric)
                    validationMessage = nil
                } label: {
                    Text(metric.shortLabel)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .overlay(alignment: .bottom) {
                            Capsule()
                                .fill(activeMetric == metric ? metric.tint : Color.clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(activeMetric == metric ? metric.tint : .secondary)
                .accessibilityLabel(metric.accessibilityLabel)
                .accessibilityValue(activeMetric == metric ? "Selected" : "Not selected")
            }
        }
    }

    private func metricValueControl(
        _ metric: WatchWorkoutMetric,
        height: CGFloat,
        availableWidth: CGFloat,
        target: WatchWorkoutNowTarget
    ) -> some View {
        Text(formattedValue(for: metric))
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(metric.tint)
            .minimumScaleFactor(0.58)
            .lineLimit(1)
            .frame(
                width: min(132, availableWidth * 0.72),
                height: height
            )
            .background(
                Color.secondary.opacity(reduceTransparency ? 0.24 : 0.08),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(metric.tint.opacity(0.78), lineWidth: 2)
            }
        .contentShape(Rectangle())
        .gesture(metricSwipeGesture(for: target))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metric.accessibilityLabel)
        .accessibilityValue("\(formattedValue(for: metric)) \(metric.shortLabel)")
        .accessibilityHint("Turn the Digital Crown to adjust. Swipe horizontally to change metric")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setActiveValue(activeValue + metric.step)
            case .decrement:
                setActiveValue(activeValue - metric.step)
            @unknown default:
                return
            }
            hasUsedFocusCrown = true
            dirtyMetrics.insert(metric)
            validationMessage = nil
        }
    }

    private func completeSetButton(_ target: WatchWorkoutNowTarget) -> some View {
        Button {
            complete(target)
        } label: {
            Label("Complete Set", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .minimumScaleFactor(0.78)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                .foregroundStyle(.white)
                .background(.green, in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .handGestureShortcut(.primaryAction)
        .accessibilityHint("Saves these values and advances to the next incomplete set")
    }

    private func suggestionRow(
        target: WatchWorkoutNowTarget,
        suggestion: WorkoutSetValuesSnapshot
    ) -> some View {
        HStack(spacing: 6) {
            Text("Try \(valuesText(suggestion, cardio: target.isCardio))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 2)

            Button("Apply") {
                apply(suggestion, to: target)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.blue)
            .accessibilityLabel("Apply suggested set values")
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .background(
            Color.blue.opacity(reduceTransparency ? 0.22 : 0.08),
            in: Capsule()
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
        if target.isCardio {
            let supportedMetrics: [WatchWorkoutMetric] = [.duration, .distance, .calories]
            let applicableMetrics = supportedMetrics.filter { metric in
                hasValue(for: metric, in: target.set.values)
                    || target.set.previousValues.map { hasValue(for: metric, in: $0) } == true
                    || target.set.suggestedValues.map { hasValue(for: metric, in: $0) } == true
            }
            return applicableMetrics.isEmpty ? [.duration] : applicableMetrics
        }

        let usesWeight = hasValue(for: .weight, in: target.set.values)
            || target.set.previousValues.map { hasValue(for: .weight, in: $0) } == true
            || target.set.suggestedValues.map { hasValue(for: .weight, in: $0) } == true
        return usesWeight ? [.weight, .reps] : [.reps]
    }

    private func hasValue(
        for metric: WatchWorkoutMetric,
        in values: WorkoutSetValuesSnapshot
    ) -> Bool {
        switch metric {
        case .weight: return values.kg != nil
        case .reps: return values.reps != nil
        case .duration: return values.durationMinutes != nil
        case .distance: return values.distanceKilometers != nil
        case .calories: return values.calories != nil
        }
    }

    private var crownValue: Binding<Double> {
        Binding(
            get: { activeValue },
            set: { newValue in
                setActiveValue(newValue)
                validationMessage = nil
                dirtyMetrics.insert(activeMetric)
                hasUsedFocusCrown = true
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

    private func formattedValue(for metric: WatchWorkoutMetric) -> String {
        switch metric {
        case .weight: return String(format: "%.1f", weight)
        case .distance: return String(format: "%.1f", distance)
        case .reps: return String(Int(reps.rounded()))
        case .duration: return String(Int(duration.rounded()))
        case .calories: return String(Int(calories.rounded()))
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

        let availableMetrics = metrics(for: target)
        activeMetric = availableMetrics.first(where: {
            hasValue(for: $0, in: target.set.values)
        }) ?? availableMetrics.first ?? (target.isCardio ? .duration : .reps)
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

    private func focusControlHeight(
        availableHeight: CGFloat,
        showsMetricPicker: Bool,
        showsSuggestion: Bool,
        showsCrownHint: Bool,
        showsValidation: Bool
    ) -> CGFloat {
        // Reserve the real Ultra 2 vertical budget for the exercise title and
        // the 44-point primary action before allowing the value field to expand.
        var reservedHeight: CGFloat = 100
        if showsMetricPicker { reservedHeight += 24 }
        if showsSuggestion { reservedHeight += 30 }
        if showsCrownHint { reservedHeight += 20 }
        if showsValidation { reservedHeight += 20 }
        return min(72, max(48, availableHeight - reservedHeight))
    }

    private func metricSwipeGesture(for target: WatchWorkoutNowTarget) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let availableMetrics = metrics(for: target)
                guard availableMetrics.count > 1,
                      let currentIndex = availableMetrics.firstIndex(of: activeMetric) else { return }

                let offset = value.translation.width < 0 ? 1 : -1
                let nextIndex = min(max(currentIndex + offset, 0), availableMetrics.count - 1)
                guard nextIndex != currentIndex else { return }

                commitPendingValues()
                setActiveMetric(availableMetrics[nextIndex])
            }
    }

    private func setActiveMetric(_ metric: WatchWorkoutMetric) {
        if reduceMotion {
            activeMetric = metric
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                activeMetric = metric
            }
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
