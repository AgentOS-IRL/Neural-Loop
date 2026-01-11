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
    var start_date: Date?          // ISO-8601: YYYY-MM-DD
    var deadline: Date?           // nullable
    var color: String?              // nullable
    var description: String?        // nullable
    var icon: String
    var is_completed: Bool
}

extension DBManager {
    // NOTE:
    // Database indexes (PRIMARY KEY, foreign key indexes, composite indexes, etc.)
    // CANNOT be created or managed from Swift/Supabase client code.
    //
    // Indexes must be defined at the database level using SQL migrations
    // (e.g. in Supabase SQL editor or migration files).
    //
    // This Swift code will automatically benefit from those indexes when
    // queries use `.eq`, `.order`, `.limit`, etc.

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
    
    func fetchGoalName(by idValue: Int64) async throws -> String? {
        let rows: [Goals] = try await customsupabase
            .from(self.goalsTableName)
            .select()
            .eq("id", value: Int(idValue))
            .limit(1)
            .execute()
            .value
        return rows.first?.title
    }

    func fetchGoals(forLifeArea lifeAreaIdValue: Int64) async throws -> [Goals] {
        try await customsupabase
            .from(self.goalsTableName)
            .select()
            .eq("lifearea_id", value: Int(lifeAreaIdValue))
            .execute()
            .value as [Goals]
    }
    
    func fetchGoalsCount(forLifeArea lifeAreaIdValue: Int64) async throws -> Int {
        try await customsupabase
            .from(self.goalsTableName)
            .select("COUNT(*)")
            .eq("lifearea_id", value: Int(lifeAreaIdValue))
            .execute()
            .value!
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
