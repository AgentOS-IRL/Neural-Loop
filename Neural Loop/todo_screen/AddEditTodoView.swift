//
//  EditTodoView.swift
//  Neural Loop
//
//  Created by Codex on 07/01/2026.
//

import SwiftUI
import RRuleKit

struct AddEditTodoView: View {
    let task: Tasks?
    let onSave: (Tasks, [ImageAttachment]) async throws -> Tasks

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: UnifiedDataModel

    @State private var title: String
    @State private var description: String
    @State private var priority: Int
    @State private var isDeadline: Bool
    @State private var scheduleDraft: TaskScheduleDraft
    @State private var goalId: Int64? = nil
    @State private var lifeAreaId: Int64? = nil
    
    @State private var GoalOrLifeAreadName: String? = nil

    @State private var showAreaGoalSheet = false
    @State private var showTimeSheet = false       // clock (time only)
    @State private var showScheduleSheet = false

    @State private var attachments: [ImageAttachment] = []
    @State private var existingMapAttachments: [TaskMapAttachment]
    @State private var selectedMapTargets: [TaskMapTarget]
    @State private var ownedPlaceDrafts: [TaskOwnedPlaceDraft] = []
    @State private var showMapPicker = false
    @State private var showAddTaskPlace = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var persistedTask: Tasks?
    
    @State private var showUnsetConfirmation = false


    init(
        task: Tasks?,
        initialTiming: TaskTiming? = nil,
        goalId: Int64? = nil,
        lifeAreaId: Int64? = nil,
        existingAttachments: [ImageAttachment] = [],
        existingMapAttachments: [TaskMapAttachment] = [],
        onSave: @escaping (Tasks, [ImageAttachment]) async throws -> Tasks
    ) {
        self.task = task
        self.onSave = onSave
        _persistedTask = State(initialValue: task)
        _attachments = State(initialValue: existingAttachments)
        let sortedMapAttachments = existingMapAttachments.sorted {
            $0.position == $1.position ? $0.id < $1.id : $0.position < $1.position
        }
        _existingMapAttachments = State(initialValue: sortedMapAttachments)
        _selectedMapTargets = State(
            initialValue: sortedMapAttachments.compactMap { attachment in
                attachment.relationship == .reference ? attachment.target : nil
            }
        )
        _title = State(initialValue: task?.title ?? "")
        _description = State(initialValue: task?.description ?? "")
        _priority = State(initialValue: task?.priority ?? 0)
        _isDeadline = State(initialValue: task?.is_deadline ?? false)
        var _draftSchedule: TaskScheduleDraft = .init(timing: nil, recurrence: nil)
        
        if task == nil {
            _draftSchedule.timing = initialTiming
        }
        else{
            if let start = task?.start_date, let duration = task?.duration {
                _draftSchedule.timing = TaskTiming(start: start, duration: duration)
            } else {
                _draftSchedule.timing = nil
            }
        }
        
        let rule = task?.recursion_rule ?? nil
        

        let parser = RecurrenceRuleRFC5545FormatStyle(calendar: .neuralLoopDisplay)
        
        let rrule: Calendar.RecurrenceRule? = {
            do {
                if rule == nil { return nil }
                let rrule =  try parser.parse(rule!)
                return rrule
            } catch {
                print("Failed to parse rule")
                return nil
            }
        }()
        _draftSchedule.recurrence = rrule
        _scheduleDraft = State(initialValue: _draftSchedule)
        
        if task?.goal_id != nil {
            _goalId = State(initialValue: task?.goal_id)
            
        }
        else {
            _goalId = State(initialValue: goalId)
            
        }
        if task?.lifearea_id != nil {
            _lifeAreaId = State(initialValue: task?.lifearea_id)
        }
        else {
            _lifeAreaId = State(initialValue: lifeAreaId)
        }
        
        
    }
    
    @ViewBuilder
    private func scheduleSummary() -> some View {
        let timeText = scheduleDraft.timing?.summary() ?? "No Time"
        let repeatText = scheduleDraft.recurrence?.summary() ?? "No Repeat"

        Text("\(timeText) • \(repeatText)")
            .onTapGesture {
                // Only ask if there’s something to unset
                if scheduleDraft.timing != nil || scheduleDraft.recurrence != nil {
                    showUnsetConfirmation = true
                }
            }
            .confirmationDialog(
                "Remove Schedule?",
                isPresented: $showUnsetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Unset Schedule", role: .destructive) {
                    scheduleDraft.timing = nil
                    scheduleDraft.recurrence = nil
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the time and repeat settings.")
            }
    }
    
    private var priorityIcon: String {
        switch priority {
        case 1: return "exclamationmark.circle"
        case 2: return "exclamationmark.circle.fill"
        case 3: return "exclamationmark.triangle.fill"
        default: return "minus.circle"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        
                        // MARK: Title & Description
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Task Details")
                            ThemedCard {
                                ThemedTextField(placeholder: "Task title", text: $title, isTitle: true)
                                
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))
                                
                                TextEditor(text: $description)
                                    .frame(minHeight: 100)
                                    .scrollContentBackground(.hidden)
                                    .font(.body)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }

