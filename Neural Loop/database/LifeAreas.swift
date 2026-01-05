//
//  LifeAreas.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import SQLite

struct LifeAreas: Codable, Identifiable {
    var id: Int64?
    var name: String
    var vision: String?
    var is_sample: Bool = false
    var color: String
}

extension DBManager {

    // MARK: - Table & Columns

    private var lifeAreasTable: Table {
        Table("LifeAreas")
    }

    private var id: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    private var name: SQLite.Expression<String> { SQLite.Expression<String>("name") }
    private var vision: SQLite.Expression<String?> { SQLite.Expression<String?>("vision") }
    private var isSample: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_sample") }
    private var color: SQLite.Expression<String> { SQLite.Expression<String>("color") }

    // MARK: - Create

    func addLifeArea(_ area: LifeAreas) throws {
        let insert = lifeAreasTable.insert(
            name <- area.name,
            vision <- area.vision,
            isSample <- area.is_sample,
            color <- area.color
        )

        let rowId = try DBManager.sqliteDB!.run(insert)
        print("Inserted LifeArea with id:", rowId)
    }

    // MARK: - Read

    func fetchAllLifeAreas() throws -> [LifeAreas] {
        try DBManager.sqliteDB!.prepare(lifeAreasTable).map { row in
            LifeAreas(
                id: row[id],
                name: row[name],
                vision: row[vision],
                is_sample: row[isSample],
                color: row[color]
            )
        }
    }

    func fetchLifeArea(by idValue: Int64) throws -> LifeAreas? {
        let query = lifeAreasTable.filter(id == idValue)
        return try DBManager.sqliteDB!.pluck(query).map { row in
            LifeAreas(
                id: row[id],
                name: row[name],
                vision: row[vision],
                is_sample: row[isSample],
                color: row[color]
            )
        }
    }

    // MARK: - Update

    func updateLifeArea(_ area: LifeAreas) throws {
        guard let areaId = area.id else { return }

        let query = lifeAreasTable.filter(id == areaId)
        try DBManager.sqliteDB!.run(
            query.update(
                name <- area.name,
                vision <- area.vision,
                isSample <- area.is_sample,
                color <- area.color
            )
        )
    }

    // MARK: - Delete

    func deleteLifeArea(id areaId: Int64) throws {
        let query = lifeAreasTable.filter(id == areaId)
        try DBManager.sqliteDB!.run(query.delete())
    }
}
