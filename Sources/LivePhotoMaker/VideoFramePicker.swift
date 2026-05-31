import AVFoundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct FramePickerRequest: Identifiable {
    let id = UUID()
    let videoID: UUID
    let videoURL: URL
}

struct VideoFramePicker: View {
    let videoURL: URL
    let onChoose: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var duration = 1.0
    @State private var selectedTime = 0.0
    @State private var previewImage: NSImage?
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择视频帧")
                        .font(.title2.weight(.semibold))
                    Text(videoURL.lastPathComponent)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.88))

                if let previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(10)
                } else {
                    ProgressView()
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(minWidth: 360, idealWidth: 560, maxWidth: .infinity)

            VStack(spacing: 8) {
                Slider(value: $selectedTime, in: 0...max(duration, 0.1))
                    .disabled(duration <= 0.1)
                    .onChange(of: selectedTime) { _, newValue in
                        Task { await loadPreview(at: newValue) }
                    }

                HStack {
                    Text(timeString(selectedTime))
                    Spacer()
                    Text(timeString(duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("取消") {
                    dismiss()
                }

                Spacer()

                Button {
                    Task { await saveFrame() }
                } label: {
                    Label("使用这一帧", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(previewImage == nil || isSaving)
            }
        }
        .padding(24)
        .task {
            await loadMetadata()
            await loadPreview(at: selectedTime)
        }
    }

    private func loadMetadata() async {
        let asset = AVURLAsset(url: videoURL)
        do {
            let loadedDuration = try await asset.load(.duration).seconds
            if loadedDuration.isFinite, loadedDuration > 0 {
                duration = loadedDuration
                selectedTime = min(max(loadedDuration * 0.5, 0), loadedDuration)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPreview(at seconds: Double) async {
        do {
            let image = try await extractImage(at: seconds)
            await MainActor.run {
                previewImage = image
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveFrame() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let outputDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("LivePhotoMaker", isDirectory: true)
                .appendingPathComponent("SelectedCovers", isDirectory: true)

            try FileManager.default.createDirectory(
                at: outputDirectory,
                withIntermediateDirectories: true
            )

            let image = try await extractCGImage(at: selectedTime, matchSourceDynamicRange: false)
            let outputURL = try saveCoverImage(image, in: outputDirectory, baseName: UUID().uuidString)
            onChoose(outputURL)
            dismiss()
        } catch {
            do {
                let outputDirectory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("LivePhotoMaker", isDirectory: true)
                    .appendingPathComponent("SelectedCovers", isDirectory: true)

                try FileManager.default.createDirectory(
                    at: outputDirectory,
                    withIntermediateDirectories: true
                )

                let image = try await extractCGImage(at: selectedTime, matchSourceDynamicRange: false)
                let outputURL = try saveCoverImage(image, in: outputDirectory, baseName: UUID().uuidString)
                onChoose(outputURL)
                dismiss()
            } catch {
                errorMessage = "无法保存这一帧，请换一帧或选择图片封面。"
            }
        }
    }

    private func saveCoverImage(_ image: CGImage, in outputDirectory: URL, baseName: String) throws -> URL {
        let heicURL = outputDirectory.appendingPathComponent("\(baseName).heic")
        if writeImage(image, to: heicURL, type: UTType.heic, includeHDROptions: false) {
            return heicURL
        }

        let jpegURL = outputDirectory.appendingPathComponent("\(baseName).jpg")
        if writeImage(image, to: jpegURL, type: UTType.jpeg, includeHDROptions: false) {
            return jpegURL
        }

        throw CocoaError(.fileWriteUnknown)
    }

    private func writeImage(
        _ image: CGImage,
        to outputURL: URL,
        type: UTType,
        includeHDROptions: Bool
    ) -> Bool {
        try? FileManager.default.removeItem(at: outputURL)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            type.identifier as CFString,
            1,
            nil
        ) else {
            return false
        }

        var metadata: [CFString: Any] = [
            kCGImagePropertyOrientation: 1,
            kCGImageDestinationLossyCompressionQuality: type == .jpeg ? 0.96 : 0.98
        ]
        if includeHDROptions {
            addHDRImageDestinationOptions(to: &metadata)
        }

        CGImageDestinationAddImage(destination, image, metadata as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    private func extractImage(at seconds: Double) async throws -> NSImage {
        let image = try await extractCGImage(at: seconds, matchSourceDynamicRange: false)
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    private func extractCGImage(at seconds: Double, matchSourceDynamicRange: Bool) async throws -> CGImage {
        try await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.08, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.08, preferredTimescale: 600)
            if #available(macOS 15.0, *) {
                generator.dynamicRangePolicy = matchSourceDynamicRange ? .matchSource : .forceSDR
            }
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            return try generator.copyCGImage(at: time, actualTime: nil)
        }.value
    }

    private func addHDRImageDestinationOptions(to metadata: inout [CFString: Any]) {
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

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = max(Int(seconds.rounded()), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
