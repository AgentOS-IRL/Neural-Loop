//
//  DBManager.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//
import Foundation
import Supabase


final class DBManager {
    let localHabitTrackingStore: LocalHabitTrackingStore
    
    private init() {
        self.localHabitTrackingStore = .init()
    }
    
    // MARK: - Factory
    static func newInstance() -> DBManager { DBManager() }

    // MARK: - Connection Check
    // Simple select query to validate Supabase connectivity
    func testSupabaseConnection() async {
        do {
            try await customsupabase
                .from("tasks")
                .select()
                .limit(1)
                .execute()

            print("Connection successful.")
        } catch {
            print("Connection failed: \(error)")
        }
    }
}
