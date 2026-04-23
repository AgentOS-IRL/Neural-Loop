import CoreGraphics
import Foundation

enum ExerciseMediaResolutionState: Equatable, Sendable {
    case loading
    case loaded(ExerciseMediaGallery)
    case fallback(ExerciseMediaFallbackReason)
}

enum ExerciseMediaDisplayMode: Equatable, Sendable {
    case thumbnail
    case hero

    var tileSize: CGSize {
        switch self {
        case .thumbnail:
            return CGSize(width: 58, height: 58)
        case .hero:
            return CGSize(width: 100, height: 72)
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .thumbnail:
            return 1.0
        case .hero:
            return 1.45
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .thumbnail:
            return 14
        case .hero:
            return 18
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .thumbnail:
            return 16
        case .hero:
            return 20
        }
    }
}

enum ExerciseMediaFallbackReason: Equatable, Sendable {
    case missingName
    case emptyFolder
    case unsupportedFiles
    case failedToLoad
}

struct ExerciseMediaAsset: Identifiable, Equatable, Sendable {
    let id: String
    let path: String
    let url: URL
    let fileName: String
    let fileExtension: String
    let isAnimated: Bool
    let sortPriority: Int

    init(
        path: String,
        url: URL,
        fileName: String,
        fileExtension: String,
        isAnimated: Bool,
        sortPriority: Int
    ) {
        self.id = path
        self.path = path
        self.url = url
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.isAnimated = isAnimated
        self.sortPriority = sortPriority
    }
}

struct ExerciseMediaGallery: Identifiable, Equatable, Sendable {
    let id: String
    let exerciseName: String
    let slug: String
    let compactAsset: ExerciseMediaAsset?
    let assets: [ExerciseMediaAsset]

    init(
        exerciseName: String,
        slug: String,
        compactAsset: ExerciseMediaAsset?,
        assets: [ExerciseMediaAsset]
    ) {
        self.id = slug
        self.exerciseName = exerciseName
        self.slug = slug
        self.compactAsset = compactAsset
        self.assets = assets.sorted {
            if $0.sortPriority == $1.sortPriority {
                return $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending
            }

            return $0.sortPriority < $1.sortPriority
        }
    }

    var thumbnailAsset: ExerciseMediaAsset? {
        compactAsset ?? assets.first(where: { !$0.isAnimated }) ?? assets.first
    }

    var expandedAsset: ExerciseMediaAsset? {
        assets.first
    }

    func heroAsset(allowsMotion: Bool) -> ExerciseMediaAsset? {
        if allowsMotion, let animatedAsset = assets.first(where: { $0.isAnimated }) {
            return animatedAsset
        }

        return assets.first ?? compactAsset
    }

    var hasAnimatedAsset: Bool {
        assets.contains(where: { $0.isAnimated })
    }

    var previewAssets: [ExerciseMediaAsset] {
        assets.isEmpty ? compactAsset.map { [$0] } ?? [] : assets
    }

    var previewAvailable: Bool {
        !previewAssets.isEmpty
    }

    var previewCaption: String {
        let count = previewAssets.count
        return count == 1 ? "1 media file" : "\(count) media files"
    }
}

enum ExerciseMediaPathBuilder {
    static let bucketName = "exercise"

    static func folderPath(for exerciseName: String) -> String {
        let slug = slugify(exerciseName)
        guard !slug.isEmpty else { return "" }
        return slug
    }

    static func slugify(_ value: String) -> String {
        var normalized = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        normalized = normalized.replacingOccurrences(
            of: #"[^\w\s-]"#,
            with: "",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"[ -]+"#,
            with: "_",
            options: .regularExpression
        )
        return normalized
    }
}
