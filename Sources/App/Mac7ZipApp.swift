import SwiftUI

@main
struct Mac7ZipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var registry = WindowRegistry()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        // One scene per open window: opening another archive adds a window instead
        // of reusing a single shared window.
        WindowGroup(id: "browser", for: BrowserWindow.ID.self) { $windowID in
            BrowserWindowRoot(
                windowID: windowID ?? registry.windows.first?.id,
                registry: registry
            )
            .environmentObject(settings)
        } defaultValue: {
            registry.windows.first?.id ?? UUID()
        }
        .defaultSize(width: 900, height: 560)
        .windowResizability(.contentMinSize)
        .commands {
            Mac7ZipCommands()
        }

        Settings {
            SettingsView(store: settings)
        }
    }
}

/// Owns the `BrowserStore` for a single window and wires it to the registry.
struct BrowserWindowRoot: View {
    let windowID: UUID?
    @ObservedObject var registry: WindowRegistry
    @StateObject private var model = BrowserStore()

    var body: some View {
        ContentView()
            .environmentObject(model)
            .task {
                guard let windowID,
                      let window = registry.windows.first(where: { $0.id == windowID }) else { return }
                if let url = window.initialURL {
                    if ArchiveFormat.detect(from: url) != nil {
                        model.openArchive(url)
                    } else {
                        model.navigate(to: url)
                    }
                }
            }
    }
}
