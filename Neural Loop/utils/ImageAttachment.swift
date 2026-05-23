//
//  ImageAttachment.swift
//  Neural Loop
//
//  Created by Codex on 23/05/2026.
//

import Foundation

/// Shared DTO used by task and fleeting-note editors and the DB persistence path.
/// Each instance represents a single image attachment with preview data for thumbnails
/// and the full Data URL for Supabase storage.
struct ImageAttachment: Identifiable, Equatable {
    /// Local stable identity for SwiftUI list diffing.
    let id: UUID

    /// JPEG Data URL stored in the `images` table `image_uri` column.
    let dataURL: String

    /// JPEG data for on-device thumbnail rendering (avoids re-decoding the Data URL).
    let thumbnailData: Data

    /// Non-nil when this attachment was loaded from an existing `ImageRecord` row.
    /// Used to determine which rows need deletion during a replace-all operation.
    var existingRecordId: Int64?

    init(
        id: UUID = UUID(),
        dataURL: String,
        thumbnailData: Data,
        existingRecordId: Int64? = nil
    ) {
        self.id = id
        self.dataURL = dataURL
        self.thumbnailData = thumbnailData
        self.existingRecordId = existingRecordId
    }
}
