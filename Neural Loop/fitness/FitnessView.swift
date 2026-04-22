import SwiftUI

struct FitnessView: View {
    @StateObject private var viewModel = FitnessViewModel()
    private let bottomInsetHeight: CGFloat = 88
    @State private var isNewWorkoutPresented = false
    @State private var selectedTemplate: WorkoutTemplateSummary?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        workoutTemplateHeader
                        workoutTemplateContent
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, bottomInsetHeight + 20)
                }
            }
            .navigationTitle("Fitness")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadIfNeeded()
            }
            .sheet(item: $selectedTemplate) { template in
                WorkoutTemplateDetailView(template: template)
            }
            .fullScreenCover(isPresented: $isNewWorkoutPresented) {
                NewWorkoutView()
            }
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

            Button {
                isNewWorkoutPresented = true
            } label: {
                headerIcon(systemName: "plus")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add workout")
        }
    }

    @ViewBuilder
    private var workoutTemplateContent: some View {
        if viewModel.isLoading && viewModel.templates.isEmpty {
            loadingState
        } else if viewModel.templates.isEmpty {
            if let errorMessage = viewModel.errorMessage {
                errorState(message: errorMessage)
            } else {
                emptyState
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if let errorMessage = viewModel.errorMessage {
                    errorBanner(message: errorMessage)
                }

                workoutTemplateGrid
            }
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
            ForEach(viewModel.templates) { template in
                Button {
                    selectedTemplate = template
                } label: {
                    WorkoutTemplateCard(template: template)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(template.title), \(template.countText)")
                .accessibilityHint("Opens workout details")
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.textPrimary)

            Text("Loading workout templates")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No workout templates yet")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Create one with the plus button.")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(.horizontal, 20)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            errorBanner(message: message)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Retry") {
                Task {
                    await viewModel.reload()
                }
            }
            .buttonStyle(.plain)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
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

#Preview {
    FitnessView()
}
