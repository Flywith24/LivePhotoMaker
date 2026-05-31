@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct LivePhotoConversionResult {
    let photoURL: URL
    let movieURL: URL
    let assetIdentifier: String
}

enum LivePhotoConversionError: LocalizedError {
    case unreadableVideo
    case cannotCreateImageDestination
    case cannotWriteImage
    case cannotReadMovie
    case cannotWriteMovie
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unreadableVideo:
            "无法读取所选视频。"
        case .cannotCreateImageDestination:
            "无法创建输出 HEIC。"
        case .cannotWriteImage:
            "无法写入 Live Photo 封面元数据。"
        case .cannotReadMovie:
            "无法读取所选视频的音频或视频轨道。"
        case .cannotWriteMovie:
            "无法写入配对 MOV 文件。"
        case .cancelled:
            "转换已取消。"
        }
    }
}

final class LivePhotoConverter: Sendable {
    typealias ProgressHandler = @Sendable (Double) -> Void

    func convert(
        videoURL: URL,
        outputDirectory: URL,
        coverImageURL: URL? = nil,
        progress: @escaping ProgressHandler
    ) async throws -> LivePhotoConversionResult {
        try await Task.detached(priority: .userInitiated) {
            let assetIdentifier = UUID().uuidString
            let baseName = "IMG_\(Self.timestampName())"
            let photoURL = outputDirectory.appendingPathComponent("\(baseName).HEIC")
            let movieURL = outputDirectory.appendingPathComponent("\(baseName).MOV")

            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            try Self.removeExistingFile(at: photoURL)
            try Self.removeExistingFile(at: movieURL)

            let asset = AVURLAsset(url: videoURL)
            progress(0.08)
            try Self.writeKeyPhoto(
                from: asset,
                coverImageURL: coverImageURL,
                to: photoURL,
                assetIdentifier: assetIdentifier
            )
            progress(0.35)
            try Self.writePairedMovie(
                from: asset,
                to: movieURL,
                assetIdentifier: assetIdentifier,
                progress: { movieProgress in
                    progress(0.35 + movieProgress * 0.62)
                }
            )
            progress(1)

            return LivePhotoConversionResult(
                photoURL: photoURL,
                movieURL: movieURL,
                assetIdentifier: assetIdentifier
            )
        }.value
    }

    private static func writeKeyPhoto(
        from asset: AVURLAsset,
        coverImageURL: URL?,
        to outputURL: URL,
        assetIdentifier: String
    ) throws {
        if let coverImageURL {
            try writeCustomCover(from: coverImageURL, to: outputURL, assetIdentifier: assetIdentifier)
            return
        }

        let duration = asset.duration.seconds
        guard duration.isFinite, duration > 0 else {
            throw LivePhotoConversionError.unreadableVideo
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        if #available(macOS 15.0, *) {
            generator.dynamicRangePolicy = .matchSource
        }

        let requestedSeconds = min(max(duration * 0.5, 0.1), max(duration - 0.1, 0.1))
        let requestedTime = CMTime(seconds: requestedSeconds, preferredTimescale: 600)
        let image = try generator.copyCGImage(at: requestedTime, actualTime: nil)

        try writeHEICImage(
            image,
            to: outputURL,
            assetIdentifier: assetIdentifier,
            sourceProperties: nil
        )
    }

    private static func writeCustomCover(
        from coverURL: URL,
        to outputURL: URL,
        assetIdentifier: String
    ) throws {
        guard let source = CGImageSourceCreateWithURL(coverURL as CFURL, imageSourceOptions()),
              let image = CGImageSourceCreateImageAtIndex(source, 0, imageSourceOptions()) else {
            throw LivePhotoConversionError.cannotWriteImage
        }

        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        if try writeImageFromSourceIfPossible(
            source,
            to: outputURL,
            assetIdentifier: assetIdentifier,
            sourceProperties: sourceProperties
        ) {
            return
        }

        try writeHEICImage(
            image,
            to: outputURL,
            assetIdentifier: assetIdentifier,
            sourceProperties: sourceProperties
        )
    }

    private static func writeHEICImage(
        _ image: CGImage,
        to outputURL: URL,
        assetIdentifier: String,
        sourceProperties: [CFString: Any]?
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw LivePhotoConversionError.cannotCreateImageDestination
        }

        let metadata = stillImageMetadata(
            assetIdentifier: assetIdentifier,
            sourceProperties: sourceProperties,
            includeHDROptions: true
        )

        CGImageDestinationAddImage(destination, image, metadata as CFDictionary)

