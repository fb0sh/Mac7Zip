import SwiftUI

/// System menu-bar commands. Archive operations are present but disabled in
/// Phase 0; they become available once the 7zz engine is integrated.
struct Mac7ZipCommands: Commands {
    @FocusedValue(\.browserStore) private var model: BrowserStore?

    var body: some Commands {
        // All commands are no-ops when no browser window is focused.
        let store = model
        // Replace the template "New" item with native file-operation commands.
        CommandGroup(replacing: .newItem) {
            Button("New Folder") {
                if let store { FileOperationsViewActions.newFolder(in: store) }
            }
            .keyboardShortcut("N", modifiers: [.command, .shift])

            Button("Rename…") {
                if let store, let item = store.selectedItems.first {
                    FileOperationsViewActions.rename(item, in: store)
                }
            }
            .keyboardShortcut("R", modifiers: .command)

            Button("Move to Trash") {
                if let store { FileOperationsViewActions.deleteSelection(in: store) }
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }

        CommandGroup(after: .pasteboard) {
            Button("Copy to Folder…") { if let store { TransferViewActions.copySelection(in: store) } }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(store == nil || store!.selection.isEmpty || !(store!.canModify))
            Button("Move to Folder…") { if let store { TransferViewActions.moveSelection(in: store) } }
                .keyboardShortcut("m", modifiers: [.command, .option])
                .disabled(store == nil || store!.selection.isEmpty || !(store!.canModify))
            Button("Duplicate") { if let store { TransferViewActions.duplicateSelection(in: store) } }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(store?.selection.isEmpty ?? true)
        }

        CommandGroup(after: .pasteboard) {
            Button("Quick Look") {
                NotificationCenter.default.post(name: .mac7zipQuickLook, object: nil)
            }
            .keyboardShortcut("y", modifiers: [.command])
        }

        CommandMenu("Go") {
            Button("Back") { store?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
            Button("Forward") { store?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
            Button("Enclosing Folder") { store?.goUp() }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Divider()
            ForEach(SidebarLocation.allCases) { location in
                Button(location.title) { store?.navigate(to: location.url) }
            }
        }

        CommandMenu("Tools") {
            Button("Add to Archive…") { store?.requestCompression() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(store?.isInsideArchive ?? true)
            Button("Extract…") {}
                .disabled(true)
            Button("Test Archive…") {}
                .disabled(true)
        }

        CommandGroup(after: .toolbar) {
            Divider()
            ForEach(FileSortField.allCases, id: \.self) { field in
                Button("Sort by \(field.displayName)") {
                    store?.setSort(field: field, ascending: true)
                }
            }
        }
    }
}
