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
            return 18
        case .hero:
            return 22
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
    let assets: [ExerciseMediaAsset]

    init(exerciseName: String, slug: String, assets: [ExerciseMediaAsset]) {
        self.id = slug
        self.exerciseName = exerciseName
        self.slug = slug
        self.assets = assets.sorted {
            if $0.sortPriority == $1.sortPriority {
                return $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending
            }

            return $0.sortPriority < $1.sortPriority
        }
    }

    var thumbnailAsset: ExerciseMediaAsset? {
        assets.first(where: { !$0.isAnimated }) ?? assets.first
    }

    func heroAsset(allowsMotion: Bool) -> ExerciseMediaAsset? {
        if allowsMotion, let animatedAsset = assets.first(where: { $0.isAnimated }) {
            return animatedAsset
        }

        return thumbnailAsset
    }

    var hasAnimatedAsset: Bool {
        assets.contains(where: { $0.isAnimated })
    }

    var previewCaption: String {
        let count = assets.count
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
