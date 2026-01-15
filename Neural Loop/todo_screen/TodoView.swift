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
import Combine


@MainActor
final class TodoViewModel: ObservableObject {

    // Source of truth
    @Published var tasks: [Tasks] = [] {
        didSet {
            rebuildDerivedState()
        }
    }

    // Derived state
    @Published private(set) var tasksMapping: [Int64: Tasks] = [:]
    @Published private(set) var dateBuckets: [DateBucket] = buildShortRangeDateBuckets()

    // UI state
    @Published var showAddTask: Bool = false
    @Published var viewMode: ViewMode = .menu
    @Published var error: String?
    @Published var searchText: String = ""
    @Published var selectedTaskForEdit: Tasks? = nil

    @Published var initializationTiming: TaskTiming = .init(
        start: Date(),
        duration: 900
    )

    var filteredTasks: [Tasks] {
        guard !searchText.isEmpty else { return tasks }
        return tasks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func rebuildDerivedState() {
        // Rebuild mapping
        var map: [Int64: Tasks] = [:]
        for task in tasks {
            if let id = task.id {
                map[id] = task
            }
        }
        tasksMapping = map

        // Rebuild buckets
        dateBuckets = rebuildDateBuckets(tasks: tasks)
    }
    
    func replaceTask(_ task: Tasks) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }
    func removeTask(_ task: Tasks) {
        if let index = tasks.firstIndex(of: task) {
            tasks.remove(at: index)
        }
    }

    // MARK: - DB

    func loadTasks() async {
        do {
            print("loadTasks")
            let manager = DBManager.newInstance()
            let fetched = try await manager.fetchAllTasks()
            tasks = fetched
        } catch {
            print("error", error)
            self.error = error.localizedDescription
        }
    }

    func reloadTasks() {
        print("Loading Tasks...")
        selectedTaskForEdit = nil
        Task {
            await loadTasks()
        }
        print("Done Loading Tasks")
    }

    func updateTaskCompletedStatus(task: Tasks, context: ModelContext) async {
        var modified_task = task
        modified_task.is_completed.toggle()
        do {
            if modified_task.recursion_rule != "" && modified_task.recursion_rule != nil {
                if dateBuckets.firstIndex(where: { $0.type == .today }) != nil {
                    if modified_task.is_completed {
                        print("Marking recurring task as completed")
                        markRecurringTaskCompleted(taskId: modified_task.id!, date: .now, context: context)
                    } else {
                        try deleteCompletion(taskId: modified_task.id!, on: .now, context: context)
                    }
                }
            } else {
                let manager = DBManager.newInstance()
                try await manager.updateTask(modified_task)
            }
        } catch {
            print("Error toggling completed status of task", error)
            self.error = error.localizedDescription
        }

        // Ensure UI reflects DB changes
        reloadTasks()
    }
}



struct TodoView: View {
    
    @StateObject private var vm = TodoViewModel()
    @Environment(\.modelContext) private var context
    
    
    @ViewBuilder
    private func upcomingTasks() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(getUpcomingBucket(dateBuckets: vm.dateBuckets)) { bucket in
                    VStack(alignment: .leading, spacing: 8) {
                        
                        HStack{
                            // Section header (Today, Tomorrow, Thu 8 Jan, etc.)
                            bucket.title
                            Image(systemName: "plus")
                                .foregroundColor(.secondary).onTapGesture {
                                    vm.initializationTiming = .init(start: Calendar.current.date(
                                        bySettingHour: 9,
                                        minute: 0,
                                        second: 0,
                                        of: bucket.start
                                    )!, duration: 900)
                                    vm.showAddTask = true
                                }
                        }
                        
                        // Tasks for this date bucket
                        ForEach(bucket.ids, id: \.self) { taskId in
                            if let task = vm.tasksMapping[taskId] {
                                taskView(task: task)
                            }
                        }
                        
                    }
                    Divider()
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }
    
