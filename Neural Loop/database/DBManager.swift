//
//  DBManager.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//
import Foundation
import Supabase


final class DBManager {
    let localHabitTrackingStore: LocalHabitTrackingStore
    
    private init() {
        self.localHabitTrackingStore = .init()
    }
    
    // MARK: - Factory
    static func newInstance() -> DBManager { DBManager() }

    // MARK: - Connection Check
    // Simple select query to validate Supabase connectivity
    func testSupabaseConnection() async {
        do {
            try await customsupabase
                .from("tasks")
                .select()
                .limit(1)
                .execute()

            print("Connection successful.")
        } catch {
            print("Connection failed: \(error)")
        }
    }

    // MARK: - App Bootstrap
    nonisolated struct AppBootstrapParams: Codable, Sendable {
        let p_last_habit_tracking_id: Int64
        let p_habit_tracking_limit: Int
    }

    /// Loads the main app data needed at startup in one database call instead of many separate calls.
    /// - Parameters:
    ///   - lastHabitTrackingId: last synced habit tracking row ID. Default 0.
    ///   - habitTrackingLimit: maximum habit tracking rows to return. Default 500.
    /// - Returns: A JSON object containing app startup data: life areas, goals, goal tracking, habits, tags, tasks, secrets, and habit tracking delta.
    func fetchAppBootstrapSnapshot(lastHabitTrackingId: Int64 = 0, habitTrackingLimit: Int = 500) async throws -> AppBootstrapSnapshot {
        return try await customsupabase
            .rpc(
                "nl_get_app_bootstrap_snapshot",
                params: AppBootstrapParams(
                    p_last_habit_tracking_id: lastHabitTrackingId,
                    p_habit_tracking_limit: habitTrackingLimit
                )
            )
            .execute()
            .value
    }
}

struct AppBootstrapSnapshot: Codable {
    let life_areas: [LifeAreas]
    let goals: [Goals]
    let goals_tracking: [GoalsTracking]
    let habits: [Habits]
    let tags: [Tags]
    let tasks: [Tasks]
    let secrets: [Secrets]
    let habit_tracking_delta: [HabitTracking]
}
