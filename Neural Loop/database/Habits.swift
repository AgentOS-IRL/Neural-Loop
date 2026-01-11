//
//  Habits.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 10/01/2026.
//

import Foundation
import Supabase

// MARK: - Habits Model

struct Habits: Codable, Identifiable {
    let id: Int64?
    
    let title: String
    let description: String?
    
    let priority: Int
    
    let goal_id: Int64?
    let lifearea_id: Int64?
    
    
    let target: Int
    let target_recursion_rule: String?
    let label: String?
    
    let created_at: Date?
    let updated_at: Date?
}
extension Habits: Equatable {
    static func == (lhs: Habits, rhs: Habits) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.description == rhs.description &&
        lhs.priority == rhs.priority &&
        lhs.goal_id == rhs.goal_id &&
        lhs.lifearea_id == rhs.lifearea_id &&
        lhs.target == rhs.target &&
        lhs.target_recursion_rule == rhs.target_recursion_rule &&
        lhs.label == rhs.label
        
    }
}
// MARK: - DBManager + Habits

extension DBManager {
    
    private var habitsTableName: String { "habits" }
    
    // CREATE
    func addHabit(_ habit: Habits) async throws -> Habits {
        try await customsupabase
            .from(habitsTableName)
            .insert(habit)
            .select()
            .single()
            .execute()
            .value
    }
    
    // READ
    
    func fetchAllHabits() async throws -> [Habits] {
        try await customsupabase
            .from(habitsTableName)
            .select()
            .execute()
            .value
    }
    
    func fetchHabit(by id: Int64) async throws -> Habits? {
        try await customsupabase
            .from(habitsTableName)
            .select()
            .eq("id", value: Int(id))
            .limit(1)
            .single()
            .execute()
            .value
    }
    
    func fetchHabits(forGoal goalId: Int64) async throws -> [Habits] {
        try await customsupabase
            .from(habitsTableName)
            .select()
            .eq("goal_id", value: Int(goalId))
            .execute()
            .value
    }
    
    func fetchHabits(forLifeArea lifeAreaId: Int64) async throws -> [Habits] {
        try await customsupabase
            .from(habitsTableName)
            .select()
            .eq("lifearea_id", value: Int(lifeAreaId))
            .execute()
            .value
    }
    
    func fetchIncompleteHabits() async throws -> [Habits] {
        try await customsupabase
            .from(habitsTableName)
            .select()
            .eq("is_completed", value: false)
            .execute()
            .value
    }
    
    // UPDATE
    
    func updateHabit(_ habit: Habits) async throws {
        guard let id = habit.id else {
            throw NSError(domain: "Habits", code: 0, userInfo: [NSLocalizedDescriptionKey: "Habit ID is missing"])
        }
        
        try await customsupabase
            .from(habitsTableName)
            .update(habit)
            .eq("id", value: Int(id))
            .execute()
    }
    
    func markHabitCompleted(habitId: Int64) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        
        try await customsupabase
            .from(habitsTableName)
            .update([
                "is_completed": "true",
                "completed_at": now,
                "updated_at": now
            ])
            .eq("id", value: Int(habitId))
            .execute()
    }
    
    // DELETE
    
    func deleteHabit(id: Int64) async throws {
        try await customsupabase
            .from(habitsTableName)
            .delete()
            .eq("id", value: Int(id))
            .execute()
    }
}
