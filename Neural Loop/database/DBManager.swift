//
//  DBManager.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//
import Foundation
import Libsql  // libSQL Swift package
import SQLite  // SQLite.swift

final class DBManager {

    // MARK: - Properties

    static var libsqlDB: Libsql.Database? = nil
    static var sqliteDB: SQLite.Connection? = nil

    // MARK: - Initializer

    private init(){}

    /// Create and return a DBManager instance
    static func newInstance() throws -> DBManager {
        if DBManager.libsqlDB != nil && DBManager.sqliteDB != nil{
            return DBManager()
        }
        
        // 1) Get environment vars safely
        let dbPath = try databasePath()

        let url = "libsql://neuralloop-sanjeevhalyal.aws-eu-west-1.turso.io"
        let token = "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3Njc1NTY5OTAsImlkIjoiMTQ5N2VhMWUtZDhhNC00NDliLTgyNTUtMGQwMDI5NGEzMDc0IiwicmlkIjoiZTEwYWY3OTktNWRlOC00Nzk0LWIzNWItZTk3ZWIyZDg1NTc2In0.HN_U8YJ_GkqIHaVIj_csK9NvsZHLQeM-JJ_JFvf8Df3F9CvtLoktiIL-BfvP6xyDFU7-LKp3UOfRAGD6oS-VDQ"
        

        // 2) Open libSQL database
        let libsqlDB = try Libsql.Database(
            path: dbPath,
            url: url,
            authToken: token,
            syncInterval: 300
        )

        let _ = try libsqlDB.connect()  // open connection for sync
        
        print("Syncing with Turso...")
        try libsqlDB.sync()
        print("Done Syncing with Turso")

        // 3) Open SQLite.swift on same file
        let sqliteDB = try SQLite.Connection(dbPath)

        // 4) Perform migrations
        try migrateIfNeeded(sqliteDB)
        
        DBManager.libsqlDB =  libsqlDB
        DBManager.sqliteDB = sqliteDB
        return DBManager()
    }
    
    private static func databasePath() throws -> String {
        let fm = FileManager.default
        let baseURL = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appDir = baseURL.appendingPathComponent("NeuralLoop", isDirectory: true)

        if !fm.fileExists(atPath: appDir.path) {
            try fm.createDirectory(
                at: appDir,
                withIntermediateDirectories: true
            )
        }

        return appDir.appendingPathComponent("local.db").path
    }

    // MARK: - Migration

    private static func migrateIfNeeded(_ db: SQLite.Connection) throws {
        let lifeArea = Table("LifeArea")

        let id = Expression<Int64>("id")
        let name = Expression<String>("name")
        let vision = Expression<String?>("vision")
        let color = Expression<String>("color")
        let isSample = Expression<Bool>("is_sample")

        try db.run(lifeArea.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(name)
            t.column(vision)
            t.column(color, unique: true)
            t.column(isSample, defaultValue: false)
        })
    }

    // MARK: - Manual Sync

    func syncNow() throws {
        
        try DBManager.libsqlDB!.sync() // sync local to Turso (optional)  [oai_citation:1‡docs.turso.tech](https://docs.turso.tech/sdk/swift/quickstart?utm_source=chatgpt.com)
    }
}
