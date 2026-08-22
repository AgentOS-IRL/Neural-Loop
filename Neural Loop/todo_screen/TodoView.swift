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
    @Published var editTaskAttachments: [ImageAttachment] = []
    @Published var editTaskMapAttachments: [TaskMapAttachment] = []
    
    @Published var showDeleteConfirmation: Bool = false
    @Published var selectedTaskForDelete: Tasks? = nil
    @Published var taskMapDeleteImpact: TaskMapDeleteImpact?
    @Published var showTaskMapDeleteReview = false
    @Published var deleteErrorMessage: String?

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
        bucketsForCurrentViewMode = self.buckets(for: viewMode, using: buckets, allTasks: allTasks)
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
        case .inProcess:
            return [buildInProcessTaskBucket(from: allTasks)]
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

    func canNavigateBackToMenu() -> Bool {
        viewMode != .menu
    }

    func navigateBackToMenu() {
        guard canNavigateBackToMenu() else { return }

        viewMode = .menu
    }

    func handleBackSwipeIfNeeded() -> Bool {
        guard canNavigateBackToMenu() else { return false }

        navigateBackToMenu()
        return true
    }
}



struct TodoView: View {
    let embeddedInTaskHub: Bool

    @StateObject private var vm = TodoViewModel()
    @ObservedObject private var deepLink = DeepLinkManager.shared
    @Environment(\.modelContext) private var context
    @EnvironmentObject var model: UnifiedDataModel
    @Query private var recurringCompletions: [CompletedRecurringTask]

    private let todoBackSwipeStartThreshold: CGFloat = 32
    private let todoBackSwipeMinimumDistance: CGFloat = 72
    private let todoBackSwipeVerticalTolerance: CGFloat = 48
    private let todoScrollTopID = "todo-scroll-top"

