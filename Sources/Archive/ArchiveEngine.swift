import Foundation

/// Supported archive formats and what the engine can do with each.
enum ArchiveFormat: String, Sendable, CaseIterable {
    case sevenZip = "7z"
    case zip
    case tar
    case gzip
    case bzip2
    case xz
    case rar

    var displayName: String {
        switch self {
        case .sevenZip: return "7z"
        case .zip: return "ZIP"
        case .tar: return "TAR"
        case .gzip: return "GZIP"
        case .bzip2: return "BZIP2"
        case .xz: return "XZ"
        case .rar: return "RAR"
        }
    }

    /// Formats Mac7Zip can create. RAR is excluded by the unRAR license restriction.
    var canCreate: Bool {
        switch self {
        case .sevenZip, .zip: return true
        case .tar, .gzip, .bzip2, .xz, .rar: return false
        }
    }

    var canExtract: Bool { true }

    /// 7zz `-t` value.
    var switchValue: String {
        switch self {
        case .sevenZip: return "7z"
        case .zip: return "zip"
        case .tar: return "tar"
        case .gzip: return "gzip"
        case .bzip2: return "bzip2"
        case .xz: return "xz"
        case .rar: return "rar"
        }
    }

    /// Best-effort detection from a file name.
    static func detect(from url: URL) -> ArchiveFormat? {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") { return .gzip }
        switch url.pathExtension.lowercased() {
        case "7z": return .sevenZip
        case "zip", "jar", "xpi", "epub", "docx", "xlsx", "pptx", "odt": return .zip
        case "tar": return .tar
        case "gz", "gzip": return .gzip
        case "bz2", "bzip2", "tbz2": return .bzip2
        case "xz", "txz": return .xz
        case "rar": return .rar
        default: return nil
        }
    }
}

struct ArchiveOptions: Sendable {
    var format: ArchiveFormat = .sevenZip
    var password: String?
    var compressionLevel: Int = 5
    var encryptFileNames: Bool = false
    var advanced: AdvancedCompressionOptions = AdvancedCompressionOptions()
}

enum ExtractPathMode: Sendable {
    case full
    case relative
}

enum OverwriteMode: Sendable {
    case ask
    case overwrite
    case skip
    case rename

    /// 7zz `-ao` value.
    var switchValue: String {
        switch self {
        case .ask: return "a"
        case .overwrite: return "o"
        case .skip: return "s"
        case .rename: return "u"
        }
    }
}

struct ExtractOptions: Sendable {
    var password: String?
    var entries: [String]?
    var destination: URL
    var createSubfolder: String?
    var pathMode: ExtractPathMode = .full
    var eliminateDuplicateRoot: Bool = false
    var overwriteMode: OverwriteMode = .ask
    var restorePermissions: Bool = false
}

/// One entry inside an archive.
struct ArchiveEntry: Identifiable, Hashable, Sendable {
    var id: String { path }
    let path: String
    let size: Int64
    let packedSize: Int64
    let isDirectory: Bool
    let modificationDate: Date?
    let crc: String?
    let isEncrypted: Bool
    let method: String?
    /// Target of a symbolic link entry, when the listing reports one.
    var linkTarget: String? = nil
}

struct ArchiveTestResult: Sendable {
    let passed: Bool
    let message: String
}

enum ArchiveError: Error, Equatable, Sendable {
    case passwordRequired
    case wrongPassword
    case corrupt(String)
    case unsupportedFormat(String)
    case unsafeEntry(paths: [String], reason: String)
    case cancelled
    case outOfMemory
    case engineFailure(code: Int32, diagnostic: String)
    case engineNotFound
    case notImplemented
    /// 7zz's password prompt is console-bound; no pipe/PTY transport is available.
    /// Mac7Zip refuses rather than silently putting the password in argv.
    case passwordTransportUnavailable

    /// Map a 7zz exit code + captured diagnostic to a typed error.
    static func from(exitCode: Int32, diagnostic: String) -> ArchiveError? {
        switch exitCode {
        case 0: return nil
        case 255: return .cancelled
        case 8: return .outOfMemory
        case 7: return .engineFailure(code: exitCode, diagnostic: diagnostic)
        case 2:
            let lower = diagnostic.lowercased()
            if lower.contains("wrong password") || lower.contains("password is incorrect") {
                return .wrongPassword
            }
            if lower.contains("can not open the file as archive") || lower.contains("is not archive") {
                return .corrupt(diagnostic)
            }
            return .engineFailure(code: exitCode, diagnostic: diagnostic)
        case 1: return .engineFailure(code: exitCode, diagnostic: diagnostic)
        default: return .engineFailure(code: exitCode, diagnostic: diagnostic)
        }
    }
}

/// Abstraction over a compression engine, keeping UI and task management free of
/// process details.
protocol ArchiveEngine: Sendable {
    func createArchive(at destination: URL, from sources: [URL], options: ArchiveOptions) async throws
    func extract(archive: URL, to destination: URL, options: ExtractOptions) async throws
    func listContents(of archive: URL) async throws -> [ArchiveEntry]
    func test(archive: URL) async throws -> ArchiveTestResult
}

/// Locates the bundled 7zz helper.
enum SevenZipLocator {
    static func helperURL(bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forAuxiliaryExecutable: "7zz") { return url }
        if let url = bundle.url(forResource: "7zz", withExtension: nil, subdirectory: "Helpers") { return url }
        let candidate = bundle.bundleURL
            .appendingPathComponent("Contents/Helpers/7zz")
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }
}
