import Foundation
import Supabase

nonisolated struct MapFolderRecord: Codable, Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    let description: String?
    let is_default: Bool
    let created_at: Date
    let updated_at: Date

    static let tableName = "map_folders"
    static let selectedColumns = "id, name, description, is_default, created_at, updated_at"
}

nonisolated enum MapPlaceKind: String, Codable, CaseIterable, Sendable {
    case saved
    case parked
}

nonisolated enum ParkingExpiryReason: String, Codable, CaseIterable, Sendable {
    case endOfDay = "end_of_day"
    case newVehicleTrip = "new_vehicle_trip"
}

nonisolated struct MapPlaceRecord: Codable, Identifiable, Equatable, Sendable {
    let id: Int64
    let folder_id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let kind: MapPlaceKind
    let pinned: Bool
    let client_event_id: UUID?
    let parked_at: Date?
    let expires_at: Date?
    let expired_at: Date?
    let expiry_reason: ParkingExpiryReason?
    let created_at: Date
    let updated_at: Date

    static let tableName = "map_places"
    static let selectedColumns = "id, folder_id, name, latitude, longitude, address, kind, pinned, client_event_id, parked_at, expires_at, expired_at, expiry_reason, created_at, updated_at"

    init(
        id: Int64,
        folder_id: Int64,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String?,
        kind: MapPlaceKind = .saved,
        pinned: Bool = false,
        client_event_id: UUID? = nil,
        parked_at: Date? = nil,
        expires_at: Date? = nil,
        expired_at: Date? = nil,
        expiry_reason: ParkingExpiryReason? = nil,
        created_at: Date,
        updated_at: Date
    ) {
        self.id = id
        self.folder_id = folder_id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.kind = kind
        self.pinned = pinned
        self.client_event_id = client_event_id
        self.parked_at = parked_at
        self.expires_at = expires_at
        self.expired_at = expired_at
        self.expiry_reason = expiry_reason
        self.created_at = created_at
        self.updated_at = updated_at
    }
}

nonisolated enum MapRouteTransportMode: String, Codable, CaseIterable, Sendable {
    case automobile
    case walking
    case cycling
    case transit
}

nonisolated struct MapRouteRecord: Codable, Identifiable, Equatable, Sendable {
    let id: Int64
    let folder_id: Int64
    let name: String
    let transport_mode: MapRouteTransportMode
    let pinned: Bool
    let created_at: Date
    let updated_at: Date

    static let tableName = "map_routes"
    static let selectedColumns = "id, folder_id, name, transport_mode, pinned, created_at, updated_at"
}

nonisolated struct MapRouteWaypointRecord: Codable, Identifiable, Equatable, Sendable {
    let id: Int64
    let route_id: Int64
    let order_index: Int
    let latitude: Double
    let longitude: Double
    let emoji: String?
    let created_at: Date

    static let tableName = "map_route_waypoints"
}

nonisolated struct MapsSnapshot: Codable, Equatable, Sendable {
    var folders: [MapFolderRecord]
    var places: [MapPlaceRecord]
    var routes: [MapRouteRecord]
    var route_waypoints: [MapRouteWaypointRecord]
    var task_links: [TaskMapLinkSummary]

    private enum CodingKeys: String, CodingKey {
        case folders
        case places
        case routes
        case route_waypoints
        case task_links
    }

    init(
        folders: [MapFolderRecord],
        places: [MapPlaceRecord],
        routes: [MapRouteRecord],
        route_waypoints: [MapRouteWaypointRecord],
        task_links: [TaskMapLinkSummary] = []
    ) {
        self.folders = folders
        self.places = places
        self.routes = routes
        self.route_waypoints = route_waypoints
        self.task_links = task_links
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        folders = try container.decode([MapFolderRecord].self, forKey: .folders)
        places = try container.decode([MapPlaceRecord].self, forKey: .places)
        routes = try container.decode([MapRouteRecord].self, forKey: .routes)
        route_waypoints = try container.decode([MapRouteWaypointRecord].self, forKey: .route_waypoints)
        task_links = try container.decodeIfPresent([TaskMapLinkSummary].self, forKey: .task_links) ?? []
    }
}

nonisolated struct CreateMapFolderRequest: Codable, Equatable, Sendable {
    let name: String
    let description: String?
}

