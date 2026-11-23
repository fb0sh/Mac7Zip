import SwiftUI

@main
struct Mac7ZipApp: App {
    @StateObject private var model = FileBrowserModel()

    var body: some Scene {
        Window("Mac7Zip", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 1000, height: 660)
        .windowResizability(.contentMinSize)
        .commands {
            Mac7ZipCommands(model: model)
        }
    }
}
