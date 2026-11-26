import AppKit
import Combine
import Foundation

/// Minimal app delegate to receive Finder document-open events on cold and warm
/// launches and route them into `FileOpenInbox`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Publish the Finder Service handlers. Info.plist declares them, but
        // AppKit only routes the menu items to us once a services provider is
        // registered - without this the Services submenu stays empty.
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        // Show icon + text in the toolbar so the actions are self-explanatory.
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.toolbar?.displayMode = .iconAndLabel
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let archive = urls.first(where: { ArchiveDocumentTypes.handles(pathExtension: $0.pathExtension) })
            ?? urls.first else { return }
        Task { @MainActor in
            // Enqueue once; the active window claims it exactly once (no duplicate open).
            FileOpenInbox.shared.enqueue(archive)
        }
    }

    // MARK: - Finder Services

    @objc func openArchiveService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        Task { @MainActor in _ = ServiceHandlers.handle(.openArchive, pasteboard: pboard) }
    }

    @objc func extractHereService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        Task { @MainActor in _ = ServiceHandlers.handle(.extractHere, pasteboard: pboard) }
    }

    @objc func extractToFolderService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        Task { @MainActor in _ = ServiceHandlers.handle(.extractToFolder, pasteboard: pboard) }
    }

    @objc func testArchiveService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        Task { @MainActor in _ = ServiceHandlers.handle(.testArchive, pasteboard: pboard) }
    }

    @objc func addToArchiveService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        Task { @MainActor in _ = ServiceHandlers.handle(.addToArchive, pasteboard: pboard) }
    }
}
