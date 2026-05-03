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
    case unknown
}

struct GoalsTracking: Codable, Identifiable {
    let id: Int64?
    let goal_id: Int64

    let type: GoalTrackingType

    let value: Double?
    var target: Double?

    let label: String?

    let created_at: Date?
    let updated_at: Date?

    static let empty = GoalsTracking(
            id: nil,
            goal_id: 0,
            type: .unknown,   // add this case if it doesn’t exist
            value: nil,
            target: nil,
            label: nil,
            created_at: nil,
            updated_at: nil
        )
}

extension GoalsTracking {
    var isEmpty: Bool {
        type == .unknown
    }
}

struct GoalTrackingBundle: Codable {
    let tracking: GoalsTracking
    let records: [GoalsTrackingRecord]
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

    func fetchAllGoalsTracking() async throws -> [GoalsTracking] {
        let response: [GoalsTracking] = try await customsupabase
            .from(goalsTrackingTableName)
            .select()
            .execute()
            .value
        
        return response
    }

    nonisolated struct FetchGoalTrackingBundleParams: Codable, Sendable {
        let p_goal_id: Int64
    }

    /// Fetches only progress/tracking data for one goal.
    /// - Parameter goalId: goal ID.
    /// - Returns: A JSON object with goal tracking config and tracking records.
    func fetchGoalTrackingBundle(goalId: Int64) async throws -> GoalTrackingBundle {
        return try await customsupabase
            .rpc("nl_get_goal_tracking_bundle", params: FetchGoalTrackingBundleParams(p_goal_id: goalId))
            .execute()
            .value
    }

    nonisolated struct CreateGoalTrackingRecordParams: Codable, Sendable {
        let p_goals_tracking_id: Int64
        let p_type: String
        let p_value: Double
        let p_label: String
        let p_created_date: String
    }

    /// Creates one new goal tracking record, finds the related goal, then returns the updated tracking data for that goal.
    /// - Parameters:
    ///   - goalsTrackingId: goal tracking config ID.
    ///   - type: tracking type, such as `task`, `sub_goal`, or `custom`.
    ///   - value: progress value.
    ///   - label: optional label/description.
    ///   - createdDate: date when the record was created.
    /// - Returns: A refreshed goal tracking bundle JSON object.
    func createGoalTrackingRecordAndReturnBundle(
        goalsTrackingId: Int64,
        type: String,
        value: Double,
        label: String,
        createdDate: Date
    ) async throws -> GoalTrackingBundle {
        return try await customsupabase
            .rpc("nl_create_goal_tracking_record_and_return_bundle", params: CreateGoalTrackingRecordParams(
                p_goals_tracking_id: goalsTrackingId,
                p_type: type,
                p_value: value,
                p_label: label,
                p_created_date: ISO8601DateFormatter().string(from: createdDate)
            ))
            .execute()
            .value
    }

    // Create tracking (only once per goal)
    func createGoalsTracking(_ tracking: GoalsTracking) async throws -> GoalsTracking? {
        let inserted: [GoalsTracking] = try await customsupabase
            .from(goalsTrackingTableName)
            .insert(tracking)
            .select()
            .execute()
            .value

        return inserted.first
    }

    // Update tracking
    func updateGoalsTracking(_ tracking: GoalsTracking) async throws -> GoalsTracking? {
        guard let id = tracking.id else { return nil }

        let updated: [GoalsTracking] = try await customsupabase
            .from(goalsTrackingTableName)
            .update(tracking)
            .eq("id", value: Int(id))
            .select()
            .execute()
            .value

        return updated.first
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
