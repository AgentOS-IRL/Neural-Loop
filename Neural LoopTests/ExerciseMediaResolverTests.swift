import XCTest
@testable import Neural_Loop

@MainActor
final class ExerciseMediaResolverTests: XCTestCase {
    func testSlugifyMatchesStorageConvention() {
        XCTAssertEqual(ExerciseMediaPathBuilder.slugify("  Bench Press  "), "bench_press")
        XCTAssertEqual(ExerciseMediaPathBuilder.slugify("Incline-Press!!"), "incline_press")
        XCTAssertEqual(ExerciseMediaPathBuilder.slugify("Seated   Cable   Row"), "seated_cable_row")
        XCTAssertEqual(ExerciseMediaPathBuilder.slugify("  Lat Pull-Down / Wide Grip  "), "lat_pull_down_wide_grip")
    }

    func testResolveOrdersAssetsDeterministicallyAndCachesTheResult() async {
        let provider = MockExerciseMediaStorageProvider(
            filesByFolder: [
                "bench_press": [
                    .init(name: "hero.gif"),
                    .init(name: "thumb.webp"),
                    .init(name: "poster.png"),
                    .init(name: "alt.jpg")
                ]
            ]
        )
        let resolver = ExerciseMediaResolver(storage: provider, cacheLifetime: 60)

        let firstState = await resolver.resolveState(for: "Bench Press")
        let secondState = await resolver.resolveState(for: "Bench Press")

        guard case .loaded(let gallery) = firstState else {
            XCTFail("Expected loaded gallery")
            return
        }

        XCTAssertEqual(gallery.slug, "bench_press")
        XCTAssertEqual(
            gallery.assets.map(\.path),
            [
                "bench_press/poster.png",
                "bench_press/thumb.webp",
                "bench_press/alt.jpg",
                "bench_press/hero.gif"
            ]
        )
        XCTAssertEqual(gallery.thumbnailAsset?.path, "bench_press/poster.png")
        XCTAssertEqual(gallery.heroAsset(allowsMotion: true)?.path, "bench_press/hero.gif")
        XCTAssertEqual(gallery.heroAsset(allowsMotion: false)?.path, "bench_press/poster.png")

        guard case .loaded(let cachedGallery) = secondState else {
            XCTFail("Expected cached loaded gallery")
            return
        }

        XCTAssertEqual(cachedGallery, gallery)
        let listCallCount = await provider.listCallCount()
        let signedURLCallCount = await provider.createSignedURLsCallCount()
        XCTAssertEqual(listCallCount, 1)
        XCTAssertEqual(signedURLCallCount, 1)
    }

    func testBlankAndUnsupportedNamesDegradeCleanly() async {
        let provider = MockExerciseMediaStorageProvider(
            filesByFolder: [
                "unsupported_move": [
                    .init(name: "notes.txt"),
                    .init(name: "readme.md")
                ]
            ]
        )
        let resolver = ExerciseMediaResolver(storage: provider, cacheLifetime: 60)

        let blankState = await resolver.resolveState(for: "   ")
        let unsupportedState = await resolver.resolveState(for: "Unsupported Move")
        let emptyState = await resolver.resolveState(for: "Empty Folder")

        if case .fallback(.missingName) = blankState {
        } else {
            XCTFail("Expected missing-name fallback")
        }

        if case .fallback(.unsupportedFiles) = unsupportedState {
        } else {
            XCTFail("Expected unsupported-files fallback")
        }

        if case .fallback(.emptyFolder) = emptyState {
        } else {
            XCTFail("Expected empty-folder fallback")
        }
    }
}

private actor MockExerciseMediaStorageProvider: ExerciseMediaStorageProviding {
    private let filesByFolder: [String: [ExerciseMediaStorageEntry]]
    private var listCallCountValue = 0
    private var createSignedURLsCallCountValue = 0

    init(filesByFolder: [String: [ExerciseMediaStorageEntry]]) {
        self.filesByFolder = filesByFolder
    }

    func listMedia(in folderPath: String) async throws -> [ExerciseMediaStorageEntry] {
        listCallCountValue += 1
        return filesByFolder[folderPath] ?? []
    }

    func createSignedURLs(for paths: [String]) async throws -> [URL] {
        createSignedURLsCallCountValue += 1
        return paths.compactMap { URL(string: "https://example.com/\($0)") }
    }

    func listCallCount() -> Int {
        listCallCountValue
    }

    func createSignedURLsCallCount() -> Int {
        createSignedURLsCallCountValue
    }
}
