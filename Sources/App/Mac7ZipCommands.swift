import SwiftUI

/// System menu-bar commands. Archive operations are present but disabled in
/// Phase 0; they become available once the 7zz engine is integrated.
struct Mac7ZipCommands: Commands {
    let model: FileBrowserModel

    var body: some Commands {
        // Replace the template "New" item with native file-operation commands.
        CommandGroup(replacing: .newItem) {
            Button("New Folder") {
                FileOperationsViewActions.newFolder(in: model)
            }
            .keyboardShortcut("N", modifiers: [.command, .shift])

            Button("Rename…") {
                if let item = model.selectedItems.first {
                    FileOperationsViewActions.rename(item, in: model)
                }
            }
            .keyboardShortcut("R", modifiers: .command)

            Button("Move to Trash") {
                FileOperationsViewActions.deleteSelection(in: model)
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }

        CommandGroup(after: .pasteboard) {
            Button("Copy to Folder…") { TransferViewActions.copySelection(in: model) }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(model.selection.isEmpty || !model.canModify)
            Button("Move to Folder…") { TransferViewActions.moveSelection(in: model) }
                .keyboardShortcut("m", modifiers: [.command, .option])
                .disabled(model.selection.isEmpty || !model.canModify)
            Button("Duplicate") { TransferViewActions.duplicateSelection(in: model) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(model.selection.isEmpty)
        }

        CommandMenu("Go") {
            Button("Back") { model.goBack() }
                .keyboardShortcut("[", modifiers: .command)
            Button("Forward") { model.goForward() }
                .keyboardShortcut("]", modifiers: .command)
            Button("Enclosing Folder") { model.goUp() }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Divider()
            ForEach(SidebarLocation.allCases) { location in
                Button(location.title) { model.navigate(to: location.url) }
            }
        }

        CommandMenu("Tools") {
            Button("Add to Archive…") { model.requestCompression() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(model.isInsideArchive)
            Button("Extract…") {}
                .disabled(true)
            Button("Test Archive…") {}
                .disabled(true)
        }

        CommandGroup(after: .toolbar) {
            Divider()
            ForEach(FileSortField.allCases, id: \.self) { field in
                Button("Sort by \(field.displayName)") {
                    model.setSort(field: field, ascending: true)
                }
            }
        }
    }
}
