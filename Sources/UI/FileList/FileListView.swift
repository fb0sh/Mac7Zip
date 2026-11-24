import AppKit
import SwiftUI

enum FileListColumn: String, CaseIterable {
    case name
    case size
    case packedSize
    case kind
    case date
    case crc
    case encrypted
    case method

    /// Columns that only make sense while browsing inside an archive.
    static let archiveOnly: Set<FileListColumn> = [.packedSize, .crc, .encrypted, .method]
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
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 22
        tableView.setAccessibilityLabel("File list")
        tableView.setAccessibilityRole(.table)
        tableView.style = .inset
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        tableView.onReturn = { [weak coordinator = context.coordinator] in
            coordinator?.openSelection()
        }

        addColumn(to: tableView, column: .name, title: "Name", width: 320)
        addColumn(to: tableView, column: .size, title: "Size", width: 100, alignment: .right)
        addColumn(to: tableView, column: .packedSize, title: "Packed Size", width: 100, alignment: .right)
        addColumn(to: tableView, column: .kind, title: "Kind", width: 140)
        addColumn(to: tableView, column: .date, title: "Date Modified", width: 170)
        addColumn(to: tableView, column: .crc, title: "CRC", width: 90)
        addColumn(to: tableView, column: .encrypted, title: "Encrypted", width: 80)
        addColumn(to: tableView, column: .method, title: "Method", width: 120)

        context.coordinator.applySavedColumnWidths(to: tableView)

