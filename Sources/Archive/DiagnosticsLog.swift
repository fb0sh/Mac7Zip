import Foundation

/// Tiny append-only diagnostic log at ~/Library/Logs/Mac7Zip.log. Used to confirm
/// behaviours that are hard to observe otherwise (e.g. ZIP name repair).
enum DiagnosticsLog {
    static func write(_ message: String) {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs", isDirectory: true) else { return }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Mac7Zip.log")
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}
