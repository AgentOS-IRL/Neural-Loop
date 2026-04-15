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
let chatgptAccountIDSecretKey = "chatgpt_account_id"
let llmEnabledOverrideStorageKey = "llm_enabled_override"

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

    func secretValue(for key: String) -> String? {
        first(where: { $0.key == key })?.value
    }
}

func shouldEnableLLMFeature(
    secretsLoaded: Bool,
    hasCodexAuthToken: Bool,
    overrideEnabled: Bool
) -> Bool {
    secretsLoaded && hasCodexAuthToken && overrideEnabled
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
