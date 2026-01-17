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

}



struct TodoView: View {
    
    @StateObject private var vm = TodoViewModel()
    @Environment(\.modelContext) private var context
    @EnvironmentObject var model: UnifiedDataModel
    
    
    @ViewBuilder
    private func upcomingTasks() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(model.getUpcomingTasksDateBucket(), id: \.id) { bucket in
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
                            if let task = model.getTask(by: taskId) {
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
        let inboxBucket = model.getInboxTasksDateBucket()
        
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                addTaskRowView().onTapGesture {
                    vm.initializationTiming = .init()
                    vm.showAddTask = true
                }
                
                
                ForEach(inboxBucket.ids, id: \.self) { taskId in
                    if let task = model.getTask(by: taskId)  {
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
        let completedBucket = model.getCompletedTasksDateBucket()
        
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(completedBucket.ids, id: \.self) { taskId in
                    if let task = model.getTask(by: taskId) {
                        taskView(task: task)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }
    
    @ViewBuilder
    private func todayTasks() -> some View {
        let todayBucket = model.getTodayTasksDateBucket()
        
        let morningTasks = todayBucket.ids.compactMap { model.getTask(by: $0)! }
            .filter {
                guard let start = $0.start_date else { return false }
                return Calendar.current.component(.hour, from: start) < 12
            }
        
        let afternoonTasks = todayBucket.ids.compactMap { model.getTask(by: $0)! }
            .filter {
                guard let start = $0.start_date else { return false }
                let hour = Calendar.current.component(.hour, from: start)
                return hour >= 12 && hour < 18
            }
        
        let eveningTasks = todayBucket.ids.compactMap { model.getTask(by: $0)! }
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
                        count: model.getInboxTasksDateBucket().ids.count,
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
                            count: model.getTodayTasksDateBucket().ids.count,
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
                ForEach(model.filterTasks(searchText: vm.searchText), id: \.id) { task in
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
        count: Int? = nil,
        showPlus: Bool = false
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            HStack(spacing: 2) {
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
                
                ForEach(model.tasks, id: \.id) { task in
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
                }
                
//                // Floating Add Button
//                if vm.searchText.isEmpty && vm.viewMode == .menu {
//                    VStack {
//                        Spacer()
//                        HStack {
//                            Spacer()
//                            Button {
//                                vm.showAddTask = true
//                            } label: {
//                                Image(
//                                    systemName: "plus"
//                                )
//                                .font(
//                                    .system(
//                                        size: 22,
//                                        weight: .bold
//                                    )
//                                )
//                                .foregroundColor(
//                                    .black
//                                )
//                                .padding()
//                                .background(
//                                    .white
//                                )
//                                .clipShape(
//                                    Circle()
//                                )
//                                .shadow(
//                                    radius: 8
//                                )
//                            }
//                            .padding()
//                        }
//                    }
//                }
            }
//            .navigationTitle(
//                vm.viewMode == .menu ? "Todos" :
//                    vm.viewMode == .inbox ? "Inbox" :
//                    vm.viewMode == .completed ? "Completed" :
//                    vm.viewMode == .upcoming ? "Upcoming Tasks" :
//                    vm.viewMode == .today ? "Today" :
//                    "All Tasks"
//            )
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
                            Text(vm.viewMode == .menu ? "Todos" :
                                    vm.viewMode == .inbox ? "Inbox" :
                                    vm.viewMode == .completed ? "Completed" :
                                    vm.viewMode == .upcoming ? "Upcoming Tasks" :
                                    vm.viewMode == .today ? "Today" :
                                    "All Tasks")
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)  // don’t compress horizontally
                            .layoutPriority(1)                             // fight for space
                            .padding(.trailing, 12)
                            .padding(.leading, vm.viewMode == .menu ? 12:0)
                            
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
