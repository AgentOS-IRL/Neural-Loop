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

nonisolated struct MapPlaceRecord: Codable, Identifiable, Equatable, Sendable {
    let id: Int64
    let folder_id: Int64
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let created_at: Date
    let updated_at: Date

    static let tableName = "map_places"
    static let selectedColumns = "id, folder_id, name, latitude, longitude, address, created_at, updated_at"
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
    let created_at: Date
    let updated_at: Date

    static let tableName = "map_routes"
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
}
