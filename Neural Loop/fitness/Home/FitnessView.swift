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

private struct FitnessActivityPeriod {
    let startDate: Date
    let endDate: Date
    let calendar: Calendar

    static func last30Days(now: Date = Date()) -> FitnessActivityPeriod {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let endDate = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        return FitnessActivityPeriod(startDate: startDate, endDate: endDate, calendar: calendar)
    }

    var days: [Date] {
        var result: [Date] = []
        var current = startDate

        while calendar.compare(current, to: endDate, toGranularity: .day) != .orderedDescending {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return result
    }

    var monthStarts: [Date] {
        guard
            let periodStartMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate)),
            let periodEndMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: endDate))
        else {
            return []
        }

        var result: [Date] = []
        var current = periodStartMonth

        while calendar.compare(current, to: periodEndMonth, toGranularity: .month) != .orderedDescending {
            result.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }

        if result.count == 1,
           let previousMonth = calendar.date(byAdding: .month, value: -1, to: result[0]) {
            result.insert(previousMonth, at: 0)
        }

        return Array(result.suffix(2))
    }

    func contains(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return calendar.compare(day, to: startDate, toGranularity: .day) != .orderedAscending &&
            calendar.compare(day, to: endDate, toGranularity: .day) != .orderedDescending
    }
}

private struct FitnessActivityCalendarCard: View {
    let sessions: [WorkoutSessionSummary]

    var body: some View {
        let period = FitnessActivityPeriod.last30Days()
        let countsByDay = activityCounts(in: period)

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 22) {
                ForEach(period.monthStarts, id: \.self) { monthStart in
                    FitnessActivityMonthGrid(
                        monthStart: monthStart,
                        period: period,
                        activityCountsByDay: countsByDay
                    )
                }
            }

            HStack(spacing: 18) {
                legendItem(color: Color(red: 0.60, green: 0.86, blue: 0.28), title: "1 activity")
                legendItem(color: Color(red: 0.30, green: 0.74, blue: 0.50), title: "2 activities")
                legendItem(color: Color(red: 0.00, green: 0.66, blue: 0.72), title: "3+ activities")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 238, alignment: .leading)
        .background {
            AnalysisCardBackground()
        }
    }

    private func activityCounts(in period: FitnessActivityPeriod) -> [Date: Int] {
        sessions.reduce(into: [:]) { result, session in
            guard period.contains(session.date) else { return }
            let day = period.calendar.startOfDay(for: session.date)
            result[day, default: 0] += 1
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct FitnessActivityMonthGrid: View {
    let monthStart: Date
    let period: FitnessActivityPeriod
    let activityCountsByDay: [Date: Int]
    private static let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthStart.formatted(.dateTime.month(.abbreviated).year()))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.42))
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarCells) { cell in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color(for: cell))
                        .frame(height: 11)
                        .overlay {
                            if cell.isToday {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(Color.blue.opacity(0.86), lineWidth: 1.5)
                            }
                        }
                        .opacity(cell.date == nil ? 0 : 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarCells: [FitnessActivityCalendarCell] {
        let calendar = period.calendar
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let leadingBlanks = leadingBlankCount(for: monthStart, calendar: calendar)
        var cells = (0..<leadingBlanks).map { index in
            FitnessActivityCalendarCell(id: "blank-\(index)", date: nil, count: 0, isInPeriod: false, isToday: false)
        }

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let dateKey = calendar.startOfDay(for: date)
            cells.append(
                FitnessActivityCalendarCell(
                    id: dateKey.timeIntervalSince1970.description,
                    date: dateKey,
                    count: activityCountsByDay[dateKey, default: 0],
                    isInPeriod: period.contains(dateKey),
                    isToday: calendar.isDateInToday(dateKey)
                )
            )
        }

        while cells.count % 7 != 0 {
            cells.append(
                FitnessActivityCalendarCell(
                    id: "trailing-\(cells.count)",
                    date: nil,
                    count: 0,
                    isInPeriod: false,
                    isToday: false
                )
            )
        }

        return cells
    }

    private func leadingBlankCount(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func color(for cell: FitnessActivityCalendarCell) -> Color {
        guard cell.date != nil else { return .clear }

        guard cell.isInPeriod else {
            return AppTheme.textSecondary.opacity(0.06)
        }

        switch cell.count {
        case 1:
            return Color(red: 0.60, green: 0.86, blue: 0.28)
        case 2:
            return Color(red: 0.30, green: 0.74, blue: 0.50)
        case 3...:
            return Color(red: 0.00, green: 0.66, blue: 0.72)
        default:
            return AppTheme.textSecondary.opacity(0.14)
        }
    }
}

private struct FitnessActivityCalendarCell: Identifiable {
    let id: String
    let date: Date?
    let count: Int
    let isInPeriod: Bool
    let isToday: Bool
}

private struct FitnessActivitySummaryCard: View {
    let sessions: [WorkoutSessionSummary]

