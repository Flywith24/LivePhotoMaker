import AppKit
import SwiftUI

struct ContentView: View {
    @State private var selectedVideo: URL?
    @State private var isConverting = false
    @State private var progress = 0.0
    @State private var status = "Choose a video to import it into Photos as a Live Photo."
    @State private var lastResult: LivePhotoConversionResult?
    @State private var errorMessage: String?

    private let converter = LivePhotoConverter()
    private let importer = PhotosImporter()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            VStack(spacing: 14) {
                fileRow(
                    title: "Video",
                    value: selectedVideo?.path(percentEncoded: false) ?? "No video selected",
                    buttonTitle: "Choose Video",
                    action: chooseVideo
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: progress)
                    .opacity(isConverting ? 1 : 0.55)

                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await convert() }
                } label: {
                    Label("Create Live Photo", systemImage: "livephoto")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedVideo == nil || isConverting)

                Button {
                    openPhotos()
                } label: {
                    Label("Open Photos", systemImage: "photo.on.rectangle")
                }
                .disabled(lastResult == nil)

                Spacer()
            }

            if let lastResult {
                ResultView(result: lastResult)
            }

            Spacer(minLength: 0)
        }
        .padding(28)
        .alert("Conversion failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LivePhoto Maker")
                .font(.system(size: 34, weight: .semibold))

            Text("Convert a local video and import it directly into Photos as an Apple Live Photo.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func fileRow(title: String, value: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 16)

            Button(action: action) {
                Text(buttonTitle)
                    .frame(width: 112)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
    }

    private func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .video]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            selectedVideo = panel.url
            lastResult = nil
            status = "Ready to convert \(panel.url?.lastPathComponent ?? "video")."
        }
    }

    @MainActor
    private func convert() async {
        guard let selectedVideo else { return }

        isConverting = true
        progress = 0
        lastResult = nil
        errorMessage = nil
        status = "Preparing Live Photo metadata..."

        do {
            let destination = temporaryOutputFolder()
            let result = try await converter.convert(
                videoURL: selectedVideo,
                outputDirectory: destination
            ) { newProgress in
                Task { @MainActor in
                    progress = newProgress
                    status = newProgress < 0.35 ? "Extracting key photo..." : "Writing paired Live Photo movie..."
                }
            }

            status = "Importing Live Photo into Photos..."
            try await importer.importLivePhoto(result)
            progress = 1
            lastResult = result
            status = "Imported into Photos as a Live Photo."
        } catch {
            progress = 0
            errorMessage = error.localizedDescription
            status = "Conversion failed."
        }

        isConverting = false
    }

    private func temporaryOutputFolder() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LivePhotoMaker", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func openPhotos() {
        guard let photosURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Photos") else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: photosURL, configuration: configuration)
    }
}

private struct ResultView: View {
    let result: LivePhotoConversionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Live Photo pair ready", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text("Imported into Photos. Asset ID: \(result.assetIdentifier)")
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
