import AppKit
import Foundation
import Quartz

/// Quick Look preview extension (`com.apple.quicklook.preview`).
///
/// Defensive by design: Quick Look shows "扩展在预览此文稿期间失败" if the
/// controller throws, so this never throws — it always builds a plain-text view and
/// calls the completion handler. Running the bundled helper inside the sandbox may
/// be denied; in that case it degrades to a short explanation instead of crashing.
final class PreviewProvider: NSViewController, QLPreviewingController {

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 520))
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        // Build UI on the main thread; never throw.
        let finish: (String) -> Void = { [weak self] text in
            let title = url.lastPathComponent
            let build: () -> Void = { self?.installTextView(title: title, body: text) }
            if Thread.isMainThread { build() } else { DispatchQueue.main.async(execute: build) }
            handler(nil)
        }

        if let listing = archiveListingText(for: url) {
            finish(listing)
        } else {
            finish("无法在 Quick Look 中读取该压缩包的内容（可能受系统沙盒限制）。\n请使用 Mac7Zip 打开查看。")
        }
    }

    /// Frame-based layout (no Auto Layout) — most robust inside Quick Look's host.
    private func installTextView(title: String, body: String) {
        let bounds = NSRect(x: 0, y: 0, width: 720, height: 520)
        let container = NSView(frame: bounds)

        let header = NSTextField(labelWithString: title)
        header.frame = NSRect(x: 16, y: bounds.height - 34, width: bounds.width - 32, height: 22)
        header.font = .boldSystemFont(ofSize: 15)
        header.lineBreakMode = .byTruncatingMiddle
        container.addSubview(header)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 44))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
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

    // MARK: - Listing

    private func archiveListingText(for url: URL) -> String? {
        guard let helper = helperURL(),
              let output = runSevenZip(helper: helper, arguments: ["l", "-slt", "-sccUTF-8", url.path]) else {
            return nil
        }
        var lines: [String] = []
        var path: String?
        var size = ""
        var folder = false
        func flush() {
            guard let p = path, !p.isEmpty else { path = nil; return }
            let suffix = folder ? "/" : ""
            let sizeText = size.isEmpty ? "" : "    \(size) B"
            lines.append("\(p)\(suffix)\(sizeText)")
            path = nil; size = ""; folder = false
        }
        for raw in output.split(separator: "\n") {
            let line = String(raw)
            if line.hasPrefix("Path = ") { flush(); path = String(line.dropFirst("Path = ".count)) }
            else if line.hasPrefix("Size = ") { size = String(line.dropFirst("Size = ".count)) }
            else if line.hasPrefix("Folder = +") { folder = true }
        }
        flush()
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func helperURL() -> URL? {
        // Extension bundle → .../Mac7ZipPreview.appex ; app is three levels up.
        let app = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidate = app.appendingPathComponent("Contents/Helpers/7zz")
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }

    private func runSevenZip(helper: URL, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = helper
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        env["LC_ALL"] = "en_US.UTF-8"
        process.environment = env
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        _ = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}
