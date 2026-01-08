//
//  LifeAreas.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import Supabase

struct LifeAreas: Codable, Identifiable {
    var id: Int64?
    var name: String
    var vision: String?
    var is_sample: Bool = false
    var color: String
}

extension DBManager {
    private var lifeAreasTableName: String { "life_areas" }

    // MARK: - Create
    func addLifeArea(_ area: LifeAreas) async throws {
        let inserted: [LifeAreas] = try await customsupabase
            .from(self.lifeAreasTableName)
            .insert(area)
            .select()
            .execute()
            .value
        if let id = inserted.first?.id { print("Inserted LifeArea with id:", id) }
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

    // MARK: - Delete
    func deleteLifeArea(id areaId: Int64) async throws {
        _ = try await customsupabase
            .from(self.lifeAreasTableName)
            .delete()
            .eq("id", value: Int(areaId))
            .execute()
    }
}
