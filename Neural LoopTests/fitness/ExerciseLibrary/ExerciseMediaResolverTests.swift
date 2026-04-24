import Foundation
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

    func testResolveUsesSmallAssetForCompactSurfacesAndGifAssetsForPreview() async {
        let provider = MockExerciseMediaStorageProvider(
            filesByFolder: [
                "bench_press": [
                    .init(name: "bench_press_small.webp"),
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
        XCTAssertEqual(gallery.compactAsset?.path, "bench_press/bench_press_small.webp")
        XCTAssertEqual(
            gallery.assets.map(\.path),
            [
                "bench_press/poster.png",
                "bench_press/thumb.webp",
                "bench_press/alt.jpg",
                "bench_press/hero.gif"
            ]
        )
        XCTAssertEqual(gallery.previewAssets.map(\.path), ["bench_press/hero.gif"])
        XCTAssertEqual(gallery.thumbnailAsset?.path, "bench_press/bench_press_small.webp")
        XCTAssertEqual(gallery.expandedPreviewAsset?.path, "bench_press/hero.gif")
        XCTAssertEqual(gallery.expandedAsset?.path, "bench_press/hero.gif")
        XCTAssertEqual(gallery.heroAsset(allowsMotion: true)?.path, "bench_press/hero.gif")
        XCTAssertEqual(gallery.heroAsset(allowsMotion: false)?.path, "bench_press/hero.gif")
        XCTAssertEqual(gallery.previewCaption, "1 media file")
        XCTAssertTrue(gallery.previewAvailable)

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

    func testResolveFallsBackToOriginalWhenSmallAssetIsMissing() async {
        let provider = MockExerciseMediaStorageProvider(
            filesByFolder: [
                "bench_press": [
                    .init(name: "poster.png"),
                    .init(name: "hero.gif")
                ]
            ]
        )
        let resolver = ExerciseMediaResolver(storage: provider, cacheLifetime: 60)

        let state = await resolver.resolveState(for: "Bench Press")

        guard case .loaded(let gallery) = state else {
            XCTFail("Expected loaded gallery")
            return
        }

        XCTAssertNil(gallery.compactAsset)
        XCTAssertEqual(gallery.thumbnailAsset?.path, "bench_press/poster.png")
        XCTAssertEqual(gallery.expandedPreviewAsset?.path, "bench_press/hero.gif")
        XCTAssertEqual(gallery.expandedAsset?.path, "bench_press/hero.gif")
        XCTAssertEqual(gallery.previewAssets.map(\.path), ["bench_press/hero.gif"])
        XCTAssertEqual(gallery.heroAsset(allowsMotion: true)?.path, "bench_press/hero.gif")
        XCTAssertEqual(gallery.previewCaption, "1 media file")
    }

    func testResolveTreatsAlternateSmallWebPNamesAsCompactAssets() async {
        let provider = MockExerciseMediaStorageProvider(
            filesByFolder: [
                "cable_row": [
                    .init(name: "1_small.webp"),
                    .init(name: "poster.png"),
                    .init(name: "demo.gif")
                ]
            ]
        )
        let resolver = ExerciseMediaResolver(storage: provider, cacheLifetime: 60)

        let state = await resolver.resolveState(for: "Cable Row")

        guard case .loaded(let gallery) = state else {
            XCTFail("Expected loaded gallery")
            return
        }

        XCTAssertEqual(gallery.compactAsset?.path, "cable_row/1_small.webp")
        XCTAssertEqual(gallery.thumbnailAsset?.path, "cable_row/1_small.webp")
        XCTAssertEqual(gallery.previewAssets.map(\.path), ["cable_row/demo.gif"])
        XCTAssertEqual(gallery.expandedPreviewAsset?.path, "cable_row/demo.gif")
        XCTAssertEqual(gallery.expandedAsset?.path, "cable_row/demo.gif")
    }

    func testResolveLeavesPreviewEmptyWhenOnlyCompactAssetExists() async {
        let provider = MockExerciseMediaStorageProvider(
            filesByFolder: [
                "bench_press": [
                    .init(name: "bench_press_small.webp")
                ]
            ]
        )
        let resolver = ExerciseMediaResolver(storage: provider, cacheLifetime: 60)

        let state = await resolver.resolveState(for: "Bench Press")

        guard case .loaded(let gallery) = state else {
            XCTFail("Expected loaded gallery")
            return
        }

        XCTAssertEqual(gallery.compactAsset?.path, "bench_press/bench_press_small.webp")
        XCTAssertNil(gallery.expandedPreviewAsset)
        XCTAssertNil(gallery.expandedAsset)
        XCTAssertEqual(gallery.thumbnailAsset?.path, "bench_press/bench_press_small.webp")
        XCTAssertEqual(gallery.previewAssets.map(\.path), [])
        XCTAssertNil(gallery.heroAsset(allowsMotion: true))
        XCTAssertFalse(gallery.previewAvailable)
        XCTAssertEqual(gallery.previewCaption, "No GIF preview")
    }

    func testConcurrentResolveStateSharesInFlightLoad() async {
        let gate = AsyncGate()
        let provider = MockExerciseMediaStorageProvider(
            filesByFolder: [
                "bench_press": [
                    .init(name: "bench_press_small.webp"),
                    .init(name: "poster.png"),
                    .init(name: "hero.gif")
                ]
            ],
            listGate: gate
        )
        let resolver = ExerciseMediaResolver(storage: provider, cacheLifetime: 60)

        async let firstState = resolver.resolveState(for: "Bench Press")
        async let secondState = resolver.resolveState(for: "Bench Press")

        await gate.open()

        let resolvedFirstState = await firstState
        let resolvedSecondState = await secondState

        guard case .loaded(let firstGallery) = resolvedFirstState,
              case .loaded(let secondGallery) = resolvedSecondState else {
            XCTFail("Expected both concurrent resolves to load successfully")
            return
        }

        XCTAssertEqual(firstGallery, secondGallery)
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
    private let listGate: AsyncGate?
    private var listCallCountValue = 0
    private var createSignedURLsCallCountValue = 0

    init(
        filesByFolder: [String: [ExerciseMediaStorageEntry]],
        listGate: AsyncGate? = nil
    ) {
        self.filesByFolder = filesByFolder
        self.listGate = listGate
    }

    func listMedia(in folderPath: String) async throws -> [ExerciseMediaStorageEntry] {
        listCallCountValue += 1
        if let listGate {
            await listGate.wait()
        }
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

private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true

        let pendingWaiters = waiters
        waiters.removeAll()
        for waiter in pendingWaiters {
            waiter.resume()
        }
    }
}
