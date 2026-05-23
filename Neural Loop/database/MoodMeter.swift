//
//  MoodMeter.swift
//  Neural Loop
//
//  Created by Codex on 23/05/2026.
//

import Foundation
import Supabase

struct MoodMeterRecord: Codable, Identifiable, Equatable {
    let id: Int64
    let timestamp: Date
    let mood: String
}

struct CreateMoodMeterRequest: Codable, Equatable {
    let mood: String
}

enum MoodMeterError: LocalizedError, Equatable {
    case insertReturnedNoRows

    var errorDescription: String? {
        switch self {
        case .insertReturnedNoRows:
            return "Mood could not be saved."
        }
    }
}

extension MoodMeterRecord {
    static let tableName = "mood_meter"
}

extension DBManager {
    func createMoodMeterRecord(_ request: CreateMoodMeterRequest) async throws -> MoodMeterRecord {
        let inserted: [MoodMeterRecord] = try await customsupabase
            .from(MoodMeterRecord.tableName)
            .insert(request)
            .select("id, timestamp, mood")
            .execute()
            .value

        guard let record = inserted.first else {
            throw MoodMeterError.insertReturnedNoRows
        }

        return record
    }
}
