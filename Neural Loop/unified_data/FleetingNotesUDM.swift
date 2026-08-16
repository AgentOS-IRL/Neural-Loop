//
//  FleetingNotesUDM.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import Foundation

@MainActor
protocol TaskNoteServicing {
    func getFleetingNotes(taskId: Int64) async -> [FleetingNote]
}

extension UnifiedDataModel {
    func saveFleetingNote(_ request: CreateFleetingNoteRequest) async -> FleetingNote? {
        do {
            let note = try await manager.createFleetingNote(request)
            if request.task_id != nil {
                await refreshTaskNoteCounts()
            }
            return note
        } catch {
            print("Error saving fleeting note", error)
            return nil
        }
    }

    func updateFleetingNote(id: Int64, request: UpdateFleetingNoteRequest) async -> FleetingNote? {
        do {
            let note = try await manager.updateFleetingNote(id: id, request: request)
            await refreshTaskNoteCounts()
            return note
        } catch {
            print("Error updating fleeting note", error)
            return nil
        }
    }

    func deleteFleetingNote(id: Int64) async -> Bool {
        do {
            try await manager.deleteFleetingNote(id: id)
            await refreshTaskNoteCounts()
            return true
        } catch {
            print("Error deleting fleeting note", error)
            return false
        }
    }

    func getFleetingNotes(taskId: Int64) async -> [FleetingNote] {
        do {
            return try await manager.fetchFleetingNotes(taskId: taskId)
        } catch {
            print("Error fetching task notes", error)
            return []
        }
    }

    func taskNoteCount(for taskId: Int64?) -> Int {
        guard let taskId else { return 0 }
        return taskNoteCounts[taskId] ?? 0
    }

    func refreshTaskNoteCounts() async {
        do {
            let rows = try await manager.fetchTaskNoteCounts()
            taskNoteCounts = Dictionary(
                uniqueKeysWithValues: rows.map { ($0.task_id, Int($0.note_count)) }
            )
        } catch {
            print("Error loading task note counts", error)
            taskNoteCounts = [:]
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

    // MARK: - Note Image Attachments

    func saveImageAttachments(_ attachments: [ImageAttachment], forFleetingNoteId noteId: Int64) async {
        guard !attachments.isEmpty else { return }

        let requests = attachments.map {
            CreateImageRequest(image_uri: $0.dataURL, task_id: nil, fleeting_note_id: noteId)
        }

        do {
            _ = try await manager.insertImages(requests)
        } catch {
            print("Error saving note image attachments", error)
        }
    }

    func replaceImageAttachments(_ attachments: [ImageAttachment], forFleetingNoteId noteId: Int64) async {
        do {
            let existingRecords = try await manager.fetchImages(forFleetingNoteId: noteId)
            let existingRecordIDs = Set(existingRecords.map(\.id))
            let keptRecordIDs = Set(attachments.compactMap(\.existingRecordId))
            let idsToDelete = Array(existingRecordIDs.subtracting(keptRecordIDs))
            let requestsToInsert = attachments
                .filter { $0.existingRecordId == nil }
                .map { CreateImageRequest(image_uri: $0.dataURL, task_id: nil, fleeting_note_id: noteId) }

            if !idsToDelete.isEmpty {
                try await manager.deleteImages(ids: idsToDelete)
            }

            if !requestsToInsert.isEmpty {
                _ = try await manager.insertImages(requestsToInsert)
            }
        } catch {
            print("Error replacing note image attachments", error)
        }
    }

    func fetchImageAttachments(forFleetingNoteId noteId: Int64) async -> [ImageAttachment] {
        do {
            let records = try await manager.fetchImages(forFleetingNoteId: noteId)
            return records.compactMap { record in
                guard let thumbnailData = record.image_uri.decodedDataURLPayload() else { return nil }
                return ImageAttachment(
                    dataURL: record.image_uri,
                    thumbnailData: thumbnailData,
                    existingRecordId: record.id
                )
            }
        } catch {
            print("Error fetching note image attachments", error)
            return []
        }
    }
}

extension UnifiedDataModel: TaskNoteServicing {}
