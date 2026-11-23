import Foundation

/// Supported archive formats. Phase 0 only defines the vocabulary; the actual
/// engines (7zz) are integrated in a later phase.
enum ArchiveFormat: String, Sendable, CaseIterable {
    case sevenZip = "7z"
    case zip
    case tarGz = "tar.gz"

    var displayName: String {
        switch self {
        case .sevenZip: return "7z"
        case .zip: return "ZIP"
        case .tarGz: return "TAR.GZ"
        }
    }
}

struct ArchiveOptions: Sendable {
    var format: ArchiveFormat = .sevenZip
    var password: String?
    var compressionLevel: Int = 5
}

struct ExtractOptions: Sendable {
    var password: String?
    var overwrite: Bool = false
}

/// One entry inside an archive (used when browsing archive contents).
struct ArchiveEntry: Identifiable, Sendable {
    let id = UUID()
    let path: String
    let size: Int64
    let isDirectory: Bool
    let modificationDate: Date?
}

struct ArchiveTestResult: Sendable {
    let passed: Bool
    let message: String
}

enum ArchiveError: Error, Sendable {
    case notImplemented
    case cancelled
    case failed(String)
}

/// Abstraction over a compression engine. Phase 0 ships only the protocol so
/// that UI, task management, and the future `7zz` subprocess integration share
/// one clear seam. Implementations are expected to run work off the main actor
/// and to honour `cancel()`.
protocol ArchiveEngine: AnyObject, Sendable {
    func createArchive(at destination: URL, from sources: [URL], options: ArchiveOptions) async throws
    func extract(archive: URL, to destination: URL, options: ExtractOptions) async throws
    func listContents(of archive: URL) async throws -> [ArchiveEntry]
    func test(archive: URL) async throws -> ArchiveTestResult
    func cancel() async
}
