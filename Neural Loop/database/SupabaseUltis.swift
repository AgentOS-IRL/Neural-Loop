//
//  SupabaseClient.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 08/01/2026.
//

import Foundation
import Supabase

private let unresolvedBuildSettingPrefix = "$("

private enum SupabaseConfiguration {
    static let urlString = requiredValue(
        forInfoDictionaryKey: "SupabaseURL",
        environmentKey: "SUPABASE_URL"
    )

    static let publishableKey = requiredValue(
        forInfoDictionaryKey: "SupabasePublishableKey",
        environmentKey: "SUPABASE_PUBLISHABLE_KEY"
    )

    static var url: URL {
        guard let url = URL(string: "https://" + urlString) else {
            fatalError("Invalid Supabase URL. Set SUPABASE_URL in Config/Supabase.xcconfig.")
        }

        return url
    }

    private static func requiredValue(
        forInfoDictionaryKey infoDictionaryKey: String,
        environmentKey: String
    ) -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String,
           value.isConfiguredValue {
            return value
        }

        if let value = ProcessInfo.processInfo.environment[environmentKey],
           value.isConfiguredValue {
            print(infoDictionaryKey)
            print(value)
            return value
        }

        fatalError("Missing \(environmentKey). Set it in Config/Supabase.xcconfig or the active scheme environment.")
    }
}

private extension String {
    var isConfiguredValue: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.hasPrefix(unresolvedBuildSettingPrefix)
    }
}

let customsupabase = SupabaseClient(
    supabaseURL: SupabaseConfiguration.url,
    supabaseKey: SupabaseConfiguration.publishableKey
)
