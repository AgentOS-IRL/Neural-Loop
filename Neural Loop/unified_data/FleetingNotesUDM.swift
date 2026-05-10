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

    func updateFleetingNote(id: Int64, request: UpdateFleetingNoteRequest) async -> FleetingNote? {
        do {
            return try await manager.updateFleetingNote(id: id, request: request)
        } catch {
            print("Error updating fleeting note", error)
            return nil
        }
    }

    func deleteFleetingNote(id: Int64) async -> Bool {
        do {
            try await manager.deleteFleetingNote(id: id)
            return true
        } catch {
            print("Error deleting fleeting note", error)
            return false
        }
    }

    func createWorkReminder(title: String, notes: String?) async throws -> WorkReminder {
        try await createWorkReminder(title: title, notes: notes, dueDate: nil)
    }

    func createWorkReminder(title: String, notes: String? = nil, dueDate: Date? = nil) async throws -> WorkReminder {
        let dateResolver: (any GenesysReminderDateResolving)?
        if dueDate == nil,
           llm_enabled,
           let credentials = await validCodexCredentials() {
            dateResolver = CodexGenesysReminderDateResolver(
                accessToken: credentials.accessToken,
                accountID: credentials.accountID
            )
        } else {
            dateResolver = nil
        }

        return try await workReminderService.createGenesysReminder(
            title: title,
            notes: notes,
            dueDate: dueDate,
            dateResolver: dateResolver
        )
    }
}
