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
    @Published var showAddTask: Bool = false
    @Published var viewMode: ViewMode = .menu
    @Published var searchText: String = ""
    @Published var selectedTaskForEdit: Tasks? = nil
    @Published var selectedTaskForViewer: Tasks? = nil
    
    @Published var showDeleteConfirmation: Bool = false
    @Published var selectedTaskForDelete: Tasks? = nil

    @Published var initializationTiming: TaskTiming = .init(
        start: Date(),
        duration: 900
    )

    @Published private(set) var bucketsForCurrentViewMode: [DateBucket] = []

    func refreshCurrentBuckets(using model: UnifiedDataModel) {
        refreshCurrentBuckets(
            using: model.shortTermTaskBuckets,
            allTasks: model.tasks
        )
    }

    func refreshCurrentBuckets(using buckets: [DateBucket], allTasks: [Tasks]) {
        bucketsForCurrentViewMode = buckets(for: viewMode, using: buckets, allTasks: allTasks)
    }

    private func buckets(for mode: ViewMode, using buckets: [DateBucket], allTasks: [Tasks]) -> [DateBucket] {
        switch mode {
        case .today:
            return buckets.compactMap { $0.type == .today ? $0 : nil }
        case .upcoming:
            return buckets.filter { $0.type == .upcoming }
        case .inbox:
            return buckets.compactMap { $0.type == .inbox ? $0 : nil }
        case .completed:
            return buckets.compactMap { $0.type == .completed ? $0 : nil }
        case .new:
            return [buildNewTaskBucket(from: allTasks)]
        case .all:
            var bucket = DateBucket(
                title: AnyView(
                    Text("All Tasks")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                ),
                start: .distantPast,
                end: .distantFuture,
                type: .upcoming
            )
            bucket.tasks = allTasks
            bucket.ids = allTasks.compactMap { $0.id }
            return [bucket]
        default:
            return []
        }
    }

}



struct TodoView: View {
    
