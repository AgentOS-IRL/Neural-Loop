import SwiftUI

struct GoalDetailView: View {
    let lifeAreaName: String
    let goal: Goals
    let tasks: [Tasks]
    @State private var tasksMapping: [Int64: Tasks] = [:]
    
    @State private var goalTracking: GoalsTracking? = nil
    
    @State private var taskDateBuckets: [DateBucket] = buildShortRangeDateBuckets()
    @State private var goalDateBuckets: [DateBucket] = buildLongRangeDateBuckets()
    @State private var subGoals: [Goals] = []
    @State private var subGoalMapping: [Int64: Goals] = [:]
    @State private var showAddTask = false
    @State private var initializationTiming: TaskTiming = .init(
        start: Date(),
        duration: 900
    )
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 16) {
                        iconTitle(icon: goal.icon, name: goal.title, size: 22, subText: goalDateText)

                        Spacer()
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                )
                .padding(.horizontal)
                
                // Sub Goals Section
                // Todo Section
                VStack(alignment: .leading, spacing: 16) {
                    
                    ProgressCard()
                    
                    HStack{
                        NavigationLink{
                            roadmapView()
                            
                        } label: {
                            HStack{
                                Text("Roadmap")
                                    .font(.headline)
                                    .padding(.horizontal)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        
                        NavigationLink {
                            AddEditGoal(lifeAreas: [], goal: nil, deadline: nil, parent_goal_id: goal.id!, fixed_lifearea: goal.lifearea_id, fixed_lifearea_name: lifeAreaName) {}
                        } label: {
                            Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .padding(8)
                        }
                    }
                
                    
                    VStack(spacing: 12) {
                        if subGoals.count == 0 {
                            Text("All subgoals are completed.").frame(maxWidth: .infinity, alignment: .center)
                        }
                        else{
                            ForEach(subGoals, id: \.id) { goal in
                                goalRow(goal)
                            }
                        }
                    }
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
                                    .font(.headline)
                                    .padding(.horizontal)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(.secondary)
                                
                            }
                        }
                        Spacer()
                        
                        NavigationLink {
                            AddEditTodoView(task: nil, goalId: goal.id!) { updatedTask in
                                Task {
                                    let db = DBManager.newInstance()
                                    let _ = try await db.addTask(updatedTask)
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .padding(8)
                        }
                    }

                    VStack(spacing: 12) {
                        if tasks.isEmpty {
                            // Empty State Card
                            VStack(spacing: 16) {
                                
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                
                                Text("Create tasks and habits")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Break your goal down into tasks and habits.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                NavigationLink {
                                    AddEditTodoView(task: nil) { updatedTask in
                                        // handle saved task
                                    }
                                } label: {
                                    Text("Create task")
                                        .font(.headline)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 10)
                                        .background(Color.secondary.opacity(0.15))
                                        .foregroundColor(.primary)
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                        }
                        else{
                            ForEach(tasks) { task in
                                taskView(task: task)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }.onAppear()
        {
            Task{
                await fetchSubGoals()
                setTasksDateBuckets()
                setGoalsDateBuclets()
            }
            for task in tasks {
                tasksMapping[task.id!] = task
//                print(task.id!)
            }
            
        }
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
                    Color.blue.opacity(0.9),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .blur(radius: 10)
                .offset(y: 6)


            // Gradient fill under the line
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.6),
                    Color.blue.opacity(0.15),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .mask(
                ChartShape()
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
            )

            // Main line
            ChartShape()
                .stroke(
                    Color.blue,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
        }
        .frame(width: 80, height: 60)
    }
    
    @ViewBuilder
    private func ProgressCard()-> some View {
        
        
            VStack(spacing: 20) {
                
                // Center graphic (choose ONE option below)
                chartGraphic
                // sfSymbolGraphic
                
                VStack(spacing: 8) {
                    Text("Measure your progress")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select the most accurate way to track your progress for this goal.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                NavigationLink{
                    SetGoalTracking(goalId: goal.id!, goalTracking: goalTracking ) { newGoalTracking in
                        goalTracking = newGoalTracking
                        
                    }
                
                    
                } label: {
                    Text("Select metric")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            )
            .padding()
            .onAppear {
                Task {
                    print("Fetching goal tracking")
                    do {
                        let db = DBManager.newInstance()
                        goalTracking = try await db.fetchGoalsTracking(forGoal: goal.id!)
                    }
                    catch {
                        // ignore
                        print("Error fetching goal tracking: \(error)")
                    }
                }
            }
        
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
        do {
            let db_manager = DBManager.newInstance()
            subGoals = try await db_manager.fecthGoalsForParentId(forParentId: goal.id!)
            
            for goal in subGoals{
                subGoalMapping[goal.id!] = goal
            }
        }
        catch {
            print("Error fetching tasks: \(error)")
        }
        
    }
    
    @ViewBuilder
    private func taskView(task: Tasks) -> some View {
        
        
        taskRowView(task: task, strikeThrough: task.is_completed)
        
        
    }
    
    
    
    func goalRow(_ goal: Goals) -> some View {
        HStack(spacing: 16) {

            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)

                Image(systemName: goal.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.gray)
            }

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(goal.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                HStack{
                    Text(
                        ((goal.start_date != nil)
                        ? goal.start_date!.formatted() : "") + " -"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    Text(
                        (goal.deadline != nil)
                        ? goal.deadline!.formatted() : "No deadline"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

            }
            Spacer()

        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    //        .onTapGesture {
    //            hydrateGoalDeadline = nil
    //            hydrateGoal = goal
    //            addGoalSheetID = UUID()
    //            showAddGoal = true
    //        }

    }


}