    var body: some View {
        let period = FitnessActivityPeriod.last30Days()
        let series = dailyMinutes(in: period)
        let totalMinutes = series.reduce(0) { $0 + $1.minutes }

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("Activity Summary")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(formatMinutes(totalMinutes))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(periodText(period))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    activityLineChart(series: series)

                    HStack {
                        Text(shortDateText(period.startDate))
                        Spacer()
                        Text(shortDateText(midpointDate(in: period)))
                        Spacer()
                        Text(shortDateText(period.endDate))
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.45))

                        Text(formatMinutes(totalMinutes))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Spacer()

                    Text("\(max(3, series.map(\.minutes).max() ?? 0))")
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.42))

                    Spacer()

                    Text("0")
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.42))
                }
                .font(.system(.headline, design: .rounded, weight: .bold))
                .frame(width: 50, height: 170)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        .background {
            AnalysisCardBackground()
        }
    }

    private func dailyMinutes(in period: FitnessActivityPeriod) -> [FitnessActivityDailyMinutes] {
        let minutesByDay = sessions.reduce(into: [Date: Int]()) { result, session in
            guard period.contains(session.date), let durationMinutes = session.durationMinutes else { return }
            let day = period.calendar.startOfDay(for: session.date)
            result[day, default: 0] += durationMinutes
        }

        return period.days.map { day in
            FitnessActivityDailyMinutes(date: day, minutes: minutesByDay[day, default: 0])
        }
    }

    private func activityLineChart(series: [FitnessActivityDailyMinutes]) -> some View {
        GeometryReader { proxy in
            let maxMinutes = max(3, series.map(\.minutes).max() ?? 0)
            let points = chartPoints(for: series, in: proxy.size, maxMinutes: maxMinutes)

            ZStack {
                FitnessActivityDottedTicks()
                    .stroke(
                        AppTheme.textSecondary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 14])
                    )

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)

                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    Color(red: 1.0, green: 0.67, blue: 0.36),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )

                if let first = points.first {
                    Circle()
                        .fill(AppTheme.cardGradient)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .strokeBorder(Color(red: 1.0, green: 0.67, blue: 0.36), lineWidth: 4)
                        }
                        .position(first)
                }

                if let last = points.last {
                    Circle()
                        .fill(AppTheme.cardGradient)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .strokeBorder(Color(red: 1.0, green: 0.67, blue: 0.36), lineWidth: 5)
                        }
                        .shadow(color: Color(red: 1.0, green: 0.67, blue: 0.36).opacity(0.34), radius: 16, x: 0, y: 0)
                        .position(last)
                }
            }
        }
        .frame(height: 150)
    }

    private func chartPoints(
        for series: [FitnessActivityDailyMinutes],
        in size: CGSize,
        maxMinutes: Int
    ) -> [CGPoint] {
        guard !series.isEmpty else { return [] }

        let bottomInset: CGFloat = 18
        let topInset: CGFloat = 12
        let drawableHeight = max(size.height - topInset - bottomInset, 1)
        let denominator = max(series.count - 1, 1)

        return series.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(denominator) * size.width
            let ratio = CGFloat(value.minutes) / CGFloat(maxMinutes)
            let y = topInset + ((1 - ratio) * drawableHeight)
            return CGPoint(x: x, y: y)
        }
    }

    private func periodText(_ period: FitnessActivityPeriod) -> String {
        "\(shortDateText(period.startDate)) - \(shortDateText(period.endDate)) \(yearText(period.endDate))"
    }

    private func midpointDate(in period: FitnessActivityPeriod) -> Date {
        period.calendar.date(byAdding: .day, value: period.days.count / 2, to: period.startDate) ?? period.startDate
    }

    private func shortDateText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func yearText(_ date: Date) -> String {
        date.formatted(.dateTime.year())
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }

        return "\(minutes)m"
    }
}

private struct FitnessActivityDailyMinutes: Identifiable {
    let date: Date
    let minutes: Int

    var id: Date { date }
}

private struct FitnessActivityDottedTicks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.maxY - 18
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addLine(to: CGPoint(x: rect.maxX, y: y))
        return path
    }
}

