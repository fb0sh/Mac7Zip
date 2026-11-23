import AppKit
import Foundation

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Extracts a single archive entry to a destination URL, synchronously, for use by
/// `NSFilePromiseProvider` delegates (which are called on the main thread).
final class ArchiveEntryExporter: NSObject {
    private let archiveURL: URL
    private let entryPath: String
    private let engineFactory: () -> ArchiveEngine?

    init(archiveURL: URL, entryPath: String, engineFactory: @escaping () -> ArchiveEngine?) {
        self.archiveURL = archiveURL
        self.entryPath = entryPath
        self.engineFactory = engineFactory
    }

    /// Performs the export. Returns `false` when the engine is unavailable.
    func export(to destination: URL) -> Bool {
        guard let engine = engineFactory() else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        var succeeded = false

        Task {
            defer { semaphore.signal() }
            do {
                var options = ExtractOptions(destination: destination)
                options.password = nil
                options.entries = [entryPath]
                // Extract into the destination's parent so the promised file lands
                // exactly where Finder asked; the engine appends the entry name.
                let parent = destination.deletingLastPathComponent()
                try await engine.extract(archive: archiveURL, to: parent, options: {
                    var adjusted = options
                    adjusted.destination = parent
                    adjusted.pathMode = .relative
                    return adjusted
                }())
                succeeded = FileManager.default.fileExists(atPath: destination.path)
            } catch {
                succeeded = false
            }
        }

        // Promise delegates must be synchronous; bound the wait so a pathological
        // archive can't hang the drag session forever.
        _ = semaphore.wait(timeout: .now() + 60)
        return succeeded
    }
}

/// `NSFilePromiseProvider` delegate that materialises archive entries on drop.
final class ArchivePromiseDelegate: NSObject, NSFilePromiseProviderDelegate {
    private let exporter: ArchiveEntryExporter

    init(exporter: ArchiveEntryExporter) {
        self.exporter = exporter
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        (filePromiseProvider.userInfo as? String) ?? "Exported"
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        if exporter.export(to: url) {
            completionHandler(nil)
        } else {
            completionHandler(FileError.operationFailed("Couldn’t export the archive entry."))
        }
    }
}

/// Keeps promise delegates alive for the duration of a drag session.
@MainActor
final class DragDelegateStore {
    static let shared = DragDelegateStore()
    private var delegates: [ObjectIdentifier: ArchivePromiseDelegate] = [:]

    func retain(_ delegate: ArchivePromiseDelegate, for identifier: ObjectIdentifier) {
        delegates[identifier] = delegate
    }

    func release(_ identifier: ObjectIdentifier) {
        delegates.removeValue(forKey: identifier)
    }
}
