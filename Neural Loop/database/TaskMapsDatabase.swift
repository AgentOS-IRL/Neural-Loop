import Foundation
import Supabase

private nonisolated struct TaskIDParams: Codable, Sendable {
    let p_task_id: Int64
}

private nonisolated struct MapPlaceIDParams: Codable, Sendable {
    let p_place_id: Int64
}

private nonisolated struct ApplyTaskMapBundleParams: Codable, Sendable {
    let p_task_id: Int64
    let p_references: [TaskMapReferenceInput]
    let p_owned_places: [TaskOwnedPlaceInput]
}

private nonisolated struct SaveTaskOwnedPlaceParams: Codable, Sendable {
    let p_task_id: Int64
    let p_place_id: Int64
    let p_folder_id: Int64
    let p_name: String?
}

private nonisolated struct DeleteTaskOwnedPlaceParams: Codable, Sendable {
    let p_task_id: Int64
    let p_place_id: Int64
}

private nonisolated struct RemoveTaskMapReferenceParams: Codable, Sendable {
    let p_task_id: Int64
    let p_place_id: Int64?
    let p_route_id: Int64?
}

private nonisolated struct DeleteTaskParams: Codable, Sendable {
    let p_task_id: Int64
    let p_preserved_places: [PreservedTaskPlaceInput]
}

extension DBManager {
    func fetchTaskMapAttachments(taskID: Int64) async throws -> [TaskMapAttachment] {
        try await customsupabase
            .rpc("nl_get_task_map_attachments", params: TaskIDParams(p_task_id: taskID))
            .execute()
            .value
    }

    func fetchTaskMapDeleteImpact(taskID: Int64) async throws -> TaskMapDeleteImpact {
        try await customsupabase
            .rpc("nl_get_task_map_delete_impact", params: TaskIDParams(p_task_id: taskID))
            .execute()
            .value
    }

    func fetchMapPlaceLinkImpact(placeID: Int64) async throws -> MapPlaceLinkImpact {
        try await customsupabase
            .rpc("nl_get_map_place_link_impact", params: MapPlaceIDParams(p_place_id: placeID))
            .execute()
            .value
    }

    @discardableResult
    func applyTaskMapBundle(
        taskID: Int64,
        draft: TaskMapBundleDraft,
        startingPosition: Int = 0
    ) async throws -> [TaskMapAttachment] {
        let references = draft.referenceTargets.enumerated().map { offset, target in
            TaskMapReferenceInput(target: target, position: startingPosition + offset)
        }
        let ownedStart = startingPosition + references.count
        let ownedPlaces = draft.ownedPlaces.enumerated().map { offset, draft in
            TaskOwnedPlaceInput(
                client_draft_id: draft.id,
                name: draft.name,
                latitude: draft.latitude,
                longitude: draft.longitude,
                address: draft.address,
                position: ownedStart + offset
            )
        }

        return try await customsupabase
            .rpc(
                "nl_apply_task_map_bundle",
                params: ApplyTaskMapBundleParams(
                    p_task_id: taskID,
                    p_references: references,
                    p_owned_places: ownedPlaces
                )
            )
            .execute()
            .value
    }

    func saveTaskOwnedPlace(
        taskID: Int64,
        placeID: Int64,
        folderID: Int64,
        name: String?
    ) async throws -> MapPlaceRecord {
        try await customsupabase
            .rpc(
                "nl_save_task_owned_place",
                params: SaveTaskOwnedPlaceParams(
                    p_task_id: taskID,
                    p_place_id: placeID,
                    p_folder_id: folderID,
                    p_name: name
                )
            )
            .execute()
            .value
    }

    @discardableResult
    func removeTaskMapReference(taskID: Int64, target: TaskMapTarget) async throws -> TaskMapLinkSummary {
        let params: RemoveTaskMapReferenceParams
        switch target {
        case .place(let id):
            params = RemoveTaskMapReferenceParams(p_task_id: taskID, p_place_id: id, p_route_id: nil)
        case .route(let id):
            params = RemoveTaskMapReferenceParams(p_task_id: taskID, p_place_id: nil, p_route_id: id)
        }

        return try await customsupabase
            .rpc("nl_remove_task_map_reference", params: params)
            .execute()
            .value
    }

    @discardableResult
    func deleteTaskOwnedPlace(taskID: Int64, placeID: Int64) async throws -> MapPlaceRecord {
        try await customsupabase
            .rpc(
                "nl_delete_task_owned_place",
                params: DeleteTaskOwnedPlaceParams(p_task_id: taskID, p_place_id: placeID)
            )
            .execute()
            .value
    }

    func deleteTask(
        id taskID: Int64,
        preservedPlaces: [PreservedTaskPlaceInput]
    ) async throws -> DeleteTaskMapReceipt {
        try await customsupabase
            .rpc(
                "nl_delete_task",
                params: DeleteTaskParams(
                    p_task_id: taskID,
                    p_preserved_places: preservedPlaces
                )
            )
            .execute()
            .value
    }
}
