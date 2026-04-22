import SwiftUI
import Charts



enum ProgressRange: String, CaseIterable, Identifiable {
    case thisWeek = "This week"
    case thisMonth = "This month"
    case thisQuarter = "This quarter"
    case thisYear = "This year"
    case last4Weeks = "Last 4 weeks"
    case last12Months = "Last 12 months"
    case last24Months = "Last 24 months"
    var id: Self { self }

    var systemImage: String {
        switch self {
        case .thisWeek: return "calendar"
        case .thisMonth: return "calendar.circle"
        case .thisQuarter: return "calendar.badge.clock"
        case .thisYear: return "calendar.badge.plus"
        case .last4Weeks: return "clock"
        case .last12Months: return "clock.arrow.circlepath"
        case .last24Months: return "clock.arrow.2.circlepath"
        }
    }
}

struct ProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct GoalDetailView: View {
    let lifeAreaName: String
    let goal: Goals
    let tasks: [Tasks]
    let habits: [Habits]
    @State private var tasksMapping: [Int64: Tasks] = [:]
    
    @State private var goalTracking: GoalsTracking = GoalsTracking.empty
    
    @State private var taskDateBuckets: [DateBucket] = buildShortRangeDateBuckets()
    @State private var goalDateBuckets: [DateBucket] = buildLongRangeDateBuckets()
    @State private var subGoals: [Goals] = []
    @State private var subGoalMapping: [Int64: Goals] = [:]
    @State private var showAddTask = false
    @State private var initializationTiming: TaskTiming = .init(
        start: Date(),
        duration: 900
    )
    
    @State private var progressSnapshot: GoalProgressSnapshot = .empty
    
