import SwiftUI

@main
struct LivePhotoMakerApp: App {
    init() {
        CommandLineConversion.runIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}
