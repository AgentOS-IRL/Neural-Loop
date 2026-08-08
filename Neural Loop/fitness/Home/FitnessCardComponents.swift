import SwiftUI

struct FitnessSectionBar: View {
    @Binding var selectedSection: FitnessSection
    let selectAction: (FitnessSection) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FitnessSection.allCases) { section in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectAction(section)
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(sectionForeground(isSelected: selectedSection == section))
                        .background {
                            if selectedSection == section {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(sectionFill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(backgroundFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }

    private var backgroundFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.secondarySystemBackground).opacity(0.96))
        }

        return AnyShapeStyle(AppTheme.sectionGradient)
    }

    private var sectionFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.tertiarySystemBackground))
        }

        return AnyShapeStyle(AppTheme.heroGradient)
    }

    private func sectionForeground(isSelected: Bool) -> Color {
        if isSelected {
            return AppTheme.textPrimary
        }

        return AppTheme.textSecondary
    }
}

struct WorkoutTemplateCard: View {
    let template: WorkoutTemplateSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(template.title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 12)

            Text(template.countText)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
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
}

struct WorkoutSessionCard: View {
    let session: WorkoutSessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(.subheadline, design: .rounded, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
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
}

struct WorkoutDraftCard: View {
    let summary: WorkoutDraftSummary
    let resumeAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: resumeAction) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            draftBadge

                            Text("Draft workout")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text(summary.title)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.accentColor)
                    }

                    Text(summary.subtitleText)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(alignment: .center, spacing: 10) {
                        Label(summary.metadataText, systemImage: "list.bullet.rectangle")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.accentColor)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(AppTheme.accentColor.opacity(0.14))
                            }

                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progress")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text(summary.progressText)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        ProgressView(value: progressFraction)
                            .tint(AppTheme.accentColor)
                    }
                }
                .padding(18)
                .padding(.trailing, 52)
                .frame(maxWidth: .infinity, minHeight: 152, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                        .fill(AppTheme.accentGradient)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(AppTheme.accentColor.opacity(0.32), lineWidth: 1.2)
                }
                .shadow(color: AppTheme.accentColor.opacity(0.14), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
            .accessibilityLabel("\(summary.title), draft workout, \(summary.progressText)")
            .accessibilityHint("Opens the workout")

            Button(role: .destructive, action: deleteAction) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(AppTheme.errorTint)
                    }
            }
            .buttonStyle(.plain)
            .padding(14)
            .accessibilityLabel("Delete draft workout")
        }
    }

    private var draftBadge: some View {
        Label("Draft", systemImage: "pencil")
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(AppTheme.accentColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.78))
            }
    }

    private var progressFraction: Double {
        guard summary.setCount > 0 else { return 0 }
        return Double(summary.completedSetCount) / Double(summary.setCount)
    }
}

#Preview {
    FitnessView()
        .environmentObject(UnifiedDataModel(autoStart: false))
}


