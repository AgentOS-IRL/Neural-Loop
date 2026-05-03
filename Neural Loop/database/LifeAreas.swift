//
//  LifeAreas.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import Supabase

struct LifeAreas: Codable, Identifiable {
    static let databasePrimaryKey = ["id"]

    var id: Int64?
    var name: String
    var vision: String?
    var is_sample: Bool = false
    var color: String
    var icon: String
}

struct LifeAreaDeleteResult: Codable {
    let deleted_life_area_id: Int64
    let deleted_goal_ids: [Int64]
    let deleted_task_ids: [Int64]
    let deleted_habit_ids: [Int64]
}

extension DBManager {
    private var lifeAreasTableName: String { "life_areas" }

    // MARK: - Create
    func addLifeArea(_ area: LifeAreas) async throws -> LifeAreas{
        let inserted: [LifeAreas] = try await customsupabase
            .from(self.lifeAreasTableName)
            .insert(area)
            .select()
            .execute()
            .value
        return inserted.first!
    }

    // MARK: - Read
    func fetchAllLifeAreas() async throws -> [LifeAreas] {
        try await customsupabase
            .from(self.lifeAreasTableName)
            .select()
            .execute()
            .value as [LifeAreas]
    }

    func fetchLifeArea(by idValue: Int64) async throws -> LifeAreas? {
        let rows: [LifeAreas] = try await customsupabase
            .from(self.lifeAreasTableName)
            .select()
            .eq("id", value: Int(idValue))
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Update
    func updateLifeArea(_ area: LifeAreas) async throws {
        guard let areaId = area.id else { return }
        _ = try await customsupabase
            .from(self.lifeAreasTableName)
            .update(area)
            .eq("id", value: Int(areaId))
            .select()
            .execute()
    }

    func updateVision(id: Int64, vision: String) async throws {
        _ = try await customsupabase
            .from(self.lifeAreasTableName)
            .update(["vision": vision])
            .eq("id", value: Int(id))
            .select()
            .execute()
    }

    // MARK: - Delete
    func deleteLifeArea(id areaId: Int64) async throws {
        _ = try await customsupabase
            .from(self.lifeAreasTableName)
            .delete()
            .eq("id", value: Int(areaId))
            .execute()
    }
    
    nonisolated struct DeleteLifeAreaParams: Codable, Sendable {
        let p_life_area_id: Int64
    }

    /// Collects IDs of related goals/tasks/habits, deletes the life area, then returns those IDs so the app can clean up local state or notifications.
    /// - Parameter areaId: life area ID to delete.
    /// - Returns: A JSON object with deleted life area ID, goal IDs, task IDs, and habit IDs.
    func deleteLifeAreaWithDeletedIDs(id areaId: Int64) async throws -> LifeAreaDeleteResult {
        return try await customsupabase
            .rpc("nl_delete_life_area_with_deleted_ids", params: DeleteLifeAreaParams(p_life_area_id: areaId))
            .execute()
            .value
    }

    // Mark: - Get Name
    func fetchLifeAreaName(by idValue: Int64) async throws -> String? {
        let rows: [LifeAreas] = try await customsupabase
            .from(self.lifeAreasTableName)
            .select()
            .eq("id", value: Int(idValue))
            .limit(1)
            .execute()
            .value
        return rows.first?.name
    }
    
    
}
