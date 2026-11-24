import AppKit
import Foundation
import Quartz

/// Quick Look preview extension (`com.apple.quicklook.preview`).
/// Deliberately minimal UI (a single multi-line label) to avoid anything that could
/// throw inside Quick Look's host. Sandboxed — reads names via libarchive (no spawn).
final class PreviewProvider: NSViewController, QLPreviewingController {

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let text = Self.body(for: url)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 520))
        let label = NSTextField(wrappingLabelWithString: text)
        label.frame = container.bounds.insetBy(dx: 14, dy: 12)
        label.autoresizingMask = [.width, .height]
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.isSelectable = true
        container.addSubview(label)
        self.view = container

        handler(nil)
    }

    private static func body(for url: URL) -> String {
        guard let entries = LibArchiveReader.listEntries(at: url), !entries.isEmpty else {
            return "请在 Mac7Zip 中打开以查看内容。"
        }
        let files = entries.filter { !$0.isDirectory }.count
        let folders = entries.count - files
        var lines = ["\(entries.count) 项（\(folders) 文件夹 · \(files) 文件）", ""]
        for entry in entries.prefix(500) {
            lines.append("\(entry.path)\(entry.isDirectory ? "/" : "")")
        }
        if entries.count > 500 { lines.append("… 仅显示前 500 项") }
        return lines.joined(separator: "\n")
    }
}
