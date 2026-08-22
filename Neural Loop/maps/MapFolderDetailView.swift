import CoreLocation
import SwiftUI

struct MapFolderDetailView: View {
    let folderID: Int64
    @ObservedObject var store: MapsStore
    @ObservedObject var coordinator: ParkingDetectionCoordinator
    @ObservedObject var locationService: MapsLocationService
    @EnvironmentObject private var model: UnifiedDataModel

    @State private var isAddingPlace = false
    @State private var placeToEdit: MapPlaceRecord?
    @State private var placeToMove: MapPlaceRecord?
    @State private var placeToDelete: MapPlaceRecord?
    @State private var mutationErrorMessage: String?
    @State private var selectedTask: Tasks?

    private var folder: MapFolderRecord? {
        store.folder(id: folderID)
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            if let folder {
                folderList(folder: folder)
            } else {
                ContentUnavailableView(
                    "Folder unavailable",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Return to Maps and refresh.")
                )
            }
        }
        .navigationTitle(folder?.name ?? "Folder")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingPlace) {
            if let folder {
                AddMapPlaceSheet(
                    folders: store.sortedFolders,
                    initialFolderID: folder.id,
                    onSave: { request in
                        _ = try await store.createPlace(request)
                    }
                )
            }
        }
        .sheet(item: $placeToEdit) { place in
            EditMapPlaceSheet(
                place: place,
                folders: store.sortedFolders,
                onSave: { name, destinationFolderID in
                    _ = try await store.updatePlace(
                        place,
                        name: name,
                        folderID: destinationFolderID
                    )
                }
            )
        }
        .sheet(item: $placeToMove) { place in
            MoveMapPlaceSheet(
                place: place,
                folders: store.sortedFolders,
                onMove: { destinationFolderID in
                    _ = try await store.movePlace(place, to: destinationFolderID)
                }
            )
        }
        .confirmationDialog(
            placeToDelete.map { "Delete \($0.name)?" } ?? "Delete place?",
            isPresented: Binding(
                get: { placeToDelete != nil },
                set: { if !$0 { placeToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Place", role: .destructive) {
                guard let place = placeToDelete else { return }
                Task {
                    do {
                        try await store.deletePlace(place)
                    } catch {
                        mutationErrorMessage = error.localizedDescription
                    }
                    placeToDelete = nil
                }
            }
            .disabled(store.isMutating)

            Button("Cancel", role: .cancel) {
                placeToDelete = nil
            }
        } message: {
            Text(placeDeleteMessage)
        }
        .alert(
            "Place action failed",
            isPresented: Binding(
                get: { mutationErrorMessage != nil },
                set: { if !$0 { mutationErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                mutationErrorMessage = nil
            }
        } message: {
            Text(mutationErrorMessage ?? "Please try again.")
        }
        .sheet(item: $selectedTask) { task in
            IndividualTodoView(task: task)
        }
    }

    private func folderList(folder: MapFolderRecord) -> some View {
        List {
            if locationService.isDeniedOrRestricted {
                MapsPermissionBanner(openSettings: locationService.openSettings)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                let places = store.savedPlaceItems(in: folder.id)
                if places.isEmpty {
                    Text("No places.")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(places) { place in
                        NavigationLink {
                            MapPlaceDetailView(
                                placeReference: place.id,
                                store: store,
                                coordinator: coordinator,
                                locationService: locationService
                            )
                        } label: {
                            MapPlaceRow(
                                place: place,
                                currentLocation: locationService.currentLocation,
                                taskLinks: place.remoteID.map { store.taskLinks(forPlaceID: $0) } ?? [],
                                onSelectTask: selectTask
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if let record = store.remoteRecord(for: place), !place.isSyncPending {
                                Button {
                                    placeToMove = record
                                } label: {
                                    Label("Move", systemImage: "folder")
                                }
                                .tint(.orange)

                                Button {
                                    placeToEdit = record
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(AppTheme.accentColor)
                            }
                        }
                        .contextMenu {
                            if let record = store.remoteRecord(for: place), !place.isSyncPending {
                                Button(role: .destructive) {
                                    placeToDelete = record
                                } label: {
                                    Label("Delete Place", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Places")
                    Spacer()
                    Button {
                        isAddingPlace = true
                    } label: {
                        Label("Add Place", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                    }
                    .disabled(store.isMutating)
                }
            }

            Section("Routes") {
                let routes = store.routes(in: folder.id)
                if routes.isEmpty {
                    Text("No routes.")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(routes) { route in
                        NavigationLink {
                            MapRouteDetailView(
                                route: route,
                                waypoints: store.waypoints(for: route.id),
                                locationService: locationService,
                                store: store
                            )
                        } label: {
                            MapRouteRow(
                                route: route,
                                firstWaypoint: store.waypoints(for: route.id).first,
                                currentLocation: locationService.currentLocation,
                                taskLinks: store.taskLinks(forRouteID: route.id),
                                onSelectTask: selectTask
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .refreshable {
            await store.refresh()
            locationService.requestFreshLocation()
        }
    }

    private var placeDeleteMessage: String {
        guard let place = placeToDelete else { return "This action cannot be undone." }
        let links = store.taskLinks(forPlaceID: place.id)
        guard !links.isEmpty else { return "This action cannot be undone." }
        if links.count == 1, let link = links.first {
            return "This place belongs to \(link.task_title) and will be removed from that task."
        }
        return "This place will be removed from \(links.count) linked tasks."
    }

    private func selectTask(_ taskID: Int64) {
        selectedTask = model.getTask(by: taskID)
    }
}

private struct MapPlaceRow: View {
    let place: MapPlaceItem
    let currentLocation: CLLocation?
    let taskLinks: [TaskMapLinkSummary]
    let onSelectTask: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(
                MapsLocationTextFormatter.subtitle(
                    latitude: place.latitude,
                    longitude: place.longitude,
                    address: place.address,
                    currentLocation: currentLocation
                )
            )
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(AppTheme.textSecondary)
            .lineLimit(2)

            TaskMapLinkBadge(links: taskLinks, onSelectTask: onSelectTask)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

private struct MapRouteRow: View {
    let route: MapRouteRecord
    let firstWaypoint: MapRouteWaypointRecord?
    let currentLocation: CLLocation?
    let taskLinks: [TaskMapLinkSummary]
    let onSelectTask: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(route.name)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            if let firstWaypoint {
                Text(
                    MapsLocationTextFormatter.subtitle(
                        latitude: firstWaypoint.latitude,
                        longitude: firstWaypoint.longitude,
                        address: nil,
                        currentLocation: currentLocation
                    )
                )
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            }

            TaskMapLinkBadge(links: taskLinks, onSelectTask: onSelectTask)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

private struct EditMapPlaceSheet: View {
    let place: MapPlaceRecord
    let folders: [MapFolderRecord]
    let onSave: (String, Int64) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var folderID: Int64
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        place: MapPlaceRecord,
        folders: [MapFolderRecord],
        onSave: @escaping (String, Int64) async throws -> Void
    ) {
        self.place = place
        self.folders = folders
        self.onSave = onSave
        _name = State(initialValue: place.name)
        _folderID = State(initialValue: place.folder_id)
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Place") {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _, value in
                            if value.count > 100 {
                                name = String(value.prefix(100))
                            }
                        }
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
            .navigationTitle("Edit Place")
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
                    .disabled(normalizedName.isEmpty || normalizedName.count > 100 || isSaving)
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
            try await onSave(normalizedName, folderID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MoveMapPlaceSheet: View {
    let place: MapPlaceRecord
    let folders: [MapFolderRecord]
    let onMove: (Int64) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var folderID: Int64
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        place: MapPlaceRecord,
        folders: [MapFolderRecord],
        onMove: @escaping (Int64) async throws -> Void
    ) {
        self.place = place
        self.folders = folders
        self.onMove = onMove
        _folderID = State(initialValue: place.folder_id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    Picker("Folder", selection: $folderID) {
                        ForEach(folders) { folder in
                            Text(folder.name).tag(folder.id)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppTheme.errorTint)
                    }
                }
            }
            .navigationTitle("Move \(place.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        Task { await move() }
                    }
                    .disabled(folderID == place.folder_id || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func move() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onMove(folderID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
