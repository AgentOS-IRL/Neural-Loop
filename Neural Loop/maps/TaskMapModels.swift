import Foundation

nonisolated enum TaskMapRelationship: String, Codable, Sendable {
    case owner
    case reference
}

nonisolated struct TaskMapLinkSummary: Codable, Identifiable, Equatable, Sendable {
    let id: Int64
    let task_id: Int64
    let task_title: String
    let place_id: Int64?
    let route_id: Int64?
    let relationship: TaskMapRelationship
    let position: Int
    let client_draft_id: UUID?
    let created_at: Date
    let updated_at: Date
}

nonisolated struct TaskMapAttachment: Codable, Identifiable, Equatable, Sendable {
    let id: Int64
    let task_id: Int64
    let task_title: String
    let place_id: Int64?
    let route_id: Int64?
    let relationship: TaskMapRelationship
    let position: Int
    let client_draft_id: UUID?
    let created_at: Date
    let updated_at: Date
    let place: MapPlaceRecord?
    let route: MapRouteRecord?
    let route_waypoints: [MapRouteWaypointRecord]
}

nonisolated enum TaskMapTarget: Hashable, Identifiable, Sendable {
    case place(Int64)
    case route(Int64)

    var id: String {
        switch self {
        case .place(let id): "place-\(id)"
        case .route(let id): "route-\(id)"
        }
    }
}

nonisolated struct TaskOwnedPlaceDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String?

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        address: String?
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
}

nonisolated struct TaskMapBundleDraft: Equatable, Sendable {
    var referenceTargets: [TaskMapTarget]
    var ownedPlaces: [TaskOwnedPlaceDraft]

    static let empty = TaskMapBundleDraft(referenceTargets: [], ownedPlaces: [])
}

nonisolated struct TaskMapReferenceInput: Codable, Equatable, Sendable {
    let place_id: Int64?
    let route_id: Int64?
    let position: Int

    init(target: TaskMapTarget, position: Int) {
        switch target {
        case .place(let id):
            place_id = id
            route_id = nil
        case .route(let id):
            place_id = nil
            route_id = id
        }
        self.position = position
    }
}

nonisolated struct TaskOwnedPlaceInput: Codable, Equatable, Sendable {
    let client_draft_id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let position: Int
}

nonisolated struct TaskMapDeleteImpact: Codable, Equatable, Sendable {
    let task_id: Int64
    let task_title: String
    let owned_place_count: Int
    let reference_place_count: Int
    let reference_route_count: Int
    let owned_places: [MapPlaceRecord]

    var hasOwnedPlaces: Bool { owned_place_count > 0 }
    var referenceCount: Int { reference_place_count + reference_route_count }
}

nonisolated struct PreservedTaskPlaceInput: Codable, Equatable, Sendable {
    let place_id: Int64
    let folder_id: Int64
    let name: String?
}

nonisolated struct DeleteTaskMapReceipt: Codable, Equatable, Sendable {
    let deleted_task_id: Int64
    let deleted_owned_place_count: Int
    let preserved_place_count: Int
    let removed_reference_place_count: Int
    let removed_reference_route_count: Int
}

nonisolated struct MapPlaceTaskLinkImpact: Codable, Equatable, Sendable {
    let link_id: Int64
    let task_id: Int64
    let task_title: String
    let relationship: TaskMapRelationship
}

nonisolated struct MapPlaceLinkImpact: Codable, Equatable, Sendable {
    let place_id: Int64
    let link_count: Int
    let links: [MapPlaceTaskLinkImpact]
}

nonisolated extension TaskMapAttachment {
    var target: TaskMapTarget? {
        if let place_id { return .place(place_id) }
        if let route_id { return .route(route_id) }
        return nil
    }

    var displayName: String {
        place?.name ?? route?.name ?? "Map item"
    }
}

