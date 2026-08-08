import SwiftUI

struct WorkoutTemplateExerciseCard: View {
    let draft: WorkoutTemplateExerciseDraft
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void
    let onWorkingSetsChange: (String) -> Void
    let onWarmupSetsChange: (String) -> Void
    let onTargetRepsMinChange: (String) -> Void
    let onTargetRepsMaxChange: (String) -> Void
    let onLoadIncrementChange: (String) -> Void
    let onDurationChange: (String) -> Void
    let onRestSecondsChange: (String) -> Void
    let onPreviewRequested: ((ExerciseMediaGallery) -> Void)?

    init(
        draft: WorkoutTemplateExerciseDraft,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onWorkingSetsChange: @escaping (String) -> Void,
        onWarmupSetsChange: @escaping (String) -> Void,
        onTargetRepsMinChange: @escaping (String) -> Void,
        onTargetRepsMaxChange: @escaping (String) -> Void,
        onLoadIncrementChange: @escaping (String) -> Void,
        onDurationChange: @escaping (String) -> Void,
        onRestSecondsChange: @escaping (String) -> Void,
        onPreviewRequested: ((ExerciseMediaGallery) -> Void)? = nil
    ) {
        self.draft = draft
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onRemove = onRemove
        self.onWorkingSetsChange = onWorkingSetsChange
        self.onWarmupSetsChange = onWarmupSetsChange
        self.onTargetRepsMinChange = onTargetRepsMinChange
        self.onTargetRepsMaxChange = onTargetRepsMaxChange
        self.onLoadIncrementChange = onLoadIncrementChange
        self.onDurationChange = onDurationChange
        self.onRestSecondsChange = onRestSecondsChange
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
                    if let supersetLabel = draft.supersetLabel {
                        pillLabel(supersetLabel, systemImage: "link")
                            .foregroundStyle(AppTheme.accentColor)
                    }
                    pillLabel(draft.exercise.equipmentName, systemImage: "dumbbell")
                    pillLabel(draft.exercise.isRepBased ? "Rep-based" : "Duration", systemImage: draft.exercise.isRepBased ? "repeat" : "timer")
                    orderPill
                }

                if !draft.exercise.muscles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(draft.exercise.muscles) { muscle in
                                muscleChip(muscle)
                            }
                        }
                    }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                editorField("WORK SETS", value: draft.workingSetsText, placeholder: "1", keyboardType: .numberPad, onChange: onWorkingSetsChange)
                if draft.exercise.isRepBased {
                    editorField("WARM-UPS", value: draft.warmupSetsText, placeholder: "0", keyboardType: .numberPad, onChange: onWarmupSetsChange)
                }
                editorField("REST (S)", value: draft.restSecondsText, placeholder: "0", keyboardType: .numberPad, onChange: onRestSecondsChange)
            }

            if draft.exercise.isRepBased {
                HStack(spacing: 10) {
                    editorField("REP MIN", value: draft.targetRepsMinText, placeholder: "8", keyboardType: .numberPad, onChange: onTargetRepsMinChange)
                    editorField("REP MAX", value: draft.targetRepsMaxText, placeholder: "12", keyboardType: .numberPad, onChange: onTargetRepsMaxChange)
                    editorField("ADD KG", value: draft.loadIncrementKgText, placeholder: "2.5", keyboardType: .decimalPad, onChange: onLoadIncrementChange)
                }
            } else {
                editorField("DURATION (MIN)", value: draft.durationText, placeholder: "0", keyboardType: .decimalPad, onChange: onDurationChange)
            }
        }
    }

    private func editorField(
        _ label: String,
        value: String,
        placeholder: String,
        keyboardType: UIKeyboardType,
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            tableHeader(label)
            numericField(
                text: Binding(get: { value }, set: onChange),
                placeholder: placeholder,
                keyboardType: keyboardType,
                accessibilityLabel: "\(draft.exercise.name) \(label.lowercased())"
            )
        }
        .frame(maxWidth: .infinity)
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