    @ViewBuilder
    private func taskView(task: Tasks, checkIfCompleted: Bool = false) -> some View {
        let strikeThrough =
        (checkIfCompleted &&
         completedTasks(on: .now, context: context).contains(task.id!)) || task.is_completed
        
        taskRowView(task: task, strikeThrough: strikeThrough)
            .onTapGesture {
                vm.selectedTaskForEdit = task
            }
            .contextMenu {
                Button {
                    Task {
                        await vm.updateTaskCompletedStatus(task: task, context: context)
                    }
                } label: {
                    Label(task.is_completed ?"UnComplete" : "Complete", systemImage: "checkmark")
                }
                
                Button(role: .destructive) {
                    Task {
                        await deleteTask(task: task)
                    }
                    vm.removeTask(task)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
    
    
    @ViewBuilder
    private func inboxView() -> some View {
        let inboxBucket = getInboxBucket(dateBuckets: vm.dateBuckets)
        
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                addTaskRowView().onTapGesture {
                    vm.initializationTiming = .init()
                    vm.showAddTask = true
                }
                
                
                ForEach(inboxBucket.ids, id: \.self) { taskId in
                    if let task = vm.tasksMapping[taskId] {
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
        let completedBucket = getCompletedBucket(dateBuckets: vm.dateBuckets)
        
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(completedBucket.ids, id: \.self) { taskId in
                    if let task = vm.tasksMapping[taskId] {
                        taskView(task: task)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }
    
    private func getTodaysBucket() -> DateBucket {
        vm.dateBuckets.first(where: { $0.type == .today })!
    }
    
    @ViewBuilder
    private func todayTasks() -> some View {
        let todayBucket = getTodaysBucket()
        
        let morningTasks = todayBucket.ids.compactMap { vm.tasksMapping[$0] }
            .filter {
                guard let start = $0.start_date else { return false }
                return Calendar.current.component(.hour, from: start) < 12
            }
        
        let afternoonTasks = todayBucket.ids.compactMap { vm.tasksMapping[$0] }
            .filter {
                guard let start = $0.start_date else { return false }
                let hour = Calendar.current.component(.hour, from: start)
                return hour >= 12 && hour < 18
            }
        
        let eveningTasks = todayBucket.ids.compactMap { vm.tasksMapping[$0] }
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
            
            
            HStack{
                // Section header (Today, Tomorrow, Thu 8 Jan, etc.)
                Text(title)
                    .font(.headline)
                Image(systemName: "plus")
                    .foregroundColor(.secondary).onTapGesture {
                        vm.initializationTiming = initialTiming
                        vm.showAddTask = true
                    }
            }
            
            ForEach(tasks, id: \.id) { task in
                taskView(task: task, checkIfCompleted: true)
            }
            Divider()
        }
    }
    
    @ViewBuilder
    private func searchBar() -> some View {
        TextField("Search tasks…", text: $vm.searchText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
            .padding(.top, 8)
    }
    
    @ViewBuilder
    private func menuView() -> some View {
        VStack(spacing: 16) {
            
            if vm.searchText.isEmpty {
                
                Button {
                    vm.viewMode = .inbox
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
                        vm.viewMode = .today
                    } label: {
                        menuRow(
                            icon: "calendar",
                            title: "Today",
                            showPlus: true
                        )
                    }
                    
                    Divider().padding(.leading, 56)
                    
                    Button {
                        vm.viewMode = .upcoming
                    } label: {
                        menuRow(
                            icon: "calendar.circle",
                            title: "Upcoming"
                        )
                    }
                    
                    Divider().padding(.leading, 56)
                    
                    Button {
                        vm.viewMode = .all
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
                    vm.viewMode = .completed
                } label: {
                    menuRow(
                        icon: "checkmark.circle",
                        title: "Completed"
                    )
                }
                
            } else {
                ForEach(vm.filteredTasks, id: \.id) { task in
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
                        vm.showAddTask = true
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
                addTaskRowView().onTapGesture {
                    vm.initializationTiming = .init()
                    vm.showAddTask = true
                }
                
                ForEach(vm.tasks, id: \.id) { task in
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
                        
                        switch vm.viewMode {
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
                }.refreshable {
                    await vm.loadTasks()
                }
                
                // Floating Add Button
                if vm.searchText.isEmpty && vm.viewMode == .menu {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                vm.showAddTask = true
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
                vm.viewMode == .menu ? "Todos" :
                    vm.viewMode == .inbox ? "Inbox" :
                    vm.viewMode == .completed ? "Completed" :
                    vm.viewMode == .upcoming ? "Upcoming Tasks" :
                    vm.viewMode == .today ? "Today" :
                    "All Tasks"
            )
            .navigationBarBackButtonHidden(vm.viewMode == .menu)
            .toolbar {
                if vm.viewMode != .menu {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            vm.viewMode = .menu
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                }
            }
            .sheet(
                isPresented: $vm.showAddTask
            ) {
                AddEditTodoView(
                    task: nil, initialTiming: vm.initializationTiming
                ) { newTask in
                    Task {
                        let _newTask = await saveTask(newTask)
                        if (_newTask != nil){
                            vm.tasks.append(_newTask!)
                        }
                        
                    }
                }
            }
            .sheet(item: $vm.selectedTaskForEdit) { task in
                AddEditTodoView(task: task) { modified_task in
                    Task {
                        await updateTask(task: task, modified_task: modified_task)
                        
                        vm.replaceTask(modified_task)
                        
                        
                    }
                }
            }
            .onAppear {
                vm.reloadTasks()
            }
        }
    }
    
}
