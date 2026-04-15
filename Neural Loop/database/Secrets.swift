//
//  Secrets.swift
//  Neural Loop
//
//  Created by Codex on 14/04/2026.
//

import Foundation
import Supabase

// Startup-only secrets metadata loaded from public.secrets.
let codexAuthTokenSecretKey = "codex_auth_token"

struct Secrets: Codable, Identifiable, Equatable {
    static let databasePrimaryKey = ["key"]

    var key: String
    var value: String

    var id: String { key }
}

extension Array where Element == Secrets {
    func containsSecretKey(_ key: String) -> Bool {
        contains { $0.key == key }
    }
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
