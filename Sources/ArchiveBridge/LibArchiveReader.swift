import Foundation

/// Thin Swift wrapper over libarchive for reading archive entries (any format
/// libarchive supports: zip/7z/rar/tar/gz/bz2/xz/cab/iso…). Runs purely in-process,
/// so it is safe inside sandboxed Quick Look extensions (no subprocess).
enum LibArchiveReader {
    struct Entry: Equatable, Sendable {
        let path: String
        let size: Int64
        let isDirectory: Bool
    }

    /// Lists entries. Returns nil if the archive can't be opened.
    static func listEntries(at url: URL) -> [Entry]? {
        guard let archive = archive_read_new() else { return nil }
        defer { archive_read_free(archive) }

        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)

        guard archive_read_open_filename(archive, url.path, 64 * 1024) == ARCHIVE_OK else {
            return nil
        }
        defer { archive_read_close(archive) }

        var entries: [Entry] = []
        var entry: OpaquePointer?
        while archive_read_next_header(archive, &entry) == ARCHIVE_OK {
            guard let entry else { break }
            let path = archive_entry_pathname(entry).map { String(cString: $0) } ?? ""
            let size = Int64(archive_entry_size(entry))
            let isDirectory = archive_entry_filetype(entry) == mode_t(0o040000) // AE_IFDIR
            if !path.isEmpty {
                entries.append(Entry(path: path, size: size, isDirectory: isDirectory))
            }
            archive_read_data_skip(archive)
        }
        return entries
    }

    /// Extracts a single entry's data into memory (for cover images / previews).
    static func extractEntry(at url: URL, path target: String, maxBytes: Int = 20 * 1024 * 1024) -> Data? {
        guard let archive = archive_read_new() else { return nil }
        defer { archive_read_free(archive) }
        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)
        guard archive_read_open_filename(archive, url.path, 64 * 1024) == ARCHIVE_OK else { return nil }
        defer { archive_read_close(archive) }

        var entry: OpaquePointer?
        while archive_read_next_header(archive, &entry) == ARCHIVE_OK {
            guard let entry else { break }
            let path = archive_entry_pathname(entry).map { String(cString: $0) } ?? ""
            if path == target {
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 64 * 1024)
                while true {
                    let n = buffer.withUnsafeMutableBytes { ptr in
                        archive_read_data(archive, ptr.baseAddress, ptr.count)
                    }
                    if n <= 0 { break }
                    data.append(contentsOf: buffer[0..<n])
                    if data.count > maxBytes { return nil }
                }
                return data
            }
            archive_read_data_skip(archive)
        }
        return nil
    }
}
