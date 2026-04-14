//
//  Secrets.swift
//  Neural Loop
//
//  Created by Codex on 14/04/2026.
//

import Foundation
import Supabase

// Startup-only secrets metadata loaded from public.secrets.
struct Secrets: Codable, Identifiable, Equatable {
    static let databasePrimaryKey = ["key"]

    var key: String
    var value: String

    var id: String { key }
}

protocol SecretsFetching {
    func fetchAllSecrets() async throws -> [Secrets]
}

extension DBManager: SecretsFetching {}

extension DBManager {
    private var secretsTableName: String { "secrets" }

    func fetchAllSecrets() async throws -> [Secrets] {
        try await customsupabase
            .from(self.secretsTableName)
            .select("key, value")
            .execute()
            .value as [Secrets]
    }
}
