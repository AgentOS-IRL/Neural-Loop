import SwiftUI

struct ExpandedWorkoutExerciseCard: View {
    let card: WorkoutExerciseCardState
    let dataManager: any ExerciseProgressionReading
    let onCopySet: (WorkoutSetDraft.ID) -> Void
    let onWeightChange: (WorkoutSetDraft.ID, String) -> Void
    let onRepsChange: (WorkoutSetDraft.ID, String) -> Void
    let onDurationChange: (WorkoutSetDraft.ID, String) -> Void
    let onDistanceChange: (WorkoutSetDraft.ID, String) -> Void
    let onCaloriesChange: (WorkoutSetDraft.ID, String) -> Void
    let onToggleComplete: (WorkoutSetDraft.ID) -> Void
    let onUseSuggestion: (WorkoutSetDraft.ID) -> Void
    let onUseAllSuggestions: () -> Void
    let onCollapse: () -> Void
    var onPreviewRequested: ((ExerciseMediaGallery) -> Void)? = nil

    @State private var showingProgression = false
    private let setColumnWidth: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(alignment: .top) {
                Text(card.exercise.equipmentName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(targetText)
                    if card.historyUnavailable == true {
                        Text("History unavailable")
                            .foregroundStyle(AppTheme.textSecondary)
                    } else if let source = card.historySource {
                        Text(source.label)
                    }
                }
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.accentColor)
            }

            setTable
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ExerciseMediaView(
                exerciseName: card.exercise.name,
                mode: .thumbnail,
                onPreviewRequested: onPreviewRequested
            )

            VStack(alignment: .leading, spacing: 6) {
                if let supersetLabel = card.supersetLabel {
                    Text(supersetLabel)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.accentColor)
                }

                Text(card.exercise.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                if !card.exercise.muscles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(card.exercise.muscles) { muscle in
                                muscleChip(muscle)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            Button(action: {}) {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textPrimary)
            .accessibilityLabel("Timer for \(card.exercise.name)")

            Menu {
                Button("Settings", action: {})
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .accessibilityLabel("Options for \(card.exercise.name)")

            Button(action: onCollapse) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accentColor)
            .accessibilityLabel("Collapse \(card.exercise.name)")
        }
    }

    private var setTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                tableHeader("SET")
                    .frame(width: setColumnWidth, alignment: .leading)
                
                ForEach(card.columnHeaders.filter { $0 != "SET" }, id: \.self) { header in
                    tableHeader(header)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                tableHeader("DONE")
                    .frame(width: 44, alignment: .center)
            }
            .padding(.bottom, 6)

            ForEach(card.sets) { set in
                HStack(spacing: 10) {
                    Text(set.setType == .warmup ? "W\(set.setNumber)" : "\(set.setNumber)")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(set.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary)
                        .frame(width: setColumnWidth, height: 44, alignment: .leading)

                    if card.exercise.isRepBased {
                        numericField(
                            text: Binding(
                                get: { set.weightText },
                                set: { onWeightChange(set.id, $0) }
                            ),
                            placeholder: "0",
                            keyboardType: .decimalPad,
                            accessibilityLabel: set.weightAccessibilityLabel(exerciseName: card.exercise.name),
                            isDisabled: set.isCompleted
                        )

                        numericField(
                            text: Binding(
                                get: { set.repsText },
                                set: { onRepsChange(set.id, $0) }
                            ),
                            placeholder: "0",
                            keyboardType: .numberPad,
                            accessibilityLabel: set.repsAccessibilityLabel(exerciseName: card.exercise.name),
                            isDisabled: set.isCompleted
                        )
                    } else if card.exercise.isDurationBased {
                        numericField(
                            text: Binding(
                                get: { set.durationText },
                                set: { onDurationChange(set.id, $0) }
                            ),
                            placeholder: "0",
                            keyboardType: .decimalPad,
                            accessibilityLabel: set.durationAccessibilityLabel(exerciseName: card.exercise.name),
                            isDisabled: set.isCompleted
                        )

                        numericField(
                            text: Binding(
                                get: { set.distanceText },
                                set: { onDistanceChange(set.id, $0) }
                            ),
                            placeholder: "KM",
                            keyboardType: .decimalPad,
                            accessibilityLabel: set.distanceAccessibilityLabel(exerciseName: card.exercise.name),
                            isDisabled: set.isCompleted
                        )

                        numericField(
                            text: Binding(
                                get: { set.caloriesText },
                                set: { onCaloriesChange(set.id, $0) }
                            ),
                            placeholder: "KCAL",
                            keyboardType: .decimalPad,
                            accessibilityLabel: set.caloriesAccessibilityLabel(exerciseName: card.exercise.name),
                            isDisabled: set.isCompleted
                        )
                    }

                    Button(action: { onToggleComplete(set.id) }) {
                        Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundStyle(set.isCompleted ? Color.green : AppTheme.textSecondary.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(!set.isCompleted && !canComplete(set))
                    .accessibilityLabel("Toggle completion for set \(set.setNumber)")
                }
                .padding(.vertical, 6)
                .opacity(set.isCompleted ? 0.6 : 1.0)

                if set.previousValues != nil || set.suggestedValues != nil {
                    suggestionRow(for: set)
                }

                if isCopyableFinalWorkingSet(set) {
                    copySetRow(for: set)
                }

                if set.id != card.sets.last?.id {
                    Divider()
                        .overlay(AppTheme.textSecondary.opacity(0.18))
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: { showingProgression = true }) {
                Label("Progression", systemImage: "chart.xyaxis.line")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accentColor)
            .sheet(isPresented: $showingProgression) {
                ExerciseProgressionView(viewModel: ExerciseProgressionViewModel(
                    exerciseId: card.exercise.id,
                    exerciseName: card.exercise.name,
                    exerciseType: card.exercise.type,
                    dataManager: dataManager
                ))
            }

            Spacer(minLength: 8)

            if card.sets.contains(where: { $0.suggestedValues != nil && !$0.isCompleted }) {
                Button("Use All", action: onUseAllSuggestions)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accentColor)
            }

        }
        .padding(.top, 2)
    }

    private var targetText: String {
        if let range = card.effectiveTargetRepRange {
            return "Target \(range.minimum)–\(range.maximum) reps"
        }
        if let duration = card.targetDuration {
            return "Target \(NumericFormatter.format(duration)) min"
        }
        return "History"
    }

    private func canComplete(_ set: WorkoutSetDraft) -> Bool {
        card.exercise.isRepBased ? set.hasRequiredStrengthValues : set.hasRequiredCardioValues
    }

    private func isCopyableFinalWorkingSet(_ set: WorkoutSetDraft) -> Bool {
        set.setType == .working &&
            set.isCompleted &&
            set.id == card.sets.last(where: { $0.setType == .working })?.id
    }

    private func copySetRow(for set: WorkoutSetDraft) -> some View {
        Button {
            onCopySet(set.id)
        } label: {
            Label("Copy set", systemImage: "arrow.down")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.accentColor)
        .padding(.leading, setColumnWidth + 10)
        .padding(.bottom, 6)
        .accessibilityLabel("Copy completed set \(set.setNumber)")
    }

    private func suggestionRow(for set: WorkoutSetDraft) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let previous = set.previousValues {
                    Text("Previous: \(valuesText(previous))")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 4)
                if let suggested = set.suggestedValues {
                    Text("Suggested: \(valuesText(suggested))")
                        .foregroundStyle(AppTheme.accentColor)
                    if !set.isCompleted {
                        Button("Use") { onUseSuggestion(set.id) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            .font(.system(.caption, design: .rounded, weight: .semibold))

            if let reason = set.suggestionReason {
                Text(reason.rawValue)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.leading, setColumnWidth + 10)
        .padding(.bottom, 6)
    }

    private func valuesText(_ values: WorkoutDraftValues) -> String {
        if card.exercise.isRepBased {
            let reps = values.reps.map { "\($0) reps" } ?? "— reps"
            guard let weight = values.weight else { return reps }
            return "\(NumericFormatter.format(weight)) kg × \(reps)"
        }

        return [
            values.durationMinutes.map { "\(NumericFormatter.format($0)) min" },
            values.distanceKilometers.map { "\(NumericFormatter.format($0)) km" },
            values.calories.map { "\(NumericFormatter.format($0)) kcal" }
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    private func tableHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(AppTheme.textSecondary)
    }

    private func muscleChip(_ muscle: MuscleMetadata) -> some View {
        Text(muscle.muscleName)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(muscle.isPrimary ? AppTheme.accentColor : AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if muscle.isPrimary {
                    Capsule()
                        .fill(AppTheme.accentColor.opacity(0.12))
                } else {
                    Capsule()
                        .fill(AppTheme.sectionGradient)
                }
            }
            .overlay {
                if muscle.isPrimary {
                    Capsule()
                        .strokeBorder(AppTheme.accentColor.opacity(0.3), lineWidth: 1)
                }
            }
    }

    private func numericField(
        text: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType,
        accessibilityLabel: String,
        isDisabled: Bool = false
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .disabled(isDisabled)
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(isDisabled ? AppTheme.textSecondary : AppTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground).opacity(isDisabled ? 0.35 : 0.72))
            }
            .accessibilityLabel(accessibilityLabel)
    }
}