        if !CGImageDestinationFinalize(destination) {
            try removeExistingFile(at: outputURL)
            try writeStandardHEICImage(
                image,
                to: outputURL,
                assetIdentifier: assetIdentifier,
                sourceProperties: sourceProperties
            )
        }
    }

    private static func writeStandardHEICImage(
        _ image: CGImage,
        to outputURL: URL,
        assetIdentifier: String,
        sourceProperties: [CFString: Any]?
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw LivePhotoConversionError.cannotCreateImageDestination
        }

        let metadata = stillImageMetadata(
            assetIdentifier: assetIdentifier,
            sourceProperties: sourceProperties,
            includeHDROptions: false
        )

        CGImageDestinationAddImage(destination, image, metadata as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw LivePhotoConversionError.cannotWriteImage
        }
    }

    private static func writeImageFromSourceIfPossible(
        _ source: CGImageSource,
        to outputURL: URL,
        assetIdentifier: String,
        sourceProperties: [CFString: Any]?
    ) throws -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw LivePhotoConversionError.cannotCreateImageDestination
        }

        var metadata = stillImageMetadata(
            assetIdentifier: assetIdentifier,
            sourceProperties: sourceProperties,
            includeHDROptions: true
        )
        metadata[kCGImageDestinationPreserveGainMap] = true
        addHDRImageDestinationOptions(to: &metadata)

        CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    private static func stillImageMetadata(
        assetIdentifier: String,
        sourceProperties: [CFString: Any]?,
        includeHDROptions: Bool
    ) -> [CFString: Any] {
        var metadata = sourceProperties ?? [:]
        var makerApple = metadata[kCGImagePropertyMakerAppleDictionary] as? [String: Any] ?? [:]
        makerApple["17"] = assetIdentifier
        metadata[kCGImagePropertyMakerAppleDictionary] = makerApple
        metadata[kCGImagePropertyOrientation] = metadata[kCGImagePropertyOrientation] ?? 1
        metadata[kCGImageDestinationLossyCompressionQuality] = 0.98
        if includeHDROptions {
            addHDRImageDestinationOptions(to: &metadata)
        }
        return metadata
    }

    private static func addHDRImageDestinationOptions(to metadata: inout [CFString: Any]) {
        if #available(macOS 15.0, *) {
            metadata[kCGImageDestinationEncodeRequest] = kCGImageDestinationEncodeToISOHDR
            metadata[kCGImageDestinationEncodeRequestOptions] = [
                kCGImageDestinationEncodeBaseIsSDR: true
            ]
        }

        if #available(macOS 16.0, *) {
            var options = metadata[kCGImageDestinationEncodeRequestOptions] as? [CFString: Any] ?? [:]
            options[kCGImageDestinationEncodeGenerateGainMapWithBaseImage] = true
            options[kCGImageDestinationEncodeGainMapSubsampleFactor] = 2
            metadata[kCGImageDestinationEncodeRequestOptions] = options
        }
    }

    private static func imageSourceOptions() -> CFDictionary? {
        var options: [CFString: Any] = [
            kCGImageSourceShouldCache: true
        ]

        if #available(macOS 14.0, *) {
            options[kCGImageSourceDecodeRequest] = kCGImageSourceDecodeToHDR
        }

        return options as CFDictionary
    }

    private static func writePairedMovie(
        from asset: AVURLAsset,
        to outputURL: URL,
        assetIdentifier: String,
        progress: @escaping ProgressHandler
    ) throws {
        guard !asset.tracks.isEmpty else {
            throw LivePhotoConversionError.cannotReadMovie
        }

        guard let reader = try? AVAssetReader(asset: asset) else {
            throw LivePhotoConversionError.cannotReadMovie
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        writer.shouldOptimizeForNetworkUse = false
        writer.metadata = movieMetadata(from: asset, assetIdentifier: assetIdentifier)

        var copyPairs: [(AVAssetReaderTrackOutput, AVAssetWriterInput)] = []
        for track in asset.tracks where shouldCopyTrack(track) {
            let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false

            guard reader.canAdd(readerOutput) else { continue }
            reader.add(readerOutput)

            let writerInput = AVAssetWriterInput(
                mediaType: track.mediaType,
                outputSettings: nil,
                sourceFormatHint: track.formatDescriptions.first as! CMFormatDescription?
            )
            writerInput.expectsMediaDataInRealTime = false
            writerInput.metadata = track.metadata
            if track.mediaType == .video {
                writerInput.transform = track.preferredTransform
            }

            guard writer.canAdd(writerInput) else { continue }
            writer.add(writerInput)
            copyPairs.append((readerOutput, writerInput))
        }

        guard !copyPairs.isEmpty else {
            throw LivePhotoConversionError.cannotReadMovie
        }

        let metadataAdaptor = try stillImageTimeMetadataAdaptor()
        if writer.canAdd(metadataAdaptor.assetWriterInput) {
            writer.add(metadataAdaptor.assetWriterInput)
        }

        guard writer.startWriting() else {
            throw writer.error ?? LivePhotoConversionError.cannotWriteMovie
        }

        guard reader.startReading() else {
            writer.cancelWriting()
            throw reader.error ?? LivePhotoConversionError.cannotReadMovie
        }

        writer.startSession(atSourceTime: .zero)
        appendStillImageTimeMetadata(with: metadataAdaptor)

        let durationSeconds = max(asset.duration.seconds, 0.01)
        try appendMediaSamples(
            copyPairs,
            reader: reader,
            writer: writer,
            durationSeconds: durationSeconds,
            progress: progress
        )
        metadataAdaptor.assetWriterInput.markAsFinished()

        switch reader.status {
        case .completed:
            break
        case .failed:
            writer.cancelWriting()
            throw reader.error ?? LivePhotoConversionError.cannotReadMovie
        case .cancelled:
            writer.cancelWriting()
            throw LivePhotoConversionError.cancelled
        default:
            break
        }

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            throw writer.error ?? LivePhotoConversionError.cannotWriteMovie
        }
    }

    private static func appendMediaSamples(
        _ copyPairs: [(AVAssetReaderTrackOutput, AVAssetWriterInput)],
        reader: AVAssetReader,
        writer: AVAssetWriter,
        durationSeconds: Double,
        progress: @escaping ProgressHandler
    ) throws {
        let group = DispatchGroup()
        let state = SampleCopyState()

        for (readerOutput, writerInput) in copyPairs {
            group.enter()
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "LivePhotoMaker.sample-copy")) {
                while writerInput.isReadyForMoreMediaData {
                    if Task.isCancelled {
                        state.fail(with: LivePhotoConversionError.cancelled)
                        reader.cancelReading()
                        writer.cancelWriting()
                        writerInput.markAsFinished()
                        group.leave()
                        return
                    }

                    if state.hasError {
                        reader.cancelReading()
                        writer.cancelWriting()
                        writerInput.markAsFinished()
                        group.leave()
                        return
                    }

                    guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                        writerInput.markAsFinished()
                        group.leave()
                        return
                    }

                    guard writerInput.append(sampleBuffer) else {
                        state.fail(with: writer.error ?? LivePhotoConversionError.cannotWriteMovie)
                        reader.cancelReading()
                        writer.cancelWriting()
                        writerInput.markAsFinished()
                        group.leave()
                        return
                    }

                    let seconds = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                    if seconds.isFinite {
                        let nextProgress = min(max(seconds / durationSeconds, 0), 1)
                        state.report(progress: nextProgress, handler: progress)
                    }
                }
            }
        }

        group.wait()

        if let error = state.error {
            throw error
        }
    }

    private static func movieMetadata(
        from asset: AVURLAsset,
        assetIdentifier: String
    ) -> [AVMetadataItem] {
        var metadata = asset.metadata.filter { !isLivePhotoPairingMetadata($0) }
        metadata.append(contentIdentifierMetadataItem(assetIdentifier))
        return metadata
    }

    private static func shouldCopyTrack(_ track: AVAssetTrack) -> Bool {
        track.mediaType == .video ||
            track.mediaType == .audio ||
            track.mediaType == .auxiliaryPicture
    }

    private static func isLivePhotoPairingMetadata(_ item: AVMetadataItem) -> Bool {
        guard let identifier = item.identifier?.rawValue else {
            return false
        }

        return identifier == AVMetadataIdentifier.quickTimeMetadataContentIdentifier.rawValue ||
            identifier == "mdta/com.apple.quicktime.still-image-time"
    }

    private static func contentIdentifierMetadataItem(_ assetIdentifier: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataContentIdentifier
        item.value = assetIdentifier as NSString
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        return item.copy() as! AVMetadataItem
    }

    private static func stillImageTimeMetadataAdaptor() throws -> AVAssetWriterInputMetadataAdaptor {
        let specification: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: kCMMetadataBaseDataType_SInt8 as String
        ]

        var formatDescription: CMFormatDescription?
        let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [specification] as CFArray,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDescription else {
            throw LivePhotoConversionError.cannotWriteMovie
        }

        let input = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: formatDescription
        )
        return AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
    }

    private static func appendStillImageTimeMetadata(with adaptor: AVAssetWriterInputMetadataAdaptor) {
        let item = AVMutableMetadataItem()
        item.identifier = AVMetadataIdentifier("mdta/com.apple.quicktime.still-image-time")
        item.value = 0 as NSNumber
        item.dataType = kCMMetadataBaseDataType_SInt8 as String

        let timeRange = CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 100))
        let group = AVTimedMetadataGroup(items: [item], timeRange: timeRange)
        adaptor.append(group)
    }

    private static func removeExistingFile(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func timestampName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

private final class SampleCopyState: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var error: Error?
    private var latestProgress = 0.0

    var hasError: Bool {
        lock.lock()
        let result = error != nil
        lock.unlock()
        return result
    }

    func fail(with error: Error) {
        lock.lock()
        if self.error == nil {
            self.error = error
        }
        lock.unlock()
    }

    func report(progress: Double, handler: LivePhotoConverter.ProgressHandler) {
        lock.lock()
        let shouldReport = progress > latestProgress
        if shouldReport {
            latestProgress = progress
        }
        lock.unlock()

        if shouldReport {
            handler(progress)
        }
    }
}
