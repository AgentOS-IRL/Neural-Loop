import Combine
import SwiftUI

enum FitnessSection: String, CaseIterable, Identifiable {
    case workout = "Workout"
    case routine = "Routine"

    var id: String { rawValue }
}

@MainActor
final class FitnessNavigationModel: ObservableObject {
    @Published var selectedSection: FitnessSection = .routine

    func select(_ section: FitnessSection) {
        selectedSection = section
    }
}

struct FitnessView: View {
    @EnvironmentObject private var model: UnifiedDataModel
    @StateObject private var viewModel = FitnessViewModel()
    @StateObject private var navigationModel = FitnessNavigationModel()
    private let bottomInsetHeight: CGFloat = 88
    @State private var isTemplateEditorPresented = false
    @State private var isRoutineGeneratorPresented = false
    @State private var selectedTemplate: WorkoutTemplateSummary?
    @State private var selectedSession: WorkoutSessionSummary?
    @State private var generatedRoutine: WorkoutRoutineGenerationPayload?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        sectionContent
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, bottomInsetHeight + 20)
                }
            }
            .navigationTitle("Fitness")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                FitnessSectionBar(
                    selectedSection: $navigationModel.selectedSection,
                    selectAction: navigationModel.select
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .task {
                await viewModel.loadIfNeeded()
            }
            .sheet(item: $selectedTemplate) { template in
                WorkoutTemplateDetailView(template: template) {
                    Task {
                        await viewModel.reload()
                    }
                }
            }
            .sheet(item: $selectedSession) { session in
                WorkoutSessionDetailView(viewModel: WorkoutSessionDetailViewModel(
                    sessionId: session.id,
                    dataManager: model.manager
                ))
            }
            .fullScreenCover(item: $viewModel.activeDraft) { draft in
                ActiveWorkoutView(viewModel: ActiveWorkoutViewModel(
                    draft: draft,
                    db: model.manager,
                    onDraftChange: { updatedDraft in
                        viewModel.activeDraft = updatedDraft
                    },
                    onFinish: {
                        viewModel.clearActiveDraft()
                    }
                ))
            }
            .fullScreenCover(isPresented: $isRoutineGeneratorPresented) {
                WorkoutRoutineGenerationView(
                    model: model,
                    dataManager: model.manager
                ) { routine in
                    generatedRoutine = routine
                    isTemplateEditorPresented = true
                }
            }
            .fullScreenCover(isPresented: $isTemplateEditorPresented, onDismiss: {
                generatedRoutine = nil
            }) {
                WorkoutTemplateEditorView(
                    mode: .create,
                    dataManager: model.manager,
                    generatedRoutine: generatedRoutine
                ) {
                    generatedRoutine = nil
                    Task {
                        await viewModel.reload()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch navigationModel.selectedSection {
        case .workout:
            VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                workoutHeader
                workoutContent
            }
        case .routine:
            VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                routineHeader
                routineContent
            }
        }
    }

    private var routineHeader: some View {
        HStack(spacing: 12) {
            Text("Routine")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 12)

            Button(action: {}) {
                headerIcon(systemName: "ellipsis")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Routine options")
            .contextMenu {
                Button("Generate Routine") {
                    isRoutineGeneratorPresented = true
                }
            }

            Button {
                isTemplateEditorPresented = true
            } label: {
                headerIcon(systemName: "plus")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add routine")
        }
    }

    @ViewBuilder
    private var routineContent: some View {
        if viewModel.isLoading && viewModel.templates.isEmpty {
            loadingState(title: "Loading routines")
        } else if viewModel.templates.isEmpty {
            if let errorMessage = viewModel.errorMessage {
                errorState(message: errorMessage)
            } else {
                emptyState(
                    title: "No routines yet",
                    subtitle: "Create one with the plus button."
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if let errorMessage = viewModel.errorMessage {
                    errorBanner(message: errorMessage)
                }

                routineGrid
            }
        }
    }

    private var routineGrid: some View {
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
                .accessibilityHint("Opens routine details")
                .contextMenu {
                    Button {
                        Task {
                            await viewModel.startWorkout(routineID: template.id)
                        }
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                    }
                }
            }
        }
    }

    private var workoutHeader: some View {
        HStack(spacing: 12) {
            Text("Workout")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 12)

            Button(action: {}) {
                headerIcon(systemName: "ellipsis")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Workout options")
        }
    }

    @ViewBuilder
    private var workoutContent: some View {
        if viewModel.isLoading && viewModel.sessions.isEmpty {
            loadingState(title: "Loading workouts")
        } else if viewModel.sessions.isEmpty {
            if let errorMessage = viewModel.errorMessage {
                errorState(message: errorMessage)
            } else {
                emptyState(
                    title: "No workouts yet",
                    subtitle: "Completed sessions will appear here."
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if let errorMessage = viewModel.errorMessage {
                    errorBanner(message: errorMessage)
                }

                workoutGrid
            }
        }
    }

    private var workoutGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 14, alignment: .top)
            ],
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(viewModel.sessions) { session in
                Button {
                    selectedSession = session
                } label: {
                    WorkoutSessionCard(session: session)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(session.title), \(session.date.formatted(date: .abbreviated, time: .omitted))")
                .accessibilityHint("Opens workout details")
            }
        }
    }

    private func loadingState(title: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.textPrimary)

            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(subtitle)
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

private struct FitnessSectionBar: View {
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

private struct WorkoutSessionCard: View {
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

#Preview {
    FitnessView()
        .environmentObject(UnifiedDataModel(autoStart: false))
}
