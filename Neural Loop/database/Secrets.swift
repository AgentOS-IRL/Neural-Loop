//
//  Secrets.swift
//  Neural Loop
//
//  Created by Codex on 14/04/2026.
//

import Foundation
import Supabase

// Startup-only secrets metadata loaded from public.secrets.
let codexAuthTokenSecretKey = "neural_loop_codex_auth_token"
let chatgptAccountIDSecretKey = "neural_loop_chatgpt_account_id"
let codexRefreshTokenSecretKey = "neural_loop_codex_refresh_token"
let codexTokenExpirySecretKey = "neural_loop_codex_token_expiry"
let llmEnabledOverrideStorageKey = "llm_enabled_override"
let codexTokenRefreshClientID = "app_EMoamEEZ73f0CkXaXp7hrann"

struct Secrets: Codable, Identifiable, Equatable {
    static let databasePrimaryKey = ["key"]

    var key: String
    var value: String?

    var id: String { key }
}

struct CodexCredentials: Equatable {
    let accessToken: String
    let accountID: String
}

struct CodexTokenRefreshResponse: Codable, Equatable {
    let access_token: String
    let expires_in: TimeInterval
    let refresh_token: String
}

enum CodexTokenRefreshError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Codex token refresh URL is invalid."
        case .invalidResponse:
            return "Codex token refresh returned an invalid response."
        case .httpStatus(let statusCode):
            return "Codex token refresh failed with HTTP \(statusCode)."
        }
    }
}

extension Array where Element == Secrets {
    func containsSecretKey(_ key: String) -> Bool {
        contains { $0.key == key }
    }

    func secretValue(for key: String) -> String? {
        guard let value = first(where: { $0.key == key })?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    mutating func updateSecretValue(_ value: String?, for key: String) {
        if let index = firstIndex(where: { $0.key == key }) {
            self[index].value = value
        } else {
            append(Secrets(key: key, value: value))
        }
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

protocol SecretsUpdating {
    func updateSecretValue(key: String, value: String?) async throws
}

protocol CodexTokenRefreshing {
    func refreshCodexToken(refreshToken: String) async throws -> CodexTokenRefreshResponse
}

extension DBManager: SecretsFetching {}
extension DBManager: SecretsUpdating {}

extension DBManager {
    private var secretsTableName: String { "secrets" }

    func fetchAllSecrets() async throws -> [Secrets] {
        try await customsupabase
            .from(self.secretsTableName)
            .select("key, value")
            .execute()
            .value as [Secrets]
    }

    func updateSecretValue(key: String, value: String?) async throws {
        try await customsupabase
            .from(self.secretsTableName)
            .update(SecretValueUpdate(value: value))
            .eq("key", value: key)
            .execute()
    }
}

private struct SecretValueUpdate: Encodable {
    let value: String?

    enum CodingKeys: String, CodingKey {
        case value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let value {
            try container.encode(value, forKey: .value)
        } else {
            try container.encodeNil(forKey: .value)
        }
    }
}

struct CodexTokenRefreshService: CodexTokenRefreshing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func refreshCodexToken(refreshToken: String) async throws -> CodexTokenRefreshResponse {
        guard let url = URL(string: "https://auth.openai.com/oauth/token") else {
            throw CodexTokenRefreshError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formURLEncodedBody([
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: codexTokenRefreshClientID)
        ])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexTokenRefreshError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CodexTokenRefreshError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(CodexTokenRefreshResponse.self, from: data)
    }

    private static func formURLEncodedBody(_ queryItems: [URLQueryItem]) -> Data? {
        var components = URLComponents()
        components.queryItems = queryItems
        return components.percentEncodedQuery?.data(using: .utf8)
    }
}
