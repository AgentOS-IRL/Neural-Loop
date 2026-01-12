//
//  HabitTracking.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 07/01/2026.
//

import Foundation
import Supabase

struct HabitTracking: Codable, Identifiable {
    // MARK: - Properties
    var id: Int64?
    var habit_id: Int64
    var entry_date: Date
    var value: Int
}

extension DBManager {
    private var habitTrackingTableName: String { "habit_tracking" }

    // MARK: - Create
    func addHabitEntry(_ entry: HabitTracking) async throws -> HabitTracking {
        let inserted: [HabitTracking] = try await customsupabase
            .from(self.habitTrackingTableName)
            .insert(entry)
            .select()
            .execute()
            .value
        return inserted.first ?? entry
    }

    /// Convenience to add by components.
    func addHabitEntry(habitId: Int64, value: Int, date: Date? = nil) async throws -> HabitTracking {
        let entry = HabitTracking(id: nil, habit_id: habitId, entry_date: date ?? Date(), value: value)
        return try await addHabitEntry(entry)
    }

    // MARK: - Read
    func fetchHabitEntry(by idValue: Int64) async throws -> HabitTracking? {
        let rows: [HabitTracking] = try await customsupabase
            .from(self.habitTrackingTableName)
            .select()
            .eq("id", value: Int(idValue))
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchHabitEntries(forTask taskIdValue: Int64, from fromDate: Date? = nil, to toDate: Date? = nil) async throws -> [HabitTracking] {
        var builder = customsupabase
            .from(self.habitTrackingTableName)
            .select()
            .eq("habit_id", value: Int(taskIdValue))

        if let fromDate = fromDate {
            builder = builder.gte("entry_date", value: ISO8601DateFormatter().string(from: fromDate))
        }
        if let toDate = toDate {
            builder = builder.lte("entry_date", value: ISO8601DateFormatter().string(from: toDate))
        }

        return try await builder
            .execute()
            .value as [HabitTracking]
    }

    func fetchLatestHabitEntry(forTask taskIdValue: Int64) async throws -> HabitTracking? {
        let rows: [HabitTracking] = try await customsupabase
            .from(self.habitTrackingTableName)
            .select()
            .eq("habit_id", value: Int(taskIdValue))
            .order("entry_date", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Update
    func updateHabitEntryValue(id idValue: Int64, value: Int) async throws {
        _ = try await customsupabase
            .from(self.habitTrackingTableName)
            .update(["value": value])
            .eq("id", value: Int(idValue))
            .execute()
    }

    // MARK: - Delete
    func deleteHabitEntry(id idValue: Int64) async throws {
        _ = try await customsupabase
            .from(self.habitTrackingTableName)
            .delete()
            .eq("id", value: Int(idValue))
            .execute()
    }
    
    func deleteHabitEntries(forTask taskIdValue: Int64) async throws {
        _ = try await customsupabase
            .from(self.habitTrackingTableName)
            .delete()
            .eq("habit_id", value: Int(taskIdValue))
            .execute()
    }
}

// MARK: - Helpers

private extension Date {
    func ISO8601FormatIfAvailable() -> String? {
        // Always format to full ISO-8601 string
        ISO8601DateFormatter().string(from: self)
    }
}
