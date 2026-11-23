import AppKit
import Combine
import Foundation

/// Holds a file URL that arrived from Finder (double-click / Open With) so the
/// SwiftUI view hierarchy can react once it is ready (TKT-M5-01).
@MainActor
final class FileOpenInbox: ObservableObject {
    static let shared = FileOpenInbox()
    @Published var pendingURL: URL?

    private init() {}

    func enqueue(_ url: URL) {
        guard url.isFileURL else { return }
        pendingURL = url
    }

    func take() -> URL? {
        defer { pendingURL = nil }
        return pendingURL
    }
}

/// Minimal app delegate to receive Finder document-open events on cold and warm
/// launches and route them into `FileOpenInbox`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let archive = urls.first(where: { ArchiveDocumentTypes.handles(pathExtension: $0.pathExtension) })
            ?? urls.first else { return }
        Task { @MainActor in FileOpenInbox.shared.enqueue(archive) }
    }
}
