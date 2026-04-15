//
//  FleetingNotesUDM.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import Foundation

extension UnifiedDataModel {
    func saveFleetingNote(_ request: CreateFleetingNoteRequest) async -> FleetingNote? {
        do {
            return try await manager.createFleetingNote(request)
        } catch {
            print("Error saving fleeting note", error)
            return nil
        }
    }
}
