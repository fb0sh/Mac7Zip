import Foundation

/// A single entry (file, folder, or symbolic link target) shown in the file browser.
///
/// `FileItem` is a value type so it is cheap to copy across threads and safe to
/// hand back from background file-system reads to the main-actor UI.
/// Extra per-entry metadata that only archive listings can provide.
struct ArchiveEntryMetadata: Hashable, Sendable {
    let packedSize: Int64
    let crc: String?
    let isEncrypted: Bool
    let method: String?
}

struct FileItem: Identifiable, Hashable, Sendable {
    /// Stable identity based on the entry's URL.
    var id: URL { url }

    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let kind: String
    /// Present only for entries listed from inside an archive.
    var archiveMetadata: ArchiveEntryMetadata? = nil
}
