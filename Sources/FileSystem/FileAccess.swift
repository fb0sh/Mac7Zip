import Foundation

/// Snapshot describing whether a path exists and whether it is a directory.
struct FileAccessSnapshot: Sendable, Equatable {
    let exists: Bool
    let isDirectory: Bool
}

/// The single choke point for filesystem access. All disk access in State and UI
/// layers must go through this seam so permission handling and (future) sandboxing
/// are enforceable in one place.
protocol FileAccess: Sendable {
    func contents(of url: URL) async throws -> [FileItem]
    func snapshot(at url: URL) -> FileAccessSnapshot
    /// Expands `~` and standardizes a user-entered path.
    func normalizeUserPath(_ raw: String) -> URL
}

/// `FileManager`-backed implementation. Errors surface raw from the filesystem and
/// are mapped to user-facing messages by the state layer.
struct RealFileAccess: FileAccess {
    private let service: FileSystemService

    init(service: FileSystemService = FileSystemService()) {
        self.service = service
    }

    func contents(of url: URL) async throws -> [FileItem] {
        try await service.contents(of: url)
    }

    func snapshot(at url: URL) -> FileAccessSnapshot {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return FileAccessSnapshot(exists: exists, isDirectory: isDirectory.boolValue)
    }

    func normalizeUserPath(_ raw: String) -> URL {
        let expanded = (raw as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }
}
