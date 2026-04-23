import Foundation
import Supabase

protocol ExerciseMediaStorageProviding: Sendable {
    func listMedia(in folderPath: String) async throws -> [ExerciseMediaStorageEntry]
    func createSignedURLs(for paths: [String]) async throws -> [URL]
}

struct ExerciseMediaStorageEntry: Sendable, Equatable {
    let name: String
}

struct SupabaseExerciseMediaStorageProvider: ExerciseMediaStorageProviding {
    func listMedia(in folderPath: String) async throws -> [ExerciseMediaStorageEntry] {
        let rows = try await customsupabase.storage
            .from(ExerciseMediaPathBuilder.bucketName)
            .list(path: folderPath)

        return rows.map { ExerciseMediaStorageEntry(name: $0.name) }
    }

    func createSignedURLs(for paths: [String]) async throws -> [URL] {
        try await customsupabase.storage
            .from(ExerciseMediaPathBuilder.bucketName)
            .createSignedURLs(paths: paths, expiresIn: 60 * 60 * 6)
    }
}

actor ExerciseMediaResolver {
    static let shared = ExerciseMediaResolver()

    private struct CacheEntry {
        let state: ExerciseMediaResolutionState
        let resolvedAt: Date
    }

    private let storage: any ExerciseMediaStorageProviding
    private let cacheLifetime: TimeInterval
    private var cache: [String: CacheEntry] = [:]
    private var inFlightTasks: [String: Task<ExerciseMediaResolutionState, Never>] = [:]

    init(
        storage: any ExerciseMediaStorageProviding = SupabaseExerciseMediaStorageProvider(),
        cacheLifetime: TimeInterval = 60 * 30
    ) {
        self.storage = storage
        self.cacheLifetime = cacheLifetime
    }

    func resolveState(for exerciseName: String) async -> ExerciseMediaResolutionState {
        let slug = ExerciseMediaPathBuilder.slugify(exerciseName)
        guard !slug.isEmpty else {
            return .fallback(.missingName)
        }

        if let cachedState = cachedState(for: slug) {
            return cachedState
        }

        if let task = inFlightTasks[slug] {
            return await task.value
        }

        let task = Task { [storage] in
            await Self.loadGallery(exerciseName: exerciseName, slug: slug, storage: storage)
        }

        inFlightTasks[slug] = task
        defer {
            inFlightTasks[slug] = nil
        }

        let state = await task.value
        cache[slug] = CacheEntry(state: state, resolvedAt: .now)
        return state
    }

    func resolveGallery(for exerciseName: String) async -> ExerciseMediaGallery? {
        switch await resolveState(for: exerciseName) {
        case .loaded(let gallery):
            return gallery
        case .loading, .fallback(_):
            return nil
        }
    }

    private func cachedState(for slug: String) -> ExerciseMediaResolutionState? {
        guard let entry = cache[slug] else { return nil }
        guard Date().timeIntervalSince(entry.resolvedAt) < cacheLifetime else {
            cache[slug] = nil
            return nil
        }

        return entry.state
    }

    private static func loadGallery(
        exerciseName: String,
        slug: String,
        storage: any ExerciseMediaStorageProviding
    ) async -> ExerciseMediaResolutionState {

        let folderPath = ExerciseMediaPathBuilder.folderPath(for: exerciseName)
        guard !folderPath.isEmpty else {
            return .fallback(.missingName)
        }

        let entries: [ExerciseMediaStorageEntry]
        do {
            entries = try await storage.listMedia(in: folderPath)
        } catch {
            return .fallback(.failedToLoad)
        }
        guard !entries.isEmpty else {
            return .fallback(.emptyFolder)
        }

        let compactFileName = "\(slug)_small.webp"
        let supportedEntries = entries.compactMap { entry -> (entry: ExerciseMediaStorageEntry, fileExtension: String, isCompact: Bool)? in
            let fileExtension = Self.fileExtension(for: entry.name).lowercased()
            guard Self.supportedExtensions.contains(fileExtension) else {
                return nil
            }

            let isCompact = entry.name.caseInsensitiveCompare(compactFileName) == .orderedSame
            return (entry, fileExtension, isCompact)
        }

        guard !supportedEntries.isEmpty else {
            return .fallback(.unsupportedFiles)
        }

        let compactEntry = supportedEntries.first(where: { $0.isCompact })
        let originalEntries = supportedEntries
            .filter { !$0.isCompact }
            .sorted {
                let leftPriority = Self.sortPriority(for: $0.fileExtension)
                let rightPriority = Self.sortPriority(for: $1.fileExtension)

                if leftPriority == rightPriority {
                    return $0.entry.name.localizedCaseInsensitiveCompare($1.entry.name) == .orderedAscending
                }

                return leftPriority < rightPriority
            }

        var selectedEntries = originalEntries
        if let compactEntry {
            selectedEntries.insert(compactEntry, at: 0)
        }
        let paths = selectedEntries.map { "\(folderPath)/\($0.entry.name)" }
        let urls: [URL]
        do {
            urls = try await storage.createSignedURLs(for: paths)
        } catch {
            return .fallback(.failedToLoad)
        }

        let originalURLs = urls.dropFirst(compactEntry == nil ? 0 : 1)
        let assets: [ExerciseMediaAsset] = zip(originalEntries, originalURLs).map { element in
            let (entry, url) = element
            return ExerciseMediaAsset(
                path: "\(folderPath)/\(entry.entry.name)",
                url: url,
                fileName: entry.entry.name,
                fileExtension: entry.fileExtension,
                isAnimated: entry.fileExtension == "gif",
                sortPriority: Self.sortPriority(for: entry.fileExtension)
            )
        }

        let compactAsset: ExerciseMediaAsset?
        if let compactEntry, let compactURL = urls.first {
            compactAsset = ExerciseMediaAsset(
                path: "\(folderPath)/\(compactEntry.entry.name)",
                url: compactURL,
                fileName: compactEntry.entry.name,
                fileExtension: compactEntry.fileExtension,
                isAnimated: compactEntry.fileExtension == "gif",
                sortPriority: Self.sortPriority(for: compactEntry.fileExtension)
            )
        } else {
            compactAsset = nil
        }

        return .loaded(
            ExerciseMediaGallery(
                exerciseName: exerciseName,
                slug: slug,
                compactAsset: compactAsset,
                assets: assets
            )
        )
    }

    private static let supportedExtensions: Set<String> = ["gif", "png", "webp", "jpg", "jpeg"]

    private static func fileExtension(for fileName: String) -> String {
        guard let dotIndex = fileName.lastIndex(of: ".") else {
            return ""
        }

        return String(fileName[fileName.index(after: dotIndex)...])
    }

    private static func sortPriority(for fileExtension: String) -> Int {
        switch fileExtension.lowercased() {
        case "png":
            return 0
        case "webp":
            return 1
        case "jpg", "jpeg":
            return 2
        case "gif":
            return 3
        default:
            return 4
        }
    }
}
