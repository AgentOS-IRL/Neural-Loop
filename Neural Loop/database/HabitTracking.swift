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


    static func fromLocal(_ record: HabitTrackingLocalRecord) -> Self {
        .init(id: Int64(record.id), habit_id: Int64(record.habitID), entry_date: record.entryDate, value: Int(record.value))
    }
}

struct HabitEntryWithSummary: Codable {
    let entry: HabitTracking
    let window_total: Int64
}

struct HabitWindowTotal: Codable {
    let window_start: Date
    let window_end: Date
    let total_value: Int64
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
        try self.localHabitTrackingStore.add(inserted.first!)
        return inserted.first ?? entry
    }

    nonisolated struct AddHabitEntryParams: Codable, Sendable {
        let p_habit_id: Int64
        let p_value: Int
        let p_entry_date: String
        let p_window_start: String?
        let p_window_end: String?
    }

    /// Adds one habit tracking entry, then calculates the updated total for the active UI window.
    /// - Parameters:
    ///   - habitId: habit ID.
    ///   - value: value to add.
    ///   - date: entry date/time.
    ///   - windowStart: optional summary start date/time.
    ///   - windowEnd: optional summary end date/time.
    /// - Returns: A JSON object with the new habit entry and the total value for the requested window.
    func addHabitEntryWithSummary(habitId: Int64, value: Int, date: Date, windowStart: Date? = nil, windowEnd: Date? = nil) async throws -> HabitEntryWithSummary {
        let params = AddHabitEntryParams(
            p_habit_id: habitId,
            p_value: value,
            p_entry_date: WorkoutDateCoding.string(from: date),
            p_window_start: windowStart != nil ? WorkoutDateCoding.string(from: windowStart!) : nil,
            p_window_end: windowEnd != nil ? WorkoutDateCoding.string(from: windowEnd!) : nil
        )

        let result: HabitEntryWithSummary = try await customsupabase
            .rpc("nl_add_habit_entry_with_summary", params: params)
            .execute()
            .value

        try self.localHabitTrackingStore.add(result.entry)
        return result
    }

    /// Convenience to add by components.
    func addHabitEntry(habitId: Int64, value: Int, date: Date? = nil) async throws -> HabitTracking {
        let entry = HabitTracking(id: nil, habit_id: habitId, entry_date: date ?? Date(), value: value)
        return try await addHabitEntry(entry)
    }

    // MARK: - Read
    func fetchHabitEntry(by idValue: Int64) async throws -> HabitTracking? {
        let habit =  try self.localHabitTrackingStore.fetchHabitEntry(by: Int32(idValue))
        if habit != nil {
            return habit
        }
        
        let rows: [HabitTracking] = try await customsupabase
            .from(self.habitTrackingTableName)
            .select()
            .eq("id", value: Int(idValue))
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    nonisolated struct WindowParam: Codable, Sendable {
        let window_start: Date
        let window_end: Date
    }
    
    nonisolated struct FetchHabitWindowTotalsParams: Codable, Sendable {
        let p_habit_id: Int64
        let p_windows: [WindowParam]
    }

    /// Calculates habit totals for multiple time windows in one database call.
    /// - Parameters:
    ///   - habitId: habit ID.
    ///   - windows: array of time windows, each with `start` and `end`.
    /// - Returns: A list of objects with `window_start`, `window_end`, and `total_value`.
    func fetchHabitWindowTotals(habitId: Int64, windows: [(start: Date, end: Date)]) async throws -> [HabitWindowTotal] {
        let windowParams = windows.map { WindowParam(window_start: $0.start, window_end: $0.end) }

        return try await customsupabase
            .rpc("nl_get_habit_window_totals", params: FetchHabitWindowTotalsParams(
                p_habit_id: habitId,
                p_windows: windowParams
            ))
            .execute()
            .value
    }

    nonisolated struct HabitTrackingDeltaParams: Codable, Sendable {
        let p_last_id: Int64
        let p_limit: Int
    }
    
    func reloadHabitEntries(refresh: Bool = false) async throws {
        // 1️⃣ Clear local store
        if refresh {
            try localHabitTrackingStore.deleteAllEntries()
        }

        let pageSize = 500
        var lastID: Int64 = try localHabitTrackingStore.fetchLastHabitEntryId()
        
        print(lastID)
        var hasMore = true
        while hasMore {
            /// Fetches habit tracking entries with IDs greater than the last synced ID.
            /// - Parameters:
            ///   - last_id: last synced habit tracking ID.
            ///   - limit: max rows to return.
            /// - Returns: A list of habit tracking rows.
            let entries: [HabitTracking] = try await customsupabase
                .rpc("nl_get_habit_tracking_delta", params: HabitTrackingDeltaParams(
                    p_last_id: lastID,
                    p_limit: pageSize
                ))
                .execute()
                .value

            if entries.isEmpty {
                print("No more entries")
                hasMore = false
                break
            }
            print("Got \(entries.count) entries")

            // 2️⃣ Insert batch locally
            try localHabitTrackingStore.addMultiple(entries)

            // 3️⃣ Advance cursor
            lastID = (entries.last?.id!)!

            // 4️⃣ Stop if this was the final page
            hasMore = entries.count == pageSize
        }
    }
    
    func fetchHabitEntries(forTask taskIdValue: Int64, from fromDate: Date? = nil, to toDate: Date? = nil) async throws -> [HabitTracking] {
        let habits =  try self.localHabitTrackingStore.fetchHabitEntries(forHabit: Int32(taskIdValue), from:fromDate, to:toDate)
        
        if !habits.isEmpty {
            return habits
        }
        else {
            return []
        }
        
        // var builder = customsupabase
        //     .from(self.habitTrackingTableName)
        //     .select()
        //     .eq("habit_id", value: Int(taskIdValue))

        // if let fromDate = fromDate {
        //     builder = builder.gte("entry_date", value: ISO8601DateFormatter().string(from: fromDate))
        // }
        // if let toDate = toDate {
        //     builder = builder.lte("entry_date", value: ISO8601DateFormatter().string(from: toDate))
        // }

        // return try await builder
        //     .execute()
        //     .value as [HabitTracking]
    }

    // MARK: - Update
    func updateHabitEntryValue(id idValue: Int64, value: Int) async throws {
        _ = try await customsupabase
            .from(self.habitTrackingTableName)
            .update(["value": value])
            .eq("id", value: Int(idValue))
            .execute()
        try self.localHabitTrackingStore.updateHabitEntryValue(id:Int32(idValue),
                                                           value:Int16(value))
    }

    // MARK: - Delete
    func deleteHabitEntry(id idValue: Int64) async throws {
        _ = try await customsupabase
            .from(self.habitTrackingTableName)
            .delete()
            .eq("id", value: Int(idValue))
            .execute()
        try self.localHabitTrackingStore.deleteHabitEntry(id:Int32(idValue))
    }
    
    func deleteHabitEntries(forTask taskIdValue: Int64) async throws {
        _ = try await customsupabase
            .from(self.habitTrackingTableName)
            .delete()
            .eq("habit_id", value: Int(taskIdValue))
            .execute()
        
        try self.localHabitTrackingStore.deleteHabitEntries(forHabit: Int32(taskIdValue))
    }
}