                        // MARK: Priority & Deadline
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Priority & Deadline")
                            ThemedCard {
                                Picker("Priority", selection: $priority) {
                                    Text("Low").tag(0)
                                    Text("Medium").tag(1)
                                    Text("High").tag(2)
                                    Text("Critical").tag(3)
                                }
                                .pickerStyle(.segmented)
                                
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                Toggle(isOn: $isDeadline) {
                                    Label("Deadline", systemImage: "timer")
                                        .font(.body.weight(.medium))
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                .tint(AppTheme.accentColor)
                            }
                        }

                        // MARK: Schedule
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Schedule")
                            ThemedCard {
                                scheduleSummary()
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(AppTheme.textSecondary)
                                
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                Button {
                                    showTimeSheet = true
                                } label: {
                                    ThemedRow {
                                        Label("Set Time", systemImage: "clock")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }

                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.1))

                                Button {
                                    showScheduleSheet = true
                                } label: {
                                    ThemedRow {
                                        Label("Repeat", systemImage: "arrow.2.circlepath")
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }

                        // MARK: Goal / Life Area
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Goal or Life Area")
                            ThemedCard {
                                Button {
                                    showAreaGoalSheet = true
                                } label: {
                                    ThemedRow {
                                        Label(
                                            GoalOrLifeAreadName ?? "Select goal or life area",
                                            systemImage: "scope"
                                        )
                                        .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }

                        mapAttachmentsSection

                        // MARK: Attachments
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Attachments")
                            ThemedCard {
                                ImageAttachmentSection(attachments: $attachments)
                            }
                        }
                    }
                    .padding(AppTheme.Metrics.screenPadding)
                    .padding(.bottom, SAFE_AREA_INSET + 20)
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Close
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if !isSaving { dismiss() }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }

