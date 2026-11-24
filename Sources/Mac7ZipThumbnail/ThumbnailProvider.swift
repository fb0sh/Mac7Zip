import AppKit
import Foundation
import QuickLookThumbnailing

/// Quick Look thumbnail extension: renders an archive's "cover" image (largest
/// picture inside) with the format badge, so Finder shows a content thumbnail
/// instead of a generic document icon.
///
/// Implementation note: `QLThumbnailProvider` runs sandboxed with no access to the
/// user's filesystem, so the archive is copied into the extension's own temp dir
/// and inspected with the bundled `7zz` helper (or `libarchive`-free fallback:
/// no helper → badge-only thumbnail).
final class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let url = request.fileURL
        let maxSize = request.maximumSize
        let scale = request.scale

        let reply = QLThumbnailReply(contextSize: maxSize, currentContextDrawing: { () -> Bool in
            Self.drawThumbnail(for: url, in: maxSize, scale: scale)
        })
        handler(reply, nil)
    }

    /// Draws into the current CGContext: cover image (if any) + badge + summary.
    private static func drawThumbnail(for url: URL, in size: CGSize, scale: CGFloat) -> Bool {
        guard let context = NSGraphicsContext.current?.cgContext else { return false }
        let bounds = CGRect(origin: .zero, size: size)
        let name = url.lastPathComponent

        // Page background.
        context.setFillColor(NSColor.white.cgColor)
        context.fill(bounds)

        if let cover = renderCover(for: url, targetSize: bounds.size) {
            cover.draw(in: bounds)
        } else {
            // No picture inside: draw a real content list instead of blank paper.
            let names = contentPreview(for: url)
            drawPlaceholder(in: bounds, name: name, fileNames: names)
        }

        drawBadge(in: bounds, text: badgeText(for: name))
        return true
    }

    private static func badgeText(for name: String) -> String {
        let lower = name.lowercased()
        for suffix in ["tar.gz", "tar.xz", "tar.zst", "tbz2", "tgz"] where lower.hasSuffix("." + suffix) {
            return suffix.uppercased()
        }
        let ext = (name as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "ARCHIVE" : ext
    }

    private static func drawBadge(in bounds: CGRect, text: String) {
        let font = NSFont.systemFont(ofSize: max(8, bounds.width * 0.13), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = max(3, bounds.width * 0.04)
        let badgeRect = CGRect(
            x: bounds.maxX - textSize.width - padding * 2 - bounds.width * 0.03,
            y: bounds.minY + bounds.height * 0.03,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )
        let path = NSBezierPath(roundedRect: badgeRect, xRadius: badgeRect.height * 0.28, yRadius: badgeRect.height * 0.28)
        NSColor.black.withAlphaComponent(0.78).setFill()
        path.fill()
        (text as NSString).draw(
            at: CGPoint(x: badgeRect.minX + padding, y: badgeRect.minY + padding / 2),
            withAttributes: attributes
        )
    }

    private static func drawPlaceholder(in bounds: CGRect, name: String, fileNames: [String]) {
        let inset = bounds.insetBy(dx: bounds.width * 0.10, dy: bounds.height * 0.10)
        NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
        let card = NSBezierPath(roundedRect: inset, xRadius: inset.width * 0.06, yRadius: inset.width * 0.06)
        card.fill()
        NSColor(calibratedWhite: 0.80, alpha: 1).setStroke()
        card.lineWidth = max(0.5, bounds.width * 0.008)
        card.stroke()

        guard !fileNames.isEmpty else {
            // Truly empty: draw a simple document glyph.
            NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
            let glyph = inset.insetBy(dx: inset.width * 0.30, dy: inset.height * 0.30)
            NSBezierPath(roundedRect: glyph, xRadius: glyph.width * 0.10, yRadius: glyph.width * 0.10).fill()
            return
        }

        // Content list: one row per file name (largest first), truncated to fit.
        let fontSize = max(6, bounds.width * 0.085)
        let font = NSFont.systemFont(ofSize: fontSize)
        let rowHeight = fontSize * 1.55
        var y = inset.maxY - rowHeight - inset.height * 0.06
        for fileName in fileNames {
            guard y > inset.minY + inset.height * 0.18 else { break }
            // Bullet
            NSColor(calibratedWhite: 0.62, alpha: 1).setFill()
            let bullet = CGRect(x: inset.minX + inset.width * 0.07, y: y + fontSize * 0.30,
                                width: fontSize * 0.34, height: fontSize * 0.34)
            NSBezierPath(ovalIn: bullet).fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingMiddle
            let textRect = CGRect(x: inset.minX + inset.width * 0.16, y: y,
                                  width: inset.width * 0.76, height: rowHeight)
            (fileName as NSString).draw(
                with: textRect,
                options: [.usesLineFragmentOrigin],
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor(calibratedWhite: 0.32, alpha: 1),
                    .paragraphStyle: paragraph,
                ],
                context: nil
            )
            y -= rowHeight
        }
    }

    /// Reads the archive listing and returns a few entry names for the preview.
    private static func contentPreview(for url: URL) -> [String] {
        guard let helper = helperURL(),
              let listing = runSevenZip(helper: helper, arguments: ["l", "-slt", "-sccUTF-8", url.path]) else {
            return []
        }
        var sizes: [String: Int64] = [:]
        var dirs: Set<String> = []
        var currentPath: String?
        for line in listing.split(separator: "\n") {
            let text = String(line)
            if text.hasPrefix("Path = ") {
                currentPath = String(text.dropFirst("Path = ".count))
            } else if text.hasPrefix("Size = "), let path = currentPath {
                sizes[path] = Int64(text.dropFirst("Size = ".count)) ?? 0
            } else if text.hasPrefix("Folder = +"), let path = currentPath {
                dirs.insert(path)
            } else if text.hasPrefix("Attributes = "), let path = currentPath,
                      text.dropFirst("Attributes = ".count).hasPrefix("D") {
                dirs.insert(path)
            }
        }
        let files = sizes.filter { !dirs.contains($0.key) }
        return files.sorted { $0.value > $1.value }
            .prefix(4)
            .map { (($0.key as NSString).lastPathComponent) }
    }

    /// Extracts the largest image entry and returns it as an `NSImage`.
    private static func renderCover(for url: URL, targetSize: CGSize) -> NSImage? {
        guard let helper = helperURL() else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipThumb-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        // 1. List entries (fast) to find candidate images.
        guard let listing = runSevenZip(helper: helper, arguments: ["l", "-slt", "-sccUTF-8", url.path]) else {
            return nil
        }
        let entries = parseEntries(listing)
        guard let best = bestImage(entries) else { return nil }

        // 2. Extract just that entry.
        guard runSevenZip(helper: helper, arguments: [
            "x", "-sccUTF-8", "-y", url.path, best, "-o\(tempDir.path)",
        ]) != nil else { return nil }

        let produced = tempDir.appendingPathComponent((best as NSString).lastPathComponent)
        guard let image = NSImage(contentsOf: produced) else { return nil }
        return image
    }

    private static func parseEntries(_ listing: String) -> [String: Int64] {
        var result: [String: Int64] = [:]
        var currentPath: String?
        for line in listing.split(separator: "\n") {
            let text = String(line)
            if text.hasPrefix("Path = ") {
                currentPath = String(text.dropFirst("Path = ".count))
            } else if text.hasPrefix("Size = "), let path = currentPath {
                if let size = Int64(text.dropFirst("Size = ".count)) { result[path] = size }
            } else if text.hasPrefix("Folder = +"), let path = currentPath {
                result.removeValue(forKey: path)
            }
        }
        return result
    }

    private static func bestImage(_ entries: [String: Int64]) -> String? {
        let allowed: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp", "icns"]
        return entries
            .filter { allowed.contains(($0.key as NSString).pathExtension.lowercased()) }
            .max { lhs, rhs in lhs.value < rhs.value }?
            .key
    }

    /// The bundled helper lives in the containing app's `Contents/Helpers`.
    private static func helperURL() -> URL? {
        let app = Bundle.main.bundleURL
            .deletingLastPathComponent()   // PlugIns
            .deletingLastPathComponent()   // Contents
            .deletingLastPathComponent()   // .app
        let candidate = app.appendingPathComponent("Contents/Helpers/7zz")
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }

    @discardableResult
    private static func runSevenZip(helper: URL, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = helper
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "en_US.UTF-8"
        process.environment = environment
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
