//
//  HabitTracking.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 07/01/2026.
//

import Foundation
import SQLite

struct HabitTracking: Codable, Identifiable {
    // MARK: - Properties
    var id: Int64?
    var task_id: Int64
    var entry_date: Date
    var value: Int
}

extension DBManager {

    // MARK: - Table & Columns

    private var habitTrackingTable: Table { Table("habit_tracking") }

    private var id: SQLite.Expression<Int64> { Expression<Int64>("id") }
    private var taskId: SQLite.Expression<Int64> { Expression<Int64>("task_id") }
    private var entryDate: SQLite.Expression<String> { Expression<String>("entry_date") }
    private var valueCol: SQLite.Expression<Int> { Expression<Int>("value") }

    // MARK: - Create

    /// Insert a habit tracking entry. If `entry_date` isn't provided, DB default is used.
    func addHabitEntry(_ entry: HabitTracking) throws -> HabitTracking {
        if let dateString = entry.entry_date.ISO8601FormatIfAvailable() {
            let insert = habitTrackingTable.insert(
                taskId <- entry.task_id,
                entryDate <- dateString,
                valueCol <- entry.value
            )
            let rowId = try DBManager.sqliteDB!.run(insert)
            var saved = entry
            saved.id = rowId
            return saved
        } else {
            let insert = habitTrackingTable.insert(
                taskId <- entry.task_id,
                valueCol <- entry.value
            )
            let rowId = try DBManager.sqliteDB!.run(insert)
            var saved = entry
            saved.id = rowId
            return saved
        }
    }

    /// Convenience to add by components.
    func addHabitEntry(taskId: Int64, value: Int, date: Date? = nil) throws -> HabitTracking {
        let entry = HabitTracking(id: nil, task_id: taskId, entry_date: date ?? Date(), value: value)
        return try addHabitEntry(entry)
    }

    // MARK: - Read

    func fetchHabitEntry(by idValue: Int64) throws -> HabitTracking? {
        let q = habitTrackingTable.filter(id == idValue)
        return try DBManager.sqliteDB!.pluck(q).map { row in
            HabitTracking(
                id: row[id],
                task_id: row[taskId],
                entry_date: ISO8601DateFormatter().date(from: row[entryDate]) ?? Date(),
                value: row[valueCol]
            )
        }
    }

    func fetchHabitEntries(forTask taskIdValue: Int64, from fromDate: Date? = nil, to toDate: Date? = nil) throws -> [HabitTracking] {
        var q: Table = habitTrackingTable.filter(taskId == taskIdValue)

        if let fromDate = fromDate {
            q = q.filter(entryDate >= fromDate.ISO8601FormatIfAvailable() ?? "")
        }
        if let toDate = toDate {
            q = q.filter(entryDate <= toDate.ISO8601FormatIfAvailable() ?? "")
        }

        return try DBManager.sqliteDB!.prepare(q).map { row in
            HabitTracking(
                id: row[id],
                task_id: row[taskId],
                entry_date: ISO8601DateFormatter().date(from: row[entryDate]) ?? Date(),
                value: row[valueCol]
            )
        }
    }

    func fetchLatestHabitEntry(forTask taskIdValue: Int64) throws -> HabitTracking? {
        let q = habitTrackingTable
            .filter(taskId == taskIdValue)
            .order(entryDate.desc)
            .limit(1)

        return try DBManager.sqliteDB!.pluck(q).map { row in
            HabitTracking(
                id: row[id],
                task_id: row[taskId],
                entry_date: ISO8601DateFormatter().date(from: row[entryDate]) ?? Date(),
                value: row[valueCol]
            )
        }
    }

    // MARK: - Update

    func updateHabitEntryValue(id idValue: Int64, value: Int) throws {
        let q = habitTrackingTable.filter(id == idValue)
        try DBManager.sqliteDB!.run(q.update(valueCol <- value))
    }

    // MARK: - Delete

    func deleteHabitEntry(id idValue: Int64) throws {
        let q = habitTrackingTable.filter(id == idValue)
        try DBManager.sqliteDB!.run(q.delete())
    }
}

// MARK: - Helpers

private extension Date {
    func ISO8601FormatIfAvailable() -> String? {
        // Always format to full ISO-8601 string
        ISO8601DateFormatter().string(from: self)
    }
}