    init(embeddedInTaskHub: Bool = false) {
        self.embeddedInTaskHub = embeddedInTaskHub
    }
    
    
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
                                vm.initializationTiming = .init(start: Calendar.neuralLoopDisplay.date(
                                    bySettingHour: 9,
                                    minute: 0,
                                    second: 0,
                                    of: bucket.start
                                )!, duration: 900)
                                vm.showAddTask = true
                            }
                    }

                    ForEach(bucket.tasks, id: \.id) { task in
                        taskView(
                            task: task,
                            occurrenceStart: recurringTaskOccurrenceStart(
                                for: task,
                                between: bucket.start,
                                and: bucket.end.addingTimeInterval(1)
                            )
                        )
                    }
                }
                Divider()
            }
        }
    }
    
    @ViewBuilder
    private func taskView(task: Tasks, occurrenceStart: Date? = nil) -> some View {
        let isRecurring = task.recursion_rule?.isEmpty == false
        let resolvedOccurrenceStart = occurrenceStart ?? (
            isRecurring ? recurringTaskOccurrenceStart(for: task, on: .now) : nil
        )
        let recurringOccurrenceIsCompleted = task.id.flatMap { taskId in
            resolvedOccurrenceStart.map {
                isRecurringTaskCompleted(
                    taskId: taskId,
                    occurrenceStart: $0,
                    completions: recurringCompletions
                )
            }
        } ?? false
        let strikeThrough = isRecurring ? recurringOccurrenceIsCompleted : task.is_completed
        
        TodoTaskRowView(
            task: task,
            strikeThrough: strikeThrough,
            noteCount: model.taskNoteCount(for: task.id),
            mapsStore: model.mapsStore
        )
            .onTapGesture {
                vm.selectedTaskForViewer = task
            }
            .contextMenu {
                if !isRecurring || resolvedOccurrenceStart != nil {
                    Button {
                        Task {
                            await model.updateTaskCompletedStatus(
                                task: task,
                                occurrenceStart: resolvedOccurrenceStart,
                                context: context
                            )
                        }
                    } label: {
                        Label(
                            strikeThrough ? "Uncomplete" : "Complete",
                            systemImage: "checkmark"
                        )
                    }
                }
                
                Button(role: .confirm){
                    Task {
                        if let taskId = task.id {
                            vm.editTaskAttachments = await model.fetchImageAttachments(forTaskId: taskId)
                            vm.editTaskMapAttachments = await model.fetchTaskMapAttachments(taskID: taskId)
                        } else {
                            vm.editTaskAttachments = []
                            vm.editTaskMapAttachments = []
                        }
                        vm.selectedTaskForEdit = task
                    }
                }label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    vm.selectedTaskForDelete = task
                    Task {
                        if let taskID = task.id {
                            vm.taskMapDeleteImpact = await model.fetchTaskMapDeleteImpact(taskID: taskID)
                        } else {
                            vm.taskMapDeleteImpact = nil
                        }
                        vm.showDeleteConfirmation = true
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .confirmationDialog(
                "Delete this task?",
                isPresented: $vm.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    vm.taskMapDeleteImpact?.hasOwnedPlaces == true
                        ? "Delete Task & Map Items"
                        : "Delete Task",
                    role: .destructive
                ) {
                    guard let task = vm.selectedTaskForDelete else { return }

                    Task {
                        do {
                            _ = try await model.deleteTaskForEditor(task: task, context: context)
                            clearTaskDeleteState()
                        } catch {
                            vm.deleteErrorMessage = error.localizedDescription
                        }
                    }
                }

                if vm.taskMapDeleteImpact?.hasOwnedPlaces == true {
                    Button("Review Map Items") {
                        vm.showTaskMapDeleteReview = true
                    }
                }

                Button("Cancel", role: .cancel) {
                    clearTaskDeleteState()
                }
            } message: {
                Text(taskDeleteConfirmationMessage)
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
                return Calendar.neuralLoopDisplay.component(.hour, from: start) < 12
            }
            let afternoonTasks = tasks.filter {
                guard let start = $0.start_date else { return false }
                let hour = Calendar.neuralLoopDisplay.component(.hour, from: start)
                return hour >= 12 && hour < 18
            }
            let eveningTasks = tasks.filter {
                guard let start = $0.start_date else { return false }
                return Calendar.neuralLoopDisplay.component(.hour, from: start) >= 18
            }

            LazyVStack(alignment: .leading, spacing: 28) {
                sectionView(title: "Morning", tasks: morningTasks, initialTiming: .init(start: Calendar.neuralLoopDisplay.date(
                    bySettingHour: 8,
                    minute: 0,
                    second: 0,
                    of: Date()
                )!, duration: 900))
                sectionView(title: "Afternoon", tasks: afternoonTasks, initialTiming: .init(start: Calendar.neuralLoopDisplay.date(
                    bySettingHour: 12,
                    minute: 0,
                    second: 0,
                    of: Date()
                )!, duration: 900))
                sectionView(title: "Evening", tasks: eveningTasks, initialTiming: .init(start: Calendar.neuralLoopDisplay.date(
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .onTapGesture {
                        vm.initializationTiming = initialTiming
                        vm.showAddTask = true
                    }
            }

            ForEach(tasks, id: \.id) { task in
                taskView(task: task)
            }
            Divider()
        }
    }

    @ViewBuilder
    private func searchBar() -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.textSecondary)
            TextField("Search tasks…", text: $vm.searchText)
                .font(.system(.body, design: .rounded, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.sectionGradient)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .cornerRadius(16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func menuView() -> some View {
        LazyVStack(spacing: 16) {
            if vm.searchText.isEmpty {
                sectionView(
                    title: "Today",
                    tasks: model.todayTaskBucket.tasks,
                    initialTiming: .init(
                        start: Calendar.neuralLoopDisplay.date(
                            bySettingHour: 9,
                            minute: 0,
                            second: 0,
                            of: Date()
                        )!,
                        duration: 900
                    )
                )

                sectionView(
                    title: "In Process",
                    tasks: landingInProcessTasks,
                    initialTiming: .init()
                )

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

                LazyVStack(spacing: 16) {
                    Button {
                        vm.viewMode = .upcoming
                    } label: {
                        menuRow(
                            icon: "calendar.circle",
                            title: "Upcoming"
                        )
                    }

                    Button {
                        vm.viewMode = .all
                    } label: {
                        menuRow(
                            icon: "list.bullet",
                            title: "All tasks"
                        )
                    }
                }

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

    private var landingInProcessTasks: [Tasks] {
        let todayTaskIDs = Set(model.todayTaskBucket.tasks.compactMap(\.id))
        return buildInProcessTaskBucket(
            from: model.tasks,
            excludingTaskIDs: todayTaskIDs
        ).tasks
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 24)

            HStack(spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                if let count {
                    Text("(\(count))")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            Spacer()

            if showPlus {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .onTapGesture {
                        vm.showAddTask = true
                    }
            }
        }
        .padding(20)
        .background(AppTheme.cardGradient)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .cornerRadius(AppTheme.Metrics.cardCornerRadius)
    }

    @ViewBuilder
    private func inProcessTasksView() -> some View {
        if let inProcessBucket = vm.bucketsForCurrentViewMode.first(where: { $0.type == .inProcess }) {
            LazyVStack(alignment: .leading, spacing: 16) {
                addTaskRowView()
                    .onTapGesture {
                        vm.initializationTiming = .init()
                        vm.showAddTask = true
                    }

                ForEach(inProcessBucket.tasks, id: \.id) { task in
                    taskView(task: task)
                }
            }
        }
    }

    @ViewBuilder
    private func allTasksView() -> some View {
        if let bucket = vm.bucketsForCurrentViewMode.first {
            LazyVStack(alignment: .leading, spacing: 16) {
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
        case .inProcess:
            return "In Process"
        }
    }

    private var bottomInsetHeight: CGFloat {
        embeddedInTaskHub ? SAFE_AREA_INSET + 104 : SAFE_AREA_INSET
    }

    @ViewBuilder
    private var todoRootContent: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        if embeddedInTaskHub {
                            todoEmbeddedHeader
                        }

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

                        case .inProcess:
                            inProcessTasksView()

                        case .inbox:
                            inboxView()

                        case .completed:
                            completedView()
                        }
                    }
                    .id(todoScrollTopID)
                    .padding(.horizontal)
                    .padding(.top)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: bottomInsetHeight)
                }
                .onChange(of: vm.viewMode) { _, _ in
                    scrollProxy.scrollTo(todoScrollTopID, anchor: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(todoBackSwipeGesture)
    }

    private var todoBackSwipeGesture: some Gesture {
        DragGesture(minimumDistance: todoBackSwipeMinimumDistance)
            .onEnded { value in
                guard isTodoBackSwipe(value) else { return }

                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    _ = vm.handleBackSwipeIfNeeded()
                }
            }
    }

    private func isTodoBackSwipe(_ value: DragGesture.Value) -> Bool {
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height

        guard vm.canNavigateBackToMenu() else { return false }
        guard value.startLocation.x <= todoBackSwipeStartThreshold else { return false }
        guard horizontalDistance >= todoBackSwipeMinimumDistance else { return false }
        guard abs(verticalDistance) <= todoBackSwipeVerticalTolerance else { return false }
        guard horizontalDistance > abs(verticalDistance) else { return false }

        return true
    }

    private var todoEmbeddedHeader: some View {
        ZStack(alignment: .trailing) {
            if vm.viewMode == .menu {
                todoHeaderLabel(showsBackIndicator: false)
            } else {
                Button {
                    vm.navigateBackToMenu()
                } label: {
                    todoHeaderLabel(showsBackIndicator: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Todo menu")
                .accessibilityHint("Returns to the Todo landing page")
            }

            Button {
                vm.showAddTask = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(AppTheme.sectionGradient)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add task")
            .padding(.trailing, 12)
        }
        .background(AppTheme.heroGradient)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .cornerRadius(AppTheme.Metrics.cardCornerRadius)
    }

    private func todoHeaderLabel(showsBackIndicator: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(toolbarTitle(for: vm.viewMode))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(
                    showsBackIndicator
                        ? "Tap anywhere on this card to go back."
                        : "Switch between todo lists and menu views."
                )
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 12)

            if showsBackIndicator {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(AppTheme.sectionGradient)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 20)
        .padding(.trailing, 72)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    var body: some View {
        Group {
            if embeddedInTaskHub {
                todoRootContent
            } else {
                NavigationView {
                    todoRootContent
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
                                    vm.navigateBackToMenu()
                                } label: {
                                    if vm.viewMode != .menu {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                    Text(toolbarTitle(for: vm.viewMode))
                                        .font(.system(.title3, design: .rounded, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .layoutPriority(1)
                                        .padding(.trailing, 12)
                                        .padding(.leading, vm.viewMode == .menu ? 12 : 0)
                                }
                            }
                        }
                }
            }
        }
        .task {
            await model.mapsStore.loadIfNeeded()
        }
        .onAppear {
            refreshBucketsFromModel()
            presentAddTaskIfNeeded(deepLink.pendingDeepLink)
        }
        .onChange(of: deepLink.pendingDeepLink) { _, newValue in
            presentAddTaskIfNeeded(newValue)
        }
        .onChange(of: vm.viewMode) { _ in
            refreshBucketsFromModel()
        }
        .onReceive(model.$tasks) { tasks in
            let buckets = model.shortTermTaskBuckets(from: tasks)
            vm.refreshCurrentBuckets(using: buckets, allTasks: tasks)
        }
        .sheet(isPresented: $vm.showAddTask) {
            AddEditTodoView(
                task: nil, initialTiming: vm.initializationTiming
            ) { newTask, attachments in
                let saved: Tasks
                if let taskID = newTask.id, let existing = model.getTask(by: taskID) {
                    saved = try await model.updateTaskForEditor(task: existing, modifiedTask: newTask)
                    await model.replaceImageAttachments(attachments, forTaskId: taskID)
                } else {
                    saved = try await model.saveTaskForEditor(newTask)
                    if let taskID = saved.id, !attachments.isEmpty {
                        await model.saveImageAttachments(attachments, forTaskId: taskID)
                    }
                }
                return saved
            }
        }
        .sheet(item: $vm.selectedTaskForEdit) { task in
            AddEditTodoView(
                task: task,
                existingAttachments: vm.editTaskAttachments,
                existingMapAttachments: vm.editTaskMapAttachments
            ) { modifiedTask, attachments in
                let current = modifiedTask.id.flatMap { model.getTask(by: $0) } ?? task
                let saved = try await model.updateTaskForEditor(task: current, modifiedTask: modifiedTask)
                if let taskID = saved.id {
                    await model.replaceImageAttachments(attachments, forTaskId: taskID)
                }
                return saved
            }
        }
        .sheet(item: $vm.selectedTaskForViewer) { task in
            IndividualTodoView(task: task)
        }
        .sheet(isPresented: $vm.showTaskMapDeleteReview) {
            if let impact = vm.taskMapDeleteImpact,
               let task = vm.selectedTaskForDelete {
                TaskMapDeleteReviewSheet(
                    impact: impact,
                    folders: model.mapsStore.sortedFolders
                ) { preservedPlaces in
                    _ = try await model.deleteTaskForEditor(
                        task: task,
                        preservedPlaces: preservedPlaces,
                        context: context
                    )
                    clearTaskDeleteState()
                }
            }
        }
        .alert(
            "Task could not be deleted",
            isPresented: Binding(
                get: { vm.deleteErrorMessage != nil },
                set: { if !$0 { vm.deleteErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { vm.deleteErrorMessage = nil }
        } message: {
            Text(vm.deleteErrorMessage ?? "Please try again.")
        }
    }

    private var taskDeleteConfirmationMessage: String {
        guard let impact = vm.taskMapDeleteImpact else {
            return "This action cannot be undone."
        }

        if impact.hasOwnedPlaces {
            return "\(impact.owned_place_count) task-owned place(s) will be deleted. \(impact.referenceCount) saved link(s) will be removed while their map items survive."
        }

        if impact.referenceCount > 0 {
            return "\(impact.referenceCount) map link(s) will be removed. The saved places and routes will survive."
        }

        return "This action cannot be undone."
    }

    private func clearTaskDeleteState() {
        vm.showDeleteConfirmation = false
        vm.showTaskMapDeleteReview = false
        vm.selectedTaskForDelete = nil
        vm.taskMapDeleteImpact = nil
    }

    private func presentAddTaskIfNeeded(_ link: AppDeepLink?) {
        guard link == .addTask else { return }

        vm.showAddTask = true
        deepLink.clearPendingNavigation()
    }
}

private struct TodoTaskRowView: View {
    let task: Tasks
    let strikeThrough: Bool
    let noteCount: Int
    @ObservedObject var mapsStore: MapsStore

    private var hasPlaceAttachment: Bool {
        guard let taskID = task.id else { return false }
        return mapsStore.taskLinkSummaries.contains { link in
            link.task_id == taskID && link.place_id != nil
        }
    }

    var body: some View {
        taskRowView(
            task: task,
            strikeThrough: strikeThrough,
            noteCount: noteCount,
            hasPlaceAttachment: hasPlaceAttachment
        )
    }
}
