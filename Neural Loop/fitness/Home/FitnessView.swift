import Combine
import SwiftUI

enum FitnessSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case workout = "Workout"

    var id: String { rawValue }
}

@MainActor
final class FitnessNavigationModel: ObservableObject {
    @Published var selectedSection: FitnessSection = .home

    func select(_ section: FitnessSection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedSection = section
        }
    }
}

struct FitnessView: View {
    @EnvironmentObject private var model: UnifiedDataModel
    @StateObject private var viewModel = FitnessViewModel()
    @StateObject private var navigationModel = FitnessNavigationModel()
    @ObservedObject private var deepLink = DeepLinkManager.shared
    private let bottomInsetHeight: CGFloat = 88
    @State private var isTemplateEditorPresented = false
    @State private var isRoutineGeneratorPresented = false
    @State private var selectedTemplate: WorkoutTemplateSummary?
    @State private var selectedSession: WorkoutSessionSummary?
    @State private var sessionToDelete: WorkoutSessionSummary?
    @State private var showDeleteConfirmation = false
    @State private var generatedRoutine: WorkoutRoutineGenerationPayload?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                TabView(selection: $navigationModel.selectedSection) {
                    ScrollView(showsIndicators: false) {
                        homeContent
                            .padding(.horizontal, AppTheme.Metrics.screenPadding)
                            .padding(.top, 16)
                            .padding(.bottom, bottomInsetHeight + 20)
                    }
                    .tag(FitnessSection.home)

                    ScrollView(showsIndicators: false) {
                        workoutTabContent
                            .padding(.horizontal, AppTheme.Metrics.screenPadding)
                            .padding(.top, 16)
                            .padding(.bottom, bottomInsetHeight + 20)
                    }
                    .tag(FitnessSection.workout)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
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
            .onChange(of: deepLink.pendingDeepLink) { _, newValue in
                guard newValue == .fitnessActiveWorkout else { return }
                viewModel.resumeActiveWorkout()
                deepLink.clearPendingNavigation()
            }
            .onAppear {
                // Handle deep link that arrived before the view appeared
                if deepLink.pendingDeepLink == .fitnessActiveWorkout {
                    viewModel.resumeActiveWorkout()
                    deepLink.clearPendingNavigation()
                }
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
            .confirmationDialog(
                "Delete Workout?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteSelectedSession()
                    }
                }

                Button("Cancel", role: .cancel) {
                    sessionToDelete = nil
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .fullScreenCover(item: $viewModel.activeViewModel, onDismiss: {
                viewModel.clearActiveDraft()
            }) { activeVM in
                ActiveWorkoutView(viewModel: activeVM)
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
    private var homeContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
            fitnessHomeHero
            FitnessActivityCalendarCard(sessions: viewModel.sessions)
            FitnessActivitySummaryCard(sessions: viewModel.sessions)
            StrengthVolumeCard(
                summary: viewModel.analysisSummary,
                isLoading: viewModel.isLoading
            )
            StrengthProgressionCard(
                summary: viewModel.analysisSummary,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.templates.isEmpty && viewModel.sessions.isEmpty ? viewModel.errorMessage : nil
            )
            routineHeader
            routineContent
        }
    }

    @ViewBuilder
    private var workoutTabContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
            workoutHeader
            workoutContent
        }
    }

    private var fitnessHomeHero: some View {
        VStack(spacing: 4) {
            Text("Fitness")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Last 30 days")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var routineHeader: some View {
        HStack(spacing: 12) {
            Text("Routines")
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
        if viewModel.isLoading && viewModel.sessions.isEmpty && viewModel.activeDraftSummary == nil {
            loadingState(title: "Loading workouts")
        } else if viewModel.sessions.isEmpty && viewModel.activeDraftSummary == nil {
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

                if let draftSummary = viewModel.activeDraftSummary {
                    WorkoutDraftCard(
                        summary: draftSummary,
                        resumeAction: {
                            Task {
                                await viewModel.startWorkout(routineID: draftSummary.routineID)
                            }
                        },
                        deleteAction: {
                            Task {
                                _ = await viewModel.deleteActiveDraft(routineID: draftSummary.routineID)
                            }
                        }
                    )
                }

                if viewModel.sessions.isEmpty {
                    if viewModel.activeDraftSummary == nil && !viewModel.isLoading {
                        emptyState(
                            title: "No workouts yet",
                            subtitle: "Completed sessions will appear here."
                        )
                    }
                } else {
                    workoutGrid
                }
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
                .contextMenu {
                    Button(role: .destructive) {
                        sessionToDelete = session
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    @MainActor
    private func deleteSelectedSession() async {
        guard let session = sessionToDelete else {
            showDeleteConfirmation = false
            return
        }

        let deleted = await viewModel.deleteSession(id: session.id)
        if deleted, selectedSession?.id == session.id {
            selectedSession = nil
        }
        sessionToDelete = nil
        showDeleteConfirmation = false
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


