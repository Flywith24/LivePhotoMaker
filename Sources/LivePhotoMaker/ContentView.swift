import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct VideoItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
}

struct ContentView: View {
    @State private var selectedVideos: [VideoItem] = []
    @State private var coverImageURL: URL?
    @State private var isDropTargeted = false
    @State private var isConverting = false
    @State private var isCheckingUpdates = false
    @State private var progress = 0.0
    @State private var importedCount = 0
    @State private var status = "Drop videos here or choose a batch."
    @State private var results: [LivePhotoConversionResult] = []
    @State private var errorMessage: String?
    @State private var updateMessage: String?
    @State private var updateURL: URL?
    @State private var showsAbout = false

    private let converter = LivePhotoConverter()
    private let importer = PhotosImporter()
    private let updateChecker = UpdateChecker()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(red: 0.89, green: 0.96, blue: 1.0),
                    Color(red: 0.98, green: 0.94, blue: 0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                toolbar

                HStack(alignment: .top, spacing: 18) {
                    queuePanel
                    settingsPanel
                }

                progressPanel
            }
            .padding(22)
        }
        .alert("Conversion failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Updates", isPresented: Binding(
            get: { updateMessage != nil },
            set: { if !$0 { updateMessage = nil } }
        )) {
            if let updateURL {
                Button("Open Release") {
                    NSWorkspace.shared.open(updateURL)
                }
            }
            Button("OK", role: .cancel) { updateMessage = nil }
        } message: {
            Text(updateMessage ?? "")
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("LivePhotoMaker")
                    .font(.system(size: 28, weight: .semibold))
                Text("Batch convert videos into Photos-ready Live Photos.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showsAbout = true
            } label: {
                Label("About", systemImage: "info.circle")
            }

            Button {
                Task { await checkForUpdates() }
            } label: {
                Label(isCheckingUpdates ? "Checking" : "Check Updates", systemImage: "arrow.clockwise")
            }
            .disabled(isCheckingUpdates)
        }
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Import Queue", systemImage: "film.stack")
                    .font(.headline)
                Spacer()
                Text("\(selectedVideos.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            dropZone

            if selectedVideos.isEmpty {
                ContentUnavailableView(
                    "No videos selected",
                    systemImage: "video.badge.plus",
                    description: Text("Drop video files here or choose multiple videos.")
                )
                .frame(maxWidth: .infinity, minHeight: 190)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(selectedVideos) { item in
                            videoRow(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 190)
            }

            HStack(spacing: 10) {
                Button {
                    chooseVideos()
                } label: {
                    Label("Choose Videos", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConverting)

                Button {
                    selectedVideos.removeAll()
                    results.removeAll()
                    importedCount = 0
                    progress = 0
                    status = "Queue cleared."
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(selectedVideos.isEmpty || isConverting)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 430)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.28), style: StrokeStyle(lineWidth: 1.4, dash: [7, 5]))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.10) : Color.white.opacity(0.22))
            )
            .overlay {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.doc")
                        .font(.title3)
                    Text("Drop videos")
                        .font(.headline)
                    Text("MP4, MOV, M4V")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 72)
            .onDrop(
                of: [UTType.fileURL.identifier],
                isTargeted: $isDropTargeted,
                perform: handleDrop
            )
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Cover", systemImage: "photo")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                if let coverImageURL {
                    HStack(spacing: 12) {
                        CoverThumbnail(url: coverImageURL)
                            .frame(width: 74, height: 74)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(coverImageURL.lastPathComponent)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("Used for every selected video.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("Automatic frame")
                            .font(.callout.weight(.medium))
                        Text("A middle frame is used when no custom cover is selected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 10) {
                Button {
                    chooseCover()
                } label: {
                    Label("Choose Cover", systemImage: "photo.badge.plus")
                }
                .disabled(isConverting)

                Button {
                    coverImageURL = nil
                } label: {
                    Label("Reset", systemImage: "xmark.circle")
                }
                .disabled(coverImageURL == nil || isConverting)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("Destination", systemImage: "photo.stack")
                    .font(.headline)
                Text("Photos.app")
                    .font(.title3.weight(.semibold))
                Text("Each converted item is imported as a Live Photo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await convertBatch() }
            } label: {
                Label("Create Live Photos", systemImage: "livephoto")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(selectedVideos.isEmpty || isConverting)

            Button {
                openPhotos()
            } label: {
                Label("Open Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .disabled(importedCount == 0)
        }
        .padding(18)
        .frame(width: 300)
        .frame(minHeight: 430)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .controlSize(.large)

            if importedCount > 0 {
                Label("\(importedCount) imported", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func videoRow(_ item: VideoItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "video.fill")
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.url.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.url.deletingLastPathComponent().path(percentEncoded: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                selectedVideos.removeAll { $0.id == item.id }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .disabled(isConverting)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func chooseVideos() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .video]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            addVideos(panel.urls)
        }
    }

    private func chooseCover() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            coverImageURL = panel.url
        }
    }

    @MainActor
    private func convertBatch() async {
        guard !selectedVideos.isEmpty else { return }

        isConverting = true
        progress = 0
        importedCount = 0
        results = []
        errorMessage = nil

        do {
            let total = Double(selectedVideos.count)

            for (index, item) in selectedVideos.enumerated() {
                let baseProgress = Double(index) / total
                let slice = 1.0 / total
                status = "Preparing \(item.url.lastPathComponent)..."

                let result = try await converter.convert(
                    videoURL: item.url,
                    outputDirectory: temporaryOutputFolder(),
                    coverImageURL: coverImageURL
                ) { itemProgress in
                    Task { @MainActor in
                        progress = baseProgress + itemProgress * slice * 0.92
                        status = itemProgress < 0.35 ? "Preparing cover for \(item.url.lastPathComponent)..." : "Writing \(item.url.lastPathComponent)..."
                    }
                }

                status = "Importing \(item.url.lastPathComponent) into Photos..."
                try await importer.importLivePhoto(result)
                results.append(result)
                importedCount += 1
                progress = Double(index + 1) / total
            }

            status = "Imported \(importedCount) Live Photo\(importedCount == 1 ? "" : "s") into Photos."
        } catch {
            errorMessage = error.localizedDescription
            status = "Stopped after importing \(importedCount) of \(selectedVideos.count)."
        }

        isConverting = false
    }

    private func addVideos(_ urls: [URL]) {
        let existing = Set(selectedVideos.map(\.url))
        let videos = urls
            .filter(isVideoURL)
            .filter { !existing.contains($0) }
            .map(VideoItem.init(url:))

        selectedVideos.append(contentsOf: videos)
        results.removeAll()
        importedCount = 0
        progress = 0
        status = selectedVideos.isEmpty ? "Drop videos here or choose a batch." : "\(selectedVideos.count) video\(selectedVideos.count == 1 ? "" : "s") ready."
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data,
                   let string = String(data: data, encoding: .utf8) {
                    url = URL(string: string)
                } else {
                    url = item as? URL
                }

                if let url {
                    Task { @MainActor in
                        addVideos([url])
                    }
                }
            }
        }

        return accepted
    }

    private func isVideoURL(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .movie) || type.conforms(to: .video)
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
        NSWorkspace.shared.openApplication(at: photosURL, configuration: NSWorkspace.OpenConfiguration())
    }

    @MainActor
    private func checkForUpdates() async {
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        do {
            let result = try await updateChecker.check()
            updateURL = result.releaseURL
            updateMessage = result.hasUpdate
                ? "Version \(result.latestVersion) is available. You are running \(result.currentVersion)."
                : "You are up to date. Current version: \(result.currentVersion)."
        } catch {
            updateURL = nil
            updateMessage = error.localizedDescription
        }
    }
}

private struct CoverThumbnail: View {
    let url: URL

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var body: some View {
        VStack(spacing: 18) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
            }

            VStack(spacing: 6) {
                Text("LivePhotoMaker")
                    .font(.title.bold())
                Text("Version \(version)")
                    .foregroundStyle(.secondary)
            }

            Text("Batch convert local videos into Photos-ready Live Photos with optional custom covers.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(width: 340)

            HStack {
                Button("GitHub") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/Flywith24/LivePhotoMaker")!)
                }

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 430)
    }
}