                // Save
                ToolbarItem(placement: .topBarTrailing) {
                    Button(task == nil ? "Save" : "Update") {
                        Task { await saveTask() }
                    }
                    .font(.body.weight(.bold))
                    .foregroundColor(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.textSecondary : AppTheme.accentColor)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showScheduleSheet) {
                TaskScheduleSheet(
                    initialTiming: TaskTiming(
                        start: scheduleDraft.timing?.start ?? .now,
                        duration: scheduleDraft.timing?.duration ?? 900
                    ),
                    initialRule: scheduleDraft.recurrence
                ) { draft in
                    scheduleDraft = draft
                }
            }
            .sheet(isPresented: $showTimeSheet) {
                TimeRuleSheet(initialTiming: scheduleDraft.timing) { timing in
                    scheduleDraft = TaskScheduleDraft(
                        timing: timing,
                        recurrence: nil
                    )
                }
            }
            .sheet(isPresented: $showAreaGoalSheet) {
                GoalSelectionSheet { result in
                    guard let result else { return }

                    switch result {
                    case .goal(let id, let title):
                        GoalOrLifeAreadName = "Goal: \(title)"
                        goalId = id
                        lifeAreaId = nil

                    case .lifeArea(let id, let name):
                        GoalOrLifeAreadName = "Life Area: \(name)"
                        goalId = nil
                        lifeAreaId = id
                    }
                }
            }
            .sheet(isPresented: $showMapPicker) {
                TaskMapReferencePicker(
                    store: model.mapsStore,
                    initialSelection: selectedMapTargets
                ) { selection in
                    selectedMapTargets = selection
                }
            }
            .sheet(isPresented: $showAddTaskPlace) {
                if let unfiled = model.mapsStore.unfiledFolder {
                    AddMapPlaceSheet(
                        folders: [unfiled],
                        initialFolderID: unfiled.id
                    ) { request in
                        ownedPlaceDrafts.append(
                            TaskOwnedPlaceDraft(
                                name: request.name,
                                latitude: request.latitude,
                                longitude: request.longitude,
                                address: request.address
                            )
                        )
                    }
                }
            }
            .alert(
                "Task could not be saved",
                isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "Please try again.")
            }
            .interactiveDismissDisabled(isSaving)
            .task {
                await model.mapsStore.loadIfNeeded()
                GoalOrLifeAreadName = await model.getGoalName(goal_id: goalId)
                if GoalOrLifeAreadName == nil {
                    GoalOrLifeAreadName = await model.getLifeAreaName(lifeArea_id: lifeAreaId)
                }
            }
        }
    }
    
    @ViewBuilder
    private var mapAttachmentsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            themedSectionHeader("Map Attachments")
            ThemedCard {
                let ownedAttachments = existingMapAttachments.filter { $0.relationship == .owner }
                if ownedAttachments.isEmpty && selectedMapTargets.isEmpty && ownedPlaceDrafts.isEmpty {
                    Text("No places or routes linked")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(ownedAttachments) { attachment in
                        mapAttachmentRow(
                            title: attachment.displayName,
                            subtitle: "Task-owned",
                            systemImage: "mappin.and.ellipse",
                            remove: nil
                        )
                        Divider()
                    }

                    ForEach(selectedMapTargets) { target in
                        mapAttachmentRow(
                            title: mapTargetName(target),
                            subtitle: "Linked reference",
                            systemImage: targetSystemImage(target),
                            remove: {
                                selectedMapTargets.removeAll { $0 == target }
                            }
                        )
                        Divider()
                    }

                    ForEach(ownedPlaceDrafts) { draft in
                        mapAttachmentRow(
                            title: draft.name,
                            subtitle: "New task-owned place",
                            systemImage: "mappin.and.ellipse",
                            remove: {
                                ownedPlaceDrafts.removeAll { $0.id == draft.id }
                            }
                        )
                        Divider()
                    }
                }

                HStack {
                    Button {
                        showMapPicker = true
                    } label: {
                        Label("Link Existing", systemImage: "link.badge.plus")
                    }

                    Spacer()

                    Button {
                        showAddTaskPlace = true
                    } label: {
                        Label("Create Place", systemImage: "mappin.and.ellipse")
                    }
                    .disabled(model.mapsStore.unfiledFolder == nil)
                }
                .font(.system(.caption, design: .rounded, weight: .bold))
            }
        }
    }

    private func mapAttachmentRow(
        title: String,
        subtitle: String,
        systemImage: String,
        remove: (() -> Void)?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if let remove {
                Button(role: .destructive, action: remove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func mapTargetName(_ target: TaskMapTarget) -> String {
        switch target {
        case .place(let id):
            return model.mapsStore.snapshot?.places.first { $0.id == id }?.name
                ?? existingMapAttachments.first { $0.place_id == id }?.displayName
                ?? "Place"
        case .route(let id):
            return model.mapsStore.snapshot?.routes.first { $0.id == id }?.name
                ?? existingMapAttachments.first { $0.route_id == id }?.displayName
                ?? "Route"
        }
    }

    private func targetSystemImage(_ target: TaskMapTarget) -> String {
        switch target {
        case .place: "mappin"
        case .route: "point.topleft.down.to.point.bottomright.curvepath"
        }
    }

    private func saveTask() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)

        var recursion_rule: String? = nil
        if let rule = scheduleDraft.recurrence {
            recursion_rule = rrule_to_string(rule: rule)
        }

        let updatedTask = Tasks(
            id: persistedTask?.id ?? task?.id,
            title: trimmedTitle,
            description: trimmedDesc,
            priority: priority,
            goal_id: goalId,
            lifearea_id: lifeAreaId,
            is_completed: task?.is_completed ?? false,
            is_deadline: isDeadline,
            completed_at: task?.completed_at ?? nil,
            recursion_rule: recursion_rule,
            start_date: scheduleDraft.timing?.start ?? nil,
            duration: scheduleDraft.timing?.duration ?? nil
        )

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        do {
            let savedTask = try await onSave(updatedTask, attachments)
            persistedTask = savedTask

            guard let taskID = savedTask.id else {
                throw TaskMapEditorError.savedTaskHasNoID
            }

            _ = try await model.applyTaskMapBundle(
                taskID: taskID,
                draft: TaskMapBundleDraft(
                    referenceTargets: selectedMapTargets,
                    ownedPlaces: ownedPlaceDrafts
                )
            )
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
    
}

private enum TaskMapEditorError: LocalizedError {
    case savedTaskHasNoID

    var errorDescription: String? {
        "The task was saved without a database ID. Please try again."
    }
}

private struct TaskMapReferencePicker: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case places = "Places"
        case routes = "Routes"

        var id: String { rawValue }
    }

    @ObservedObject var store: MapsStore
    let onDone: ([TaskMapTarget]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var segment: Segment = .places
    @State private var searchText = ""
    @State private var selection: [TaskMapTarget]

    init(
        store: MapsStore,
        initialSelection: [TaskMapTarget],
        onDone: @escaping ([TaskMapTarget]) -> Void
    ) {
        self.store = store
        self.onDone = onDone
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Map type", selection: $segment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)

                if segment == .places {
                    ForEach(filteredPlaces) { place in
                        selectionRow(
                            title: place.name,
                            subtitle: store.folder(id: place.folder_id)?.name,
                            target: .place(place.id),
                            systemImage: "mappin"
                        )
                    }
                } else {
                    ForEach(filteredRoutes) { route in
                        selectionRow(
                            title: route.name,
                            subtitle: store.folder(id: route.folder_id)?.name,
                            target: .route(route.id),
                            systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                        )
                    }
                }
            }
            .navigationTitle("Link Existing")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search Maps")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(selection)
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredPlaces: [MapPlaceRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return (store.snapshot?.places ?? [])
            .filter { place in
                place.kind == .saved &&
                !store.isTaskOwned(placeID: place.id) &&
                (query.isEmpty || place.name.localizedCaseInsensitiveContains(query))
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredRoutes: [MapRouteRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return (store.snapshot?.routes ?? [])
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func selectionRow(
        title: String,
        subtitle: String?,
        target: TaskMapTarget,
        systemImage: String
    ) -> some View {
        Button {
            if selection.contains(target) {
                selection.removeAll { $0 == target }
            } else {
                selection.append(target)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(AppTheme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: selection.contains(target) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selection.contains(target) ? AppTheme.accentColor : AppTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}