private struct StrengthVolumeCard: View {
    let summary: FitnessAnalysisSummary
    let isLoading: Bool
    @State private var selectedMetric: MuscleWheelMetric = .totalVolume

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: selectedMetric.iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(selectedMetric.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Menu {
                    ForEach(MuscleWheelMetric.allCases) { metric in
                        Button {
                            selectedMetric = metric
                        } label: {
                            Label(metric.title, systemImage: metric == selectedMetric ? "checkmark" : metric.iconSystemName)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change analysis metric")
            }

            if isLoading && !summary.hasStrengthData {
                loadingAnalysis
            } else {
                MuscleVolumeWheel(
                    muscleVolumes: selectedMetric.muscleVolumes(from: summary),
                    valueFormatter: selectedMetric.valueText
                )
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

private enum MuscleWheelMetric: String, CaseIterable, Identifiable {
    case totalVolume
    case workoutFrequency

    var id: String { rawValue }

    var title: String {
        switch self {
        case .totalVolume: return "Total Volume"
        case .workoutFrequency: return "Workout Frequency"
        }
    }

    var iconSystemName: String {
        switch self {
        case .totalVolume: return "scalemass.fill"
        case .workoutFrequency: return "calendar.badge.clock"
        }
    }

    func muscleVolumes(from summary: FitnessAnalysisSummary) -> [FitnessMuscleVolume] {
        switch self {
        case .totalVolume: return summary.muscleVolumes
        case .workoutFrequency: return summary.muscleFrequencies
        }
    }

    func valueText(_ value: Double) -> String {
        switch self {
        case .totalVolume:
            let rounded = Int(value.rounded())

            if rounded >= 1000 {
                let thousands = Double(rounded) / 1000
                return "\(thousands.formatted(.number.precision(.fractionLength(1))))k kg"
            }

            return "\(rounded) kg"
        case .workoutFrequency:
            return "\(Int(value.rounded()))x"
        }
    }
}

private struct MuscleVolumeWheel: View {
    let muscleVolumes: [FitnessMuscleVolume]
    let valueFormatter: (Double) -> String
    private let ringCount = 4
    private let ringWidth: CGFloat = 10
    private let ringGap: CGFloat = 5
    private let innerRingRadius: CGFloat = 28
    private let sectorDegrees = 60.0
    private let sectorGapDegrees = 12.0

    private var maxMuscleVolume: Double {
        muscleVolumes.map(\.volume).max() ?? 0
    }

    private var hasData: Bool {
        maxMuscleVolume > 0
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
            ForEach(Array(muscleVolumes.enumerated()), id: \.element.id) { index, muscle in
                ForEach(0..<ringCount, id: \.self) { ringIndex in
                    let angles = angleRange(for: muscle, fallbackIndex: index)
                    let radius = radius(for: ringIndex)

                    MuscleVolumeWheelArc(
                        radius: radius,
                        startAngle: angles.start,
                        endAngle: angles.end
                    )
                    .stroke(
                        AppTheme.textSecondary.opacity(0.14),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )

                    if activeFraction(for: muscle, ringIndex: ringIndex) > 0 {
                        MuscleVolumeWheelArc(
                            radius: radius,
                            startAngle: angles.start,
                            endAngle: angles.end
                        )
                        .stroke(
                            AppTheme.accentColor.opacity(activeOpacity(for: muscle, ringIndex: ringIndex)),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                    }
                }
            }

            Circle()
                .fill(AppTheme.textPrimary.opacity(0.05))
                .frame(width: 54, height: 54)
        }
        .opacity(hasData ? 0.92 : 0.42)
    }

    private func radius(for ringIndex: Int) -> CGFloat {
        innerRingRadius + CGFloat(ringIndex) * (ringWidth + ringGap)
    }

    private func angleRange(
        for muscle: FitnessMuscleVolume,
        fallbackIndex: Int
    ) -> (start: Angle, end: Angle) {
        let center = sectorCenterAngle(for: muscle, fallbackIndex: fallbackIndex)
        let halfSpan = (sectorDegrees - sectorGapDegrees) / 2

        return (
            start: .degrees(center - halfSpan),
            end: .degrees(center + halfSpan)
        )
    }

    private func sectorCenterAngle(
        for muscle: FitnessMuscleVolume,
        fallbackIndex: Int
    ) -> Double {
        switch muscle.name {
        case "Chest": return -90
        case "Back": return -30
        case "Legs": return 30
        case "Shoulders": return 90
        case "Core": return 150
        case "Arms": return 210
        default: return -90 + Double(fallbackIndex) * sectorDegrees
        }
    }

    private func activeFraction(
        for muscle: FitnessMuscleVolume,
        ringIndex: Int
    ) -> Double {
        guard maxMuscleVolume > 0, muscle.volume > 0 else { return 0 }

        let ratio = min(max(muscle.volume / maxMuscleVolume, 0), 1)
        let lowerBound = Double(ringIndex) / Double(ringCount)
        let upperBound = Double(ringIndex + 1) / Double(ringCount)

        guard ratio > lowerBound else { return 0 }
        return min((ratio - lowerBound) / (upperBound - lowerBound), 1)
    }

    private func activeOpacity(
        for muscle: FitnessMuscleVolume,
        ringIndex: Int
    ) -> Double {
        0.22 + (activeFraction(for: muscle, ringIndex: ringIndex) * 0.42)
    }

    private func muscleLabel(_ muscle: FitnessMuscleVolume) -> some View {
        VStack(spacing: 2) {
            Text(valueFormatter(muscle.volume))
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
}

private struct MuscleVolumeWheelArc: Shape {
    let radius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
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
