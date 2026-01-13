//
//  GoalsTracking.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 12/01/2026.
//
import Foundation
import Supabase

enum GoalTrackingType: String, Codable {
    case task
    case sub_goal
    case custom
}

struct GoalsTracking: Codable, Identifiable {
    let id: Int64?
    let goal_id: Int64

    let type: GoalTrackingType

    let value: Double?
    let target: Double?

    let label: String?

    let created_at: Date?
    let updated_at: Date?
}


extension DBManager {

    private var goalsTrackingTableName: String { "goals_tracking" }

    // Fetch tracking for a goal (1-to-1)
    func fetchGoalsTracking(forGoal goalId: Int64) async throws -> GoalsTracking? {
        let response: [GoalsTracking] = try await customsupabase
            .from(goalsTrackingTableName)
            .select()
            .eq("goal_id", value: Int(goalId))
            .limit(1)
            .execute()
            .value

        return response.first
    }

    // Create tracking (only once per goal)
    func createGoalsTracking(_ tracking: GoalsTracking) async throws {
        try await customsupabase
            .from(goalsTrackingTableName)
            .insert(tracking)
            .execute()
    }

    // Update tracking
    func updateGoalsTracking(_ tracking: GoalsTracking) async throws {
        guard let id = tracking.id else { return }

        try await customsupabase
            .from(goalsTrackingTableName)
            .update(tracking)
            .eq("id", value: Int(id))
            .execute()
    }

    // Delete tracking for a goal
    func deleteGoalsTracking(forGoal goalId: Int64) async throws {
        try await customsupabase
            .from(goalsTrackingTableName)
            .delete()
            .eq("goal_id", value: Int(goalId))
            .execute()
    }
}
