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
}

private struct MockSecretsFetcher: SecretsFetching {
    let rows: [Secrets]

    func fetchAllSecrets() async throws -> [Secrets] {
        rows
    }
}
