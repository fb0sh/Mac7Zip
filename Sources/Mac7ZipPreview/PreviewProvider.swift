import AppKit
import Foundation
import Quartz

/// Quick Look **preview** extension (`com.apple.quicklook.preview`): shows an
/// archive's contents list when the user presses Space in Finder.
///
/// The principal class must be an `NSViewController` conforming to
/// `QLPreviewingController`.
final class PreviewProvider: NSViewController, QLPreviewingController {

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let text = archiveListingText(for: url) ?? "无法读取该压缩包内容。"
        let title = url.lastPathComponent

        let header = NSTextField(labelWithString: title)
        header.font = .boldSystemFont(ofSize: 15)
        header.lineBreakMode = .byTruncatingMiddle
        header.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = text
        textView.textContainerInset = NSSize(width: 12, height: 10)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = textView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(header)
        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container
        handler(nil)
    }

    // MARK: - Archive listing

    private func archiveListingText(for url: URL) -> String? {
        guard let helper = helperURL(),
              let output = runSevenZip(helper: helper, arguments: ["l", "-slt", "-sccUTF-8", url.path]) else {
            return nil
        }
        var lines: [String] = []
        var currentPath: String?
        var currentSize = ""
        var isFolder = false
        func flush() {
            guard let p = currentPath, !p.isEmpty else { return }
            let suffix = isFolder ? "/" : ""
            let size = currentSize.isEmpty ? "" : "  \(currentSize) B"
            lines.append("\(p)\(suffix)\(size)")
            currentPath = nil; currentSize = ""; isFolder = false
        }
        for raw in output.split(separator: "\n") {
            let line = String(raw)
            if line.hasPrefix("Path = ") { flush(); currentPath = String(line.dropFirst("Path = ".count)) }
            else if line.hasPrefix("Size = ") { currentSize = String(line.dropFirst("Size = ".count)) }
            else if line.hasPrefix("Folder = +") { isFolder = true }
            else if line.hasPrefix("Attributes = "), line.dropFirst("Attributes = ".count).hasPrefix("D") { isFolder = true }
        }
        flush()
        if lines.isEmpty { return nil }
        return lines.joined(separator: "\n")
    }

    private func helperURL() -> URL? {
        let app = Bundle.main.bundleURL
            .deletingLastPathComponent()   // PlugIns
            .deletingLastPathComponent()   // Contents
            .deletingLastPathComponent()   // .app
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
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}
