import XCTest
@testable import Neural_Loop

@MainActor
final class SecretsLoadingTests: XCTestCase {

    func testSecretsModelDecodesKeyAndValue() throws {
        let data = """
        [
          {"key":"api_key","value":"secret-one"},
          {"key":"database_url","value":"secret-two"}
        ]
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([Secrets].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].key, "api_key")
        XCTAssertEqual(decoded[0].value, "secret-one")
        XCTAssertEqual(decoded[0].id, "api_key")
        XCTAssertEqual(decoded[1].key, "database_url")
        XCTAssertEqual(decoded[1].value, "secret-two")
    }

    func testSecretsModelDecodesNullValue() throws {
        let data = """
        [
          {"key":"optional_secret","value":null}
        ]
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([Secrets].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].key, "optional_secret")
        XCTAssertNil(decoded[0].value)
    }

    func testNeuralLoopSecretKeyNamesAreStable() {
        XCTAssertEqual(codexAuthTokenSecretKey, "neural_loop_codex_auth_token")
        XCTAssertEqual(chatgptAccountIDSecretKey, "neural_loop_chatgpt_account_id")
        XCTAssertEqual(codexRefreshTokenSecretKey, "neural_loop_codex_refresh_token")
        XCTAssertEqual(codexTokenExpirySecretKey, "neural_loop_codex_token_expiry")
    }

    func testLoadSecretsStoresRowsAndDerivesSortedKeys() async {
        let rows = [
            Secrets(key: "zeta_token", value: "hidden-z"),
            Secrets(key: "alpha_token", value: "hidden-a")
        ]
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertEqual(model.secrets, rows)
        XCTAssertEqual(model.loadedSecretKeys, ["alpha_token", "zeta_token"])
    }

    func testLoadedSecretKeysDoNotExposeValues() async {
        let rows = [
            Secrets(key: "settings_flag", value: "do-not-render")
        ]
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertEqual(model.loadedSecretKeys, ["settings_flag"])
        XCTAssertFalse(model.loadedSecretKeys.contains("do-not-render"))
    }

    func testCanUseAudioModeWhenCodexAuthTokenIsPresent() async {
        let rows = [
            Secrets(key: "settings_flag", value: "do-not-render"),
            Secrets(key: codexAuthTokenSecretKey, value: "hidden-token"),
            Secrets(key: chatgptAccountIDSecretKey, value: "hidden-account")
        ]
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            autoStart: false
        )

        XCTAssertFalse(model.secretsLoaded)

        await model.loadSecrets()

        XCTAssertTrue(model.secretsLoaded)
        XCTAssertTrue(model.canUseAudioMode)
    }

    func testCanUseAudioModeIsFalseWhenChatGPTAccountIDIsMissing() async {
        let rows = [
            Secrets(key: codexAuthTokenSecretKey, value: "hidden-token")
        ]
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertTrue(model.secretsLoaded)
        XCTAssertFalse(model.canUseAudioMode)
    }

    func testCanUseAudioModeIsFalseWhenCodexAuthTokenIsMissing() async {
        let rows = [
            Secrets(key: "settings_flag", value: "do-not-render")
        ]
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertTrue(model.secretsLoaded)
        XCTAssertFalse(model.canUseAudioMode)
    }

    func testCanUseAudioModeDependsOnSecretKeyNotValue() async {
        let rows = [
            Secrets(key: "not_the_token", value: codexAuthTokenSecretKey)
        ]
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertTrue(model.secretsLoaded)
        XCTAssertFalse(model.canUseAudioMode)
    }

    func testCanUseAudioModeRequiresBothSecrets() async {
        let rows = [
            Secrets(key: codexAuthTokenSecretKey, value: "hidden-token"),
            Secrets(key: chatgptAccountIDSecretKey, value: "hidden-account")
        ]
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertTrue(model.secretsLoaded)
        XCTAssertTrue(model.hasCodexAuthTokenSecret)
        XCTAssertTrue(model.hasChatGPTAccountIDSecret)
        XCTAssertTrue(model.canUseAudioMode)
    }

    func testShouldEnableLLMFeatureRequiresSecretAndOverride() {
        XCTAssertTrue(
            shouldEnableLLMFeature(
                secretsLoaded: true,
                hasCodexAuthToken: true,
                overrideEnabled: true
            )
        )

        XCTAssertFalse(
            shouldEnableLLMFeature(
                secretsLoaded: true,
                hasCodexAuthToken: true,
                overrideEnabled: false
            )
        )

        XCTAssertFalse(
            shouldEnableLLMFeature(
                secretsLoaded: true,
                hasCodexAuthToken: false,
                overrideEnabled: true
            )
        )

        XCTAssertFalse(
            shouldEnableLLMFeature(
                secretsLoaded: false,
                hasCodexAuthToken: true,
                overrideEnabled: true
            )
        )
    }

    func testLLMEnabledMatchesLoadedSecretsAndOverrideState() async {
        defer {
            UserDefaults.standard.removeObject(forKey: llmEnabledOverrideStorageKey)
        }

        let cases: [(rows: [Secrets], overrideEnabled: Bool, expected: Bool)] = [
            (
                rows: [Secrets(key: codexAuthTokenSecretKey, value: "hidden-token")],
                overrideEnabled: true,
                expected: true
            ),
            (
                rows: [Secrets(key: codexAuthTokenSecretKey, value: "hidden-token")],
                overrideEnabled: false,
                expected: false
            ),
            (
                rows: [Secrets(key: "settings_flag", value: "do-not-render")],
                overrideEnabled: true,
                expected: false
            ),
            (
                rows: [Secrets(key: "settings_flag", value: "do-not-render")],
                overrideEnabled: false,
                expected: false
            )
        ]

        for testCase in cases {
            UserDefaults.standard.set(testCase.overrideEnabled, forKey: llmEnabledOverrideStorageKey)

            let model = UnifiedDataModel(
                manager: DBManager.newInstance(),
                secretsFetcher: MockSecretsFetcher(rows: testCase.rows),
                autoStart: false
            )

            await model.loadSecrets()

            XCTAssertTrue(model.secretsLoaded)
            XCTAssertEqual(model.llm_enabled, testCase.expected)
        }
    }

    func testRefreshSecretsRefetchesAndUpdatesLLMEnabled() async {
        defer {
            UserDefaults.standard.removeObject(forKey: llmEnabledOverrideStorageKey)
        }

        UserDefaults.standard.set(true, forKey: llmEnabledOverrideStorageKey)

        let firstRows = [
            Secrets(key: codexAuthTokenSecretKey, value: "hidden-token")
        ]
        let secondRows = [
            Secrets(key: "settings_flag", value: "do-not-render")
        ]
        let fetcher = SequencedSecretsFetcher(responses: [firstRows, secondRows])
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: fetcher,
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertEqual(fetcher.fetchCount, 1)
        XCTAssertEqual(model.loadedSecretKeys, [codexAuthTokenSecretKey])
        XCTAssertTrue(model.llm_enabled)

        await model.refreshSecrets()

        XCTAssertEqual(fetcher.fetchCount, 2)
        XCTAssertEqual(model.loadedSecretKeys, ["settings_flag"])
        XCTAssertFalse(model.llm_enabled)
    }

    func testLoadSecretsRefreshesCodexTokenWhenExpiryIsNull() async {
        let rows = codexSecretRows(expiry: nil)
        let updater = MockSecretsUpdater()
        let refresher = MockCodexTokenRefresher()
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            secretsUpdater: updater,
            codexTokenRefresher: refresher,
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertEqual(refresher.refreshTokens, ["refresh-old"])
        XCTAssertEqual(updater.value(for: codexAuthTokenSecretKey), "access-new")
        XCTAssertEqual(updater.value(for: codexRefreshTokenSecretKey), "refresh-new")
        XCTAssertNotNil(updater.value(for: codexTokenExpirySecretKey))
        XCTAssertEqual(model.codexAccessToken, "access-new")
        XCTAssertEqual(model.codexAccountID, "account-1")
    }

    func testLoadSecretsRefreshesCodexTokenWhenExpiryIsExpired() async {
        let rows = codexSecretRows(expiry: isoDateString(secondsFromNow: -1))
        let refresher = MockCodexTokenRefresher()
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            secretsUpdater: MockSecretsUpdater(),
            codexTokenRefresher: refresher,
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertEqual(refresher.refreshTokens, ["refresh-old"])
        XCTAssertEqual(model.codexAccessToken, "access-new")
    }

    func testLoadSecretsRefreshesCodexTokenWhenExpiryIsNearExpiry() async {
        let rows = codexSecretRows(expiry: isoDateString(secondsFromNow: 30))
        let refresher = MockCodexTokenRefresher()
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            secretsUpdater: MockSecretsUpdater(),
            codexTokenRefresher: refresher,
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertEqual(refresher.refreshTokens, ["refresh-old"])
        XCTAssertEqual(model.codexAccessToken, "access-new")
    }

    func testLoadSecretsRefreshesCodexTokenWhenExpiryIsMalformed() async {
        let rows = codexSecretRows(expiry: "not-a-date")
        let refresher = MockCodexTokenRefresher()
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            secretsUpdater: MockSecretsUpdater(),
            codexTokenRefresher: refresher,
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertEqual(refresher.refreshTokens, ["refresh-old"])
        XCTAssertEqual(model.codexAccessToken, "access-new")
    }

    func testLoadSecretsRefreshesCodexTokenWhenAccessTokenIsMissing() async {
        var rows = codexSecretRows(expiry: isoDateString(secondsFromNow: 3600))
        rows.updateSecretValue(nil, for: codexAuthTokenSecretKey)
        let refresher = MockCodexTokenRefresher()
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            secretsUpdater: MockSecretsUpdater(),
            codexTokenRefresher: refresher,
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertEqual(refresher.refreshTokens, ["refresh-old"])
        XCTAssertEqual(model.codexAccessToken, "access-new")
    }

    func testLoadSecretsDoesNotRefreshCodexTokenWhenExpiryIsValid() async {
        let rows = codexSecretRows(expiry: isoDateString(secondsFromNow: 3600))
        let refresher = MockCodexTokenRefresher()
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            secretsUpdater: MockSecretsUpdater(),
            codexTokenRefresher: refresher,
            autoStart: false
        )

        await model.loadSecrets()

        XCTAssertTrue(refresher.refreshTokens.isEmpty)
        XCTAssertEqual(model.codexAccessToken, "access-old")
    }

    func testRefreshSecretsForcesCodexTokenRefresh() async {
        let rows = codexSecretRows(expiry: isoDateString(secondsFromNow: 3600))
        let updater = MockSecretsUpdater()
        let refresher = MockCodexTokenRefresher()
        let model = UnifiedDataModel(
            manager: DBManager.newInstance(),
            secretsFetcher: MockSecretsFetcher(rows: rows),
            secretsUpdater: updater,
            codexTokenRefresher: refresher,
            autoStart: false
        )

        await model.refreshSecrets()

        XCTAssertEqual(refresher.refreshTokens, ["refresh-old"])
        XCTAssertEqual(updater.value(for: codexAuthTokenSecretKey), "access-new")
        XCTAssertEqual(model.codexAccessToken, "access-new")
    }

    func testAudioModeTransitionCopyUsesAIPageLabels() {
        XCTAssertEqual(AudioModeTransitionCopy.pageTitle, "AI")
        XCTAssertEqual(AudioModeTransitionCopy.activeStatusTitle, "AI ready")
        XCTAssertEqual(AudioModeTransitionCopy.activeStatusDetail, "Voice capture can send committed segments to Codex.")
    }

    func testSettingsDebugSectionsOnlyShowWhenDebugIsEnabled() {
        XCTAssertFalse(shouldShowSettingsDebugSections(isDebugEnabled: false))
        XCTAssertTrue(shouldShowSettingsDebugSections(isDebugEnabled: true))
    }

    func testSettingsDebugStorageKeyIsStable() {
        XCTAssertEqual(settingsDebugEnabledStorageKey, "settingsDebugEnabled")
    }
}

