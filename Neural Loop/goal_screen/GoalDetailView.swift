import SwiftUI

struct GoalDetailView: View {
    let lifeAreaName: String
    let goal: Goals
    let tasks: [Tasks]
    @State private var tasksMapping: [Int64: Tasks] = [:]
    
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
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray5))
                                .frame(width: 56, height: 56)

                            Image(systemName: goal.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(goal.title)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text(goalDateText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

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
                    NavigationLink{
                        roadmapView()
                        
                    } label: {
                        HStack{
                            Text("Sub Goals")
                                .font(.headline)
                                .padding(.horizontal)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.secondary)
                        }
                    }
                
                    
                    VStack(spacing: 12) {
                        
                        ForEach(getSubGoals(), id: \.id) { goal in
                            goalRow(goal)
                        }
                    }
                    .padding(.horizontal)
                }

                // Todo Section
                VStack(alignment: .leading, spacing: 16) {
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

                    VStack(spacing: 12) {
                        ForEach(tasks) { task in
                            taskView(task: task)
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
                print(task.id!)
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
