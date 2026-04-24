import SwiftUI

struct WorkoutExerciseCard: View {
    let card: WorkoutExerciseCardState
    let onAddSet: () -> Void
    let onWeightChange: (WorkoutSetDraft.ID, String) -> Void
    let onRepsChange: (WorkoutSetDraft.ID, String) -> Void
    let onDurationChange: (WorkoutSetDraft.ID, String) -> Void
    let onDistanceChange: (WorkoutSetDraft.ID, String) -> Void
    let onCaloriesChange: (WorkoutSetDraft.ID, String) -> Void
    let onToggleComplete: (WorkoutSetDraft.ID) -> Void

    private let setColumnWidth: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Text(card.exercise.equipmentName)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

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
        HStack(spacing: 10) {
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
                    Text("\(set.setNumber)")
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
                    .accessibilityLabel("Toggle completion for set \(set.setNumber)")
                }
                .padding(.vertical, 6)
                .opacity(set.isCompleted ? 0.6 : 1.0)

                if set.id != card.sets.last?.id {
                    Divider()
                        .overlay(AppTheme.textSecondary.opacity(0.18))
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                Label("Progression", systemImage: "chart.xyaxis.line")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accentColor)

            Spacer(minLength: 8)

            Button(action: onAddSet) {
                Label("Add Set", systemImage: "plus")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accentColor)
        }
        .padding(.top, 2)
    }

    private func tableHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(AppTheme.textSecondary)
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
