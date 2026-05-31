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
    @State private var status = "拖入视频，或选择一批视频开始。"
    @State private var results: [LivePhotoConversionResult] = []
    @State private var errorMessage: String?
    @State private var updateMessage: String?
    @State private var updateURL: URL?
    @State private var showsAbout = false
    @State private var framePickerRequest: FramePickerRequest?

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
        .alert("转换失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("检查更新", isPresented: Binding(
            get: { updateMessage != nil },
            set: { if !$0 { updateMessage = nil } }
        )) {
            if let updateURL {
                Button("打开发布页") {
                    NSWorkspace.shared.open(updateURL)
                }
            }
            Button("好", role: .cancel) { updateMessage = nil }
        } message: {
            Text(updateMessage ?? "")
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
        }
        .sheet(item: $framePickerRequest) { request in
            VideoFramePicker(videoURL: request.videoURL) { coverURL in
                coverImageURL = coverURL
                status = "已从 \(request.videoURL.lastPathComponent) 选择封面帧。"
            }
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
                Text("批量把视频导入「照片」并识别为 Live Photo。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showsAbout = true
            } label: {
                Label("关于", systemImage: "info.circle")
            }
            .buttonStyle(ToolbarPillButtonStyle())

            Button {
                Task { await checkForUpdates() }
            } label: {
                Label(isCheckingUpdates ? "检查中" : "检查更新", systemImage: "arrow.clockwise")
            }
            .disabled(isCheckingUpdates)
            .buttonStyle(ToolbarPillButtonStyle())
        }
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("导入队列", systemImage: "film.stack")
                    .font(.headline)
                Spacer()
                Text("\(selectedVideos.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            dropZone

            if selectedVideos.isEmpty {
                ContentUnavailableView(
                    "还没有选择视频",
                    systemImage: "video.badge.plus",
                    description: Text("拖入视频文件，或一次选择多个视频。")
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
                    Label("选择视频", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConverting)

                Button {
                    selectedVideos.removeAll()
                    results.removeAll()
                    importedCount = 0
                    progress = 0
                    status = "队列已清空。"
                } label: {
                    Label("清空", systemImage: "trash")
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
                    Text("拖入视频")
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
            Label("封面", systemImage: "photo")
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
                            Text("将用于所有待转换视频。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("自动封面")
                            .font(.callout.weight(.medium))
                        Text("未选择封面时，会使用视频中间帧。")
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
                    Label("选择图片", systemImage: "photo.badge.plus")
                }
                .disabled(isConverting)

                Button {
                    if let firstVideo = selectedVideos.first?.url {
                        framePickerRequest = FramePickerRequest(videoURL: firstVideo)
                    }
                } label: {
                    Label("选帧", systemImage: "film")
                }
                .disabled(selectedVideos.isEmpty || isConverting)

                Button {
                    coverImageURL = nil
                } label: {
                    Label("重置", systemImage: "xmark.circle")
                }
                .disabled(coverImageURL == nil || isConverting)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("导入位置", systemImage: "photo.stack")
                    .font(.headline)
                Text("照片 App")
                    .font(.title3.weight(.semibold))
                Text("每个视频都会作为 Live Photo 导入。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if let firstVideo = selectedVideos.first?.url {
                    framePickerRequest = FramePickerRequest(videoURL: firstVideo)
                }
            } label: {
                Label("从视频选择封面", systemImage: "slider.horizontal.below.sun.max")
                    .frame(maxWidth: .infinity)
            }
            .disabled(selectedVideos.isEmpty || isConverting)

            Button {
                Task { await convertBatch() }
            } label: {
                Label("创建 Live Photo", systemImage: "livephoto")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(selectedVideos.isEmpty || isConverting)

            Button {
                openPhotos()
            } label: {
                Label("打开「照片」", systemImage: "photo.on.rectangle")
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
                Label("已导入 \(importedCount) 个", systemImage: "checkmark.circle.fill")
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
                framePickerRequest = FramePickerRequest(videoURL: item.url)
            } label: {
                Image(systemName: "photo")
            }
            .buttonStyle(.borderless)
            .help("从这个视频选择封面帧")
            .disabled(isConverting)

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
                status = "正在准备 \(item.url.lastPathComponent)..."

                let result = try await converter.convert(
                    videoURL: item.url,
                    outputDirectory: temporaryOutputFolder(),
                    coverImageURL: coverImageURL
                ) { itemProgress in
                    Task { @MainActor in
                        progress = baseProgress + itemProgress * slice * 0.92
                        status = itemProgress < 0.35 ? "正在准备 \(item.url.lastPathComponent) 的封面..." : "正在写入 \(item.url.lastPathComponent)..."
                    }
                }

                status = "正在导入 \(item.url.lastPathComponent) 到「照片」..."
                try await importer.importLivePhoto(result)
                results.append(result)
                importedCount += 1
                progress = Double(index + 1) / total
            }

            status = "已导入 \(importedCount) 个 Live Photo 到「照片」。"
        } catch {
            errorMessage = error.localizedDescription
            status = "已停止：共 \(selectedVideos.count) 个，已导入 \(importedCount) 个。"
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
        status = selectedVideos.isEmpty ? "拖入视频，或选择一批视频开始。" : "\(selectedVideos.count) 个视频已准备好。"
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
                ? "发现新版本 \(result.latestVersion)。当前版本是 \(result.currentVersion)。"
                : "已经是最新版本。当前版本：\(result.currentVersion)。"
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

private struct ToolbarPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.10), radius: 8, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
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
                Text("版本 \(version)")
                    .foregroundStyle(.secondary)
            }

            Text("批量把本地视频转换并导入「照片」，支持自定义封面。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(width: 340)

            HStack {
                Button("GitHub") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/Flywith24/LivePhotoMaker")!)
                }

                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 430)
    }
}
