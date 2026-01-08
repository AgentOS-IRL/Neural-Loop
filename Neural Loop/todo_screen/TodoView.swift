//
//  TodoView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026
//

//
//  TodoView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026
//

import SwiftUI
import RRuleKit
import SwiftData

func nextOccurrence(
    of rule: Calendar.RecurrenceRule,
    after now: Date = .now
) -> Date? {
    print("In nextOccurrence, Interval: \(rule.interval)")

    for date in rule.recurrences(of: now) {
        if date > now {
            return date
        }
    }
    return nil
}

func rrule_to_string(rule: Calendar.RecurrenceRule) -> String{
    let formatter = RecurrenceRuleRFC5545FormatStyle(calendar: .current)
    let rruleString = formatter.format(rule)
    
    return rruleString
}

func parse_rrule(rruleString: String) throws -> Calendar.RecurrenceRule {
    let parser = RecurrenceRuleRFC5545FormatStyle(calendar: .current)
    
    return try parser.parse(rruleString)
}



struct TodoView: View {
    enum ViewMode {
        case menu
        case today
        case upcoming
        case all
        case inbox
        case completed
    }
    
    var filteredTasks: [Tasks] {
        guard !searchText.isEmpty else { return tasks }
        return tasks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    @State private var tasks: [Tasks] = []
    @State private var tasksMapping: [Int64: Tasks] = [:]
    @State private var showAddTask = false
    @State private var viewMode: ViewMode = .menu
    @State private var error: String?
    @State private var dateBuckets: [DateBucket] = buildDateBuckets()
    @State private var searchText: String = ""
    @State private var selectedTaskForEdit: Tasks? = nil
    
    @State private var initializationTiming: TaskTiming = .init(
        start: Date(),
        duration: 900
    )
    
    
    @Environment(\.modelContext) private var context

    
    @ViewBuilder
    private func upcomingTasks() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(getUpcomingBucket()) { bucket in
                    VStack(alignment: .leading, spacing: 8) {
                        
                        // Section header (Today, Tomorrow, Thu 8 Jan, etc.)
                        bucket.title
                        
                        // Tasks for this date bucket
                        ForEach(bucket.taskIds, id: \.self) { taskId in
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
    private func taskView(task: Tasks, checkIfCompleted: Bool = false) -> some View {
        let strikeThrough =
                checkIfCompleted &&
                completedTasks(on: .now, context: context).contains(task.id!)

        
        HStack(alignment: .top, spacing: 12) {
            
            // Checkbox placeholder
            Circle()
                .stroke(Color.secondary, lineWidth: 2)
                .frame(width: 22, height: 22)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(strikeThrough)
                    .foregroundColor(.primary)
                
                
                let start = task.start_date!
                let duration = task.duration!
                let end = start.addingTimeInterval(duration)

                Text(verbatim:
                    "\(start.formatted(date: .omitted, time: .shortened)) – " +
                    "\(end.formatted(date: .omitted, time: .shortened))"
                )
                .font(.caption)
                .foregroundColor(.secondary)
                
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // future tap support
        .onTapGesture {
            selectedTaskForEdit = task
        }
        
    }
    
    @ViewBuilder
    private func addTask(initialTiming: TaskTiming) -> some View {
        HStack(spacing: 12) {
            Circle()
                .stroke(
                    style: StrokeStyle(lineWidth: 2, dash: [4])
                )
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
            
            Text("Add task")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, 8).onTapGesture {
            initializationTiming = initialTiming
            showAddTask = true
        }
    }
    
    private func getInboxBucket() -> DateBucket {
        dateBuckets.first(where: { $0.type == .inbox })!
    }
    private func getCompletedBucket() -> DateBucket {
        dateBuckets.first(where: { $0.type == .completed })!
    }

    @ViewBuilder
    private func inboxView() -> some View {
        let inboxBucket = getInboxBucket()

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                addTask(initialTiming: .init(start: .now, duration: 900))

                ForEach(inboxBucket.taskIds, id: \.self) { taskId in
                    if let task = tasksMapping[taskId] {
                        taskView(task: task)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }

    @ViewBuilder
    private func completedView() -> some View {
        let completedBucket = getCompletedBucket()

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(completedBucket.taskIds, id: \.self) { taskId in
                    if let task = tasksMapping[taskId] {
                        taskView(task: task)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }
    
    private func getUpcomingBucket() -> [DateBucket] {
        dateBuckets.filter({ $0.type == .upcoming})
    }
    
    private func getTodaysBucket() -> DateBucket {
        dateBuckets.first(where: { $0.type == .today })!
    }
    
    @ViewBuilder
    private func todayTasks() -> some View {
        let todayBucket = getTodaysBucket()
        
    
        let morningTasks = todayBucket.taskIds.compactMap { tasksMapping[$0] }
            .filter {
                guard let start = $0.start_date else { return false }
                return Calendar.current.component(.hour, from: start) < 12
            }
        
        let afternoonTasks = todayBucket.taskIds.compactMap { tasksMapping[$0] }
            .filter {
                guard let start = $0.start_date else { return false }
                let hour = Calendar.current.component(.hour, from: start)
                return hour >= 12 && hour < 18
            }
        
        let eveningTasks = todayBucket.taskIds.compactMap { tasksMapping[$0] }
            .filter {
                guard let start = $0.start_date else { return false }
                return Calendar.current.component(.hour, from: start) >= 18
            }
        
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                
                sectionView(title: "Morning", tasks: morningTasks, initialTiming: .init(start: Calendar.current.date(
                    bySettingHour: 8,
                    minute: 0,
                    second: 0,
                    of: Date()
                )!, duration: 900))
                sectionView(title: "Afternoon", tasks: afternoonTasks, initialTiming: .init(start: Calendar.current.date(
                    bySettingHour: 12,
                    minute: 0,
                    second: 0,
                    of: Date()
                )!, duration: 900))
                sectionView(title: "Evening", tasks: eveningTasks, initialTiming: .init(start: Calendar.current.date(
                    bySettingHour: 18,
                    minute: 0,
                    second: 0,
                    of: Date()
                )!, duration: 900))
                
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }
    
    @ViewBuilder
    private func sectionView(title: String, tasks: [Tasks], initialTiming: TaskTiming) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            
            ForEach(tasks, id: \.id) { task in
                taskView(task: task, checkIfCompleted: true)
            }
            // Add task row
            addTask(initialTiming:initialTiming, )
        }
    }
    
    @ViewBuilder
    private func searchBar() -> some View {
        TextField("Search tasks…", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
            .padding(.top, 8)
    }
    
    @ViewBuilder
    private func menuView() -> some View {
        VStack(spacing: 16) {

            if searchText.isEmpty {

                Button {
                    viewMode = .inbox
                } label: {
                    menuRow(
                        icon: "tray",
                        title: "Inbox",
                        showPlus: true
                    )
                }

                Divider()
                    .padding(.leading, 56)
                    .opacity(0.6)
                VStack(spacing: 0) {

                    Button {
                        viewMode = .today
                    } label: {
                        menuRow(
                            icon: "calendar",
                            title: "Today",
                            showPlus: true
                        )
                    }

                    Divider().padding(.leading, 56)

                    Button {
                        viewMode = .upcoming
                    } label: {
                        menuRow(
                            icon: "calendar.circle",
                            title: "Upcoming"
                        )
                    }

                    Divider().padding(.leading, 56)

                    Button {
                        viewMode = .all
                    } label: {
                        menuRow(
                            icon: "list.bullet",
                            title: "All tasks"
                        )
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)

                Button {
                    viewMode = .completed
                } label: {
                    menuRow(
                        icon: "checkmark.circle",
                        title: "Completed"
                    )
                }

            } else {
                ForEach(filteredTasks, id: \.id) { task in
                    taskView(task: task)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func menuRow(
        icon: String,
        title: String,
        showPlus: Bool = false
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            if showPlus {
                Image(systemName: "plus")
                    .foregroundColor(.secondary).onTapGesture {
                        showAddTask = true
                    }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func taskListView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                addTask(initialTiming: .init(start: .now, duration: 900))
                
                ForEach(tasks, id: \.id) { task in
                    taskView(task: task)
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        searchBar()

                        switch viewMode {
                        case .menu:
                            menuView()

                        case .today:
                            todayTasks()

                        case .upcoming:
                            upcomingTasks()

                        case .all:
                            taskListView()

                        case .inbox:
                            inboxView()

                        case .completed:
                            completedView()
                        }
                    }
                }

                // Floating Add Button
                if searchText.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showAddTask = true
                            } label: {
                                Image(
                                    systemName: "plus"
                                )
                                .font(
                                    .system(
                                        size: 22,
                                        weight: .bold
                                    )
                                )
                                .foregroundColor(
                                    .black
                                )
                                .padding()
                                .background(
                                    .white
                                )
                                .clipShape(
                                    Circle()
                                )
                                .shadow(
                                    radius: 8
                                )
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle(
                viewMode == .menu ? "Todos" :
                viewMode == .inbox ? "Inbox" :
                viewMode == .completed ? "Completed" :
                viewMode == .upcoming ? "Upcoming Tasks" :
                viewMode == .today ? "Today" :
                "All Tasks"
            )
            .navigationBarBackButtonHidden(viewMode == .menu)
            .toolbar {
                if viewMode != .menu {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewMode = .menu
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                }
            }
            .sheet(
                isPresented: $showAddTask
            ) {
                AddTodoView(
                    initialTiming: initializationTiming
                ) { newTask in
                    Task {
                        await addTask(
                        newTask
                    )
                    }
                }
            }
            .sheet(item: $selectedTaskForEdit) { task in
                EditTodoView(task: task) { newTitle, newDescription, isCompleted in
                    Task {
                        await updateTask(task: task, newTitle: newTitle, newDescription: newDescription, isCompleted: isCompleted)
                    }
                } onDelete: {
                    Task {
                        await deleteTask(task: task)
                    }
                }
            }
            .onAppear {
                print("Loading Tasks...")
                Task {
                    
                    await loadTasks()
                    rebuildDateBuckets()
                    print("Tasks Loaded.")
                }
            }
        }
    }

    // MARK: - DB

    func loadTasks() async {
        do {
            print("loadTasks")
            let manager =  DBManager.newInstance()
            tasks = try await manager
                .fetchAllTasks()
            for task in tasks {
                tasksMapping[task.id!] = task
                print(task.id!)
            }
//            try manager
//                .syncNow(
//
//                )
        } catch {
            print(error)
            self.error = error.localizedDescription
        }
    }

    func addTask(
        _ task_input: TaskInput
    ) async {
        do {
            print(
                "saving task..."
            )
            let manager = DBManager.newInstance()
            var rruleString = ""
            if task_input.schedule!.recurrence != nil {
                let rule = task_input.schedule!.recurrence!
                let formatter = RecurrenceRuleRFC5545FormatStyle(calendar: .current)
                rruleString = formatter.format(rule)
            }
            
            print("rruleString", rruleString)
            
            let task = Tasks(
                id: nil,
                title: task_input.title,
                description: task_input.description,
                priority: task_input.priority,
                target: task_input.target,
                label: task_input.label,
                is_completed: false,
                is_deadline: task_input.is_deadline,
                recursion_rule: rruleString,
                start_date: task_input.schedule?.timing?.start,
                duration: task_input.schedule?.timing?.duration,
                
            )
            
            let savedTask = try await manager.addTask(
                task
            )
            
            print(
                "done saving"
            )
            print(
                savedTask.id ?? "no id"
            )   // ✅ now works
            if savedTask.id == nil {
                return
            }
            // TODO: add to calender
            //            if task_input.schedule != nil {
            //                if task_input.schedule!.timing != nil && task_input.schedule!.recurrence != nil {
            //                    do {
            //                        var rule = task_input.schedule!.recurrence!
            //
            //                        try NeuralLoopCalendarService.shared
            //                            .addRecurringEvent(
            //                                taskId: Int(savedTask.id!) ,
            //                                title: task.title,
            //                                timing: task_input.schedule!.timing!,
            //                                recurrenceRule: rule,
            //                                notes: task.description,
            //                            )
            //                        if let next = nextOccurrence(of: rule) {
            //                            print("Next occurrence:", next)
            //                        } else {
            //                                print("No next occurrence found")
            //                            }
            //                    } catch {
            //                        print(
            //                            "❌ Calendar preview failed:",
            //                            error
            //                        )
            //                    }
            //                }
            //                else if task_input.schedule!.timing != nil  {
            //                    do {
            //                        try NeuralLoopCalendarService.shared
            //                            .addEvent(
            //                                taskId: Int(savedTask.id!) ,
            //                                title: task.title,
            //                                timing: task_input.schedule!.timing!,
            //
            //                                notes: task.description,
            //                            )
            //                    } catch {
            //                        print(
            //                            "❌ Calendar preview failed:",
            //                            error
            //                        )
            //                    }
            //                }
            //            }
            Task {
                await loadTasks()
                rebuildDateBuckets()
            }
        } catch {
            print(
                "Error saving task"
            )
            print(
                error
            )
            self.error = error.localizedDescription
//            do {
//                try DBManager.resetLocalDatabase()
//            }
//            catch {
//                print("Error resetting local database")
//            }
        }
    }

    private func rebuildDateBuckets() {
        var _dateBuckets = buildDateBuckets()

        var inbox_bucket = DateBucket(title: AnyView( Text("Inbox")
            .font(.title3.weight(.semibold))
            .foregroundColor(.primary)), start: .distantPast, end: .now, type: .inbox)

        var overdue_bucket = DateBucket(title: AnyView( Text("Overdue")
            .font(.title3.weight(.semibold))
            .foregroundColor(.primary)), start: .distantPast, end: .now, type: .overdue)
        var completed_bucket = DateBucket(title: AnyView( Text("Completed")
            .font(.title3.weight(.semibold))
            .foregroundColor(.primary)), start: .distantPast, end: .distantFuture, type: .completed)

        for task in tasks {
            if task.start_date == nil {
                inbox_bucket.taskIds.append(task.id!)
            }
            else if task.is_completed {
                completed_bucket.taskIds.append(task.id!)
            }
            else if (task.recursion_rule == "" || task.recursion_rule == nil) && task.start_date != nil && task.start_date! < Date() {
                    overdue_bucket.taskIds.append(task.id!)

            }
            else {
                _dateBuckets = attachTaskToBuckets(task: task, buckets: _dateBuckets)
            }
        }

        dateBuckets = [inbox_bucket, overdue_bucket, completed_bucket] + _dateBuckets
    }

    func updateTask(task: Tasks, newTitle: String, newDescription: String?, isCompleted: Bool) async {
        var has_updated = false
        var updated = task
        do {
            
            if task.title != newTitle {
                has_updated = true
                updated.title = newTitle
            }
            
            if task.description != newDescription {
                has_updated = true
                updated.description = newDescription
            }
            
            if task.recursion_rule == nil  || task.recursion_rule == "" {
                
                if updated.is_completed != isCompleted {
                    has_updated = true
                    updated.is_completed = isCompleted
                    updated.completed_at = isCompleted ? Date() : nil
                }
            }
            else {
                if dateBuckets.firstIndex(where: { $0.type == .today }) != nil    {
                    if isCompleted {
                        print("Marking recurring task as completed")
                        markRecurringTaskCompleted(taskId: task.id!, date: .now, context: context)
                        
                    }
                    else {
                        try deleteCompletion(taskId: task.id!, on: .now, context: context)
                        
                    }
                
                    
                }
            }
            
            if has_updated == true {
                let manager = DBManager.newInstance()
                try await manager.updateTask(updated)
                
            }
            Task {
                await loadTasks()
                rebuildDateBuckets()
            }
        } catch {
            print("Error updating task", error)
            self.error = error.localizedDescription
        }
    }

    func deleteTask(task: Tasks) async {
        guard let id = task.id else { return }
        do {
            let manager = DBManager.newInstance()
            try await manager.deleteTask(id: id)
            // Clear selection if it was the same task
            if selectedTaskForEdit?.id == id { selectedTaskForEdit = nil }
            Task {
                await loadTasks()
                rebuildDateBuckets()
            }
        } catch {
            print("Error deleting task", error)
            self.error = error.localizedDescription
        }
    }
}
