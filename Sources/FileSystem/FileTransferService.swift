import Foundation

/// A single copy/move/duplicate request.
struct FileTransferRequest: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case copy
        case move
        case duplicate
    }

    var kind: Kind
    var sources: [URL]
    var destinationDirectory: URL
    /// Applied per conflicting item.
    var conflictPolicy: ConflictPolicy
    /// When true, symlinks are copied as links rather than followed.
    var preserveSymlinks: Bool

    init(
        kind: Kind,
        sources: [URL],
        destinationDirectory: URL,
        conflictPolicy: ConflictPolicy = .ask,
        preserveSymlinks: Bool = true
    ) {
        self.kind = kind
        self.sources = sources
        self.destinationDirectory = destinationDirectory
        self.conflictPolicy = conflictPolicy
        self.preserveSymlinks = preserveSymlinks
    }
}

/// Outcome for one source item, so partial batches are reported honestly.
struct FileTransferOutcome: Sendable, Equatable {
    enum Status: Sendable, Equatable {
        case copied
        case moved
        case duplicated
        case skipped
        case failed(String)
    }

    let source: URL
    let destination: URL?
    let status: Status
}

/// Recursive copy/move with explicit per-item outcomes.
///
/// Design notes (SPEC-FO):
/// - Same-volume moves use an atomic rename; cross-volume moves copy, verify size,
///   then remove the source (never the other way round).
/// - A failed item never aborts the whole batch; every item produces an outcome.
/// - Symlinks are preserved by default (copied as links) rather than followed.
struct FileTransferService: Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func perform(_ request: FileTransferRequest) async throws -> [FileTransferOutcome] {
        try await Task.detached(priority: .userInitiated) {
            try Self.performSynchronously(request, fileManager: FileManager())
        }.value
    }

    // MARK: - Synchronous core (unit-testable)

    static func performSynchronously(
        _ request: FileTransferRequest,
        fileManager: FileManager
    ) throws -> [FileTransferOutcome] {
        guard !request.sources.isEmpty else { return [] }
        try fileManager.createDirectory(at: request.destinationDirectory, withIntermediateDirectories: true)

        var outcomes: [FileTransferOutcome] = []
        for source in request.sources {
            let desired = request.destinationDirectory.appendingPathComponent(source.lastPathComponent)
            let resolved = resolve(desired: desired, policy: request.conflictPolicy, fileManager: fileManager)
            guard let target = resolved else {
                outcomes.append(FileTransferOutcome(source: source, destination: nil, status: .skipped))
                continue
            }

            do {
                switch request.kind {
                case .copy, .duplicate:
                    try copyItem(at: source, to: target, preserveSymlinks: request.preserveSymlinks, fileManager: fileManager)
                    outcomes.append(FileTransferOutcome(source: source, destination: target, status: request.kind == .duplicate ? .duplicated : .copied))
                case .move:
                    try moveItem(at: source, to: target, preserveSymlinks: request.preserveSymlinks, fileManager: fileManager)
                    outcomes.append(FileTransferOutcome(source: source, destination: target, status: .moved))
                }
            } catch {
                outcomes.append(FileTransferOutcome(source: source, destination: target, status: .failed(error.localizedDescription)))
            }
        }
        return outcomes
    }

    static func resolve(desired: URL, policy: ConflictPolicy, fileManager: FileManager) -> URL? {
        guard fileManager.fileExists(atPath: desired.path) else { return desired }
        switch policy {
        case .ask, .replace:
            return desired
        case .skip:
            return nil
        case .keepBoth:
            return uniqueSibling(of: desired, fileManager: fileManager)
        }
    }

    static func uniqueSibling(of url: URL, fileManager: FileManager) -> URL {
        let directory = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let name = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            let candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    // MARK: - Item operations

    static func copyItem(at source: URL, to destination: URL, preserveSymlinks: Bool, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        if preserveSymlinks, isSymlink(source) {
            let linkTarget = try fileManager.destinationOfSymbolicLink(atPath: source.path)
            try fileManager.createSymbolicLink(atPath: destination.path, withDestinationPath: linkTarget)
            return
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    /// Same volume → atomic rename. Cross volume → copy, verify, then delete.
    static func moveItem(at source: URL, to destination: URL, preserveSymlinks: Bool, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        do {
            try fileManager.moveItem(at: source, to: destination)
            return
        } catch {
            // Fall through to the copy+verify+delete path (e.g. cross-volume).
        }
        try copyItem(at: source, to: destination, preserveSymlinks: preserveSymlinks, fileManager: fileManager)
        guard sizesMatch(source: source, destination: destination, fileManager: fileManager) else {
            try? fileManager.removeItem(at: destination)
            throw FileError.operationFailed("Copy verification failed for “\(source.lastPathComponent)”.")
        }
        try fileManager.removeItem(at: source)
    }

    static func sizesMatch(source: URL, destination: URL, fileManager: FileManager) -> Bool {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey]
        guard let sourceValues = try? source.resourceValues(forKeys: keys) else { return false }
        if sourceValues.isSymbolicLink == true { return true }
        if sourceValues.isDirectory == true {
            // Directory sizes are not comparable; existence is enough here.
            return fileManager.fileExists(atPath: destination.path)
        }
        guard let destinationValues = try? destination.resourceValues(forKeys: keys) else { return false }
        return sourceValues.fileSize == destinationValues.fileSize
    }

    static func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    }
}