nonisolated struct UpdateMapFolderRequest: Codable, Equatable, Sendable {
    let name: String
    let description: String?
}

nonisolated struct CreateMapPlaceRequest: Codable, Equatable, Sendable {
    let folder_id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
}

nonisolated struct UpdateMapPlaceRequest: Codable, Equatable, Sendable {
    let folder_id: Int64
    let name: String
}

nonisolated struct MoveMapPlaceRequest: Codable, Equatable, Sendable {
    let folder_id: Int64
}

nonisolated struct SetMapPinnedRequest: Codable, Equatable, Sendable {
    let pinned: Bool
}

nonisolated struct UpsertParkedPlaceParams: Codable, Equatable, Sendable {
    let p_client_event_id: UUID
    let p_latitude: Double
    let p_longitude: Double
    let p_parked_at: Date
    let p_expires_at: Date
    let p_expired_at: Date?
    let p_expiry_reason: String?
    let p_address: String?
}

nonisolated struct ExpireParkedPlacesParams: Codable, Equatable, Sendable {
    let p_expired_at: Date
    let p_expiry_reason: String
}

nonisolated struct MaterializeExpiredParkedPlacesParams: Codable, Equatable, Sendable {
    let p_now: Date
}

nonisolated struct ConvertParkedPlaceParams: Codable, Equatable, Sendable {
    let p_client_event_id: UUID
    let p_folder_id: Int64
    let p_name: String
}

nonisolated struct DeleteParkedPlaceParams: Codable, Equatable, Sendable {
    let p_client_event_id: UUID
}

nonisolated struct DeleteMapFolderParams: Codable, Equatable, Sendable {
    let p_folder_id: Int64
}

nonisolated struct DeleteMapFolderReceipt: Codable, Equatable, Sendable {
    let deleted_folder_id: Int64
    let moved_place_count: Int
    let moved_route_count: Int
}

enum MapsDatabaseError: LocalizedError {
    case insertReturnedNoRows
    case updateReturnedNoRows
    case deleteReturnedNoRows

    var errorDescription: String? {
        switch self {
        case .insertReturnedNoRows:
            return "Supabase did not confirm the new item."
        case .updateReturnedNoRows:
            return "Supabase did not confirm the change."
        case .deleteReturnedNoRows:
            return "Supabase did not confirm the deletion."
        }
    }
}

extension DBManager {
    func fetchMapsSnapshot() async throws -> MapsSnapshot {
        try await customsupabase
            .rpc("nl_get_maps_snapshot")
            .execute()
            .value
    }

    func createMapFolder(_ request: CreateMapFolderRequest) async throws -> MapFolderRecord {
        let rows: [MapFolderRecord] = try await customsupabase
            .from(MapFolderRecord.tableName)
            .insert(request)
            .select(MapFolderRecord.selectedColumns)
            .execute()
            .value

        guard let folder = rows.first else {
            throw MapsDatabaseError.insertReturnedNoRows
        }

        return folder
    }

    func updateMapFolder(id: Int64, request: UpdateMapFolderRequest) async throws -> MapFolderRecord {
        let rows: [MapFolderRecord] = try await customsupabase
            .from(MapFolderRecord.tableName)
            .update(request)
            .eq("id", value: Int(id))
            .select(MapFolderRecord.selectedColumns)
            .execute()
            .value

        guard let folder = rows.first else {
            throw MapsDatabaseError.updateReturnedNoRows
        }

        return folder
    }

    func deleteMapFolder(id: Int64) async throws -> DeleteMapFolderReceipt {
        try await customsupabase
            .rpc(
                "nl_delete_map_folder",
                params: DeleteMapFolderParams(p_folder_id: id)
            )
            .execute()
            .value
    }

    func createMapPlace(_ request: CreateMapPlaceRequest) async throws -> MapPlaceRecord {
        let rows: [MapPlaceRecord] = try await customsupabase
            .from(MapPlaceRecord.tableName)
            .insert(request)
            .select(MapPlaceRecord.selectedColumns)
            .execute()
            .value

        guard let place = rows.first else {
            throw MapsDatabaseError.insertReturnedNoRows
        }

        return place
    }

