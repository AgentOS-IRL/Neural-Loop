import SwiftUI

struct FitnessView: View {
    private let templates: [WorkoutTemplateSummary] = WorkoutTemplateSummary.samples
    private let bottomInsetHeight: CGFloat = 88

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        workoutTemplateHeader
                        workoutTemplateGrid
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, bottomInsetHeight + 20)
                }
            }
            .navigationTitle("Fitness")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var workoutTemplateHeader: some View {
        HStack(spacing: 12) {
            Text("Workout Template")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 12)

            Button(action: {}) {
                headerIcon(systemName: "ellipsis")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Workout template options")

            Button(action: {}) {
                headerIcon(systemName: "plus")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add workout template")
        }
    }

    private var workoutTemplateGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 14, alignment: .top)
            ],
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(templates) { template in
                WorkoutTemplateCard(template: template)
            }
        }
    }

    private func headerIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 36, height: 36)
            .background {
                Circle()
                    .fill(AppTheme.cardGradient)
            }
            .overlay {
                Circle()
                    .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
            }
            .contentShape(Circle())
    }
}

private struct WorkoutTemplateCard: View {
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

private struct WorkoutTemplateSummary: Identifiable, Equatable {
    let id: UUID
    var title: String
    var exerciseCount: Int
    var setCount: Int

    var countText: String {
        "\(exerciseCount) exercise, \(setCount) set"
    }

    static let samples: [WorkoutTemplateSummary] = [
        WorkoutTemplateSummary(title: "Push Day", exerciseCount: 5, setCount: 18),
        WorkoutTemplateSummary(title: "Pull Day", exerciseCount: 6, setCount: 20),
        WorkoutTemplateSummary(title: "Leg Day", exerciseCount: 5, setCount: 16),
        WorkoutTemplateSummary(title: "Full Body", exerciseCount: 7, setCount: 24)
    ]

    init(id: UUID = UUID(), title: String, exerciseCount: Int, setCount: Int) {
        self.id = id
        self.title = title
        self.exerciseCount = exerciseCount
        self.setCount = setCount
    }
}

#Preview {
    FitnessView()
}
