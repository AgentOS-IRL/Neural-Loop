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
        
        print("Get environment vars safely")
        // 1) Get environment vars safely
        let dbPath = try databasePath()

        let url = "https://neuralloop-sanjeevhalyal.aws-eu-west-1.turso.io"
        let token = "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3Njc1NTY5OTAsImlkIjoiMTQ5N2VhMWUtZDhhNC00NDliLTgyNTUtMGQwMDI5NGEzMDc0IiwicmlkIjoiZTEwYWY3OTktNWRlOC00Nzk0LWIzNWItZTk3ZWIyZDg1NTc2In0.HN_U8YJ_GkqIHaVIj_csK9NvsZHLQeM-JJ_JFvf8Df3F9CvtLoktiIL-BfvP6xyDFU7-LKp3UOfRAGD6oS-VDQ"
        
        
        
        print("Open libSQL database")
        // 2) Open libSQL database
        let libsqlDB = try Libsql.Database(
            path: dbPath,
            url: url,
            authToken: token,
            syncInterval: 300
        )
        
        print("open connection for sync")
        let _ = try libsqlDB.connect()  // open connection for sync
        
        print("Syncing with Turso...")
        try libsqlDB.sync()
        print("Done Syncing with Turso")

        // 3) Open SQLite.swift on same file
        let sqliteDB = try SQLite.Connection(dbPath)

        
        DBManager.libsqlDB =  libsqlDB
        DBManager.sqliteDB = sqliteDB
        return DBManager()
    }
    
    static func resetLocalDatabase() throws {
//        // 1. Close connections
//        DBManager.sqliteDB = nil
//        DBManager.libsqlDB = nil
//
//        // 2. Delete the local DB file
//        let dbPath = try databasePath()
//        let fm = FileManager.default
//
//        if fm.fileExists(atPath: dbPath) {
//            try fm.removeItem(atPath: dbPath)
//            print("🗑️ Local database deleted")
//        }
//
//        // 3. Recreate DB (will resync from Turso on init)
//        _ = try DBManager.newInstance()
//        print("✅ Local database recreated and synced")
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

        try fm.createDirectory(
            at: appDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return appDir.appendingPathComponent("local.sqlite").path
    }



    // MARK: - Manual Sync

    func syncNow() throws {
        
//        try DBManager.libsqlDB!.sync() // sync local to Turso (optional)  [oai_citation:1‡docs.turso.tech](https://docs.turso.tech/sdk/swift/quickstart?utm_source=chatgpt.com)
    }
}
