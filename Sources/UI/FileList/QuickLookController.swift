import AppKit
import Combine
import Foundation
import Quartz

/// Presents a Quick Look preview of a single archive entry by extracting it to a
/// private temp folder, then deletes that folder on dismiss.
@MainActor
final class QuickLookController: NSObject, ObservableObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var workspace = QuickLookTempWorkspace()
    private var previewURL: URL?

    /// Extracts `entryPath` from `archiveURL` into a temp workspace and prepares
    /// it for preview. Returns the temp file URL.
    func prepare(entryPath: String, archiveURL: URL, engine: ArchiveEngine) async throws -> URL {
        workspace.cleanUp()
        let dir = try workspace.create()
        var options = ExtractOptions(destination: dir)
        var adjusted = options
        adjusted.destination = dir
        adjusted.entries = [entryPath]
        adjusted.password = nil
        try await engine.extract(archive: archiveURL, to: dir, options: adjusted)
        _ = options

        let name = (entryPath as NSString).lastPathComponent
        let fileURL = dir.appendingPathComponent(name)
        previewURL = FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : dir
        return previewURL ?? dir
    }

    func present() {
        guard let previewURL else { return }
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        _ = previewURL
    }

    func cleanUp() {
        workspace.cleanUp()
        previewURL = nil
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL as NSURL?
    }

    // MARK: - QLPreviewPanelDelegate

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Closing the panel cleans up the temp workspace immediately.
        if event.type == .keyDown && event.keyCode == 53 { // Escape
            cleanUp()
        }
        return false
    }
}