    @StateObject private var vm = TodoViewModel()
    @Environment(\.modelContext) private var context
    @EnvironmentObject var model: UnifiedDataModel
    
    
    @ViewBuilder
    private func upcomingTasks() -> some View {
        LazyVStack(alignment: .leading, spacing: 28) {
            ForEach(vm.bucketsForCurrentViewMode) { bucket in
                LazyVStack(alignment: .leading, spacing: 8) {
                    HStack {
                        bucket.title
                        Image(systemName: "plus")
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                vm.initializationTiming = .init(start: Calendar.current.date(
                                    bySettingHour: 9,
                                    minute: 0,
                                    second: 0,
                                    of: bucket.start
                                )!, duration: 900)
                                vm.showAddTask = true
                            }
                    }

                    ForEach(bucket.tasks, id: \.id) { task in
                        taskView(task: task)
                    }
                }
                Divider()
            }
        }
    }
    
    @ViewBuilder
    private func taskView(task: Tasks, checkIfCompleted: Bool = false) -> some View {
        let strikeThrough =
        (checkIfCompleted &&
         completedTasks(on: .now, context: context).contains(task.id!)) || task.is_completed
        
        taskRowView(task: task, strikeThrough: strikeThrough)
            .onTapGesture {
                vm.selectedTaskForViewer = task
            }
            .contextMenu {
                Button {
                    Task {
                        await model.updateTaskCompletedStatus(task: task, context: context)
                    }
                } label: {
                    Label(task.is_completed ?"UnComplete" : "Complete", systemImage: "checkmark")
                }
                
                Button(role: .confirm){
                    vm.selectedTaskForEdit = task
                }label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    vm.showDeleteConfirmation = true
                    vm.selectedTaskForDelete = task
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .confirmationDialog(
                "Delete this task?",
                isPresented: $vm.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Task", role: .destructive) {
                    guard let task = vm.selectedTaskForDelete else { return }

                    Task {
                        await model.deleteTask(task: task)
                        vm.selectedTaskForDelete = nil
                    }
                }

                Button("Cancel", role: .cancel) {
                    vm.selectedTaskForDelete = nil
                }
            } message: {
                Text("This action cannot be undone.")
            }
    }
    
    
    @ViewBuilder
    private func inboxView() -> some View {
        if let inboxBucket = vm.bucketsForCurrentViewMode.first(where: { $0.type == .inbox }) {
            LazyVStack(alignment: .leading, spacing: 14) {
                addTaskRowView()
                    .onTapGesture {
                        vm.initializationTiming = .init()
                        vm.showAddTask = true
                    }

                ForEach(inboxBucket.tasks, id: \.id) { task in
                    taskView(task: task)
                }
            }
        }
    }

    @ViewBuilder
    private func completedView() -> some View {
        if let completedBucket = vm.bucketsForCurrentViewMode.first(where: { $0.type == .completed }) {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(completedBucket.tasks, id: \.id) { task in
                    taskView(task: task)
                }
            }
        }
    }

    @ViewBuilder
    private func todayTasks() -> some View {
        if let todayBucket = vm.bucketsForCurrentViewMode.first(where: { $0.type == .today }) {
            let tasks = todayBucket.tasks
            let morningTasks = tasks.filter {
                guard let start = $0.start_date else { return false }
                return Calendar.current.component(.hour, from: start) < 12
            }
            let afternoonTasks = tasks.filter {
                guard let start = $0.start_date else { return false }
                let hour = Calendar.current.component(.hour, from: start)
                return hour >= 12 && hour < 18
            }
            let eveningTasks = tasks.filter {
                guard let start = $0.start_date else { return false }
                return Calendar.current.component(.hour, from: start) >= 18
            }

            LazyVStack(alignment: .leading, spacing: 28) {
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
        }
    }

    @ViewBuilder
    private func sectionView(title: String, tasks: [Tasks], initialTiming: TaskTiming) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                Image(systemName: "plus")
                    .foregroundColor(.secondary)
                    .onTapGesture {
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
            .padding(.top, 8)
    }

    @ViewBuilder
    private func menuView() -> some View {
        LazyVStack(spacing: 16) {
            if vm.searchText.isEmpty {
                Button {
                    vm.viewMode = .inbox
                } label: {
                    menuRow(
                        icon: "tray",
                        title: "Inbox",
                        count: model.inboxTaskBucket.tasks.count,
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
                            count: model.todayTaskBucket.tasks.count,
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
                        vm.viewMode = .new
                    } label: {
                        menuRow(
                            icon: "sparkles",
                            title: "New",
                            count: model.newTaskBucket.tasks.count
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
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(model.filterTasks(searchText: vm.searchText), id: \.id) { task in
                        taskView(task: task)
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private func menuRow(
        icon: String,
        title: String,
        count: Int? = nil,
        showPlus: Bool = false
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            HStack(spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let count {
                    Text("(\(count))")
                        .foregroundColor(.secondary)
                }
            }
            Spacer()

            if showPlus {
                Image(systemName: "plus")
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        vm.showAddTask = true
                    }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    @ViewBuilder
    private func newTasksView() -> some View {
        if let newBucket = vm.bucketsForCurrentViewMode.first(where: { $0.type == .new }) {
            LazyVStack(alignment: .leading, spacing: 14) {
                addTaskRowView()
                    .onTapGesture {
                        vm.initializationTiming = .init()
                        vm.showAddTask = true
                    }

                ForEach(newBucket.tasks, id: \.id) { task in
                    taskView(task: task)
                }
            }
        }
    }

    @ViewBuilder
    private func allTasksView() -> some View {
        if let bucket = vm.bucketsForCurrentViewMode.first {
            LazyVStack(alignment: .leading, spacing: 14) {
                addTaskRowView()
                    .onTapGesture {
                        vm.initializationTiming = .init()
                        vm.showAddTask = true
                    }

                ForEach(bucket.tasks, id: \.id) { task in
                    taskView(task: task)
                }
            }
        }
    }

    private func refreshBucketsFromModel() {
        vm.refreshCurrentBuckets(using: model.shortTermTaskBuckets, allTasks: model.tasks)
    }

    private func toolbarTitle(for mode: ViewMode) -> String {
        switch mode {
        case .menu:
            return "Todos"
        case .inbox:
            return "Inbox"
        case .completed:
            return "Completed"
        case .upcoming:
            return "Upcoming Tasks"
        case .today:
            return "Today"
        case .all:
            return "All Tasks"
        case .new:
            return "New"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        searchBar()

                        switch vm.viewMode {
                        case .menu:
                            menuView()

                        case .today:
                            todayTasks()

                        case .upcoming:
                            upcomingTasks()

                        case .all:
                            allTasksView()

                        case .new:
                            newTasksView()

                        case .inbox:
                            inboxView()

                        case .completed:
                            completedView()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: SAFE_AREA_INSET)
                }
            }
            .navigationBarBackButtonHidden(vm.viewMode == .menu)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        vm.viewMode = .menu
                    } label: {
                        if vm.viewMode != .menu {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Text(toolbarTitle(for: vm.viewMode))
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                        .padding(.trailing, 12)
                        .padding(.leading, vm.viewMode == .menu ? 12 : 0)
                    }
                }
            }
            .onAppear {
                refreshBucketsFromModel()
            }
            .onChange(of: vm.viewMode) { _ in
                refreshBucketsFromModel()
            }
            .onReceive(model.$tasks) { tasks in
                let buckets = model.shortTermTaskBuckets(from: tasks)
                vm.refreshCurrentBuckets(using: buckets, allTasks: tasks)
            }
            .sheet(
                isPresented: $vm.showAddTask
            ) {
                AddEditTodoView(
                    task: nil, initialTiming: vm.initializationTiming
                ) { newTask in
                    Task {
                        await model.saveTask(newTask)
                    }
                }
            }
            .sheet(item: $vm.selectedTaskForEdit) { task in
                AddEditTodoView(task: task) { modified_task in
                    Task {
                        await model.updateTask(task: task, modified_task: modified_task)
                    }
                }
            }
            .sheet(item: $vm.selectedTaskForViewer) { task in
                IndividualTodoView(task: task)
            }
        }
    }
}
