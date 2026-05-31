import SwiftUI

@main
struct LivePhotoMakerApp: App {
    init() {
        CommandLineConversion.runIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 460)
        }
        .windowStyle(.titleBar)
    }
}
