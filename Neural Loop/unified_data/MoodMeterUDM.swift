//
//  MoodMeterUDM.swift
//  Neural Loop
//
//  Created by Codex on 23/05/2026.
//

import Foundation

extension UnifiedDataModel {
    func saveMoodMeterRecord(mood: String) async -> MoodMeterRecord? {
        do {
            return try await manager.createMoodMeterRecord(CreateMoodMeterRequest(mood: mood))
        } catch {
            print("Error saving mood meter record", error)
            return nil
        }
    }
}
