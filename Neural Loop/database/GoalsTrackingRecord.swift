//
//  GoalsTrackingRecord.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 13/01/2026.
//

import Foundation
import Supabase

struct GoalsTrackingRecord: Codable, Identifiable {
    let id: Int64?
    let goals_tracking_id: Int64

    let type: GoalTrackingType

    let value: Double
    let label: String

    let created_at: Date?
}

extension DBManager {

    private var goalsTrackingRecordsTableName: String { "goals_tracking_records" }

    // Fetch all records for a tracking entry
    func fetchGoalsTrackingRecords(forTracking trackingId: Int64) async throws -> [GoalsTrackingRecord] {
        let response: [GoalsTrackingRecord] = try await customsupabase
            .from(goalsTrackingRecordsTableName)
            .select()
            .eq("goals_tracking_id", value: Int(trackingId))
            .order("created_at", ascending: true)
            .execute()
            .value

        return response
    }

    // Create a new tracking record
    func createGoalsTrackingRecord(_ record: GoalsTrackingRecord) async throws {
        try await customsupabase
            .from(goalsTrackingRecordsTableName)
            .insert(record)
            .execute()
    }

    // Delete all records for a tracking entry (usually handled by FK cascade)
    func deleteGoalsTrackingRecords(forTracking trackingId: Int64) async throws {
        try await customsupabase
            .from(goalsTrackingRecordsTableName)
            .delete()
            .eq("goals_tracking_id", value: Int(trackingId))
            .execute()
    }

    // Delete one record, scoped to its parent tracking entry for data safety.
    func deleteGoalsTrackingRecord(
        id recordId: Int64,
        forTracking trackingId: Int64
    ) async throws {
        try await customsupabase
            .from(goalsTrackingRecordsTableName)
            .delete()
            .eq("id", value: Int(recordId))
            .eq("goals_tracking_id", value: Int(trackingId))
            .execute()
    }
    
    // Fetch records by trackingId + type
    func fetchGoalsTrackingRecords(
        forTracking trackingId: Int64,
        type: GoalTrackingType
    ) async throws -> [GoalsTrackingRecord] {
        let response: [GoalsTrackingRecord] = try await customsupabase
            .from(goalsTrackingRecordsTableName)
            .select()
            .eq("goals_tracking_id", value: Int(trackingId))
            .eq("type", value: type.rawValue)
            .order("created_at", ascending: true)
            .execute()
            .value

        return response
    }

    // Fetch records by trackingId + type + label
    func fetchGoalsTrackingRecords(
        forTracking trackingId: Int64,
        type: GoalTrackingType,
        label: String
    ) async throws -> [GoalsTrackingRecord] {
        let response: [GoalsTrackingRecord] = try await customsupabase
            .from(goalsTrackingRecordsTableName)
            .select()
            .eq("goals_tracking_id", value: Int(trackingId))
            .eq("type", value: type.rawValue)
            .eq("label", value: label)
            .order("created_at", ascending: true)
            .execute()
            .value

        return response
    }
}
