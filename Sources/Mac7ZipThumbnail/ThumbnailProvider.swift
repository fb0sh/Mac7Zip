import AppKit
import Foundation
import QuickLookThumbnailing

/// Quick Look thumbnail extension. Sandboxed: no subprocess; ZIP contents are read
/// with a pure-Swift central-directory parser and drawn as a content list + badge.
final class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let url = request.fileURL
        let maxSize = request.maximumSize
        let entries = zipEntries(for: url)
        let reply = QLThumbnailReply(contextSize: maxSize, currentContextDrawing: { () -> Bool in
            Self.draw(entries: entries, name: url.lastPathComponent, in: maxSize)
            return true
        })
        handler(reply, nil)
    }

    private func zipEntries(for url: URL) -> [ZipCentralDirectoryReader.Entry] {
        let known: Set<String> = ["zip", "apk", "jar", "epub", "cbz", "docx", "xlsx", "pptx"]
        guard known.contains(url.pathExtension.lowercased()) else { return [] }
        return ZipCentralDirectoryReader.entries(inFileAt: url) ?? []
    }

    private static func draw(entries: [ZipCentralDirectoryReader.Entry], name: String, in size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        NSColor.white.setFill()
        bounds.fill()

        let inset = bounds.insetBy(dx: bounds.width * 0.10, dy: bounds.height * 0.10)
        NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
        let card = NSBezierPath(roundedRect: inset, xRadius: inset.width * 0.06, yRadius: inset.width * 0.06)
        card.fill()
        NSColor(calibratedWhite: 0.80, alpha: 1).setStroke()
        card.lineWidth = max(0.5, bounds.width * 0.008)
        card.stroke()

        let names = entries.filter { !$0.isDirectory }.prefix(4).map { ($0.path as NSString).lastPathComponent }
        if names.isEmpty {
            drawBadge(in: bounds, text: badge(for: name))
            return
        }

        let fontSize = max(6, bounds.width * 0.085)
        let font = NSFont.systemFont(ofSize: fontSize)
        let rowHeight = fontSize * 1.55
        var y = inset.maxY - rowHeight - inset.height * 0.05
        for fileName in names {
            guard y > inset.minY + inset.height * 0.16 else { break }
            NSColor(calibratedWhite: 0.62, alpha: 1).setFill()
            NSBezierPath(ovalIn: CGRect(x: inset.minX + inset.width * 0.07, y: y + fontSize * 0.30,
                                        width: fontSize * 0.34, height: fontSize * 0.34)).fill()
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingMiddle
            (fileName as NSString).draw(
                with: CGRect(x: inset.minX + inset.width * 0.16, y: y, width: inset.width * 0.76, height: rowHeight),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: font, .foregroundColor: NSColor(calibratedWhite: 0.32, alpha: 1), .paragraphStyle: paragraph],
                context: nil
            )
            y -= rowHeight
        }
        drawBadge(in: bounds, text: badge(for: name))
    }

    private static func badge(for name: String) -> String {
        let lower = name.lowercased()
        for suffix in ["tar.gz", "tar.xz", "tar.zst", "tbz2", "tgz"] where lower.hasSuffix("." + suffix) {
            return suffix.uppercased()
        }
        let ext = (name as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "ARCHIVE" : ext
    }

    private static func drawBadge(in bounds: CGRect, text: String) {
        let font = NSFont.systemFont(ofSize: max(8, bounds.width * 0.13), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = max(3, bounds.width * 0.04)
        let badgeRect = CGRect(
            x: bounds.maxX - textSize.width - padding * 2 - bounds.width * 0.03,
            y: bounds.minY + bounds.height * 0.03,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )
        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: badgeRect.height * 0.28, yRadius: badgeRect.height * 0.28).fill()
        (text as NSString).draw(at: CGPoint(x: badgeRect.minX + padding, y: badgeRect.minY + padding / 2), withAttributes: attributes)
    }
}