struct CompactWorkoutExerciseCard: View {
    let card: WorkoutExerciseCardState
    var isHighlighted = false
    let onExpand: () -> Void

    private var workingSets: [WorkoutSetDraft] {
        card.sets.filter { $0.setType == .working }
    }

    private var completedWorkingSetCount: Int {
        workingSets.filter(\.isCompleted).count
    }

    private var warmupCount: Int {
        card.sets.filter { $0.setType == .warmup }.count
    }

    private var isComplete: Bool {
        !workingSets.isEmpty && completedWorkingSetCount == workingSets.count
    }

    private var progress: Double {
        guard !workingSets.isEmpty else { return 0 }
        return Double(completedWorkingSetCount) / Double(workingSets.count)
    }

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 13) {
                ExerciseMediaView(
                    exerciseName: card.exercise.name,
                    mode: .thumbnail,
                    showsPreviewAffordance: false
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let supersetLabel = card.supersetLabel {
                                Text(supersetLabel)
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .foregroundStyle(AppTheme.accentColor)
                            }

                            Text(card.exercise.name)
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 6)

                        if isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.green)
                        }

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.accentColor)
                    }

                    Text(detailText)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        ProgressView(value: progress)
                            .tint(isComplete ? Color.green : AppTheme.accentColor)

                        Text(progressText)
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(isComplete ? Color.green : AppTheme.textSecondary)
                            .monospacedDigit()
                            .fixedSize()
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.cardGradient)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isHighlighted ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(card.exercise.name), \(progressText)")
        .accessibilityHint("Opens editable exercise details")
    }

    private var detailText: String {
        let target: String
        if let range = card.effectiveTargetRepRange {
            target = "Target \(range.minimum)–\(range.maximum) reps"
        } else if let duration = card.targetDuration {
            target = "Target \(NumericFormatter.format(duration)) min"
        } else {
            target = card.exercise.isRepBased ? "Strength" : "Cardio"
        }
        return "\(card.exercise.equipmentName) • \(target)"
    }

    private var progressText: String {
        let workingText = "\(completedWorkingSetCount)/\(workingSets.count) working"
        guard warmupCount > 0 else { return workingText }
        return "\(warmupCount)W • \(workingText)"
    }

    private var borderColor: Color {
        if isHighlighted { return AppTheme.accentColor }
        if isComplete { return Color.green.opacity(0.45) }
        return AppTheme.textSecondary.opacity(0.18)
    }
}

