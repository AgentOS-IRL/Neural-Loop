import SwiftUI
import UIKit
import ImageIO

struct ExerciseMediaView: View {
    let exerciseName: String
    let mode: ExerciseMediaDisplayMode
    var showsPreviewAffordance: Bool = true
    var onPreviewRequested: ((ExerciseMediaGallery) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state: ExerciseMediaResolutionState = .loading

    private let resolver: ExerciseMediaResolver

    init(
        exerciseName: String,
        mode: ExerciseMediaDisplayMode,
        showsPreviewAffordance: Bool = true,
        onPreviewRequested: ((ExerciseMediaGallery) -> Void)? = nil,
        resolver: ExerciseMediaResolver = .shared
    ) {
        self.exerciseName = exerciseName
        self.mode = mode
        self.showsPreviewAffordance = showsPreviewAffordance
        self.onPreviewRequested = onPreviewRequested
        self.resolver = resolver
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ExerciseMediaLoadingTile(mode: mode)
            case .fallback:
                ExerciseMediaFallbackTile(mode: mode)
            case .loaded(let gallery):
                let asset = mode == .thumbnail
                    ? gallery.thumbnailAsset
                    : gallery.heroAsset(allowsMotion: !reduceMotion)

                if let asset {
                    ExerciseMediaLoadedTile(
                        exerciseName: exerciseName,
                        mode: mode,
                        gallery: gallery,
                        asset: asset,
                        allowsMotion: !reduceMotion,
                        showsPreviewAffordance: showsPreviewAffordance,
                        onPreviewRequested: onPreviewRequested
                    )
                } else {
                    ExerciseMediaFallbackTile(mode: mode)
                }
            }
        }
        .frame(width: mode.tileSize.width, height: mode.tileSize.height)
        .task(id: exerciseName) {
            await MainActor.run {
                state = .loading
            }

            let resolved = await resolver.resolveState(for: exerciseName)
            await MainActor.run {
                state = resolved
            }
        }
    }
}

private struct ExerciseMediaLoadingTile: View {
    let mode: ExerciseMediaDisplayMode

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .fill(AppTheme.sectionGradient)

            ProgressView()
                .tint(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .redacted(reason: .placeholder)
    }
}

private struct ExerciseMediaFallbackTile: View {
    let mode: ExerciseMediaDisplayMode

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)

            VStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: mode.iconSize, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("No media")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ExerciseMediaLoadedTile: View {
    let exerciseName: String
    let mode: ExerciseMediaDisplayMode
    let gallery: ExerciseMediaGallery
    let asset: ExerciseMediaAsset
    let allowsMotion: Bool
    let showsPreviewAffordance: Bool
    let onPreviewRequested: ((ExerciseMediaGallery) -> Void)?

    var body: some View {
        let canPreview = showsPreviewAffordance && gallery.previewAvailable

        Group {
            if canPreview {
                Button {
                    onPreviewRequested?(gallery)
                } label: {
                    tileContent(canPreview: canPreview)
                }
                .buttonStyle(.plain)
            } else {
                tileContent(canPreview: canPreview)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func tileContent(canPreview: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            ExerciseMediaAssetContent(
                asset: asset,
                mode: mode,
                allowsMotion: allowsMotion
            )

            if canPreview {
                previewBadge
                    .padding(8)
            }

            if asset.isAnimated {
                gifBadge
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        )
    }

    private var accessibilityLabel: String {
        let mediaLabel = asset.isAnimated ? "animated media" : "media thumbnail"
        if !gallery.previewAvailable || gallery.previewAssets.count == 1 {
            return "\(exerciseName), \(mediaLabel)"
        }

        return "\(exerciseName), \(gallery.previewCaption)"
    }

    private var previewBadge: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: mode == .thumbnail ? 10 : 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.55))
            }
    }

    private var gifBadge: some View {
        Text("GIF")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.55))
            }
    }
}

private struct ExerciseMediaAssetContent: View {
    let asset: ExerciseMediaAsset
    let mode: ExerciseMediaDisplayMode
    let allowsMotion: Bool