    func updateMapPlace(id: Int64, request: UpdateMapPlaceRequest) async throws -> MapPlaceRecord {
        let rows: [MapPlaceRecord] = try await customsupabase
            .from(MapPlaceRecord.tableName)
            .update(request)
            .eq("id", value: Int(id))
            .select(MapPlaceRecord.selectedColumns)
            .execute()
            .value

        guard let place = rows.first else {
            throw MapsDatabaseError.updateReturnedNoRows
        }

        return place
    }

    func moveMapPlace(id: Int64, folderID: Int64) async throws -> MapPlaceRecord {
        let rows: [MapPlaceRecord] = try await customsupabase
            .from(MapPlaceRecord.tableName)
            .update(MoveMapPlaceRequest(folder_id: folderID))
            .eq("id", value: Int(id))
            .select(MapPlaceRecord.selectedColumns)
            .execute()
            .value

        guard let place = rows.first else {
            throw MapsDatabaseError.updateReturnedNoRows
        }

        return place
    }

    func setMapPlacePinned(id: Int64, pinned: Bool) async throws -> MapPlaceRecord {
        let rows: [MapPlaceRecord] = try await customsupabase
            .from(MapPlaceRecord.tableName)
            .update(SetMapPinnedRequest(pinned: pinned))
            .eq("id", value: Int(id))
            .select(MapPlaceRecord.selectedColumns)
            .execute()
            .value

        guard let place = rows.first else {
            throw MapsDatabaseError.updateReturnedNoRows
        }

        return place
    }

    func setMapRoutePinned(id: Int64, pinned: Bool) async throws -> MapRouteRecord {
        let rows: [MapRouteRecord] = try await customsupabase
            .from(MapRouteRecord.tableName)
            .update(SetMapPinnedRequest(pinned: pinned))
            .eq("id", value: Int(id))
            .select(MapRouteRecord.selectedColumns)
            .execute()
            .value

        guard let route = rows.first else {
            throw MapsDatabaseError.updateReturnedNoRows
        }

        return route
    }

    func deleteMapPlace(id: Int64) async throws -> MapPlaceRecord {
        let rows: [MapPlaceRecord] = try await customsupabase
            .from(MapPlaceRecord.tableName)
            .delete()
            .eq("id", value: Int(id))
            .select(MapPlaceRecord.selectedColumns)
            .execute()
            .value

        guard let place = rows.first else {
            throw MapsDatabaseError.deleteReturnedNoRows
        }

        return place
    }

    func upsertParkedPlace(_ params: UpsertParkedPlaceParams) async throws -> MapPlaceRecord {
        try await customsupabase
            .rpc("nl_upsert_parked_place", params: params)
            .execute()
            .value
    }

    func expireActiveParkedPlaces(
        at date: Date,
        reason: ParkingExpiryReason
    ) async throws -> [MapPlaceRecord] {
        try await customsupabase
            .rpc(
                "nl_expire_active_parked_places",
                params: ExpireParkedPlacesParams(
                    p_expired_at: date,
                    p_expiry_reason: reason.rawValue
                )
            )
            .execute()
            .value
    }

    func materializeExpiredParkedPlaces(at date: Date) async throws -> [MapPlaceRecord] {
        try await customsupabase
            .rpc(
                "nl_materialize_expired_parked_places",
                params: MaterializeExpiredParkedPlacesParams(p_now: date)
            )
            .execute()
            .value
    }

    func convertParkedPlace(
        clientEventID: UUID,
        folderID: Int64,
        name: String
    ) async throws -> MapPlaceRecord {
        try await customsupabase
            .rpc(
                "nl_convert_parked_place",
                params: ConvertParkedPlaceParams(
                    p_client_event_id: clientEventID,
                    p_folder_id: folderID,
                    p_name: name
                )
            )
            .execute()
            .value
    }

    @discardableResult
    func deleteParkedPlace(clientEventID: UUID) async throws -> MapPlaceRecord? {
        try await customsupabase
            .rpc(
                "nl_delete_parked_place",
                params: DeleteParkedPlaceParams(p_client_event_id: clientEventID)
            )
            .execute()
            .value
    }
}

nonisolated extension MapPlaceRecord {
    func isActiveParked(at date: Date = .now) -> Bool {
        kind == .parked && expired_at == nil && (expires_at.map { $0 > date } ?? false)
    }

    func isExpiredParked(at date: Date = .now) -> Bool {
        kind == .parked && (expired_at != nil || (expires_at.map { $0 <= date } ?? false))
    }
}
