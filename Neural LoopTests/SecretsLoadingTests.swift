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
            Secrets(key: codexAuthTokenSecretKey, value: "hidden-token")
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

    func testAudioModeRoutingRequiresAuthorization() {
        XCTAssertFalse(
            shouldShowAudioModeShell(
                isAudioModeEnabled: true,
                canUseAudioMode: false
            )
        )

        XCTAssertTrue(
            shouldShowAudioModeShell(
                isAudioModeEnabled: true,
                canUseAudioMode: true
            )
        )
    }

    func testSettingsToggleOnlyEnablesWhenAuthorizedSecretsAreLoaded() {
        XCTAssertFalse(
            shouldEnableAudioModeToggle(
                secretsLoaded: false,
                canUseAudioMode: true
            )
        )

        XCTAssertFalse(
            shouldEnableAudioModeToggle(
                secretsLoaded: true,
                canUseAudioMode: false
            )
        )

        XCTAssertTrue(
            shouldEnableAudioModeToggle(
                secretsLoaded: true,
                canUseAudioMode: true
            )
        )
    }
}

private struct MockSecretsFetcher: SecretsFetching {
    let rows: [Secrets]

    func fetchAllSecrets() async throws -> [Secrets] {
        rows
    }
}
