//
//  Goals.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import Supabase

struct Goals: Codable, Identifiable {

    // MARK: - Properties
    var id: Int64?
    var title: String
    var lifearea_id: Int64
    var start_date: String          // ISO-8601: YYYY-MM-DD
    var deadline: String?           // nullable
    var color: String?              // nullable
    var description: String?        // nullable
}

extension DBManager {
    private var goalsTableName: String { "goals" }

    // MARK: - Create
    func addGoal(_ goal: Goals) async throws {
        let inserted: [Goals] = try await customsupabase
            .from(self.goalsTableName)
            .insert(goal)
            .select()
            .execute()
            .value
        if let first = inserted.first, let newId = first.id {
            print("Inserted Goal with id:", newId)
        }
    }

    // MARK: - Read
    func fetchAllGoals() async throws -> [Goals] {
        try await customsupabase
            .from(self.goalsTableName)
            .select()
            .execute()
            .value as [Goals]
    }

    func fetchGoal(by idValue: Int64) async throws -> Goals? {
        let rows: [Goals] = try await customsupabase
            .from(self.goalsTableName)
            .select()
            .eq("id", value: Int(idValue))
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchGoals(forLifeArea lifeAreaIdValue: Int64) async throws -> [Goals] {
        try await customsupabase
            .from(self.goalsTableName)
            .select()
            .eq("lifearea_id", value: Int(lifeAreaIdValue))
            .execute()
            .value as [Goals]
    }

    // MARK: - Update
    func updateGoal(_ goal: Goals) async throws {
        guard let goalId = goal.id else { return }
        _ = try await customsupabase
            .from(self.goalsTableName)
            .update(goal)
            .eq("id", value: Int(goalId))
            .select()
            .execute()
    }

    // MARK: - Delete
    func deleteGoal(id goalId: Int64) async throws {
        _ = try await customsupabase
            .from(self.goalsTableName)
            .delete()
            .eq("id", value: Int(goalId))
            .execute()
    }

    func deleteGoals(forLifeArea lifeAreaIdValue: Int64) async throws {
        _ = try await customsupabase
            .from(self.goalsTableName)
            .delete()
            .eq("lifearea_id", value: Int(lifeAreaIdValue))
            .execute()
    }
}
