import Foundation

/// Typed file-operation errors surfaced to the UI. Maps raw filesystem errors to a
/// small, user-facing vocabulary.
enum FileError: Error, Equatable {
    case accessDenied(String)
    case notFound(String)
    case alreadyExists(String)
    case invalidName(String)
    case operationFailed(String)
    case cancelled
}

/// Conflict policy for future copy/move (M4). Defined now so call sites and the
/// operation service share one vocabulary.
enum ConflictPolicy: Sendable {
    case ask
    case replace
    case skip
    case keepBoth
}

/// Single seam for file mutations (create/rename/trash-delete; copy/move added in M4).
protocol FileOperating: Sendable {
    func createFolder(named name: String, in directory: URL) async throws -> URL
    func rename(_ url: URL, to newName: String) async throws -> URL
    func moveToTrash(_ url: URL) async throws
}

/// `FileManager`-backed implementation. Runs off the main thread and returns typed
/// `FileError` values. No UI dependencies.
struct FileOperationsService: FileOperating {
    func createFolder(named name: String, in directory: URL) async throws -> URL {
        try Self.validate(name: name)
        let target = directory.appendingPathComponent(name, isDirectory: true)
        return try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: target.path) {
                throw FileError.alreadyExists(target.lastPathComponent)
            }
            do {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: false)
            } catch {
                throw Self.map(error, url: target)
            }
            return target
        }.value
    }

    func rename(_ url: URL, to newName: String) async throws -> URL {
        try Self.validate(name: newName)
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        return try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else {
                throw FileError.notFound(url.lastPathComponent)
            }
            if fileManager.fileExists(atPath: destination.path) {
                throw FileError.alreadyExists(newName)
            }
            do {
                try fileManager.moveItem(at: url, to: destination)
            } catch {
                throw Self.map(error, url: url)
            }
            return destination
        }.value
    }

    func moveToTrash(_ url: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else {
                throw FileError.notFound(url.lastPathComponent)
            }
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            } catch {
                throw Self.map(error, url: url)
            }
        }.value
    }

    // MARK: - Helpers

    static func validate(name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "." || trimmed == ".." || trimmed.contains("/") {
            throw FileError.invalidName(name)
        }
    }

    static func map(_ error: Error, url: URL) -> FileError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileWriteFileExistsError:
                return .alreadyExists(url.lastPathComponent)
            case NSFileReadNoSuchFileError:
                return .notFound(url.lastPathComponent)
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return .accessDenied(url.path)
            default:
                break
            }
        }
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case 13, 1: // EACCES, EPERM
                return .accessDenied(url.path)
            case 2: // ENOENT
                return .notFound(url.lastPathComponent)
            default:
                break
            }
        }
        return .operationFailed(nsError.localizedDescription)
    }
}
