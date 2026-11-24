import Foundation

/// Read-only `FileSystemProvider` for archive contents (ADR-006).
///
/// The archive's real URL is held separately from the opaque internal path, so an
/// archive entry can never be mistaken for a filesystem path. Listings are cached
/// per archive: one `7zz l` call serves all directory navigation.
final class ArchiveFileSystemProvider: FileSystemProvider {
    private let engine: ArchiveEngine
    private let archiveURL: URL
    private var cachedEntries: [ArchiveEntry]?

    init(engine: ArchiveEngine, archiveURL: URL) {
        self.engine = engine
        self.archiveURL = archiveURL
    }

    var kind: FileSystemProviderKind { .archive }

    /// The archive this provider is bound to (used to detect location switches).
    var sourceArchiveURL: URL { archiveURL }

    /// Read-only: no write/rename/delete/create capability.
    var capabilities: FileSystemCapabilities { [.list, .readFile] }

    func list(_ location: BrowserLocation) async throws -> [FileItem] {
        guard case .archive(let requestedArchive, let internalPath) = location else {
            throw FileSystemProviderError.unsupportedLocation
        }
        guard requestedArchive.standardizedFileURL == archiveURL.standardizedFileURL else {
            throw FileSystemProviderError.unsupportedLocation
        }

        let entries: [ArchiveEntry]
        if let cachedEntries {
            entries = cachedEntries
        } else {
            entries = try await engine.listContents(of: archiveURL)
            cachedEntries = entries
        }

        return Self.directoryListing(entries: entries, prefix: internalPath, archiveURL: archiveURL)
    }

    /// Drops the cached listing (e.g. after the archive changes on disk).
    func invalidateCache() {
        cachedEntries = nil
    }

    // MARK: - Pure mapping (unit-testable without a process)

    /// Filters archive entries to the direct children of `prefix` and maps them to
    /// `FileItem`s. Directories are synthesised from path prefixes when the engine
    /// does not list explicit folder entries.
    static func directoryListing(entries: [ArchiveEntry], prefix: String, archiveURL: URL) -> [FileItem] {
        let normalizedPrefix = normalize(prefix)
        var seenDirectories: Set<String> = []
        var items: [FileItem] = []

        for entry in entries {
            let path = normalize(entry.path)
            guard !path.isEmpty, path != normalizedPrefix else { continue }
            guard path.hasPrefix(normalizedPrefix) else { continue }

            let remainder = String(path.dropFirst(normalizedPrefix.count))
            guard !remainder.isEmpty else { continue }

            let components = remainder.split(separator: "/", omittingEmptySubsequences: true)
            guard let first = components.first.map(String.init) else { continue }

            let childPath = normalizedPrefix.isEmpty ? first : normalizedPrefix + "/" + first
            let isDirectChild = components.count == 1

            if isDirectChild && !entry.isDirectory {
                items.append(
                    FileItem(
                        url: archiveURL.appendingPathComponent(childPath),
                        name: first,
                        isDirectory: false,
                        size: entry.size,
                        modificationDate: entry.modificationDate,
                        kind: entry.method.flatMap { $0.isEmpty ? nil : $0 } ?? "File",
                        archiveMetadata: ArchiveEntryMetadata(
                            packedSize: entry.packedSize,
                            crc: entry.crc,
                            isEncrypted: entry.isEncrypted,
                            method: entry.method
                        )
                    )
                )
            } else {
                // A nested entry implies a synthesised directory at this level.
                if !seenDirectories.contains(childPath) {
                    seenDirectories.insert(childPath)
                    items.append(
                        FileItem(
                            url: archiveURL.appendingPathComponent(childPath),
                            name: first,
                            isDirectory: true,
                            size: 0,
                            modificationDate: nil,
                            kind: "Folder"
                        )
                    )
                }
            }
        }
        return items
    }

    /// Normalizes an archive-internal path: no leading/trailing slashes.
    static func normalize(_ path: String) -> String {
        var value = path.replacingOccurrences(of: "\\", with: "/")
        while value.hasPrefix("/") { value.removeFirst() }
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    /// Builds the breadcrumb segments for an archive-internal path.
    static func breadcrumbs(prefix: String) -> [String] {
        normalize(prefix).split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }
}
