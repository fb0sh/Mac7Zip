import AppKit
import Foundation

import AppKit
import Combine
import Foundation

/// Minimal app delegate to receive Finder document-open events on cold and warm
/// launches and route them into `FileOpenInbox`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let archive = urls.first(where: { ArchiveDocumentTypes.handles(pathExtension: $0.pathExtension) })
            ?? urls.first else { return }
        Task { @MainActor in FileOpenInbox.shared.enqueue(archive) }
    }
}
