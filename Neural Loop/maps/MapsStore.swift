import Combine
import Foundation

enum MapsLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

enum MapsStoreError: LocalizedError {
    case mutationInProgress
    case missingUnfiledFolder

    var errorDescription: String? {
        switch self {
        case .mutationInProgress:
            return "Another Maps change is still being saved."
        case .missingUnfiledFolder:
            return "The Unfiled folder is missing. Refresh Maps and try again."
        }
    }
}

@MainActor
final class MapsStore: ObservableObject {
    @Published private(set) var snapshot: MapsSnapshot?
    @Published private(set) var loadState: MapsLoadState = .idle
    @Published private(set) var isRefreshing = false
    @Published private(set) var isMutating = false
    @Published var refreshErrorMessage: String?
    @Published private(set) var parkingOverlayItems: [MapPlaceItem] = []
    @Published private(set) var parkingDeletedClientIDs: Set<UUID> = []
    @Published private(set) var syncedParkingCache: [UUID: MapPlaceItem] = [:]

    private let manager: DBManager

    init(manager: DBManager) {
        self.manager = manager
    }

    var sortedFolders: [MapFolderRecord] {
        (snapshot?.folders ?? []).sorted { lhs, rhs in
            if lhs.is_default != rhs.is_default {
                return lhs.is_default
            }

            let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
        }
    }

    var unfiledFolder: MapFolderRecord? {
        snapshot?.folders.first(where: \.is_default)
    }

    func folder(id: Int64) -> MapFolderRecord? {
        snapshot?.folders.first { $0.id == id }
    }

    func places(in folderID: Int64) -> [MapPlaceRecord] {
        (snapshot?.places ?? [])
            .filter { $0.folder_id == folderID && $0.kind == .saved }
            .sorted { lhs, rhs in
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
            }
    }

    func savedPlaceItems(in folderID: Int64) -> [MapPlaceItem] {
        allPlaceItems
            .filter { $0.kind == .saved && $0.folderID == folderID }
            .sorted { lhs, rhs in
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if comparison != .orderedSame { return comparison == .orderedAscending }
                return lhs.id.id < rhs.id.id
            }
    }

    func remoteRecord(for item: MapPlaceItem) -> MapPlaceRecord? {
        snapshot?.places.first { record in
            record.id == item.remoteID ||
            (item.clientEventID != nil && record.client_event_id == item.clientEventID)
        }
    }

    var allPlaceItems: [MapPlaceItem] {
        var merged: [ParkingPlaceReference: MapPlaceItem] = [:]

        for record in snapshot?.places ?? [] {
            guard record.client_event_id.map({ !parkingDeletedClientIDs.contains($0) }) ?? true else {
                continue
            }
            let item = MapPlaceItem(record: record)
            merged[item.id] = item
        }

        for item in syncedParkingCache.values where
            item.clientEventID.map({ !parkingDeletedClientIDs.contains($0) }) ?? true {
            merged[item.id] = item
        }

        for item in parkingOverlayItems {
            merged[item.id] = item
        }

        return Array(merged.values)
    }

    func activeParkingPlaces(at date: Date = .now) -> [MapPlaceItem] {
        allPlaceItems
            .filter { $0.isActiveParked(at: date) }
            .sorted { ($0.parkedAt ?? $0.createdAt) > ($1.parkedAt ?? $1.createdAt) }
    }

    func parkingHistory(at date: Date = .now) -> [MapPlaceItem] {
        allPlaceItems
            .filter { $0.isExpiredParked(at: date) }
            .sorted { ($0.parkedAt ?? $0.createdAt) > ($1.parkedAt ?? $1.createdAt) }
    }

    func place(reference: ParkingPlaceReference) -> MapPlaceItem? {
        allPlaceItems.first { item in
            if item.id == reference { return true }
            if case .remote(let remoteID) = reference { return item.remoteID == remoteID }
            return false
        }
    }

    func setParkingOverlay(items: [MapPlaceItem], deletedClientIDs: Set<UUID>) {
        parkingOverlayItems = items
        parkingDeletedClientIDs = deletedClientIDs
    }

    func applySyncedParkingPlace(_ place: MapPlaceRecord) {
        if let clientEventID = place.client_event_id {
            syncedParkingCache[clientEventID] = MapPlaceItem(record: place)
        }
        if let index = snapshot?.places.firstIndex(where: {
            $0.id == place.id ||
            ($0.client_event_id != nil && $0.client_event_id == place.client_event_id)
        }) {
            snapshot?.places[index] = place
        } else {
            snapshot?.places.append(place)
        }
    }

    func removeParkingPlace(clientEventID: UUID) {
        syncedParkingCache.removeValue(forKey: clientEventID)
        snapshot?.places.removeAll { $0.client_event_id == clientEventID }
    }

    func routes(in folderID: Int64) -> [MapRouteRecord] {
        (snapshot?.routes ?? [])
            .filter { $0.folder_id == folderID }
            .sorted { lhs, rhs in
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
            }
    }

    func waypoints(for routeID: Int64) -> [MapRouteWaypointRecord] {
        (snapshot?.route_waypoints ?? [])
            .filter { $0.route_id == routeID }
            .sorted {
                if $0.order_index != $1.order_index {
                    return $0.order_index < $1.order_index
                }
                return $0.id < $1.id
            }
    }

    func folderNameIsAvailable(_ candidate: String, excluding folderID: Int64? = nil) -> Bool {
        let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return !(snapshot?.folders ?? []).contains { folder in
            folder.id != folderID && folder.name.caseInsensitiveCompare(normalized) == .orderedSame
        }
    }

