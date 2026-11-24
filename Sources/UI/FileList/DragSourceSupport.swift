import AppKit
import Foundation

/// Extracts a single archive entry for an `NSFilePromiseProvider` drop.
///
/// The extraction runs on a **detached** task (never the main actor) so blocking
/// the promise callback on a semaphore cannot deadlock the main thread. The entry
/// is extracted into a private temp dir, then the produced file is copied to the
/// exact URL Finder requested (handles nested entry paths correctly).
final class ArchiveEntryExporter: NSObject {
    private let archiveURL: URL
    private let entryPath: String
    private let engineFactory: () -> ArchiveEngine?

    init(archiveURL: URL, entryPath: String, engineFactory: @escaping () -> ArchiveEngine?) {
        self.archiveURL = archiveURL
        self.entryPath = entryPath
        self.engineFactory = engineFactory
    }

    func export(to destination: URL) -> Bool {
        guard let engine = engineFactory() else { return false }

        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox()
        let archiveURL = self.archiveURL
        let entryPath = self.entryPath
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7Zip-promise-\(UUID().uuidString)", isDirectory: true)

        Task.detached {
            defer {
                try? FileManager.default.removeItem(at: tempDir)
                semaphore.signal()
            }
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                var options = ExtractOptions(destination: tempDir)
                options.entries = [entryPath]
                options.password = nil
                try await engine.extract(archive: archiveURL, to: tempDir, options: options)

                let name = DragExportPlanner.producedFileName(entryPath: entryPath)
                let produced = tempDir.appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: produced.path) else {
                    box.value = false
                    return
                }
                if FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: produced, to: destination)
                box.value = true
            } catch {
                box.value = false
            }
        }

        _ = semaphore.wait(timeout: .now() + 120)
        return box.value
    }
}

/// Tiny thread-safe box for the export result.
final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false
    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); storage = newValue; lock.unlock() }
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
