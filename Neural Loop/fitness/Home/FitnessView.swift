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
        selectedSection = section
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
    private var sectionContent: some View {
        switch navigationModel.selectedSection {
        case .home:
            VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                fitnessHomeHero
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
        case .workout:
            VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                workoutHeader
                workoutContent
            }
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

private struct StrengthVolumeCard: View {
    let summary: FitnessAnalysisSummary
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("Total Volume")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if isLoading && !summary.hasStrengthData {
                loadingAnalysis
            } else {
                MuscleVolumeWheel(summary: summary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 340, alignment: .topLeading)
        .background {
            AnalysisCardBackground()
        }
    }

    private var loadingAnalysis: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.textPrimary)

            Text("Loading strength analysis")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
}

private struct MuscleVolumeWheel: View {
    let summary: FitnessAnalysisSummary

    private var muscleVolumes: [FitnessMuscleVolume] {
        summary.muscleVolumes
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                centerWheel
                    .frame(width: 166, height: 166)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                ForEach(Array(muscleVolumes.enumerated()), id: \.element.id) { index, muscle in
                    muscleLabel(muscle)
                        .position(position(for: index, in: proxy.size))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 250)
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }

    private var centerWheel: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(segmentColor(for: index))
                    .frame(width: 44, height: 18)
                    .offset(y: -58)
                    .rotationEffect(.degrees(Double(index) * 15))
            }

            Circle()
                .fill(AppTheme.textPrimary.opacity(0.05))
                .frame(width: 54, height: 54)
        }
        .opacity(summary.hasStrengthData ? 0.92 : 0.42)
    }

    private func segmentColor(for index: Int) -> Color {
        guard summary.totalVolume > 0 else {
            return AppTheme.textSecondary.opacity(0.16)
        }

        let activeCount = max(
            1,
            Int((summary.muscleVolumes.filter { $0.volume > 0 }.count * 24) / max(summary.muscleVolumes.count, 1))
        )

        if index < activeCount {
            return AppTheme.accentColor.opacity(0.42)
        }

        return AppTheme.textSecondary.opacity(0.16)
    }

    private func muscleLabel(_ muscle: FitnessMuscleVolume) -> some View {
        VStack(spacing: 2) {
            Text(volumeText(muscle.volume))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(muscle.name)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(width: 116)
        .accessibilityElement(children: .combine)
    }

    private func position(for index: Int, in size: CGSize) -> CGPoint {
        let fractional: CGPoint
        switch index {
        case 0: fractional = CGPoint(x: 0.50, y: 0.09)
        case 1: fractional = CGPoint(x: 0.78, y: 0.28)
        case 2: fractional = CGPoint(x: 0.78, y: 0.78)
        case 3: fractional = CGPoint(x: 0.22, y: 0.78)
        case 4: fractional = CGPoint(x: 0.50, y: 0.95)
        default: fractional = CGPoint(x: 0.22, y: 0.28)
        }

        return CGPoint(x: fractional.x * size.width, y: fractional.y * size.height)
    }

    private func volumeText(_ value: Double) -> String {
        let rounded = Int(value.rounded())

        if rounded >= 1000 {
            let thousands = Double(rounded) / 1000
            return "\(thousands.formatted(.number.precision(.fractionLength(1))))k kg"
        }

        return "\(rounded) kg"
    }
}

private struct StrengthProgressionCard: View {
    let summary: FitnessAnalysisSummary
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("Strength Progression")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if isLoading && summary.progressionPoints.isEmpty {
                ProgressView()
                    .tint(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 156)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 156)
            } else if summary.progressionPoints.isEmpty {
                emptyProgression
            } else {
                progressionChart
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .background {
            AnalysisCardBackground()
        }
    }

    private var emptyProgression: some View {
        ZStack {
            progressionSkeleton

            VStack(spacing: 8) {
                Text("No progression data")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("No strength activity recorded in the last 30 days.")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, minHeight: 156)
    }

    private var progressionSkeleton: some View {
        VStack(spacing: 18) {
            ForEach(0..<4, id: \.self) { row in
                HStack {
                    Capsule()
                        .fill(AppTheme.textSecondary.opacity(0.08))
                        .frame(width: row.isMultiple(of: 2) ? 96 : 170, height: 12)

                    Spacer()

                    Capsule()
                        .fill(AppTheme.textSecondary.opacity(0.08))
                        .frame(width: row.isMultiple(of: 2) ? 172 : 96, height: 12)
                }
            }
        }
    }

    private var progressionChart: some View {
        GeometryReader { proxy in
            let maxVolume = max(summary.progressionPoints.map(\.volume).max() ?? 1, 1)
            let barWidth = max((proxy.size.width - 36) / CGFloat(max(summary.progressionPoints.count, 1)), 5)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(summary.progressionPoints) { point in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(AppTheme.accentGradient)
                        .frame(
                            width: barWidth,
                            height: max(12, proxy.size.height * CGFloat(point.volume / maxVolume))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(height: 156)
        .accessibilityLabel("Strength progression chart")
    }
}

private struct AnalysisCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(AppTheme.cardGradient)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 12, y: 8)
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

private struct WorkoutDraftCard: View {
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
