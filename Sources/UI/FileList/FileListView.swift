import AppKit
import SwiftUI

enum FileListColumn: String, CaseIterable {
    case name
    case size
    case kind
    case date
}

/// AppKit-backed file table. `NSTableView` is used directly (rather than a
/// SwiftUI table) for precise control over keyboard interaction, selection, and
/// rendering of large directory listings.
struct FileListView: NSViewRepresentable {
    @ObservedObject var model: FileBrowserModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = FileNSTableView()
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 24
        tableView.style = .inset
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        tableView.onReturn = { [weak coordinator = context.coordinator] in
            coordinator?.openSelection()
        }

        addColumn(to: tableView, column: .name, title: "Name", width: 320)
        addColumn(to: tableView, column: .size, title: "Size", width: 100, alignment: .right)
        addColumn(to: tableView, column: .kind, title: "Kind", width: 140)
        addColumn(to: tableView, column: .date, title: "Date Modified", width: 190)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true

        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.model = model
        context.coordinator.synchronize()
    }

    private func addColumn(
        to tableView: NSTableView,
        column: FileListColumn,
        title: String,
        width: CGFloat,
        alignment: NSTextAlignment = .left
    ) {
        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
        tableColumn.title = title
        tableColumn.width = width
        tableColumn.minWidth = 44
        tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue, ascending: true)
        tableView.addTableColumn(tableColumn)
    }
}

// MARK: - Coordinator

extension FileListView {
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var model: FileBrowserModel
        weak var tableView: NSTableView?

        private var lastItemIDs: [FileItem.ID] = []
        private var lastSortField: FileSortField?
        private var lastSortAscending: Bool?
        private var isSynchronizing = false

        private let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }()

        init(model: FileBrowserModel) {
            self.model = model
        }

        func synchronize() {
            guard let tableView else { return }
            let items = model.items

            if items.map(\.id) != lastItemIDs {
                lastItemIDs = items.map(\.id)
                tableView.reloadData()
            }

            if lastSortField != model.sortDescriptor.field || lastSortAscending != model.sortDescriptor.ascending {
                lastSortField = model.sortDescriptor.field
                lastSortAscending = model.sortDescriptor.ascending
                let descriptor = NSSortDescriptor(
                    key: model.sortDescriptor.field.rawValue,
                    ascending: model.sortDescriptor.ascending
                )
                isSynchronizing = true
                tableView.sortDescriptors = [descriptor]
                isSynchronizing = false
            }

            let indexes = IndexSet(
                items.enumerated().compactMap { model.selection.contains($0.element.id) ? $0.offset : nil }
            )
            if tableView.selectedRowIndexes != indexes {
                isSynchronizing = true
                tableView.selectRowIndexes(indexes, byExtendingSelection: false)
                isSynchronizing = false
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            model.items.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn, row >= 0, row < model.items.count else { return nil }
            let item = model.items[row]
            let column = FileListColumn(rawValue: tableColumn.identifier.rawValue)
            let cell = cellView(for: tableColumn, column: column, in: tableView)

            switch column {
            case .name:
                cell.textField?.stringValue = item.name
                cell.imageView?.image = NSWorkspace.shared.icon(forFile: item.url.path)
            case .size:
                cell.textField?.stringValue = item.isDirectory ? "--" : FileSizeFormatter.string(fromByteCount: item.size)
            case .kind:
                cell.textField?.stringValue = item.kind
            case .date:
                cell.textField?.stringValue = item.modificationDate.map { dateFormatter.string(from: $0) } ?? "--"
            case .none:
                break
            }
            return cell
        }

        private func cellView(
            for tableColumn: NSTableColumn,
            column: FileListColumn?,
            in tableView: NSTableView
        ) -> NSTableCellView {
            let identifier = tableColumn.identifier
            if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
                return reused
            }

            let cell = NSTableCellView()
            cell.identifier = identifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle
            cell.addSubview(textField)
            cell.textField = textField

            if column == .name {
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.imageScaling = .scaleProportionallyDown
                cell.addSubview(imageView)
                cell.imageView = imageView

                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 18),
                    imageView.heightAnchor.constraint(equalToConstant: 18),
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
            } else {
                textField.alignment = column == .size ? .right : .left
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
            }

            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSynchronizing, let tableView else { return }
            let selectedIDs = Set(
                tableView.selectedRowIndexes.compactMap { index -> FileItem.ID? in
                    guard index < model.items.count else { return nil }
                    return model.items[index].id
                }
            )
            if model.selection != selectedIDs {
                model.selection = selectedIDs
            }
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard
                !isSynchronizing,
                let descriptor = tableView.sortDescriptors.first,
                let key = descriptor.key,
                let field = FileSortField(rawValue: key)
            else { return }
            model.setSort(field: field, ascending: descriptor.ascending)
        }

        @objc func handleDoubleClick(_ sender: Any?) {
            guard let tableView else { return }
            let row = tableView.clickedRow
            guard row >= 0, row < model.items.count else { return }
            model.open(model.items[row])
        }

        func openSelection() {
            model.openSelected()
        }
    }
}

/// Table view that maps the Return / Enter keys to "open the selection".
final class FileNSTableView: NSTableView {
    var onReturn: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            onReturn?()
            return
        }
        super.keyDown(with: event)
    }
}
