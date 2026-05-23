//
//  ImageAttachmentSection.swift
//  Neural Loop
//
//  Created by Codex on 23/05/2026.
//

import PhotosUI
import SwiftUI

/// Reusable image-attachment section for task and fleeting-note editors.
///
/// Shows a horizontal thumbnail strip with per-image remove buttons, and an
/// add-image action that lets the user choose between camera and photo library.
struct ImageAttachmentSection: View {
    @Binding var attachments: [ImageAttachment]

    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var encodingError: String?

    private let thumbnailSize: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail strip
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(attachments) { attachment in
                            thumbnailView(for: attachment)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    showSourcePicker = true
                } label: {
                    ThemedRow {
                        Label("Add Image", systemImage: "photo.badge.plus")
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }

            if let encodingError {
                Text(encodingError)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.errorTint)
            }
        }
        .confirmationDialog("Add Image", isPresented: $showSourcePicker, titleVisibility: .visible) {
            Button("Photo Library") {
                showPhotoLibrary = true
            }

            Button("Camera") {
                showCamera = true
            }

            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryPickerView { images in
                for image in images {
                    encodeAndAppend(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                encodeAndAppend(image)
            }
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private func thumbnailView(for attachment: ImageAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: attachment.thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.sectionGradient)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(AppTheme.textSecondary)
                    }
            }

            // Remove button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    attachments.removeAll { $0.id == attachment.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.red)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
            .offset(x: 6, y: -6)
        }
    }

    // MARK: - Photo Processing

    private func encodeAndAppend(_ image: UIImage) {
        do {
            let result = try ImageAttachmentEncoder.encode(image)
            let attachment = ImageAttachment(
                dataURL: result.dataURL,
                thumbnailData: result.thumbnailData
            )
            withAnimation(.easeInOut(duration: 0.2)) {
                attachments.append(attachment)
            }
            encodingError = nil
        } catch {
            encodingError = error.localizedDescription
        }
    }
}

// MARK: - Camera Picker (UIImagePickerController wrapper)

private struct CameraPickerView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Photo Library Picker (PHPickerViewController wrapper)

private struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    let onImagesPicked: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 10

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagesPicked: onImagesPicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagesPicked: ([UIImage]) -> Void
        let dismiss: DismissAction

        init(onImagesPicked: @escaping ([UIImage]) -> Void, dismiss: DismissAction) {
            self.onImagesPicked = onImagesPicked
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                dismiss()
                return
            }

            var images: [UIImage] = []
            let lock = NSLock()
            let group = DispatchGroup()

            for result in results {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }

                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        lock.lock()
                        images.append(image)
                        lock.unlock()
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.onImagesPicked(images)
                self.dismiss()
            }
        }
    }
}
