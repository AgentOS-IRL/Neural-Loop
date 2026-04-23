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
    let onPreviewRequested: ((ExerciseMediaGallery) -> Void)?

    init(
        draft: WorkoutTemplateExerciseDraft,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onTargetSetsChange: @escaping (String) -> Void,
        onTargetRepsChange: @escaping (String) -> Void,
        onDurationChange: @escaping (String) -> Void,
        onPreviewRequested: ((ExerciseMediaGallery) -> Void)? = nil
    ) {
        self.draft = draft
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onRemove = onRemove
        self.onTargetSetsChange = onTargetSetsChange
        self.onTargetRepsChange = onTargetRepsChange
        self.onDurationChange = onDurationChange
        self.onPreviewRequested = onPreviewRequested
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

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
        HStack(alignment: .top, spacing: 12) {
            ExerciseMediaView(
                exerciseName: draft.exercise.name,
                mode: .thumbnail,
                onPreviewRequested: onPreviewRequested
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(draft.exercise.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 6) {
                    pillLabel(draft.exercise.equipmentName, systemImage: "dumbbell")
                    pillLabel(draft.exercise.type == .repBased ? "Rep-based" : "Duration", systemImage: draft.exercise.type == .repBased ? "repeat" : "timer")
                    orderPill
                }
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                tableHeader(targetHeaderLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 6)

            HStack(spacing: 10) {
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

    private var orderPill: some View {
        Text("#\(draft.orderIndex)")
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(AppTheme.sectionGradient)
            }
            .accessibilityLabel("Order \(draft.orderIndex)")
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

    private func pillLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.system(.caption, design: .rounded, weight: .semibold))
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(AppTheme.sectionGradient)
        }
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
