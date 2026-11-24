import Foundation

/// Manages the private temporary workspace used to preview an archive entry
/// (TKT-M5-03). Extraction reuses the security-validated engine, and the temp
/// directory is always removed on dismiss — nothing is left behind.
struct QuickLookTempWorkspace {
    private(set) var directory: URL?

    mutating func create() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7Zip-QuickLook-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        directory = url
        return url
    }

    /// Deletes the workspace if present. Idempotent.
    func cleanUp() {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}
