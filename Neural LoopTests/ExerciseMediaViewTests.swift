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

    func testGalleryPrefersCompactAssetForThumbnailsAndOriginalAssetForExpandedPreview() {
        let compactAsset = ExerciseMediaAsset(
            path: "bench_press/bench_press_small.webp",
            url: URL(string: "https://example.com/bench_press/bench_press_small.webp")!,
            fileName: "bench_press_small.webp",
            fileExtension: "webp",
            isAnimated: false,
            sortPriority: 1
        )
        let originalAsset = ExerciseMediaAsset(
            path: "bench_press/poster.png",
            url: URL(string: "https://example.com/bench_press/poster.png")!,
            fileName: "poster.png",
            fileExtension: "png",
            isAnimated: false,
            sortPriority: 0
        )
        let gallery = ExerciseMediaGallery(
            exerciseName: "Bench Press",
            slug: "bench_press",
            compactAsset: compactAsset,
            assets: [originalAsset]
        )

        XCTAssertEqual(gallery.thumbnailAsset?.path, compactAsset.path)
        XCTAssertEqual(gallery.expandedAsset?.path, originalAsset.path)
        XCTAssertEqual(gallery.previewAssets.map(\.path), [originalAsset.path])
        XCTAssertEqual(gallery.heroAsset(allowsMotion: false)?.path, originalAsset.path)
        XCTAssertEqual(gallery.previewCaption, "1 media file")
    }
}
