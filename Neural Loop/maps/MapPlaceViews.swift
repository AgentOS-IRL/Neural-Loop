import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct AddMapPlaceSheet: View {
    let folders: [MapFolderRecord]
    let onSave: (CreateMapPlaceRequest) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var folderID: Int64
    @State private var importedPlace: ImportedMapPlace?
    @State private var name = ""
    @State private var isResolving = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let importer = MapLinkImporter()

    init(
        folders: [MapFolderRecord],
        initialFolderID: Int64,
        onSave: @escaping (CreateMapPlaceRequest) async throws -> Void
    ) {
        self.folders = folders
        self.onSave = onSave
        _folderID = State(initialValue: initialFolderID)
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Maps URL") {
                    TextField("Apple Maps or Google Maps URL", text: $urlText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...5)
                        .onChange(of: urlText) {
                            importedPlace = nil
                            name = ""
                            errorMessage = nil
                        }

                    HStack {
                        PasteButton(payloadType: String.self) { values in
                            if let value = values.first {
                                urlText = value
                            }
                        }

                        Spacer()

                        Button(importedPlace == nil ? "Resolve" : "Resolve Again") {
                            Task { await resolve() }
                        }
                        .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResolving || isSaving)
                    }

                    if isResolving {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Resolving place…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Folder") {
                    Picker("Folder", selection: $folderID) {
                        ForEach(folders) { folder in
                            Text(folder.name).tag(folder.id)
                        }
                    }
                }

                if let importedPlace {
                    Section("Place Preview") {
                        TextField("Name", text: $name)
                            .onChange(of: name) { _, value in
                                if value.count > 100 {
                                    name = String(value.prefix(100))
                                }
                            }

                        if let address = importedPlace.address, !address.isEmpty {
                            Text(address)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(
                                MapsLocationTextFormatter.coordinates(
                                    latitude: importedPlace.coordinate.latitude,
                                    longitude: importedPlace.coordinate.longitude
                                )
                            )
                            .foregroundStyle(.secondary)
                        }

                        PlaceImportPreviewMap(coordinate: importedPlace.coordinate)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .id("\(importedPlace.coordinate.latitude),\(importedPlace.coordinate.longitude)")
                    }
                }

                if let errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(errorMessage)
                                .foregroundStyle(AppTheme.errorTint)
                            Button("Retry") {
                                Task { await resolve() }
                            }
                            .disabled(isResolving || isSaving)
                        }
                    }
                }
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isResolving || isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(
                        importedPlace == nil ||
                        normalizedName.isEmpty ||
                        normalizedName.count > 100 ||
                        isResolving ||
                        isSaving
                    )
                }
            }
            .interactiveDismissDisabled(isResolving || isSaving)
        }
    }

    private func resolve() async {
        isResolving = true
        errorMessage = nil
        importedPlace = nil
        defer { isResolving = false }

        do {
            let result = try await importer.resolve(urlText)
            importedPlace = result
            name = result.suggestedName ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let importedPlace, !normalizedName.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await onSave(
                CreateMapPlaceRequest(
                    folder_id: folderID,
                    name: normalizedName,
                    latitude: importedPlace.coordinate.latitude,
                    longitude: importedPlace.coordinate.longitude,
                    address: importedPlace.address
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PlaceImportPreviewMap: View {
    let coordinate: CLLocationCoordinate2D
    @State private var position: MapCameraPosition

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
        )
    }

    var body: some View {
        Map(position: $position) {
            Marker("Imported place", coordinate: coordinate)
                .tint(AppTheme.accentColor)
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .accessibilityLabel("Map preview with a fixed pin")
    }
}

struct MapPlaceDetailView: View {
    let placeReference: ParkingPlaceReference
    @ObservedObject var store: MapsStore
    @ObservedObject var coordinator: ParkingDetectionCoordinator
    @ObservedObject var locationService: MapsLocationService
    @EnvironmentObject private var model: UnifiedDataModel

    @State private var isOpenPlacePresented = false
    @State private var onboardingProvider: ExternalMapProvider?
    @State private var isSavePermanentlyPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var actionErrorMessage: String?
    @State private var selectedTask: Tasks?
    @State private var isSaveTaskOwnedPresented = false
    @State private var isDeleteTaskOwnedPresented = false

    private var place: MapPlaceItem? {
        store.place(reference: placeReference)
    }

    private var taskLinks: [TaskMapLinkSummary] {
        guard let placeID = place?.remoteID else { return [] }
        return store.taskLinks(forPlaceID: placeID)
    }

    private var ownerLink: TaskMapLinkSummary? {
        taskLinks.first { $0.relationship == .owner }
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            if let place {
                VStack(spacing: 0) {
                    SavedPlaceMap(place: place, showsUserLocation: locationService.isAuthorized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(place.name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(place.address ?? MapsLocationTextFormatter.coordinates(
                            latitude: place.latitude,
                            longitude: place.longitude
                        ))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)

                        if place.kind == .parked, let parkedAt = place.parkedAt {
                            Label(
                                "Parked \(parkedAt.formatted(date: .abbreviated, time: .shortened))",
                                systemImage: "parkingsign.circle.fill"
                            )
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        }

                        if place.kind == .parked, let expiresAt = place.expiresAt {
                            Text(parkingExpiryText(for: place, expiresAt: expiresAt))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(place.isExpiredParked() ? AppTheme.textSecondary : AppTheme.warningTint)
                        }

                        if place.isSyncPending {
                            HStack {
                                Label("Sync Pending", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(AppTheme.warningTint)
                                Spacer()
                                Button("Retry") {
                                    Task { await coordinator.retryPendingSynchronization(force: true) }
                                }
                                .font(.system(.caption, design: .rounded, weight: .bold))
                            }
                        }

                        TaskMapLinkBadge(
                            links: taskLinks,
                            onSelectTask: { taskID in
                                selectedTask = model.getTask(by: taskID)
                            }
                        )

                        Button {
                            isOpenPlacePresented = true
                        } label: {
                            Label("Open Place", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentColor)

                        if place.kind == .parked {
                            HStack {
                                Button("Save Permanently") {
                                    isSavePermanentlyPresented = true
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                Button("Delete", role: .destructive) {
                                    isDeleteConfirmationPresented = true
                                }
                                .buttonStyle(.bordered)
                            }
                        } else if ownerLink != nil {
                            HStack {
                                Button("Save Permanently") {
                                    isSaveTaskOwnedPresented = true
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                Button("Delete", role: .destructive) {
                                    isDeleteTaskOwnedPresented = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 84)
                    .background(.ultraThinMaterial)
                }
            } else {
                ContentUnavailableView(
                    "Place unavailable",
                    systemImage: "mappin.slash",
                    description: Text("Return to the folder and refresh.")
                )
            }
        }
        .navigationTitle(place?.name ?? "Place")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let place,
                   place.kind == .saved,
                   !place.isSyncPending,
                   store.remoteRecord(for: place) != nil {
                    Button {
                        setPinned(!place.pinned, for: place)
                    } label: {
                        Image(systemName: place.pinned ? "pin.slash" : "pin")
                    }
                    .disabled(store.isMutating)
                    .accessibilityLabel(place.pinned ? "Unpin Place" : "Pin Place")
                }
            }
        }
        .confirmationDialog(
            "Open Place",
            isPresented: $isOpenPlacePresented,
            titleVisibility: .visible
        ) {
            if let place {
                Button("Apple Maps") { open(place, with: .apple) }
                    .disabled(!MapAppAvailability.isAppleMapsInstalled)
                Button("Google Maps") { open(place, with: .google) }
                    .disabled(!MapAppAvailability.isGoogleMapsInstalled)
                Button("Waze") { open(place, with: .waze) }
                    .disabled(!MapAppAvailability.isWazeInstalled)
                if let shareURL = ExternalMapProvider.canonicalAppleURL(for: place) {
                    ShareLink("Send to Mercedes-Benz", item: shareURL)
                }
                Button("Copy Place Details") { copyDetails(for: place) }
            }
            Button("Cancel", role: .cancel) {}
        }

        .sheet(item: $onboardingProvider) { provider in
            if let place {
                ParkingDetectionSetupSheet(
                    provider: provider,
                    onEnable: {
                        let enabled = await coordinator.enableFromUserAction()
                        if enabled {
                            await coordinator.openEligiblePlace(place, with: provider)
                        } else {
                            await coordinator.openDirectly(place, with: provider)
                        }
                    },
                    onOpenWithoutDetection: {
                        coordinator.declineOnboarding()
                        await coordinator.openDirectly(place, with: provider)
                    }
                )
            }
        }
        .sheet(isPresented: $isSavePermanentlyPresented) {
            if let place, let initialFolderID = store.unfiledFolder?.id {
                SaveParkingPermanentlySheet(
                    place: place,
                    folders: store.sortedFolders,
                    initialFolderID: initialFolderID,
                    onSave: { folderID, name in
                        try coordinator.savePermanently(place, folderID: folderID, name: name)
                    }
                )
            }
        }
        .sheet(isPresented: $isSaveTaskOwnedPresented) {
            if let placeID = place?.remoteID,
               let record = store.snapshot?.places.first(where: { $0.id == placeID }),
               let ownerLink,
               let initialFolderID = store.unfiledFolder?.id {
                SaveTaskOwnedPlaceSheet(
                    place: record,
                    folders: store.sortedFolders,
                    initialFolderID: initialFolderID
                ) { folderID, name in
                    try await store.saveTaskOwnedPlace(
                        taskID: ownerLink.task_id,
                        placeID: placeID,
                        folderID: folderID,
                        name: name
                    )
                }
            }
        }
        .confirmationDialog(
            "Delete this parking location?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let place else { return }
                do {
                    try coordinator.deleteParkingPlace(place)
                } catch {
                    actionErrorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be removed locally now and deleted from Supabase when synchronization succeeds.")
        }
        .confirmationDialog(
            "Delete this task-owned place?",
            isPresented: $isDeleteTaskOwnedPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Place", role: .destructive) {
                guard let placeID = place?.remoteID, let ownerLink else { return }
                Task {
                    do {
                        try await store.deleteTaskOwnedPlace(
                            taskID: ownerLink.task_id,
                            placeID: placeID
                        )
                    } catch {
                        actionErrorMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The place will be permanently deleted and removed from \(ownerLink?.task_title ?? "the task").")
        }
        .alert(
            "Maps action failed",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { if !$0 { actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionErrorMessage ?? "Please try again.")
        }
        .sheet(item: $selectedTask) { task in
            IndividualTodoView(task: task)
        }
    }

    private func open(_ place: MapPlaceItem, with provider: ExternalMapProvider) {
        isOpenPlacePresented = false
        if place.kind == .saved, coordinator.shouldPresentOnboarding {
            onboardingProvider = provider
            return
        }
        Task {
            if place.kind == .saved, coordinator.isEnabled {
                await coordinator.openEligiblePlace(place, with: provider)
            } else {
                await coordinator.openDirectly(place, with: provider)
            }
        }
    }

    private func setPinned(_ pinned: Bool, for place: MapPlaceItem) {
        guard let record = store.remoteRecord(for: place) else { return }
        Task {
            do {
                _ = try await store.setPlacePinned(record, pinned: pinned)
            } catch {
                actionErrorMessage = error.localizedDescription
            }
        }
    }

    private func copyDetails(for place: MapPlaceItem) {
        guard let canonicalURL = ExternalMapProvider.canonicalAppleURL(for: place) else { return }
        UIPasteboard.general.string = """
        \(place.name)
        \(place.latitude),\(place.longitude)
        \(canonicalURL.absoluteString)
        """
    }

    private func parkingExpiryText(for place: MapPlaceItem, expiresAt: Date) -> String {
        guard place.isExpiredParked() else {
            return "Expires \(expiresAt.formatted(date: .omitted, time: .shortened))"
        }
        switch place.expiryReason {
        case .some(.endOfDay):
            return "Expired at the end of the parking day"
        case .some(.newVehicleTrip):
            return "Expired when a new vehicle trip began"
        case nil:
            return "Expired"
        }
    }
}

private struct SavedPlaceMap: View {
    let place: MapPlaceItem
    let showsUserLocation: Bool
    @State private var position: MapCameraPosition

    init(place: MapPlaceItem, showsUserLocation: Bool) {
        self.place = place
        self.showsUserLocation = showsUserLocation
        let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
        )
    }

    var body: some View {
        Map(position: $position) {
            Marker(
                place.name,
                coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            )
            .tint(AppTheme.accentColor)

            if showsUserLocation {
                UserAnnotation()
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }
}
