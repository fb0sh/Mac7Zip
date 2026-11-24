import Foundation

/// Chooses which archive entry to use as a Finder thumbnail (TKT: QL thumbnail).
/// Pure logic so the selection rules are unit-testable without Quick Look.
enum ThumbnailCandidate {
    /// Extensions Quick Look / AppKit can render directly, best first.
    static let imageExtensions: [String] = [
        "png", "jpg", "jpeg", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp", "icns",
    ]

    struct Entry: Equatable, Sendable {
        let path: String
        let size: Int64
        let isDirectory: Bool

        init(path: String, size: Int64, isDirectory: Bool) {
            self.path = path
            self.size = size
            self.isDirectory = isDirectory
        }
    }

    /// Picks the best entry to preview: the largest image file. Falls back to
    /// `nil` when the archive contains no renderable image.
    static func bestImageEntry(in entries: [Entry]) -> Entry? {
        let images = entries.filter { entry in
            guard !entry.isDirectory else { return false }
            let ext = (entry.path as NSString).pathExtension.lowercased()
            return imageExtensions.contains(ext)
        }
        return images.max { lhs, rhs in
            if lhs.size == rhs.size { return lhs.path > rhs.path }
            return lhs.size < rhs.size
        }
    }

    /// Up to `limit` entry names to draw as a content preview when the archive has
    /// no renderable image (so the thumbnail shows real contents, not blank paper).
    static func previewLines(for entries: [Entry], limit: Int = 4) -> [String] {
        let visible = entries.filter { !$0.isDirectory }
        let sorted = visible.sorted { lhs, rhs in
            if lhs.size == rhs.size { return lhs.path < rhs.path }
            return lhs.size > rhs.size
        }
        return sorted.prefix(limit).map { entry in
            let name = (entry.path as NSString).lastPathComponent
            return name.isEmpty ? entry.path : name
        }
    }

    /// Short badge text for the archive (e.g. "ZIP", "7Z", "TAR.GZ"), uppercased.
    static func badgeText(forFileName name: String) -> String {
        let lower = name.lowercased()
        for suffix in ["tar.gz", "tar.xz", "tar.zst", "tbz2", "tgz"] where lower.hasSuffix("." + suffix) {
            return suffix.uppercased()
        }
        let ext = (name as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "ARCHIVE" : ext
    }

    /// Entry count summary text, e.g. "12 items".
    static func summaryText(fileCount: Int, folderCount: Int) -> String {
        let total = fileCount + folderCount
        if total == 0 { return "Empty archive" }
        var parts: [String] = []
        if folderCount > 0 { parts.append("\(folderCount) folder\(folderCount == 1 ? "" : "s")") }
        if fileCount > 0 { parts.append("\(fileCount) file\(fileCount == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }
}
