import SwiftUI

struct WorkoutTemplateExerciseCard: View {
    let draft: WorkoutTemplateExerciseDraft
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void
    let onTargetSetsChange: (String) -> Void
    let onTargetRepsChange: (String) -> Void
    let onDurationChange: (String) -> Void

    private let setColumnWidth: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Text(draft.exercise.equipmentName)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            targetTable
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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.exercise.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(draft.exercise.type == .repBased ? "Rep-based exercise" : "Duration-based exercise")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveUp ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.35))
                .disabled(!canMoveUp)
                .accessibilityLabel("Move \(draft.exercise.name) up")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveDown ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.35))
                .disabled(!canMoveDown)
                .accessibilityLabel("Move \(draft.exercise.name) down")

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.errorTint)
                .accessibilityLabel("Remove \(draft.exercise.name)")
            }
        }
    }

    private var targetTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                tableHeader("SETS")
                    .frame(width: setColumnWidth, alignment: .leading)
                tableHeader("TARGET")
                    .frame(maxWidth: .infinity, alignment: .leading)
                tableHeader(targetHeaderLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 6)

            HStack(spacing: 10) {
                Text("\(draft.orderIndex)")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: setColumnWidth, height: 44, alignment: .leading)

                numericField(
                    text: Binding(
                        get: { draft.targetSetsText },
                        set: onTargetSetsChange
                    ),
                    placeholder: "1",
                    keyboardType: .numberPad,
                    accessibilityLabel: "\(draft.exercise.name) target sets"
                )

                switch draft.exercise.type {
                case .repBased:
                    numericField(
                        text: Binding(
                            get: { draft.targetRepsText },
                            set: onTargetRepsChange
                        ),
                        placeholder: "0",
                        keyboardType: .numberPad,
                        accessibilityLabel: "\(draft.exercise.name) target reps"
                    )
                case .duration:
                    numericField(
                        text: Binding(
                            get: { draft.durationText },
                            set: onDurationChange
                        ),
                        placeholder: "0",
                        keyboardType: .decimalPad,
                        accessibilityLabel: "\(draft.exercise.name) duration"
                    )
                }
            }
        }
    }

    private var targetHeaderLabel: String {
        switch draft.exercise.type {
        case .repBased:
            return "REPS"
        case .duration:
            return "DURATION"
        }
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
        accessibilityLabel: String
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground).opacity(0.72))
            }
            .accessibilityLabel(accessibilityLabel)
    }
}
