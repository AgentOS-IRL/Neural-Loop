//
//  LocalHabitTrackingStore.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 19/01/2026.
//
import Foundation
import SwiftData
import GRDB



//let dbQueue =
//let dbQueue = try DatabaseQueue(path: ":memory:")

struct HabitTrackingLocalRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int32
    var habitID: Int32
    var entryDate: Date
    var value: Int16

    static let databaseTableName = "habit_tracking"

    enum Columns {
        static let id = Column("id")
        static let habitID = Column("habitID")
        static let entryDate = Column("entryDate")
        static let value = Column("value")
    }

    static func fromDatabaseObject(_ habit: HabitTracking) -> HabitTrackingLocalRecord {
        HabitTrackingLocalRecord(
            id: Int32(habit.id ?? 0),
            habitID: Int32(habit.habit_id),
            entryDate: habit.entry_date,
            value: Int16(habit.value)
        )
    }
}

final class LocalHabitTrackingStore {

    private let dbQueue: DatabaseQueue

    init() {
        do {
            let fileManager = FileManager.default
            
            let appSupportURL = try fileManager
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            
            // ✅ Ensure directory exists
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                try fileManager.createDirectory(
                    at: appSupportURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            let dbURL = appSupportURL.appendingPathComponent("habits.sqlite")

            self.dbQueue = try DatabaseQueue(path: dbURL.path)

            var migrator = DatabaseMigrator()

            migrator.registerMigration("createHabitTracking") { db in
                try db.create(table: "habit_tracking", ifNotExists: true) { t in
                    t.column("id", .integer).primaryKey()
                    t.column("habitID", .integer).notNull()
                    t.column("entryDate", .datetime).notNull()
                    t.column("value", .integer).notNull()
                }
            }

            try migrator.migrate(self.dbQueue)

            print("Done Migration")
        }
        catch {
            fatalError("Failed to initialize DatabaseQueue: \(error)")
        }
    }

    // MARK: - Create

    func add(_ habit: HabitTracking) throws {
        try dbQueue.write { db in
            try HabitTrackingLocalRecord
                .fromDatabaseObject(habit)
                .insert(db)
        }
    }

    func addMultiple(_ habits: [HabitTracking]) throws {
        try dbQueue.write { db in
            for habit in habits {
                try HabitTrackingLocalRecord
                    .fromDatabaseObject(habit)
                    .insert(db)
            }
        }
    }

    // MARK: - Read
    
    func fetchLastHabitEntryId() throws -> Int64 {
        let habit = try dbQueue.read { db in
            try HabitTrackingLocalRecord
                .order(HabitTrackingLocalRecord.Columns.id.desc)
                .fetchOne(db)
                .map(HabitTracking.fromLocal)
        }
        return habit?.id ?? -1
    }

    func fetchHabitEntry(by id: Int32) throws -> HabitTracking? {
        try dbQueue.read { db in
            try HabitTrackingLocalRecord
                .filter(HabitTrackingLocalRecord.Columns.id == id)
                .fetchOne(db)
                .map(HabitTracking.fromLocal)
        }
    }

    func fetchHabitEntries(
        forHabit habitID: Int32,
        from fromDate: Date? = nil,
        to toDate: Date? = nil
    ) throws -> [HabitTracking] {

        try dbQueue.read { db in
            var request = HabitTrackingLocalRecord
                .filter(HabitTrackingLocalRecord.Columns.habitID == habitID)

            if let fromDate {
                request = request.filter(HabitTrackingLocalRecord.Columns.entryDate >= fromDate)
            }
            if let toDate {
                request = request.filter(HabitTrackingLocalRecord.Columns.entryDate <= toDate)
            }

            return try request
                .order(HabitTrackingLocalRecord.Columns.entryDate)
                .fetchAll(db)
                .map(HabitTracking.fromLocal)
        }
    }

    func fetchLatest(for habitID: Int32) throws -> HabitTracking? {
        try dbQueue.read { db in
            try HabitTrackingLocalRecord
                .filter(HabitTrackingLocalRecord.Columns.habitID == habitID)
                .order(HabitTrackingLocalRecord.Columns.entryDate.desc)
                .fetchOne(db)
                .map(HabitTracking.fromLocal)
        }
    }

    // MARK: - Update

    func updateHabitEntryValue(id: Int32, value: Int16) throws {
        try dbQueue.write { db in
            guard var record = try HabitTrackingLocalRecord
                .filter(HabitTrackingLocalRecord.Columns.id == id)
                .fetchOne(db)
            else {
                throw DatabaseError(message: "Habit entry not found")
            }

            record.value = value
            try record.update(db)
        }
    }

    // MARK: - Delete

    func deleteHabitEntry(id: Int32) throws {
        try dbQueue.write { db in
            try HabitTrackingLocalRecord
                .filter(HabitTrackingLocalRecord.Columns.id == id)
                .deleteAll(db)
        }
    }

    func deleteHabitEntries(
        forHabit habitID: Int32,
        from fromDate: Date? = nil,
        to toDate: Date? = nil
    ) throws {

        try dbQueue.write { db in
            var request = HabitTrackingLocalRecord
                .filter(HabitTrackingLocalRecord.Columns.habitID == habitID)

            if let fromDate {
                request = request.filter(HabitTrackingLocalRecord.Columns.entryDate >= fromDate)
            }
            if let toDate {
                request = request.filter(HabitTrackingLocalRecord.Columns.entryDate <= toDate)
            }

            try request.deleteAll(db)
        }
    }

    func deleteAllEntries() throws {
        try dbQueue.write { db in
            try HabitTrackingLocalRecord.deleteAll(db)
        }
    }
}

//
//@Model
//final class HabitTrackingLocalRecord {
//    var id: Int32
//    var habitID: Int32
//    var entryDate: Date
//    var value: Int16
//
//    init(id:Int32, habitID: Int32, entryDate: Date, value: Int16) {
//        self.id = id
//        self.habitID = habitID
//        self.entryDate = entryDate
//        self.value = value
//    }
//    
//    static func fromDatabaseObject(_ habit_tracking: HabitTracking) -> HabitTrackingLocalRecord {
//        HabitTrackingLocalRecord(
//            id: Int32(habit_tracking.id ?? 0),
//            habitID: Int32(habit_tracking.habit_id),
//            entryDate: habit_tracking.entry_date,
//            value: Int16(habit_tracking.value)
//        )
//    }
//}
//
//@MainActor
//final class LocalHabitTrackingStore {
//    private let context: ModelContext
//
//    init(context: ModelContext) {
//        self.context = context
//    }
//
//    // MARK: - Create
//    func add(_ habit_tracking: HabitTracking) {
//        
//        do {
//            context.insert(HabitTrackingLocalRecord.fromDatabaseObject(habit_tracking))
//            try context.save()
//        } catch {
//            print("Error saving habit tracking: \(error)")
//        }
//    }
//    
//    func addMultiple(_ habitTrackings: [HabitTracking]) {
//        do {
//            print("Inserting locally stored habit tracking entries \(habitTrackings.count)")
//            for tracking in habitTrackings {
//                let record = HabitTrackingLocalRecord.fromDatabaseObject(tracking)
//                context.insert(record)
//            }
//            try context.save()
//            let descriptor = FetchDescriptor<HabitTrackingLocalRecord>()
//            let records = try context.fetch(descriptor)
//            print("Saved \(records.count) habit tracking entries")
//            
//        } catch {
//            print("Error saving multiple habit tracking entries: \(error)")
//        }
//    }
//    
//    
//    func fetchHabitEntry(by idValue: Int32) -> HabitTracking? {
//        do {
//            let descriptor = FetchDescriptor<HabitTrackingLocalRecord>(
//                predicate: #Predicate { record in
//                    record.id == idValue
//                }
//            )
//
//            let records = try context.fetch(descriptor)
//            return records.first.map { HabitTracking.fromLocal($0) }
//
//        } catch {
//            print("Error fetching habit entry by id: \(error)")
//            return nil
//        }
//    }
//    
//    func fetchHabitEntries(
//        forHabit habitIdValue: Int32,
//        from fromDate: Date? = nil,
//        to toDate: Date? = nil
//    ) -> [HabitTracking] {
//
//        do {
//            let descriptor = FetchDescriptor<HabitTrackingLocalRecord>()
////                predicate: #Predicate { record in
////                    record.habitID == habitIdValue &&
////                    (fromDate == nil || record.entryDate >= fromDate!) &&
////                    (toDate == nil || record.entryDate <= toDate!)
////                },
////                sortBy: [.init(\.entryDate)]
////            )
//
//            let records = try context.fetch(descriptor)
//
//            return records.map {
//                HabitTracking.fromLocal($0)
//            }
//
//        } catch {
//            print("Error fetching habit entries: \(error)")
//            return []
//        }
//    }
//    
//    func updateHabitEntryValue(id idValue: Int32, value: Int) {
//        do {
//            let descriptor = FetchDescriptor<HabitTrackingLocalRecord>(
//                predicate: #Predicate { $0.id == idValue }
//            )
//
//            if let record = try context.fetch(descriptor).first {
//                record.value = Int16(value)
//                try context.save()
//            }
//        } catch {
//            print("Error updating habit entry value: \(error)")
//        }
//    }
//    
//
//    func fetchLatest(for habitID: Int32) throws -> HabitTracking? {
//        let descriptor = FetchDescriptor<HabitTrackingLocalRecord>(
//            predicate: #Predicate { $0.habitID == habitID },
//            sortBy: [.init(\.entryDate, order: .reverse)]
//        )
//        let habit = try context.fetch(descriptor).first
//        if habit == nil {
//            return nil
//        }
//        return try HabitTracking.fromLocal(context.fetch(descriptor).first!)
//    }
//
//    // MARK: - Update
//    func updateHabitEntryValue(id idValue: Int32, value: Int16) throws {
//        let descriptor = FetchDescriptor<HabitTrackingLocalRecord>(
//            predicate: #Predicate { record in
//                record.id == idValue
//            }
//        )
//
//        let records = try context.fetch(descriptor)
//
//        guard let record = records.first else {
//            throw NSError(
//                domain: "HabitTracking",
//                code: 404,
//                userInfo: [NSLocalizedDescriptionKey: "Habit entry not found"]
//            )
//        }
//
//        record.value = value
//        try context.save()
//    }
//
//    // MARK: - Delete
//    func deleteHabitEntry(id idValue: Int32) throws {
//        let descriptor = FetchDescriptor<HabitTrackingLocalRecord>(
//            predicate: #Predicate { record in
//                record.id == idValue
//            }
//        )
//
//        let records = try context.fetch(descriptor)
//
//        guard let record = records.first else {
//            throw NSError(
//                domain: "HabitTracking",
//                code: 404,
//                userInfo: [NSLocalizedDescriptionKey: "Habit entry not found"]
//            )
//        }
//
//        context.delete(record)
//        try context.save()
//    }
//    
//    
//    func deleteHabitEntries(
//        forHabit habitIdValue: Int32,
//        from fromDate: Date? = nil,
//        to toDate: Date? = nil
//    ) {
//        do {
//            let descriptor = FetchDescriptor<HabitTrackingLocalRecord>(
//                predicate: #Predicate { record in
//                    record.habitID == habitIdValue &&
//                    (fromDate == nil || record.entryDate >= fromDate!) &&
//                    (toDate == nil || record.entryDate <= toDate!)
//                }
//            )
//
//            let records = try context.fetch(descriptor)
//            for record in records {
//                context.delete(record)
//            }
//            try context.save()
//        } catch {
//            print("Error deleting habit entries: \(error)")
//        }
//    }
//    
//    
//    func deleteAllEntries() {
//        do {
//            let descriptor = FetchDescriptor<HabitTrackingLocalRecord>()
//            let records = try context.fetch(descriptor)
//            for record in records {
//                context.delete(record)
//            }
//            try context.save()
//        } catch {
//            print("Error deleting all habit tracking entries: \(error)")
//        }
//    }
//}
