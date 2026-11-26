import AppKit
import Foundation
import Quartz
import UniformTypeIdentifiers

/// Quick Look preview extension (`com.apple.quicklook.preview`).
/// Data-based preview: returns an HTML table via `QLPreviewReply`. Apple requires
/// the principal class to subclass `QLPreviewProvider` (not `NSViewController`)
/// and the Info.plist to set `QLIsDataBasedPreview`, otherwise Quick Look rejects
/// it with "Principal object for extension invalid".
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest,
                        completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let url = request.fileURL
        let entries = LibArchiveReader.listEntries(at: url) ?? []

        let sizeFormatter = ByteCountFormatter()
        let files = entries.filter { !$0.isDirectory }.count
        let folders = entries.count - files
        let total = entries.filter { !$0.isDirectory }.reduce(Int64(0)) { $0 + max(0, $1.size) }
        let summary = entries.isEmpty
            ? "无法读取内容，请在 Mac7Zip 中打开查看。"
            : "\(entries.count) 项（\(folders) 文件夹 · \(files) 文件）  解压后约 \(sizeFormatter.string(fromByteCount: total))"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        // Cap the rows so a huge archive cannot stall Quick Look on rendering.
        let shown = Array(entries.prefix(1000))
        // One batch, one main-thread hop: rendering icons per row was the main cost.
        let icons = Self.renderIcons(for: shown)
        let items = shown.map { entry in
            PreviewHTMLBuilder.Item(
                path: entry.path,
                sizeText: entry.isDirectory ? "--" : sizeFormatter.string(fromByteCount: entry.size),
                dateText: entry.modified.map { dateFormatter.string(from: $0) } ?? "",
                isDirectory: entry.isDirectory,
                kindText: Self.kindText(forPath: entry.path, isDirectory: entry.isDirectory),
                iconDataURL: icons[Self.iconKey(forPath: entry.path, isDirectory: entry.isDirectory)] ?? nil
            )
        }
        let html = PreviewHTMLBuilder.html(title: url.lastPathComponent, items: items, summary: summary)
        let data = Data(html.utf8)

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: NSSize(width: 800, height: 600)) { _ in
            data
        }
        reply.title = url.lastPathComponent
        handler(reply, nil)
    }

    /// Finder's "Kind" text for an entry, derived from its UTType so a `.xlsx`
    /// reads "XLSX document" and a `.pdf` "PDF document". Folder and unknown-type
    /// labels come from the system too, so the column stays consistent.
    private static func kindText(forPath path: String, isDirectory: Bool) -> String {
        let key = iconKey(forPath: path, isDirectory: isDirectory)
        let cached = kindCache.get(key)
        if cached.found { return cached.value ?? "" }

        let text: String
        if isDirectory {
            text = UTType.folder.localizedDescription ?? "Folder"
        } else if !key.isEmpty, let type = UTType(filenameExtension: key) {
            text = type.localizedDescription ?? key.uppercased() + " document"
        } else {
            text = UTType.data.localizedDescription ?? "Document"
        }
        kindCache.set(text, for: key)
        return text
    }

    /// Renders the icons for a whole listing in one main-thread hop.
    ///
    /// Doing this per row would mean up to a thousand synchronous hops to the main
    /// thread, each drawing an `NSImage`; a large archive then blocks Quick Look for
    /// seconds. AppKit drawing is not thread-safe, so the whole batch runs there.
    /// Returns extension -> data URL.
    private static func renderIcons(for entries: [LibArchiveReader.Entry]) -> [String: String?] {
        var needed: [String] = []
        var seen: Set<String> = []
        for entry in entries {
            let key = iconKey(forPath: entry.path, isDirectory: entry.isDirectory)
            if seen.insert(key).inserted { needed.append(key) }
        }

        var missing: [String] = []
        for key in needed where !iconCache.get(key).found { missing.append(key) }
        guard !missing.isEmpty else {
            return resolved(keys: needed)
        }

        let rendered = onMain { () -> [String: String?] in
            var result: [String: String?] = [:]
            for key in missing {
                // "" is the folder key; an extension-less file maps to public.data.
                let uti = key.isEmpty ? "public.folder" : "public.\(key)"
                let icon = NSWorkspace.shared.icon(forFileType: uti)
                result[key] = pngDataURL(from: icon)
            }
            return result
        }
        for (key, value) in rendered { iconCache.set(value, for: key) }
        return resolved(keys: needed)
    }

    private static func resolved(keys: [String]) -> [String: String?] {
        var result: [String: String?] = [:]
        for key in keys { result[key] = iconCache.get(key).value }
        return result
    }

    /// Cache key for an entry's icon: the lowercase extension, or "" for folders.
    private static func iconKey(forPath path: String, isDirectory: Bool) -> String {
        isDirectory ? "" : (path as NSString).pathExtension.lowercased()
    }

    private static func onMain<T>(_ body: () -> T) -> T {
        Thread.isMainThread ? body() : DispatchQueue.main.sync(execute: body)
    }

    /// 16px raster, matching the 16px CSS box. Drawing larger only inflates the
    /// base64 payload; Quick Look scales the element to 16 CSS pixels.
    private static func pngDataURL(from icon: NSImage) -> String? {
        let side: CGFloat = 16
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = NSSize(width: side, height: side)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        icon.draw(
            in: NSRect(x: 0, y: 0, width: side, height: side),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return "data:image/png;base64,\(png.base64EncodedString())"
    }

    /// Extension -> icon data URL. `.some(nil)` means "resolved, no icon".
    private static let iconCache = ValueCache()
    /// Extension -> Finder kind text. UTType lookups are not free either.
    private static let kindCache = ValueCache()

    /// Small thread-safe cache from extension -> optional string value.
    /// Recording a resolved-but-empty entry matters, so a missing icon is not
    /// re-rendered on every lookup.
    private final class ValueCache: @unchecked Sendable {
        private var storage: [String: String?] = [:]
        private let lock = NSLock()

        func get(_ key: String) -> (found: Bool, value: String?) {
            lock.lock(); defer { lock.unlock() }
            if let entry = storage[key] { return (true, entry) }
            return (false, nil)
        }

        func set(_ value: String?, for key: String) {
            lock.lock(); defer { lock.unlock() }
            storage[key] = .some(value)
        }
    }
}
