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

        let items = entries.prefix(1000).map { entry in
            PreviewHTMLBuilder.Item(
                path: entry.path,
                sizeText: entry.isDirectory ? "--" : sizeFormatter.string(fromByteCount: entry.size),
                dateText: entry.modified.map { dateFormatter.string(from: $0) } ?? "",
                isDirectory: entry.isDirectory,
                kindText: Self.kindText(forPath: entry.path, isDirectory: entry.isDirectory),
                iconDataURL: Self.iconDataURL(forPath: entry.path, isDirectory: entry.isDirectory)
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
        if isDirectory {
            return UTType.folder.localizedDescription ?? "Folder"
        }
        let ext = (path as NSString).pathExtension.lowercased()
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else {
            return UTType.data.localizedDescription ?? "Document"
        }
        return type.localizedDescription ?? ext.uppercased() + " document"
    }

    /// The system's icon for the entry's type, as a base64 PNG data URL.
    ///
    /// Uses `NSWorkspace` (the same source Finder uses) so a `.jar` shows the Java
    /// icon and a `.db` its database icon. Resolved on the main thread because
    /// AppKit drawing is not thread-safe there, which also serialises the cache.
    private static func iconDataURL(forPath path: String, isDirectory: Bool) -> String? {
        let ext = isDirectory ? "" : (path as NSString).pathExtension.lowercased()
        let cached = iconCache.get(ext)
        if cached.found { return cached.value }

        let dataURL = onMain {
            let icon = isDirectory
                ? NSWorkspace.shared.icon(forFileType: "public.folder")
                : NSWorkspace.shared.icon(forFileType: ext.isEmpty ? "public.data" : "public.\(ext)")
            return pngDataURL(from: icon)
        }
        iconCache.set(dataURL, for: ext)
        return dataURL
    }

    private static func onMain<T>(_ body: () -> T) -> T {
        Thread.isMainThread ? body() : DispatchQueue.main.sync(execute: body)
    }

    /// 16pt raster. Quick Look renders the table at 1x–2x, and a 32px raster
    /// keeps it crisp without bloating the HTML.
    private static func pngDataURL(from icon: NSImage) -> String? {
        let side: CGFloat = 32
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = NSSize(width: side, height: side)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return "data:image/png;base64,\(png.base64EncodedString())"
    }

    /// Extension -> icon data URL. `.some(nil)` means "resolved, no icon".
    private static let iconCache = IconCache()

    private final class IconCache: @unchecked Sendable {
        private var storage: [String: String?] = [:]
        private let lock = NSLock()

        /// Total lookup; returns whether the key was resolved and its value.
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
