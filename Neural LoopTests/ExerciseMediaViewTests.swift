import Foundation
import XCTest
@testable import Neural_Loop

final class ExerciseMediaViewTests: XCTestCase {
    func testExerciseMediaDisplayModeSizingContract() {
        XCTAssertEqual(ExerciseMediaDisplayMode.thumbnail.tileSize, CGSize(width: 58, height: 58))
        XCTAssertEqual(ExerciseMediaDisplayMode.hero.tileSize, CGSize(width: 100, height: 72))
        XCTAssertNotEqual(ExerciseMediaDisplayMode.thumbnail.tileSize, ExerciseMediaDisplayMode.hero.tileSize)
        XCTAssertLessThan(ExerciseMediaDisplayMode.thumbnail.tileSize.width, ExerciseMediaDisplayMode.hero.tileSize.width)
        XCTAssertLessThan(ExerciseMediaDisplayMode.thumbnail.tileSize.height, ExerciseMediaDisplayMode.hero.tileSize.height)
    }

    func testGalleryPrefersCompactAssetForThumbnailsAndGifAssetsForExpandedPreview() {
        let compactAsset = ExerciseMediaAsset(
            path: "bench_press/bench_press_small.webp",
            url: URL(string: "https://example.com/bench_press/bench_press_small.webp")!,
            fileName: "bench_press_small.webp",
            fileExtension: "webp",
            isAnimated: false,
            sortPriority: 1
        )
        let gifAsset = ExerciseMediaAsset(
            path: "bench_press/hero.gif",
            url: URL(string: "https://example.com/bench_press/hero.gif")!,
            fileName: "hero.gif",
            fileExtension: "gif",
            isAnimated: true,
            sortPriority: 3
        )
        let gallery = ExerciseMediaGallery(
            exerciseName: "Bench Press",
            slug: "bench_press",
            compactAsset: compactAsset,
            assets: [gifAsset]
        )

        XCTAssertEqual(gallery.thumbnailAsset?.path, compactAsset.path)
        XCTAssertEqual(gallery.expandedAsset?.path, gifAsset.path)
        XCTAssertEqual(gallery.previewAssets.map(\.path), [gifAsset.path])
        XCTAssertEqual(gallery.heroAsset(allowsMotion: false)?.path, gifAsset.path)
        XCTAssertEqual(gallery.previewCaption, "1 media file")
    }
}
