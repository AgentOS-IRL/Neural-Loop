//
//  Goals.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import Foundation
import SQLite

struct Goals: Codable, Identifiable {

    // MARK: - Properties
    var id: Int64?
    var title: String
    var lifearea_id: Int64
    var start_date: String          // ISO-8601: YYYY-MM-DD
    var deadline: String?           // nullable
    var color: String?              // nullable
    var description: String?        // nullable
}

extension DBManager {

    // MARK: - Table & Columns

    private var goalsTable: Table {
        Table("Goals")
    }

    private var id: SQLite.Expression<Int64> { Expression<Int64>("id") }
    private var title: SQLite.Expression<String> { Expression<String>("title") }
    private var lifeAreaId: SQLite.Expression<Int64> { Expression<Int64>("lifearea_id") }
    private var startDate: SQLite.Expression<String> { Expression<String>("start_date") }
    private var deadline: SQLite.Expression<String?> { Expression<String?>("deadline") }
    private var color: SQLite.Expression<String?> { Expression<String?>("color") }
    private var description: SQLite.Expression<String?> { Expression<String?>("description") }

    // MARK: - Create

    func addGoal(_ goal: Goals) throws {
        let insert = goalsTable.insert(
            title <- goal.title,
            lifeAreaId <- goal.lifearea_id,
            startDate <- goal.start_date,
            deadline <- goal.deadline,
            color <- goal.color,
            description <- goal.description
        )

        let rowId = try DBManager.sqliteDB!.run(insert)
        print("Inserted Goal with id:", rowId)
    }

    // MARK: - Read

    func fetchAllGoals() throws -> [Goals] {
        try DBManager.sqliteDB!.prepare(goalsTable).map { row in
            Goals(
                id: row[id],
                title: row[title],
                lifearea_id: row[lifeAreaId],
                start_date: row[startDate],
                deadline: row[deadline],
                color: row[color],
                description: row[description]
            )
        }
    }

    func fetchGoal(by idValue: Int64) throws -> Goals? {
        let query = goalsTable.filter(id == idValue)
        return try DBManager.sqliteDB!.pluck(query).map { row in
            Goals(
                id: row[id],
                title: row[title],
                lifearea_id: row[lifeAreaId],
                start_date: row[startDate],
                deadline: row[deadline],
                color: row[color],
                description: row[description]
            )
        }
    }

    func fetchGoals(forLifeArea lifeAreaIdValue: Int64) throws -> [Goals] {
        let query = goalsTable.filter(lifeAreaId == lifeAreaIdValue)
        return try DBManager.sqliteDB!.prepare(query).map { row in
            Goals(
                id: row[id],
                title: row[title],
                lifearea_id: row[lifeAreaId],
                start_date: row[startDate],
                deadline: row[deadline],
                color: row[color],
                description: row[description]
            )
        }
    }

    // MARK: - Update

    func updateGoal(_ goal: Goals) throws {
        guard let goalId = goal.id else { return }

        let query = goalsTable.filter(id == goalId)
        try DBManager.sqliteDB!.run(
            query.update(
                title <- goal.title,
                lifeAreaId <- goal.lifearea_id,
                startDate <- goal.start_date,
                deadline <- goal.deadline,
                color <- goal.color,
                description <- goal.description
            )
        )
    }

    // MARK: - Delete

    func deleteGoal(id goalId: Int64) throws {
        let query = goalsTable.filter(id == goalId)
        try DBManager.sqliteDB!.run(query.delete())
    }

    func deleteGoals(forLifeArea lifeAreaIdValue: Int64) throws {
        let query = goalsTable.filter(lifeAreaId == lifeAreaIdValue)
        try DBManager.sqliteDB!.run(query.delete())
    }
}
