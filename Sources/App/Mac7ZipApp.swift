import SwiftUI

@main
struct Mac7ZipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = FileBrowserModel()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        Window("Mac7Zip", id: "main") {
            ContentView()
                .environmentObject(model)
                .environmentObject(settings)
        }
        .defaultSize(width: 1000, height: 660)
        .windowResizability(.contentMinSize)
        .commands {
            Mac7ZipCommands(model: model)
        }

        Settings {
            SettingsView(store: settings)
        }
    }
}
