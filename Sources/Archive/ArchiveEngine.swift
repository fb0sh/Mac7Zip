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

    /// Detection from the file name alone. Fast, but wrong for renamed files and
    /// for the many archives that ship without a recognisable extension.
    static func detectFromName(_ url: URL) -> ArchiveFormat? {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") { return .gzip }
        switch url.pathExtension.lowercased() {
        case "7z": return .sevenZip
        case "zip", "jar", "xpi", "apk", "epub", "docx", "xlsx", "pptx", "odt": return .zip
        case "tar": return .tar
        case "gz", "gzip": return .gzip
        case "bz2", "bzip2", "tbz2": return .bzip2
        case "xz", "txz": return .xz
        case "rar": return .rar
        default: return nil
        }
    }

    /// Detection by file content alone.
    ///
    /// The extension is deliberately ignored: the same bytes arrive with any name,
    /// and a renamed or extensionless archive must still open. `detectFromName` is
    /// kept only for callers that have no file to read.
    static func detect(from url: URL) -> ArchiveFormat? {
        detectFromMagicBytes(at: url)
    }

    /// Sniffs the leading bytes. Reads at most `magicByteCount` bytes, so it is
    /// safe to call on arbitrary files.
    static func detectFromMagicBytes(at url: URL) -> ArchiveFormat? {
        // Opening a directory succeeds on macOS but reading from it fails, and a
        // folder is never an archive.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return nil }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: magicByteCount), !head.isEmpty else { return nil }
        return format(forMagic: head)
    }

    /// Enough for every signature below, including the tar checksum probe.
    static let magicByteCount = 512

    /// Pure signature match over the leading bytes.
    static func format(forMagic bytes: Data) -> ArchiveFormat? {
        func has(_ signature: [UInt8], at offset: Int = 0) -> Bool {
            guard bytes.count >= offset + signature.count else { return false }
            return Array(bytes[offset..<(offset + signature.count)]) == signature
        }
        func hasASCII(_ signature: String, at offset: Int = 0) -> Bool {
            has(Array(signature.utf8), at: offset)
        }

        // 7z: "7z¼¯'×" + version bytes.
        if has([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) { return .sevenZip }
        // ZIP (also jar/docx/xlsx/apk): local header, empty archive, or spanned.
        if has([0x50, 0x4B, 0x03, 0x04]) || has([0x50, 0x4B, 0x05, 0x06]) || has([0x50, 0x4B, 0x07, 0x08]) {
            return .zip
        }
        // RAR 4.x ("Rar!") and RAR 5.x ("Rar!").
        if has([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]) { return .rar }
        // gzip.
        if has([0x1F, 0x8B]) { return .gzip }
        // bzip2: "BZh" + level digit.
        if hasASCII("BZh") { return .bzip2 }
        // xz: FD 37 7A 58 5A 00.
        if has([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) { return .xz }
        // tar: "ustar" at offset 257 (GNU/POSIX). Old-style tar has no magic, so
        // fall back to the checksum rule below.
        if hasASCII("ustar", at: 257) { return .tar }
        if looksLikeTar(bytes) { return .tar }

        return nil
    }

    /// Classic tar heuristic: the 512-byte header carries an octal checksum that
    /// matches the sum of its own bytes with the checksum field treated as spaces.
    private static func looksLikeTar(_ header: Data) -> Bool {
        let bytes = [UInt8](header)
        guard bytes.count >= 512 else { return false }
        // Names are not NUL-padded everywhere, but the header must start with
        // something printable and end in NULs.
        guard bytes[0] != 0 else { return false }

        // The field is octal ASCII, conventionally "%06o\0 " but some writers use
        // spaces; stop at the first NUL or space.
        var octal = ""
        for byte in bytes[148..<156] {
            if byte == 0 || byte == 0x20 { break }
            // 0x30…0x37 are the ASCII digits 0–7.
            guard byte >= 0x30, byte <= 0x37 else { return false }
            octal.append(Character(UnicodeScalar(byte)))
        }
        guard !octal.isEmpty, let stored = Int(octal, radix: 8) else { return false }

        var sum = 0
        for (index, byte) in bytes[0..<512].enumerated() {
            sum += (148..<156).contains(index) ? 0x20 : Int(byte)
        }
        return sum == stored
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

    /// 7zz `-ao` value. 7-Zip only accepts `a|s|t|u`: there is no `o`, so
    /// "overwrite" means "overwrite all" (`a`) with prompts disabled by `-y`.
    var switchValue: String {
        switch self {
        case .ask: return "a"
        case .overwrite: return "a"
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
            // No password supplied for an encrypted archive. 7-Zip exits 2 and asks
            // for one; with `-y` it aborts instead of prompting.
            if lower.contains("enter password") || lower.contains("password required") {
                return .passwordRequired
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

    /// Progress-aware variants. `progress` receives (0…1, currentItem).
    func extract(
        archive: URL, to destination: URL, options: ExtractOptions,
        progress: (@Sendable (Double, String?) -> Void)?
    ) async throws
    func createArchive(
        at destination: URL, from sources: [URL], options: ArchiveOptions,
        progress: (@Sendable (Double, String?) -> Void)?
    ) async throws
}

extension ArchiveEngine {
    func extract(
        archive: URL, to destination: URL, options: ExtractOptions,
        progress: (@Sendable (Double, String?) -> Void)?
    ) async throws {
        try await extract(archive: archive, to: destination, options: options)
    }

    func createArchive(
        at destination: URL, from sources: [URL], options: ArchiveOptions,
        progress: (@Sendable (Double, String?) -> Void)?
    ) async throws {
        try await createArchive(at: destination, from: sources, options: options)
    }
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
