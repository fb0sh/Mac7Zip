import Foundation

/// Identifies what a browser pane is showing.
///
/// Only `.real` locations may be converted to a filesystem `URL`. Archive-internal
/// paths are opaque and must never be passed to `FileManager`/`NSWorkspace`.
enum BrowserLocation: Hashable, Sendable {
    case real(URL)
    case archive(archiveURL: URL, internalPath: String)

    /// The real filesystem URL, or `nil` for archive-internal locations.
    var realURL: URL? {
        if case .real(let url) = self { return url }
        return nil
    }

    var isArchive: Bool {
        if case .archive = self { return true }
        return false
    }

    /// Standardized real URL (nil for archives).
    var standardizedRealURL: URL? {
        realURL?.standardizedFileURL
    }
}
