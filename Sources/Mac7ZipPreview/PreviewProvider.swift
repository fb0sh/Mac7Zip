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
                isDirectory: entry.isDirectory
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
}
