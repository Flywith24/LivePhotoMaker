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
            .frame(width: 560, height: 315)

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
            let image = try await extractCGImage(at: selectedTime)
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("LivePhotoMaker", isDirectory: true)
                .appendingPathComponent("SelectedCovers", isDirectory: true)
                .appendingPathComponent("\(UUID().uuidString).jpg")

            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                throw CocoaError(.fileWriteUnknown)
            }

            CGImageDestinationAddImage(destination, image, [
                kCGImagePropertyOrientation: 1,
                kCGImageDestinationLossyCompressionQuality: 0.96
            ] as CFDictionary)

            guard CGImageDestinationFinalize(destination) else {
                throw CocoaError(.fileWriteUnknown)
            }

            onChoose(outputURL)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func extractImage(at seconds: Double) async throws -> NSImage {
        let image = try await extractCGImage(at: seconds)
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    private func extractCGImage(at seconds: Double) async throws -> CGImage {
        try await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.08, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.08, preferredTimescale: 600)
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            return try generator.copyCGImage(at: time, actualTime: nil)
        }.value
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = max(Int(seconds.rounded()), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
