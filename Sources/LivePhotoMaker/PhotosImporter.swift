import Foundation
import Photos

enum PhotosImportError: LocalizedError {
    case permissionDenied
    case importFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Photos permission was not granted. Allow this app to add photos in System Settings, then try again."
        case .importFailed:
            "Photos could not import the Live Photo."
        }
    }
}

final class PhotosImporter: Sendable {
    func importLivePhoto(_ result: LivePhotoConversionResult) async throws {
        let status = await requestAddOnlyAccessIfNeeded()
        guard status == .authorized || status == .limited else {
            throw PhotosImportError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()

                let photoOptions = PHAssetResourceCreationOptions()
                photoOptions.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: result.photoURL, options: photoOptions)

                let videoOptions = PHAssetResourceCreationOptions()
                videoOptions.shouldMoveFile = false
                request.addResource(with: .pairedVideo, fileURL: result.movieURL, options: videoOptions)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotosImportError.importFailed)
                }
            }
        }
    }

    private func requestAddOnlyAccessIfNeeded() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else {
            return current
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