private func codexSecretRows(expiry: String?) -> [Secrets] {
    [
        Secrets(key: codexAuthTokenSecretKey, value: "access-old"),
        Secrets(key: chatgptAccountIDSecretKey, value: "account-1"),
        Secrets(key: codexRefreshTokenSecretKey, value: "refresh-old"),
        Secrets(key: codexTokenExpirySecretKey, value: expiry)
    ]
}

private func isoDateString(secondsFromNow seconds: TimeInterval) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: Date().addingTimeInterval(seconds))
}

private struct MockSecretsFetcher: SecretsFetching {
    let rows: [Secrets]

    func fetchAllSecrets() async throws -> [Secrets] {
        rows
    }
}

private final class MockSecretsUpdater: SecretsUpdating {
    private(set) var updatedValues: [String: String?] = [:]

    func updateSecretValue(key: String, value: String?) async throws {
        updatedValues.updateValue(value, forKey: key)
    }

    func value(for key: String) -> String? {
        guard let value = updatedValues[key] else {
            return nil
        }

        return value
    }
}

private final class MockCodexTokenRefresher: CodexTokenRefreshing {
    private(set) var refreshTokens: [String] = []
    var response = CodexTokenRefreshResponse(
        access_token: "access-new",
        expires_in: 3600,
        refresh_token: "refresh-new"
    )

    func refreshCodexToken(refreshToken: String) async throws -> CodexTokenRefreshResponse {
        refreshTokens.append(refreshToken)
        return response
    }
}

private final class SequencedSecretsFetcher: SecretsFetching {
    private let responses: [[Secrets]]
    private(set) var fetchCount = 0

    init(responses: [[Secrets]]) {
        self.responses = responses
    }

    func fetchAllSecrets() async throws -> [Secrets] {
        let index = min(fetchCount, responses.count - 1)
        defer { fetchCount += 1 }
        return responses[index]
    }
}
