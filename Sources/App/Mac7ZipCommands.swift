import SwiftUI

/// System menu-bar commands. Archive operations are present but disabled in
/// Phase 0; they become available once the 7zz engine is integrated.
struct Mac7ZipCommands: Commands {
    let model: FileBrowserModel

    var body: some Commands {
        // The app manages a single browser window; remove the template "New" item.
        CommandGroup(replacing: .newItem) {}

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
            Button("Add to Archive…") {}
                .disabled(true)
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