    @State private var progressRange : ProgressRange = .thisWeek
    
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: UnifiedDataModel
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 16) {
                            iconTitle(icon: goal.icon, name: goal.title, size: 28, subText: goalDateText)
                            
                            Spacer()
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous)
                            .fill(AppTheme.heroGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.heroCornerRadius, style: .continuous)
                            .stroke(AppTheme.borderGradient, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Progress Section
                    ProgressCard()

                    // Sub Goals Section
                    VStack(alignment: .leading, spacing: 16) {
                        
                        HStack{
                            NavigationLink{
                                roadmapView()
                                
                            } label: {
                                HStack{
                                    Text("Roadmap")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                            
                            NavigationLink {
                                AddEditGoal(lifeAreas: [], goal: nil, deadline: nil, parent_goal_id: goal.id!, fixed_lifearea: goal.lifearea_id, fixed_lifearea_name: lifeAreaName) {}
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal)
                        
                        
                        VStack(spacing: 0) {
                            if subGoals.count == 0 {
                                Text("All subgoals are completed.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            }
                            else{
                                ForEach(subGoals) { subGoal in
                                    NavigationLink {
                                        GoalDetailView(
                                            lifeAreaName: lifeAreaName,
                                            goal: subGoal,
                                            tasks: model.getTasks(goalId: subGoal.id!),
                                            habits: model.getHabits(goalId: subGoal.id!)
                                        )
                                    } label: {
                                        goalRow(subGoal)
                                    }
                                    
                                    if subGoal.id != subGoals.last?.id {
                                        Divider()
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                        }
                        .background(AppTheme.cardGradient)
                        .cornerRadius(AppTheme.Metrics.cardCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                                .stroke(AppTheme.borderGradient, lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    
                    // Todo Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            NavigationLink{
                                upcomingTasks()
                                
                            } label: {
                                HStack{
                                    Text("Todo")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundColor(AppTheme.textSecondary)
                                    
                                }
                            }
                            Spacer()
                            
                            NavigationLink {
                                AddEditTodoView(task: nil, goalId: goal.id!) { updatedTask in
                                    Task {
                                        await model.saveTask(updatedTask)
                                    }
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            if tasks.isEmpty {
                                // Empty State Card
                                VStack(spacing: 16) {
                                    
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 32))
                                        .foregroundStyle(AppTheme.accentGradient)
                                    
                                    Text("Create tasks")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                    
                                    Text("Break your goal down into tasks.")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                    
                                    NavigationLink {
                                        AddEditTodoView(task: nil) { updatedTask in
                                            // handle saved task
                                        }
                                    } label: {
                                        Text("Create task")
                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 10)
                                            .background(AppTheme.accentGradient)
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .background(AppTheme.cardGradient)
                                .cornerRadius(AppTheme.Metrics.cardCornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                                )
                            }
                            else{
                                ForEach(tasks) { task in
                                    taskView(task: task)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Habits Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            NavigationLink {
                                habitsView()
                            } label: {
                                HStack {
                                    Text("Habits")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            NavigationLink {
                                // Replace with AddEditHabitView when available
                                Text("Add Habit")
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            if habits.isEmpty {
                                // Empty state scaffold
                                VStack(spacing: 16) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 32))
                                        .foregroundStyle(AppTheme.accentGradient)
                                    
                                    Text("Create habits")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                    
                                    Text("Build habits to make progress consistently.")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                    
                                    NavigationLink {
                                        Text("Add Habit")
                                    } label: {
                                        Text("Create habit")
                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 10)
                                            .background(AppTheme.accentGradient)
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .background(AppTheme.cardGradient)
                                .cornerRadius(AppTheme.Metrics.cardCornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                                )
                            }
                            else{
                                ForEach(habits) { habit in
                                    if let progress = model.currentHabitProgressMap[habit.id!]{
                                        HabitCardView(
                                            habit: habit,
                                            progress: progress,
                                            onIncrement: {
                                                Task {
                                                    await model.incrementHabit(habit, value:1)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .onAppear()
        {
            for task in tasks {
                tasksMapping[task.id!] = task
            }
            Task{
                await fetchSubGoals()
                setTasksDateBuckets()
                setGoalsDateBuclets()
                await setGoalTrackingRecords()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: SAFE_AREA_INSET)
        }
    }
    private func setGoalTrackingRecords() async {
        goalTracking = await model.fetchGoalsTracking(forGoal: goal.id!)

        if goalTracking.isEmpty {
            progressSnapshot = .empty
            return
        }

        var customRecords: [GoalsTrackingRecord] = []
        if goalTracking.type == .custom,
           let trackingId = goalTracking.id {
            customRecords = await model.fetchGoalsTrackingRecords(
                forTracking: trackingId,
                type: goalTracking.type
            )
        }

        progressSnapshot = makeProgressSnapshot(
            tracking: goalTracking,
            customRecords: customRecords
        )
    }

    private func makeProgressSnapshot(
        tracking: GoalsTracking,
        customRecords: [GoalsTrackingRecord] = []
    ) -> GoalProgressSnapshot {
        GoalProgressCalculator.snapshot(
            goalId: goal.id!,
            tracking: tracking,
            tasks: Array(tasksMapping.values),
            subGoals: subGoals,
            customRecords: customRecords
        )
    }
    
    struct ChartShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.7))
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + 6),
                control1: CGPoint(x: rect.midX * 0.9, y: rect.maxY),
                control2: CGPoint(x: rect.midX * 1.1, y: rect.minY)
            )
            
            return path
        }
    }

    private var chartGraphic: some View {
        ZStack {
//            // Strong outer glow
            ChartShape()
                .stroke(
                    AppTheme.accentGradient,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .opacity(0.9)
                .blur(radius: 10)
                .offset(y: 6)


            // Gradient fill under the line
            AppTheme.accentGradient
                .opacity(0.3)
                .mask(
                    ChartShape()
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                )

            // Main line
            ChartShape()
                .stroke(
                    AppTheme.accentGradient,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
        }
        .frame(width: 80, height: 60)
    }
    
    @ViewBuilder
    private func ProgressCard() -> some View {
        if goalTracking.isEmpty {
            EmptyProgressCard()
        } else {
            ProgressChartCard(snapshot: progressSnapshot)
        }
    }
    
    @ViewBuilder
    private func ProgressChartCard(snapshot: GoalProgressSnapshot) -> some View {

        let points = buildProgressPoints(
            range: progressRange,
            records: snapshot.chartRecords
        )

        let totalProgress = snapshot.current
        let progressPercent = snapshot.percentage
        let label = snapshot.label

        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack {
                
                    Text("Target")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    
                    Spacer()
                    // 3 dot context menu
                    Menu {
                        NavigationLink{
                        
                            // Edit goal tracking
                            SetGoalTracking(goalId: goal.id!, goalTracking: goalTracking ) { newGoalTracking in
                                goalTracking = newGoalTracking
                                Task {
                                    await setGoalTrackingRecords()
                                }
                            }
                        } label: {
                            Label("Edit tracking", systemImage: "pencil")
                        }
                        Divider()
                        
                        if goalTracking.type == .custom {
                            ForEach(ProgressRange.allCases) { range in
                                Button {
                                    progressRange = range
                                } label: {
                                    Label(range.rawValue, systemImage: range.systemImage)
                                }
                                .buttonStyle(.bordered)
                                .tint(progressRange == range ? .blue : .gray)
                            }
                        }
                        
                        
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(8)
                    }
                
            }
            HStack {
                    
                    
                    Text("\(formattedProgressValue(totalProgress)) \(label)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    
                    Spacer()
                    
                    Text("\(Int(progressPercent * 100))%")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.accentGradient)
                
            }
            
            
            // Chart
            if goalTracking.type == .custom {
                
                Chart(points) {
                    LineMark(
                        x: .value("Date", $0.date),
                        y: .value("Progress", $0.value)
                    )
                    .foregroundStyle(AppTheme.accentGradient)
                    .lineStyle(.init(lineWidth: 3))

                    PointMark(
                        x: .value("Date", $0.date),
                        y: .value("Progress", $0.value)
                    )
                    .foregroundStyle(AppTheme.accentGradient)
                    .symbolSize(80)
                }
                .chartYScale(domain: 0...max(snapshot.target, snapshot.current, 1))
                .frame(height: 180)
            }
            else{
                FancyProgressBar(totalProgress: totalProgress, targetValue: snapshot.target)
            }
            
            if goalTracking.type == .custom {
                // CTA
                NavigationLink{
                
                    // Edit goal tracking
                    AddGoalProgressView( goalTracking: goalTracking ) {
                        Task {
                            await setGoalTrackingRecords()
                        }
                    }
                }  label: {
                    Text("Update progress")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(AppTheme.accentGradient)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.borderGradient, lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func EmptyProgressCard()-> some View {
        
            VStack(spacing: 20) {
                
                // Center graphic (choose ONE option below)
                chartGraphic
                // sfSymbolGraphic
                
                VStack(spacing: 8) {
                    Text("Measure your progress")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("Select the most accurate way to track your progress for this goal.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                NavigationLink{
                    SetGoalTracking(goalId: goal.id!, goalTracking: goalTracking ) { newGoalTracking in
                        goalTracking = newGoalTracking
                        Task {
                            await setGoalTrackingRecords()
                        }
                    }
                
                    
                } label: {
                    Text("Select metric")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(AppTheme.accentGradient)
                        )
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .stroke(AppTheme.borderGradient, lineWidth: 1)
            )
            .padding(.horizontal)
    }
    
    @ViewBuilder
    private func upcomingTasks() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(taskDateBuckets) { bucket in
                    VStack(alignment: .leading, spacing: 8) {
                        
                        // Section header (Today, Tomorrow, Thu 8 Jan, etc.)
                        bucket.title
                        
                        // Tasks for this date bucket
                        ForEach(bucket.ids, id: \.self) { taskId in
                            if let task = tasksMapping[taskId] {
                                taskView(task: task)
                            }
                        }
                        
                        // Add task row
                        addTask(initialTiming: .init(start: Calendar.current.date(
                            bySettingHour: 9,
                            minute: 0,
                            second: 0,
                            of: bucket.start
                        )!, duration: 900))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }
    
    @ViewBuilder
    private func roadmapView() -> some View {
        VStack {
            Spacer()
            ScrollView {
                VStack {
                    ForEach(goalDateBuckets) { bucket in
                        VStack(alignment: .leading, spacing: 8) {

                            bucket.title
                            // Goals for this date bucket
                            ForEach(bucket.ids, id: \.self) { goalId in
                                if let goal = subGoalMapping[goalId] {
                                    Text(goal.title)
                                }
                            }

                            Spacer()

                            HStack(spacing: 16) {

                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            Color.gray.opacity(0.7),
                                            style: StrokeStyle(
                                                lineWidth: 2,
                                                lineCap: .round,  // makes dashes look like dots
                                                dash: [1, 4]  // dot length, gap
                                            )
                                        )
                                        .frame(width: 28, height: 28)

                                    Image(systemName: "scope")  // looks closer to your screenshot than "target"
                                        .font(
                                            .system(size: 14, weight: .semibold)
                                        )
                                        .foregroundColor(.gray)
                                }

                                Text("Add Goal")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
            }
        }
    }
    
    
    @ViewBuilder
    private func addTask(initialTiming: TaskTiming) -> some View {
        addTaskRowView().onTapGesture {
            initializationTiming = initialTiming
            showAddTask = true
        }
    }
    
    private func setGoalsDateBuclets(){
//        goalDateBuckets = re
        
    }
    
    private func setTasksDateBuckets() {
        taskDateBuckets = rebuildDateBuckets(tasks:tasks)
    }
    
    private func getSubGoals() -> [Goals]{
        return subGoals
    }
    
    private var goalDateText: String {
        let start =  goal.start_date?.formatted() ?? ""
        let end = goal.deadline?.formatted() ?? "No deadline"
        return start.isEmpty ? end : "\(start) – \(end)"
    }
    
    private func fetchSubGoals() async -> Void {
        subGoals = model.getSubGoals(forPatentId: goal.id!)
        for goal in subGoals{
            subGoalMapping[goal.id!] = goal
        }
    }
    
    @ViewBuilder
    private func taskView(task: Tasks) -> some View {
        
        
        taskRowView(task: task, strikeThrough: task.is_completed)
        
        
    }
    
    
    
    func goalRow(_ goal: Goals) -> some View {
        HStack(spacing: 16) {
            // Icon container
            iconTitle(icon: goal.icon, name: goal.title, size: 28)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
    
    private func buildProgressPoints(
        range: ProgressRange,
        records: [Date: Double]
    ) -> [ProgressPoint] {

        let calendar = Calendar.current
        let now = Date()

        let startDate: Date
        let step: Calendar.Component

        switch range {
        case .thisWeek:
            startDate = calendar.startOfWeek(for: now)
            step = .day

        case .thisMonth:
            startDate = calendar.startOfMonth(for: now)
            step = .day

        case .thisQuarter:
            startDate = calendar.startOfQuarter(for: now)
            step = .weekOfYear

        case .thisYear:
            startDate = calendar.startOfYear(for: now)
            step = .month

        case .last4Weeks:
            startDate = calendar.date(byAdding: .weekOfYear, value: -4, to: now)!
            step = .weekOfYear

        case .last12Months:
            startDate = calendar.date(byAdding: .month, value: -12, to: now)!
            step = .month

        case .last24Months:
            startDate = calendar.date(byAdding: .month, value: -24, to: now)!
            step = .month
        }

        var buckets: [Date: Double] = [:]

        for (date, value) in records where date >= startDate {
            let bucketDate: Date

            switch step {
            case .day:
                bucketDate = calendar.startOfDay(for: date)
            case .weekOfYear:
                bucketDate = calendar.startOfWeek(for: date)
            case .month:
                bucketDate = calendar.startOfMonth(for: date)
            default:
                bucketDate = date
            }

            buckets[bucketDate, default: 0] += value
        }

        return buckets
            .sorted(by: { $0.key < $1.key })
            .map { ProgressPoint(date: $0.key, value: $0.value) }
    }

    private func formattedProgressValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

}

// Habits list view builder
@ViewBuilder
private func habitsView() -> some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Habits")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            // Placeholder list – wire to real habits later
            VStack(spacing: 12) {
                Text("Habit list goes here")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
}
