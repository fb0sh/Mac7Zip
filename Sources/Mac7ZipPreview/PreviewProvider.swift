import AppKit
import Foundation
import Quartz

/// Quick Look preview extension (`com.apple.quicklook.preview`).
///
/// IMPORTANT: this runs **sandboxed**, and launching a subprocess (7zz) here throws
/// an ObjC exception that crashes the extension ("扩展在预览此文稿期间失败"). So we
/// never spawn a process: ZIP contents are read with a pure-Swift central-directory
/// parser. Other formats show a short note.
final class PreviewProvider: NSViewController, QLPreviewingController {

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 520))
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let body = previewBody(for: url)
        install(title: url.lastPathComponent, body: body)
        handler(nil)
    }

    private func previewBody(for url: URL) -> String {
        if let entries = LibArchiveReader.listEntries(at: url), !entries.isEmpty {
            do {
                let files = entries.filter { !$0.isDirectory }.count
                let folders = entries.count - files
                var lines = ["\(entries.count) 个项目（\(folders) 文件夹 · \(files) 文件）", ""]
                for entry in entries.prefix(500) {
                    let suffix = entry.isDirectory ? "/" : ""
                    lines.append("\(entry.path)\(suffix)")
                }
                if entries.count > 500 { lines.append("… 仅显示前 500 项") }
                return lines.joined(separator: "\n")
            }
        }
        return "请在 Mac7Zip 中打开以查看内容。"
    }

    private func install(title: String, body: String) {
        let bounds = NSRect(x: 0, y: 0, width: 720, height: 520)
        let container = NSView(frame: bounds)

        let header = NSTextField(labelWithString: title)
        header.frame = NSRect(x: 16, y: bounds.height - 34, width: bounds.width - 32, height: 22)
        header.font = .boldSystemFont(ofSize: 15)
        header.lineBreakMode = .byTruncatingMiddle
        container.addSubview(header)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 44))
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 44))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = body
        textView.textContainerInset = NSSize(width: 12, height: 10)
        scroll.documentView = textView
        container.addSubview(scroll)
        view = container
    }
}