    var body: some View {
        ZStack {
            RemoteMediaImageView(
                url: asset.url,
                animateGIF: asset.isAnimated && mode == .hero && allowsMotion
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(mode == .hero ? 0.18 : 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous))
    }
}

struct ExerciseMediaPreviewSheet: View {
    let gallery: ExerciseMediaGallery
    let allowsMotion: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAssetID: ExerciseMediaAsset.ID?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    galleryInfo
                    assetGrid
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(gallery.exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if selectedAssetID == nil, gallery.previewAvailable {
                    selectedAssetID = gallery.expandedPreviewAsset?.id
                }
            }
        }
    }

    private var hero: some View {
        let asset = gallery.previewAssets.first(where: { $0.id == selectedAssetID })
            ?? gallery.expandedPreviewAsset

        return Group {
            if let asset {
                ExerciseMediaPreviewAssetView(asset: asset, allowsMotion: allowsMotion)
                    .frame(height: 260)
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.cardGradient)
                    .frame(height: 260)
                    .overlay {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
            }
        }
    }

    private var galleryInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(gallery.previewCaption)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if gallery.previewAvailable {
                Text("Tap a tile to focus a different asset.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("Only the compact thumbnail is available for this exercise.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var assetGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(gallery.previewAssets) { asset in
                Button {
                    selectedAssetID = asset.id
                } label: {
                    ExerciseMediaPreviewAssetView(asset: asset, allowsMotion: allowsMotion)
                        .frame(height: 132)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    selectedAssetID == asset.id ? AppTheme.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ExerciseMediaPreviewAssetView: View {
    let asset: ExerciseMediaAsset
    let allowsMotion: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.cardGradient)

            RemoteMediaImageView(
                url: asset.url,
                animateGIF: asset.isAnimated && allowsMotion
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            LinearGradient(
                colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.24)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(asset.fileName)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct RemoteMediaImageView: UIViewRepresentable {
    let url: URL
    let animateGIF: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        return imageView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard context.coordinator.currentURL != url || context.coordinator.isAnimating != animateGIF else {
            return
        }

        context.coordinator.currentURL = url
        context.coordinator.isAnimating = animateGIF
        context.coordinator.loadTask?.cancel()
        uiView.image = nil
        uiView.animationImages = nil
        uiView.stopAnimating()

        context.coordinator.loadTask = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                guard let image = RemoteMediaDecodedImage(data: data, animateGIF: animateGIF) else { return }

                await MainActor.run {
                    guard context.coordinator.currentURL == url else { return }

                    if animateGIF, let frames = image.frames, !frames.isEmpty {
                        uiView.animationImages = frames
                        uiView.animationDuration = image.duration
                        uiView.animationRepeatCount = 0
                        uiView.image = frames.first
                        uiView.startAnimating()
                    } else if let frames = image.frames, !frames.isEmpty {
                        uiView.image = frames.first
                        uiView.stopAnimating()
                    } else {
                        uiView.image = image.staticImage
                        uiView.stopAnimating()
                    }
                }
            } catch {
                await MainActor.run {
                    guard context.coordinator.currentURL == url else { return }
                    uiView.image = nil
                    uiView.stopAnimating()
                }
            }
        }
    }

    final class Coordinator {
        var currentURL: URL?
        var isAnimating: Bool = false
        var loadTask: Task<Void, Never>?
    }
}

private struct RemoteMediaDecodedImage {
    private static let gifPlaybackSpeedMultiplier: TimeInterval = 1.75

    let staticImage: UIImage
    let frames: [UIImage]?
    let duration: TimeInterval

    init?(data: Data, animateGIF: Bool) {
        if animateGIF, let animatedImage = Self.decodeAnimatedGIF(data: data) {
            staticImage = animatedImage.frames[0]
            frames = animatedImage.frames
            duration = animatedImage.duration
            return
        }

        guard let image = UIImage(data: data) else {
            return nil
        }

        staticImage = image
        frames = image.images
        duration = image.duration > 0 ? image.duration : Double(image.images?.count ?? 1) * 0.1
    }

    private static func decodeAnimatedGIF(data: Data) -> (frames: [UIImage], duration: TimeInterval)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else {
            return nil
        }

        guard let firstFrame = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let frameSize = CGSize(width: firstFrame.width, height: firstFrame.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: frameSize, format: format)

        var frames: [UIImage] = []
        frames.reserveCapacity(frameCount)
        var duration: TimeInterval = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }

            let frameImage = UIImage(cgImage: cgImage)
            let renderedFrame = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: frameSize))
                frameImage.draw(in: CGRect(origin: .zero, size: frameSize))
            }

            frames.append(renderedFrame)
            duration += frameDuration(at: index, in: source)
        }

        guard !frames.isEmpty else {
            return nil
        }

        let resolvedDuration = duration > 0 ? duration : Double(frames.count) * 0.1
        return (frames, resolvedDuration * gifPlaybackSpeedMultiplier)
    }

    private static func frameDuration(at index: Int, in source: CGImageSource) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return 0.1
        }

        let unclampedDelay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let clampedDelay = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval
        let delay = unclampedDelay ?? clampedDelay ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }
}
