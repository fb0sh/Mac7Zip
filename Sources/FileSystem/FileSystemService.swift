import Foundation

/// Reads directory contents off the main thread and converts them into
/// `FileItem` values. Kept as a value type so it is trivially `Sendable`.
struct FileSystemService: Sendable {
    func contents(of directory: URL) async throws -> [FileItem] {
        try await Task.detached(priority: .userInitiated) {
            try Self.readContents(of: directory)
        }.value
    }

    static func readContents(of directory: URL) throws -> [FileItem] {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: []
        )

        return urls.map { url in
            let values = try? url.resourceValues(forKeys: keys)
            let isDirectory = values?.isDirectory ?? false
            let size = Int64(values?.fileSize ?? 0)
            return FileItem(
                url: url,
                name: url.lastPathComponent,
                isDirectory: isDirectory,
                size: size,
                modificationDate: values?.contentModificationDate,
                kind: kind(for: url, isDirectory: isDirectory)
            )
        }
    }

    static func kind(for url: URL, isDirectory: Bool) -> String {
        if isDirectory { return "Folder" }
        let ext = url.pathExtension
        return ext.isEmpty ? "Document" : "\(ext.uppercased()) document"
    }
}
