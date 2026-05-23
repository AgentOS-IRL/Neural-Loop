//
//  ImageAttachmentEncoder.swift
//  Neural Loop
//
//  Created by Codex on 23/05/2026.
//

import UIKit

/// Shared image encoding pipeline used by task/note attachment editors and AIMode.
/// Normalises orientation, downscales to fit within a maximum dimension, then
/// encodes as JPEG and produces a `data:image/jpeg;base64,…` Data URL.
enum ImageAttachmentEncoder {
    static let defaultMaxDimension: CGFloat = 2048
    static let defaultCompressionQuality: CGFloat = 0.86

    struct Result {
        /// `data:image/jpeg;base64,…` string for Supabase `image_uri` storage.
        let dataURL: String
        /// Raw JPEG data for on-device thumbnail rendering.
        let thumbnailData: Data
    }

    enum EncodingError: LocalizedError {
        case jpegEncodingFailed

        var errorDescription: String? {
            switch self {
            case .jpegEncodingFailed:
                return "Could not encode the image as JPEG."
            }
        }
    }

    /// Encodes a `UIImage` into a JPEG Data URL with an accompanying thumbnail.
    /// - Parameters:
    ///   - image: Source image (any orientation).
    ///   - maxDimension: Longest-side cap in points. Defaults to `2048`.
    ///   - compressionQuality: JPEG quality `0…1`. Defaults to `0.86`.
    /// - Returns: Encoded result containing the Data URL and raw JPEG data.
    static func encode(
        _ image: UIImage,
        maxDimension: CGFloat = defaultMaxDimension,
        compressionQuality: CGFloat = defaultCompressionQuality
    ) throws -> Result {
        let normalized = image.normalizeOrientation()
        let scaled = normalized.scaleToFit(maxDimension: maxDimension)

        guard let data = scaled.jpegData(compressionQuality: compressionQuality) else {
            throw EncodingError.jpegEncodingFailed
        }

        let dataURL = "data:image/jpeg;base64,\(data.base64EncodedString())"
        return Result(dataURL: dataURL, thumbnailData: data)
    }
}

// MARK: - UIImage helpers

extension UIImage {
    /// Re-draws the image with `.up` orientation so downstream consumers
    /// don't need to handle EXIF rotation.
    func normalizeOrientation() -> UIImage {
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

    /// Proportionally scales the image so its longest side is at most `maxDimension`.
    func scaleToFit(maxDimension: CGFloat) -> UIImage {
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
