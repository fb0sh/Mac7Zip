import Foundation

/// Owns a private staging directory for one extraction and guarantees cleanup.
///
/// Extraction never writes directly to the user's destination: 7zz writes into
/// this staging area, the result is validated, and only then are items committed.
/// `defer`-style cleanup runs on success, failure and cancellation (ADR-008).
final class StagingArea {
    let url: URL
    private let fileManager: FileManager
    private var cleaned = false

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let base = fileManager.temporaryDirectory
            .appendingPathComponent("Mac7Zip-staging", isDirectory: true)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        let unique = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: unique, withIntermediateDirectories: false)
        self.url = unique
    }

    /// Deletes the staging directory. Idempotent.
    func cleanUp() {
        guard !cleaned else { return }
        cleaned = true
        try? fileManager.removeItem(at: url)
    }

    deinit {
        cleanUp()
    }

    /// Commits staged items into the destination.
    ///
    /// Per-item commit is atomic **only** when a same-volume rename succeeds;
    /// otherwise it falls back to copy-then-remove. Multi-file extraction is
    /// therefore *not* atomic as a whole (ADR-008).
    /// - Returns: number of items committed.
    @discardableResult
    func commit(to destination: URL) throws -> Int {
        let items = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: []
        )
        var committed = 0
        for item in items {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            do {
                try fileManager.moveItem(at: item, to: target)
            } catch {
                try fileManager.copyItem(at: item, to: target)
            }
            committed += 1
        }
        return committed
    }

    /// Bytes currently written into staging (independent of 7zz's percentage).
    func currentByteCount() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }
}
