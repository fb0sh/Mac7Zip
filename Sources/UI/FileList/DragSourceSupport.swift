import AppKit
import Foundation

/// Extracts a single archive entry for an `NSFilePromiseProvider` drop.
///
/// `NSFilePromiseProvider` callbacks are synchronous, so we must not block the main
/// thread on the extraction (that froze the UI and showed no progress). Instead the
/// work runs on a background queue and we pump the run loop while waiting, which
/// keeps the app responsive and lets progress/UI updates render.
final class ArchiveEntryExporter: NSObject {
    private let archiveURL: URL
    private let entryPath: String
    private let isDirectory: Bool
    private let engineFactory: () -> ArchiveEngine?

    init(archiveURL: URL, entryPath: String, isDirectory: Bool = false, engineFactory: @escaping () -> ArchiveEngine?) {
        self.archiveURL = archiveURL
        self.entryPath = entryPath
        self.isDirectory = isDirectory
        self.engineFactory = engineFactory
    }

    func export(to destination: URL) -> Bool {
        guard let engine = engineFactory() else { return false }

        let box = ResultBox()
        let finished = DispatchSemaphore(value: 0)
        let archiveURL = self.archiveURL
        let entryPath = self.entryPath
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7Zip-promise-\(UUID().uuidString)", isDirectory: true)

        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                try? FileManager.default.removeItem(at: tempDir)
                finished.signal()
            }
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                var options = ExtractOptions(destination: tempDir)
                options.entries = [entryPath]
                options.password = nil

                let done = DispatchSemaphore(value: 0)
                Task.detached {
                    defer { done.signal() }
                    do {
                        try await engine.extract(archive: archiveURL, to: tempDir, options: options)
                        let name = DragExportPlanner.producedFileName(entryPath: entryPath)
                        var produced = tempDir.appendingPathComponent(name)
                        if !FileManager.default.fileExists(atPath: produced.path),
                           let found = Self.findItem(named: name, under: tempDir) {
                            produced = found
                        }
                        guard FileManager.default.fileExists(atPath: produced.path) else { return }
                        if FileManager.default.fileExists(atPath: destination.path) {
                            try? FileManager.default.removeItem(at: destination)
                        }
                        try FileManager.default.copyItem(at: produced, to: destination)
                        box.value = true
                    } catch {
                        box.value = false
                    }
                }
                done.wait()
            } catch {
                box.value = false
            }
        }

        // Pump the run loop instead of hard-blocking so the UI stays responsive
        // (spinning cursor rather than a beachball) and progress can render.
        let deadline = Date().addingTimeInterval(180)
        while finished.wait(timeout: .now()) == .timedOut {
            if Date() > deadline { break }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        return box.value
    }

    private static func findItem(named name: String, under root: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == name { return url }
        }
        return nil
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
