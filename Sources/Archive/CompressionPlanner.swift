import Foundation

/// A validated request to create an archive.
struct CompressionRequest: Sendable, Equatable {
    var sources: [URL]
    var destination: URL
    var format: ArchiveFormat
    var level: Int
    var method: String?
    var password: String?
    var encryptFileNames: Bool

    init(
        sources: [URL],
        destination: URL,
        format: ArchiveFormat = .sevenZip,
        level: Int = 5,
        method: String? = nil,
        password: String? = nil,
        encryptFileNames: Bool = false
    ) {
        self.sources = sources
        self.destination = destination
        self.format = format
        self.level = level
        self.method = method
        self.password = password
        self.encryptFileNames = encryptFileNames
    }
}

/// Pure validation + argv mapping for archive creation. Kept free of process and
/// UI concerns so every rule is unit-testable.
enum CompressionPlanner {

    enum ValidationError: Error, Equatable {
        case noSources
        case unsupportedFormat(String)
        case destinationNotWritable(String)
        case destinationIsDirectory(String)
        case archiveInsideSource(String)
        case invalidLevel(Int)
        case encryptFileNamesRequires7z
        case passwordUnavailable
    }

    /// Formats Mac7Zip can create today (RAR is impossible under the unRAR license).
    static let creatableFormats: [ArchiveFormat] = [.sevenZip, .zip]

    /// Validates a request against the filesystem.
    static func validate(_ request: CompressionRequest, passwordTransportAvailable: Bool = false) -> [ValidationError] {
        var errors: [ValidationError] = []

        if request.sources.isEmpty {
            errors.append(.noSources)
        }
        if !creatableFormats.contains(request.format) {
            errors.append(.unsupportedFormat(request.format.displayName))
        }
        if !(0...9).contains(request.level) {
            errors.append(.invalidLevel(request.level))
        }
        if request.encryptFileNames && request.format != .sevenZip {
            errors.append(.encryptFileNamesRequires7z)
        }
        if request.password != nil && !passwordTransportAvailable {
            errors.append(.passwordUnavailable)
        }

        let destination = request.destination.standardizedFileURL
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            errors.append(.destinationIsDirectory(destination.lastPathComponent))
        }

        let parent = destination.deletingLastPathComponent()
        if !FileManager.default.isWritableFile(atPath: parent.path) {
            errors.append(.destinationNotWritable(parent.lastPathComponent))
        }

        // Refuse to create an archive inside one of its own sources.
        for source in request.sources {
            let sourcePath = source.standardizedFileURL.path
            if destination.path == sourcePath || destination.path.hasPrefix(sourcePath + "/") {
                errors.append(.archiveInsideSource(source.lastPathComponent))
                break
            }
        }

        return errors
    }

    /// Maps a validated request to 7zz arguments (password excluded by policy).
    static func arguments(for request: CompressionRequest) -> [String] {
        var args = [
            "a",
            "-t\(request.format.switchValue)",
            "-mx\(max(0, min(9, request.level)))",
            "-sccUTF-8",
        ]
        if let method = request.method, !method.isEmpty, request.format == .sevenZip {
            args.append("-m0=\(method)")
        }
        if request.format == .sevenZip && request.encryptFileNames {
            args.append("-mhe")
        }
        if let password = request.password {
            args.append("-p\(password)")
        }
        args.append(request.destination.standardizedFileURL.path)
        args.append(contentsOf: request.sources.map { $0.standardizedFileURL.path })
        return args
    }

    /// Default archive name for a selection: single item → its name; many → "Archive".
    static func suggestedArchiveName(for sources: [URL], format: ArchiveFormat) -> String {
        let base: String
        if sources.count == 1, let first = sources.first {
            let name = first.deletingPathExtension().lastPathComponent
            base = name.isEmpty ? "Archive" : name
        } else {
            base = "Archive"
        }
        return "\(base).\(format.rawValue)"
    }

    /// "photo.jpg" → "photo (2).jpg"; used by the Keep Both conflict choice.
    static func uniqueDestination(for url: URL) -> URL {
        let directory = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let candidateName = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    /// Resolves a target conflict according to the chosen policy.
    /// - Returns: the URL to write to, or `nil` when the operation should be skipped.
    static func resolveConflict(at destination: URL, policy: ConflictPolicy) -> URL? {
        guard FileManager.default.fileExists(atPath: destination.path) else { return destination }
        switch policy {
        case .ask, .replace:
            return destination
        case .skip:
            return nil
        case .keepBoth:
            return uniqueDestination(for: destination)
        }
    }
}
