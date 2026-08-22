import SwiftUI

struct TaskMapLinkBadge: View {
    let links: [TaskMapLinkSummary]
    let onSelectTask: (Int64) -> Void

    var body: some View {
        if links.count == 1, let link = links.first {
            Button {
                onSelectTask(link.task_id)
            } label: {
                badgeLabel(text: singleLabel(link))
            }
            .buttonStyle(.plain)
        } else if !links.isEmpty {
            Menu {
                ForEach(links) { link in
                    Button(link.task_title) {
                        onSelectTask(link.task_id)
                    }
                }
            } label: {
                badgeLabel(text: "Linked to \(links.count) tasks")
            }
        }
    }

    private func singleLabel(_ link: TaskMapLinkSummary) -> String {
        switch link.relationship {
        case .owner:
            return "Task-owned · \(link.task_title)"
        case .reference:
            return "Linked · \(link.task_title)"
        }
    }

    private func badgeLabel(text: String) -> some View {
        Label(text, systemImage: "checklist")
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.accentColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(AppTheme.accentColor.opacity(0.12), in: Capsule())
    }
}

struct SaveTaskOwnedPlaceSheet: View {
    let place: MapPlaceRecord
    let folders: [MapFolderRecord]
    let onSave: (Int64, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var folderID: Int64
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        place: MapPlaceRecord,
        folders: [MapFolderRecord],
        initialFolderID: Int64,
        onSave: @escaping (Int64, String) async throws -> Void
    ) {
        self.place = place
        self.folders = folders
        self.onSave = onSave
        _folderID = State(initialValue: initialFolderID)
        _name = State(initialValue: place.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Place") {
                    TextField("Name", text: $name)
                    Picker("Folder", selection: $folderID) {
                        ForEach(folders) { folder in
                            Text(folder.name).tag(folder.id)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppTheme.errorTint)
                    }
                }
            }
            .navigationTitle("Save Permanently")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await onSave(folderID, name.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TaskMapDeleteReviewSheet: View {
    let impact: TaskMapDeleteImpact
    let folders: [MapFolderRecord]
    let onDelete: ([PreservedTaskPlaceInput]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var savedPlaceIDs: Set<Int64> = []
    @State private var folderByPlaceID: [Int64: Int64] = [:]
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var defaultFolderID: Int64? {
        folders.first(where: \.is_default)?.id ?? folders.first?.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose which task-owned places should become permanent. Unselected places will be deleted with the task.")
                        .foregroundStyle(AppTheme.textSecondary)
                }

                ForEach(impact.owned_places) { place in
                    Section(place.name) {
                        Toggle("Save Permanently", isOn: saveBinding(for: place.id))
                        if savedPlaceIDs.contains(place.id) {
                            Picker("Folder", selection: folderBinding(for: place.id)) {
                                ForEach(folders) { folder in
                                    Text(folder.name).tag(folder.id)
                                }
                            }
                        } else {
                            Label("Delete with task", systemImage: "trash")
                                .foregroundStyle(AppTheme.errorTint)
                        }
                    }
                }

                if impact.referenceCount > 0 {
                    Section("References") {
                        Text("\(impact.referenceCount) saved place or route link(s) will be removed. Their map items will remain saved.")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppTheme.errorTint)
                    }
                }
            }
            .navigationTitle("Review Map Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete Task", role: .destructive) {
                        Task { await deleteTask() }
                    }
                    .disabled(isDeleting || (defaultFolderID == nil && !savedPlaceIDs.isEmpty))
                }
            }
            .interactiveDismissDisabled(isDeleting)
        }
    }

    private func saveBinding(for placeID: Int64) -> Binding<Bool> {
        Binding(
            get: { savedPlaceIDs.contains(placeID) },
            set: { shouldSave in
                if shouldSave {
                    savedPlaceIDs.insert(placeID)
                    if folderByPlaceID[placeID] == nil {
                        folderByPlaceID[placeID] = defaultFolderID
                    }
                } else {
                    savedPlaceIDs.remove(placeID)
                }
            }
        )
    }

    private func folderBinding(for placeID: Int64) -> Binding<Int64> {
        Binding(
            get: { folderByPlaceID[placeID] ?? defaultFolderID ?? 0 },
            set: { folderByPlaceID[placeID] = $0 }
        )
    }

    private func deleteTask() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        let preserved = impact.owned_places.compactMap { place -> PreservedTaskPlaceInput? in
            guard savedPlaceIDs.contains(place.id),
                  let folderID = folderByPlaceID[place.id] ?? defaultFolderID else { return nil }
            return PreservedTaskPlaceInput(
                place_id: place.id,
                folder_id: folderID,
                name: place.name
            )
        }

        do {
            try await onDelete(preserved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TaskLinkedMapsView: View {
    @ObservedObject var store: MapsStore
    @ObservedObject var coordinator: ParkingDetectionCoordinator
    @ObservedObject var locationService: MapsLocationService

    @EnvironmentObject private var model: UnifiedDataModel
    @State private var selectedTask: Tasks?

    private struct LinkGroup: Identifiable {
        let taskID: Int64
        let title: String
        let links: [TaskMapLinkSummary]

        var id: Int64 { taskID }
    }

    private var groupedLinks: [LinkGroup] {
        Dictionary(grouping: store.taskLinkSummaries, by: \.task_id)
            .map { taskID, links in
                LinkGroup(
                    taskID: taskID,
                    title: links.first?.task_title ?? "Task",
                    links: links.sorted { lhs, rhs in
                        lhs.position == rhs.position ? lhs.id < rhs.id : lhs.position < rhs.position
                    }
                )
            }
            .sorted { lhs, rhs in
                let comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                return comparison == .orderedSame ? lhs.taskID < rhs.taskID : comparison == .orderedAscending
            }
    }

    var body: some View {
        List {
            if groupedLinks.isEmpty {
                ContentUnavailableView(
                    "No task-linked maps",
                    systemImage: "checklist",
                    description: Text("Link a saved place or route from a task.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedLinks) { group in
                    Section {
                        ForEach(group.links) { link in
                            linkDestination(link)
                        }
                    } header: {
                        Button {
                            selectedTask = model.getTask(by: group.taskID)
                        } label: {
                            HStack {
                                Text(group.title)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Task-linked")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .refreshable { await store.refresh() }
        .sheet(item: $selectedTask) { task in
            IndividualTodoView(task: task)
        }
    }

    @ViewBuilder
    private func linkDestination(_ link: TaskMapLinkSummary) -> some View {
        if let placeID = link.place_id,
           let place = store.snapshot?.places.first(where: { $0.id == placeID }) {
            NavigationLink {
                MapPlaceDetailView(
                    placeReference: .remote(place.id),
                    store: store,
                    coordinator: coordinator,
                    locationService: locationService
                )
            } label: {
                linkedRow(
                    title: place.name,
                    subtitle: link.relationship == .owner ? "Task-owned place" : "Linked place",
                    systemImage: "mappin"
                )
            }
        } else if let routeID = link.route_id,
                  let route = store.snapshot?.routes.first(where: { $0.id == routeID }) {
            NavigationLink {
                MapRouteDetailView(
                    route: route,
                    waypoints: store.waypoints(for: route.id),
                    locationService: locationService,
                    store: store
                )
            } label: {
                linkedRow(
                    title: route.name,
                    subtitle: "Linked route",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                )
            }
        }
    }

    private func linkedRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
