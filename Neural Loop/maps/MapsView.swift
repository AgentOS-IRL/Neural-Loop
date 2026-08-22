import SwiftUI

struct MapsView: View {
    @ObservedObject var store: MapsStore
    @ObservedObject var coordinator: ParkingDetectionCoordinator
    @StateObject private var locationService = MapsLocationService()
    @Environment(\.scenePhase) private var scenePhase

    @State private var folderEditor: MapFolderEditorContext?
    @State private var folderToDelete: MapFolderRecord?
    @State private var mutationErrorMessage: String?
    @State private var isStopConfirmationPresented = false
    @State private var deepLinkedParkingPlace: ParkingPlaceReference?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        folderEditor = .create
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .disabled(store.isMutating || store.snapshot == nil)
                    .accessibilityLabel("Add Folder")
                }
            }
            .task {
                await store.loadIfNeeded()
                coordinator.handleAppBecameActive()
                locationService.handleMapsOpen()
                if let clientEventID = coordinator.pendingDeepLinkClientEventID {
                    deepLinkedParkingPlace = .client(clientEventID)
                    coordinator.pendingDeepLinkClientEventID = nil
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                locationService.requestFreshLocation()
                coordinator.handleAppBecameActive()
            }
            .onChange(of: coordinator.pendingDeepLinkClientEventID) { _, clientEventID in
                guard let clientEventID else { return }
                deepLinkedParkingPlace = .client(clientEventID)
                coordinator.pendingDeepLinkClientEventID = nil
            }
            .sheet(item: $folderEditor) { context in
                MapFolderEditorSheet(
                    folder: context.folder,
                    nameIsAvailable: { candidate in
                        store.folderNameIsAvailable(candidate, excluding: context.folder?.id)
                    },
                    onSave: { name, description in
                        if let folder = context.folder {
                            _ = try await store.updateFolder(
                                folder,
                                name: name,
                                description: description
                            )
                        } else {
                            _ = try await store.createFolder(name: name, description: description)
                        }
                    }
                )
            }
            .confirmationDialog(
                folderToDelete.map { "Delete \($0.name)?" } ?? "Delete folder?",
                isPresented: Binding(
                    get: { folderToDelete != nil },
                    set: { if !$0 { folderToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Folder", role: .destructive) {
                    guard let folder = folderToDelete else { return }
                    Task {
                        do {
                            _ = try await store.deleteFolder(folder)
                        } catch {
                            mutationErrorMessage = error.localizedDescription
                        }
                        folderToDelete = nil
                    }
                }
                .disabled(store.isMutating)

                Button("Cancel", role: .cancel) {
                    folderToDelete = nil
                }
            } message: {
                Text("Its places and routes will move to Unfiled.")
            }
            .alert(
                "Maps action failed",
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
            .confirmationDialog(
                "Stop without saving a parking location?",
                isPresented: $isStopConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Stop Without Saving", role: .destructive) {
                    coordinator.stopFromUser()
                }
                Button("Keep Detecting", role: .cancel) {}
            }
            .sheet(item: $deepLinkedParkingPlace) { reference in
                NavigationStack {
                    MapPlaceDetailView(
                        placeReference: reference,
                        store: store,
                        coordinator: coordinator,
                        locationService: locationService
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("Loading Maps…")
                .font(.system(.body, design: .rounded, weight: .semibold))
        case .failed(let message):
            if store.activeParkingPlaces().isEmpty && store.parkingHistory().isEmpty {
                MapsCenteredErrorView(message: message) {
                    Task { await store.refresh() }
                }
            } else {
                folderList
            }
        case .loaded:
            folderList
        }
    }

    private var folderList: some View {
        List {
            if coordinator.phase.isActive {
                ParkingDetectionBanner(phase: coordinator.phase) {
                    if coordinator.phase == .waitingForDrive || coordinator.phase == .preparing {
                        coordinator.stopFromUser()
                    } else {
                        isStopConfirmationPresented = true
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            let activeParkingPlaces = store.activeParkingPlaces()
            if !activeParkingPlaces.isEmpty {
                Section("Active Temporary Places") {
                    ForEach(activeParkingPlaces) { place in
                        NavigationLink {
                            MapPlaceDetailView(
                                placeReference: place.id,
                                store: store,
                                coordinator: coordinator,
                                locationService: locationService
                            )
                        } label: {
                            ParkingPlaceRow(place: place)
                        }
                    }
                }
            }

            let parkingHistory = store.parkingHistory()
            if !parkingHistory.isEmpty {
                NavigationLink {
                    ParkingHistoryView(
                        store: store,
                        coordinator: coordinator,
                        locationService: locationService
                    )
                } label: {
                    HStack {
                        Label("Parking History", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text("\(parkingHistory.count)")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            if let outcome = coordinator.latestOutcomeMessage {
                VStack(alignment: .leading, spacing: 10) {
                    MapsInlineBanner(
                        title: "Parking wasn't saved",
                        message: outcome,
                        systemImage: "parkingsign.circle"
                    )
                    HStack {
                        if coordinator.latestOutcomeNeedsSettings {
                            Button("Open Settings") { locationService.openSettings() }
                                .font(.system(.caption, design: .rounded, weight: .bold))
                        }
                        Spacer()
                        Button("Dismiss") { coordinator.dismissLatestOutcome() }
                            .font(.system(.caption, design: .rounded, weight: .bold))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if locationService.isDeniedOrRestricted {
                MapsPermissionBanner(openSettings: locationService.openSettings)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if let refreshErrorMessage = store.refreshErrorMessage {
                MapsInlineBanner(
                    title: "Maps may be out of date",
                    message: refreshErrorMessage,
                    systemImage: "arrow.clockwise.circle"
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if case .failed(let message) = store.loadState {
                MapsInlineBanner(
                    title: "Supabase is unavailable",
                    message: message,
                    systemImage: "wifi.slash"
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if store.sortedFolders.isEmpty {
                ContentUnavailableView(
                    "No folders",
                    systemImage: "folder",
                    description: Text("Pull to refresh Maps.")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(store.sortedFolders) { folder in
                    NavigationLink {
                        MapFolderDetailView(
                            folderID: folder.id,
                            store: store,
                            coordinator: coordinator,
                            locationService: locationService
                        )
                    } label: {
                        MapFolderRow(folder: folder)
                    }
                    .listRowBackground(AppTheme.cardGradient)
                    .listRowSeparatorTint(AppTheme.textSecondary.opacity(0.2))
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            folderEditor = .edit(folder)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(AppTheme.accentColor)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !folder.is_default {
                            Button(role: .destructive) {
                                folderToDelete = folder
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .contextMenu {
                        Button("Edit Folder", systemImage: "pencil") {
                            folderEditor = .edit(folder)
                        }

                        if !folder.is_default {
                            Button(role: .destructive) {
                                folderToDelete = folder
                            } label: {
                                Label("Delete Folder", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .refreshable {
            await store.refresh()
            locationService.requestFreshLocation()
        }
    }
}

private enum MapFolderEditorContext: Identifiable {
    case create
    case edit(MapFolderRecord)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let folder):
            return "edit-\(folder.id)"
        }
    }

    var folder: MapFolderRecord? {
        switch self {
        case .create:
            return nil
        case .edit(let folder):
            return folder
        }
    }
}

private struct MapFolderRow: View {
    let folder: MapFolderRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(folder.name)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            if let description = folder.description, !description.isEmpty {
                Text(description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

struct MapsPermissionBanner: View {
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "location.slash")
                .foregroundStyle(AppTheme.warningTint)
                .font(.title3)

            VStack(alignment: .leading, spacing: 5) {
                Text("Location is off")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Allow location access to show distances and your position on maps.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 4)

            Button("Settings", action: openSettings)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
        }
        .padding(16)
        .background(AppTheme.sectionGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
    }
}

struct MapsInlineBanner: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.warningTint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(message)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.sectionGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct MapsCenteredErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Maps unavailable", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentColor)
        }
        .padding()
    }
}

private struct MapFolderEditorSheet: View {
    let folder: MapFolderRecord?
    let nameIsAvailable: (String) -> Bool
    let onSave: (String, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var folderDescription: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        folder: MapFolderRecord?,
        nameIsAvailable: @escaping (String) -> Bool,
        onSave: @escaping (String, String?) async throws -> Void
    ) {
        self.folder = folder
        self.nameIsAvailable = nameIsAvailable
        self.onSave = onSave
        _name = State(initialValue: folder?.name ?? "")
        _folderDescription = State(initialValue: folder?.description ?? "")
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedDescription: String? {
        let value = folderDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var validationMessage: String? {
        if normalizedName.isEmpty {
            return "Enter a folder name."
        }
        if normalizedName.count > 100 {
            return "Folder names are limited to 100 characters."
        }
        if folderDescription.count > 500 {
            return "Descriptions are limited to 500 characters."
        }
        if !nameIsAvailable(normalizedName) {
            return "A folder with this name already exists."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Folder") {
                    TextField("Name", text: $name)
                        .disabled(folder?.is_default == true)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 100 {
                                name = String(newValue.prefix(100))
                            }
                        }

                    TextField("Description (optional)", text: $folderDescription, axis: .vertical)
                        .lineLimit(3...8)
                        .onChange(of: folderDescription) { _, newValue in
                            if newValue.count > 500 {
                                folderDescription = String(newValue.prefix(500))
                            }
                        }

                    Text("\(folderDescription.count)/500")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if folder?.is_default == true {
                    Section {
                        Text("Unfiled can have its description changed, but its name is permanent.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = errorMessage ?? validationMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(AppTheme.errorTint)
                    }
                }
            }
            .navigationTitle(folder == nil ? "Add Folder" : "Edit Folder")
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
                    .disabled(validationMessage != nil || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() async {
        guard validationMessage == nil else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await onSave(normalizedName, normalizedDescription)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
