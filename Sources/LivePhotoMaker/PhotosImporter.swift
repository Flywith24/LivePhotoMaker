import Foundation
import Photos

enum PhotosImportError: LocalizedError {
    case permissionDenied
    case importFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "没有获得「照片」权限。请在系统设置中允许本 App 访问照片图库后重试。"
        case .importFailed:
            "「照片」无法导入这个 Live Photo。"
        }
    }
}

final class PhotosImporter: Sendable {
    func importLivePhoto(_ result: LivePhotoConversionResult) async throws {
        let status = await requestReadWriteAccessIfNeeded()
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

    private func requestReadWriteAccessIfNeeded() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else {
            return current
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
