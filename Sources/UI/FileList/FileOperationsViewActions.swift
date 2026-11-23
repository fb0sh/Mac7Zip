import AppKit

/// Native AppKit prompts for file operations. Kept in the UI layer; delegates the
/// actual work to `BrowserStore` → `FileOperationsService`.
@MainActor
enum FileOperationsViewActions {
    static func newFolder(in model: BrowserStore) {
        guard model.canModify else { return }
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.informativeText = "Enter a name for the new folder."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let field = makeTextField(placeholder: "Folder name")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue
        Task { await model.newFolder(named: name) }
    }

    static func rename(_ item: FileItem, in model: BrowserStore) {
        guard model.canModify else { return }
        let alert = NSAlert()
        alert.messageText = "Rename"
        alert.informativeText = "Enter a new name for “\(item.name)”."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = makeTextField(placeholder: "Name")
        field.stringValue = item.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = field.stringValue
        Task { await model.rename(item, to: newName) }
    }

    static func deleteSelection(in model: BrowserStore) {
        let items = model.selectedItems
        guard !items.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = items.count == 1
            ? "Move “\(items[0].name)” to the Trash?"
            : "Move \(items.count) items to the Trash?"
        alert.informativeText = "You can restore them from the Trash."
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await model.deleteSelected() }
    }

    private static func makeTextField(placeholder: String) -> NSTextField {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = placeholder
        field.isEditable = true
        return field
    }
}