        let menu = NSMenu()
        menu.addItem(withTitle: "Open", action: #selector(Coordinator.menuOpen(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Quick Look", action: #selector(Coordinator.menuQuickLook(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        for operation in CoreOperation.allCases {
            let item = NSMenuItem(title: operation.title, action: #selector(Coordinator.menuCoreOperation(_:)), keyEquivalent: "")
            item.representedObject = operation.rawValue
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Rename…", action: #selector(Coordinator.menuRename(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Reveal in Finder", action: #selector(Coordinator.menuReveal(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "New Folder", action: #selector(Coordinator.menuNewFolder(_:)), keyEquivalent: "")
        for item in menu.items where item.action != nil {
            item.target = context.coordinator
        }
        tableView.menu = menu

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
    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuItemValidation {
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

        // MARK: - Dragging out (TKT-M4-09)

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            let items = model.items
            guard items.indices.contains(row) else { return nil }
            let payload = DragExportPlanner.payload(for: items[row], isInsideArchive: model.isInsideArchive, internalPath: model.archiveInternalPath ?? "")

            switch payload {
            case .fileURL(let url):
                return url as NSURL
            case .promise(let entryPath, let fileName, let isDirectory):
                guard let archiveURL = model.archiveURL,
                      let helper = SevenZipLocator.helperURL() else { return nil }
                let exporter = ArchiveEntryExporter(
                    archiveURL: archiveURL,
                    entryPath: entryPath,
                    isDirectory: isDirectory,
                    engineFactory: { SevenZipEngine(executableURL: helper) }
                )
                let delegate = ArchivePromiseDelegate(exporter: exporter)
                let provider = NSFilePromiseProvider(fileType: DragExportPlanner.fileType(for: fileName, isDirectory: isDirectory), delegate: delegate)
                provider.userInfo = fileName
                DragDelegateStore.shared.retain(delegate, for: ObjectIdentifier(provider))
                return provider
            case .none:
                return nil
            }
        }

        func tableView(
            _ tableView: NSTableView,
            draggingSession session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            for item in session.draggingPasteboard.pasteboardItems ?? [] {
                if let provider = item as? NSFilePromiseProvider {
                    DragDelegateStore.shared.release(ObjectIdentifier(provider))
                }
            }
        }

        // MARK: - Dropping in (TKT-M4-03)

        func tableView(
            _ tableView: NSTableView,
            validateDrop info: NSDraggingInfo,
            proposedRow row: Int,
            proposedDropOperation dropOperation: NSTableView.DropOperation
        ) -> NSDragOperation {
            guard model.canModify, !model.isInsideArchive else { return [] }
            return info.draggingSourceOperationMask.contains(.move) ? .move : .copy
        }

        func tableView(
            _ tableView: NSTableView,
            acceptDrop info: NSDraggingInfo,
            row: Int,
            dropOperation: NSTableView.DropOperation
        ) -> Bool {
            let urls = info.draggingPasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL] ?? []
            guard !urls.isEmpty, model.canModify else { return false }
            let kind: FileTransferRequest.Kind = info.draggingSourceOperationMask.contains(.move) ? .move : .copy
            Task { await model.transfer(kind: kind, to: model.currentDirectory, policy: .ask) }
            return true
        }

        func synchronize() {
            guard let tableView else { return }
            let archiveMode = model.isInsideArchive
            for column in tableView.tableColumns {
                guard let id = FileListColumn(rawValue: column.identifier.rawValue) else { continue }
                column.isHidden = FileListColumn.archiveOnly.contains(id) && !archiveMode
            }
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

            var indexes = IndexSet()
            for (offset, item) in items.enumerated() where model.selection.contains(item.id) {
                indexes.insert(offset)
            }
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
                cell.imageView?.image = IconCache.shared.icon(for: item)
            case .size:
                cell.textField?.stringValue = item.isDirectory ? "--" : FileSizeFormatter.string(fromByteCount: item.size)
            case .kind:
                cell.textField?.stringValue = item.kind
            case .date:
                cell.textField?.stringValue = item.modificationDate.map { dateFormatter.string(from: $0) } ?? "--"
            case .packedSize:
                if let meta = item.archiveMetadata {
                    cell.textField?.stringValue = item.isDirectory ? "--" : FileSizeFormatter.string(fromByteCount: meta.packedSize)
                } else {
                    cell.textField?.stringValue = "--"
                }
            case .crc:
                cell.textField?.stringValue = item.archiveMetadata?.crc ?? "--"
            case .encrypted:
                let encrypted = item.archiveMetadata?.isEncrypted ?? false
                cell.textField?.stringValue = encrypted ? "Yes" : "No"
            case .method:
                cell.textField?.stringValue = item.archiveMetadata?.method ?? "--"
            case .none:
                break
            }

            // Accessibility: expose a meaningful description per row.
            if column == .name {
                let sizeText = item.isDirectory ? "folder" : FileSizeFormatter.string(fromByteCount: item.size)
                cell.setAccessibilityLabel("\(item.name), \(sizeText), \(item.kind)")
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
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
            } else {
                textField.alignment = (column == .size || column == .packedSize) ? .right : .left
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

        // MARK: - Context menu

        @objc func menuOpen(_ sender: Any?) {
            model.openSelected()
        }

        @objc func menuQuickLook(_ sender: Any?) {
            NotificationCenter.default.post(name: .mac7zipQuickLook, object: nil)
        }

        @objc func menuCoreOperation(_ sender: NSMenuItem) {
            guard let raw = sender.representedObject as? String,
                  let operation = CoreOperation(rawValue: raw) else { return }
            switch operation {
            case .add: model.requestCompression()
            case .extract: model.requestExtract()
            case .test: Task { await model.testCurrentArchive() }
            case .copy: TransferViewActions.copySelection(in: model)
            case .move: TransferViewActions.moveSelection(in: model)
            case .delete: FileOperationsViewActions.deleteSelection(in: model)
            case .info: model.showInfoForSelection()
            }
        }

        @objc func menuRename(_ sender: Any?) {
            if let item = model.selectedItems.first {
                FileOperationsViewActions.rename(item, in: model)
            }
        }

        @objc func menuDelete(_ sender: Any?) {
            FileOperationsViewActions.deleteSelection(in: model)
        }

        @objc func menuNewFolder(_ sender: Any?) {
            FileOperationsViewActions.newFolder(in: model)
        }

        @objc func menuReveal(_ sender: Any?) {
            let urls = model.selectedItems.map(\.url)
            guard !urls.isEmpty else { return }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }

        func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
            switch menuItem.action {
            case #selector(menuOpen(_:)), #selector(menuRename(_:)), #selector(menuReveal(_:)):
                return !model.selection.isEmpty
            case #selector(menuQuickLook(_:)):
                return model.isInsideArchive && !model.selection.isEmpty
            case #selector(menuCoreOperation(_:)):
                guard let raw = menuItem.representedObject as? String,
                      let operation = CoreOperation(rawValue: raw) else { return false }
                return CoreOperation.isEnabled(
                    operation,
                    isInsideArchive: model.isInsideArchive,
                    canModify: model.canModify,
                    hasSelection: !model.selection.isEmpty,
                    hasItems: !model.items.isEmpty
                )
            case #selector(menuNewFolder(_:)):
                return model.canModify
            default:
                return true
            }
        }

        // MARK: - Column width persistence

        private static let widthsKey = "Mac7Zip.FileList.columnWidths"

        func applySavedColumnWidths(to tableView: NSTableView) {
            guard let saved = UserDefaults.standard.dictionary(forKey: Self.widthsKey) as? [String: Double] else {
                return
            }
            for column in tableView.tableColumns {
                if let width = saved[column.identifier.rawValue], width > 0 {
                    column.width = width
                }
            }
        }

        func tableViewColumnDidResize(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            var widths: [String: Double] = [:]
            for column in tableView.tableColumns {
                widths[column.identifier.rawValue] = Double(column.width)
            }
            UserDefaults.standard.set(widths, forKey: Self.widthsKey)
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