struct WorkoutRecommendationSection: View {
    let routineName: String
    let sourceDate: Date
    let recommendations: [WorkoutExerciseRecommendation]
    let onAdd: (WorkoutExerciseRecommendation.ID) -> Void
    let onAddAll: () -> Void

    @State private var isShowingAll = false

    private var displayedRecommendations: ArraySlice<WorkoutExerciseRecommendation> {
        recommendations.prefix(isShowingAll ? recommendations.count : 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 0) {
                ForEach(Array(displayedRecommendations.enumerated()), id: \.element.id) { index, recommendation in
                    recommendationRow(recommendation)

                    if index < displayedRecommendations.count - 1 {
                        Divider()
                            .overlay(AppTheme.textSecondary.opacity(0.16))
                            .padding(.leading, 70)
                    }
                }
            }

            if recommendations.count > 3 {
                Button(isShowingAll ? "Show less" : "Show \(recommendations.count - 3) more") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingAll.toggle()
                    }
                }
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.accentColor)
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(AppTheme.accentColor.opacity(0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.accentColor.opacity(0.28), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accentColor)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(AppTheme.accentColor.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("Recommended additions")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("From your last \(routineName) • \(sourceDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            if recommendations.count >= 2 {
                Button("Add all", action: onAddAll)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(AppTheme.accentColor)
            }
        }
    }

    private func recommendationRow(_ recommendation: WorkoutExerciseRecommendation) -> some View {
        HStack(spacing: 12) {
            ExerciseMediaView(
                exerciseName: recommendation.exercise.name,
                mode: .thumbnail,
                showsPreviewAffordance: false
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.exercise.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(contextText(for: recommendation))
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)

                Text(recommendation.setPatternText)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.accentColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button {
                onAdd(recommendation.id)
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.system(.caption, design: .rounded, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(AppTheme.accentColor)
            .accessibilityLabel("Add \(recommendation.exercise.name) to this workout")
        }
        .padding(.vertical, 9)
    }

    private func contextText(for recommendation: WorkoutExerciseRecommendation) -> String {
        let primaryMuscle = recommendation.exercise.muscles.first(where: \.isPrimary)?.muscleName
        return [recommendation.exercise.equipmentName, primaryMuscle]
            .compactMap { $0 }
            .joined(separator: " • ")
    }
}

struct WorkoutRecommendationLoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("Finding previous additions")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Looking at earlier versions of this routine")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(AppTheme.accentColor.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.accentColor.opacity(0.2), lineWidth: 1)
        }
    }
}
