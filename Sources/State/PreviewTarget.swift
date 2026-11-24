import Foundation

/// What should be previewed for the current selection. Pure logic so the decision
/// (real file vs archive entry) is unit-testable.
enum PreviewTarget: Equatable, Sendable {
    /// A file that exists on disk; Quick Look can read it directly.
    case file(URL)
    /// An entry inside an archive; must be extracted to a temp file first.
    case archiveEntry(archive: URL, entryPath: String, fileName: String)
    /// Nothing previewable (empty selection, folder inside an archive, …).
    case none

    static func resolve(
        item: FileItem?,
        isInsideArchive: Bool,
        archiveURL: URL?,
        internalPath: String
    ) -> PreviewTarget {
        guard let item else { return .none }
        if isInsideArchive {
            guard let archiveURL, !item.isDirectory else { return .none }
            let base = internalPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let entryPath = base.isEmpty ? item.name : base + "/" + item.name
            return .archiveEntry(archive: archiveURL, entryPath: entryPath, fileName: (item.name as NSString).lastPathComponent)
        }
        // Folders are not previewed (Finder behaves the same way).
        guard !item.isDirectory else { return .none }
        return .file(item.url)
    }
}