    func loadIfNeeded() async {
        guard snapshot == nil, loadState != .loading else { return }
        await loadSnapshot(showInitialLoading: true)
    }

    func refresh() async {
        guard !isMutating else { return }
        await loadSnapshot(showInitialLoading: snapshot == nil)
    }

    func createFolder(name: String, description: String?) async throws -> MapFolderRecord {
        try beginMutation()
        defer { isMutating = false }

        let folder = try await manager.createMapFolder(
            CreateMapFolderRequest(name: name, description: description)
        )
        snapshot?.folders.append(folder)
        return folder
    }

    func updateFolder(
        _ folder: MapFolderRecord,
        name: String,
        description: String?
    ) async throws -> MapFolderRecord {
        try beginMutation()
        defer { isMutating = false }

        let updated = try await manager.updateMapFolder(
            id: folder.id,
            request: UpdateMapFolderRequest(name: name, description: description)
        )
        replaceFolder(updated)
        return updated
    }

    func deleteFolder(_ folder: MapFolderRecord) async throws -> DeleteMapFolderReceipt {
        try beginMutation()
        defer { isMutating = false }

        guard let unfiledID = unfiledFolder?.id else {
            throw MapsStoreError.missingUnfiledFolder
        }

        let receipt = try await manager.deleteMapFolder(id: folder.id)

        snapshot?.folders.removeAll { $0.id == folder.id }
        snapshot?.places = snapshot?.places.map { place in
            guard place.folder_id == folder.id else { return place }
            return place.moving(to: unfiledID)
        } ?? []
        snapshot?.routes = snapshot?.routes.map { route in
            guard route.folder_id == folder.id else { return route }
            return route.moving(to: unfiledID)
        } ?? []

        do {
            let refreshed = try await manager.fetchMapsSnapshot()
            snapshot = refreshed
            for clientEventID in refreshed.places.compactMap(\.client_event_id) {
                syncedParkingCache.removeValue(forKey: clientEventID)
            }
            loadState = .loaded
            refreshErrorMessage = nil
        } catch {
            refreshErrorMessage = "The folder was deleted, but Maps could not refresh. Pull to refresh when you are online."
        }

        return receipt
    }

    func createPlace(_ request: CreateMapPlaceRequest) async throws -> MapPlaceRecord {
        try beginMutation()
        defer { isMutating = false }

        let place = try await manager.createMapPlace(request)
        snapshot?.places.append(place)
        return place
    }

    func updatePlace(
        _ place: MapPlaceRecord,
        name: String,
        folderID: Int64
    ) async throws -> MapPlaceRecord {
        try beginMutation()
        defer { isMutating = false }

        let updated = try await manager.updateMapPlace(
            id: place.id,
            request: UpdateMapPlaceRequest(folder_id: folderID, name: name)
        )
        replacePlace(updated)
        return updated
    }

    func movePlace(_ place: MapPlaceRecord, to folderID: Int64) async throws -> MapPlaceRecord {
        try beginMutation()
        defer { isMutating = false }

        let moved = try await manager.moveMapPlace(id: place.id, folderID: folderID)
        replacePlace(moved)
        return moved
    }

    func deletePlace(_ place: MapPlaceRecord) async throws {
        try beginMutation()
        defer { isMutating = false }

        let deleted = try await manager.deleteMapPlace(id: place.id)
        snapshot?.places.removeAll { $0.id == deleted.id }
    }

    private func loadSnapshot(showInitialLoading: Bool) async {
        if showInitialLoading {
            loadState = .loading
        } else {
            isRefreshing = true
        }

        defer { isRefreshing = false }

        do {
            let fetched = try await manager.fetchMapsSnapshot()
            snapshot = fetched
            for clientEventID in fetched.places.compactMap(\.client_event_id) {
                syncedParkingCache.removeValue(forKey: clientEventID)
            }
            loadState = .loaded
            refreshErrorMessage = nil
        } catch {
            if snapshot == nil {
                loadState = .failed(error.localizedDescription)
            } else {
                loadState = .loaded
                refreshErrorMessage = error.localizedDescription
            }
        }
    }

    private func beginMutation() throws {
        guard !isMutating else {
            throw MapsStoreError.mutationInProgress
        }
        isMutating = true
    }

    private func replaceFolder(_ folder: MapFolderRecord) {
        guard let index = snapshot?.folders.firstIndex(where: { $0.id == folder.id }) else { return }
        snapshot?.folders[index] = folder
    }

    private func replacePlace(_ place: MapPlaceRecord) {
        guard let index = snapshot?.places.firstIndex(where: { $0.id == place.id }) else { return }
        snapshot?.places[index] = place
    }
}

private extension MapPlaceRecord {
    func moving(to folderID: Int64) -> MapPlaceRecord {
        MapPlaceRecord(
            id: id,
            folder_id: folderID,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            kind: kind,
            client_event_id: client_event_id,
            parked_at: parked_at,
            expires_at: expires_at,
            expired_at: expired_at,
            expiry_reason: expiry_reason,
            created_at: created_at,
            updated_at: updated_at
        )
    }
}

private extension MapRouteRecord {
    func moving(to folderID: Int64) -> MapRouteRecord {
        MapRouteRecord(
            id: id,
            folder_id: folderID,
            name: name,
            transport_mode: transport_mode,
            created_at: created_at,
            updated_at: updated_at
        )
    }
}
