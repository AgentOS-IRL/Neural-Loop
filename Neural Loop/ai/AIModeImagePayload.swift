import UIKit

enum AIModeImageFormat: String, Equatable, Sendable {
    case png = "png"
    case jpeg = "jpeg"
    case webP = "webp"

    var mimeType: String {
        switch self {
        case .png:
            return "image/png"
        case .jpeg:
            return "image/jpeg"
        case .webP:
            return "image/webp"
        }
    }
}

struct AIModeImagePayload: Equatable, Sendable {
    static let maxDimension: CGFloat = 2048

    let dataURL: String
    let format: AIModeImageFormat
    let previewData: Data

    init(cameraImage image: UIImage) throws {
        let normalized = image.aiModeNormalized()
        let scaled = normalized.aiModeScaledToFit(maxDimension: Self.maxDimension)

        guard let data = scaled.jpegData(compressionQuality: 0.86) else {
            throw AIModeImagePayloadError.encodingFailed
        }

        self.format = .jpeg
        self.previewData = data
        self.dataURL = "data:\(AIModeImageFormat.jpeg.mimeType);base64,\(data.base64EncodedString())"
    }
}

enum AIModeImagePayloadError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Could not prepare the camera image for Codex."
        }
    }
}

private extension UIImage {
    func aiModeNormalized() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func aiModeScaledToFit(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else {
            return self
        }

        let scaleRatio = maxDimension / longestSide
        let targetSize = CGSize(
            width: size.width * scaleRatio,
            height: size.height * scaleRatio
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
