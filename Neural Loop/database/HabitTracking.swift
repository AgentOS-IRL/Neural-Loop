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
            
            let builder = customsupabase
                .from(self.habitTrackingTableName)
                .select()
                .gt("id", value: Int(lastID))
                .order("id", ascending: true)
                .limit(pageSize)
                
            let entries: [HabitTracking] = try await builder.execute().value  as [HabitTracking]


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
