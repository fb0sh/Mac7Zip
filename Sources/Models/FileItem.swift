import Foundation

/// A single entry (file, folder, or symbolic link target) shown in the file browser.
///
/// `FileItem` is a value type so it is cheap to copy across threads and safe to
/// hand back from background file-system reads to the main-actor UI.
struct FileItem: Identifiable, Hashable, Sendable {
    /// Stable identity based on the entry's URL.
    var id: URL { url }

    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let kind: String
}
