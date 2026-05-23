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
    static let maxDimension: CGFloat = ImageAttachmentEncoder.defaultMaxDimension

    let dataURL: String
    let format: AIModeImageFormat
    let previewData: Data

    init(cameraImage image: UIImage) throws {
        do {
            let result = try ImageAttachmentEncoder.encode(image)
            self.format = .jpeg
            self.previewData = result.thumbnailData
            self.dataURL = result.dataURL
        } catch {
            throw AIModeImagePayloadError.encodingFailed
        }
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
