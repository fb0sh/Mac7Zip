import AppKit
import Foundation
import Quartz

/// Quick Look preview extension (`com.apple.quicklook.preview`).
/// Shows a table of entries (Name / Date Modified / Size) like a file browser.
/// Sandboxed: reads names via libarchive (no subprocess).
final class PreviewProvider: NSViewController, QLPreviewingController,
                             NSTableViewDataSource, NSTableViewDelegate {
    private var entries: [LibArchiveReader.Entry] = []
    private let sizeFormatter = ByteCountFormatter()

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        entries = LibArchiveReader.listEntries(at: url) ?? []
        buildUI(title: url.lastPathComponent)
        handler(nil)
    }

    private func buildUI(title: String) {
        let bounds = NSRect(x: 0, y: 0, width: 720, height: 520)
        let container = NSView(frame: bounds)

        let files = entries.filter { !$0.isDirectory }.count
        let folders = entries.count - files
        let totalSize = entries.filter { !$0.isDirectory }.reduce(Int64(0)) { $0 + max(0, $1.size) }
        let summary = entries.isEmpty
            ? "无法读取内容"
            : "\(entries.count) 项（\(folders) 文件夹 · \(files) 文件）  解压后约 \(sizeFormatter.string(fromByteCount: totalSize))"

        let header = NSTextField(labelWithString: "\(title)    \(summary)")
        header.frame = NSRect(x: 14, y: bounds.height - 30, width: bounds.width - 28, height: 20)
        header.font = .systemFont(ofSize: 12)
        header.textColor = .secondaryLabelColor
        header.lineBreakMode = .byTruncatingMiddle
        container.addSubview(header)

        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 20
        table.style = .plain
        table.allowsMultipleSelection = false
        table.dataSource = self
        table.delegate = self

        let nameCol = NSTableColumn(identifier: .init("name")); nameCol.title = "名称"; nameCol.width = 400
        let dateCol = NSTableColumn(identifier: .init("date")); dateCol.title = "修改时间"; dateCol.width = 160
        let sizeCol = NSTableColumn(identifier: .init("size")); sizeCol.title = "大小"; sizeCol.width = 110
        [nameCol, dateCol, sizeCol].forEach { table.addTableColumn($0) }

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 38))
        scroll.hasVerticalScroller = true
        scroll.documentView = table
        container.addSubview(scroll)

        self.view = container
    }

    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard entries.indices.contains(row) else { return nil }
        let entry = entries[row]
        let id = tableColumn?.identifier.rawValue ?? "name"
        let cell = NSTableCellView()
        let field = NSTextField(labelWithString: "")
        field.frame = NSRect(x: 4, y: 0, width: (tableColumn?.width ?? 200) - 8, height: 18)
        field.font = .systemFont(ofSize: 12)
        field.lineBreakMode = .byTruncatingMiddle
        field.autoresizingMask = [.width]

        switch id {
        case "name":
            let name = (entry.path as NSString).lastPathComponent
            field.stringValue = (entry.isDirectory ? "📁 " : "📄 ") + (name.isEmpty ? entry.path : name)
        case "date":
            field.stringValue = entry.modified.map { Self.dateFormatter.string(from: $0) } ?? ""
        case "size":
            field.alignment = .right
            field.stringValue = entry.isDirectory ? "--" : sizeFormatter.string(fromByteCount: entry.size)
        default:
            break
        }
        cell.addSubview(field)
        cell.textField = field
        return cell
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}
