import SwiftUI

/// Native macOS toolbar. Navigation and archive actions are grouped; every
/// archive/editing action that is not implemented in Phase 0 is disabled.
struct MainToolbar: ToolbarContent {
    let model: BrowserStore
    @ObservedObject var tasks: TaskCenterAdapter
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @State private var showingTasks = false

    init(
        model: BrowserStore,
        tasks: TaskCenterAdapter,
        columnVisibility: Binding<NavigationSplitViewVisibility>
    ) {
        self.model = model
        self.tasks = tasks
        self._columnVisibility = columnVisibility
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Show or Hide Sidebar")
        }

        ToolbarItemGroup(placement: .navigation) {
            Button { model.goBack() } label: {
                Image(systemName: "chevron.left")
            }
            .help("Back")
            .disabled(!model.canGoBack)

            Button { model.goForward() } label: {
                Image(systemName: "chevron.right")
            }
            .help("Forward")
            .disabled(!model.canGoForward)

            Button { model.goUp() } label: {
                Image(systemName: "arrow.up")
            }
            .help("Enclosing Folder")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {} label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add to Archive — not available yet")
            .disabled(true)

            Button {
                model.requestExtract()
            } label: {
                Label("Extract", systemImage: "square.and.arrow.up")
            }
            .help("Extract the selected items (or the whole archive)")
            .disabled(!model.isInsideArchive || model.items.isEmpty)

            Button {
                Task { await model.testCurrentArchive() }
            } label: {
                Label("Test", systemImage: "checkmark.seal")
            }
            .help("Test the open archive")
            .disabled(!model.isInsideArchive)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {} label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy — not available yet")
            .disabled(true)

            Button {} label: {
                Image(systemName: "folder")
            }
            .help("Move — not available yet")
            .disabled(true)

            Button {
                FileOperationsViewActions.deleteSelection(in: model)
            } label: {
                Image(systemName: "trash")
            }
            .help("Move to Trash")
            .disabled(model.selection.isEmpty)

            Button {} label: {
                Image(systemName: "info.circle")
            }
            .help("Info — not available yet")
            .disabled(true)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showingTasks.toggle()
            } label: {
                Image(systemName: tasks.hasActiveTasks ? "arrow.triangle.2.circlepath" : "checklist")
            }
            .help("Tasks")
            .popover(isPresented: $showingTasks) {
                TasksPopoverView(adapter: tasks)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section("Sort By") {
                    ForEach(FileSortField.allCases, id: \.self) { field in
                        Button {
                            model.toggleSort(field: field)
                        } label: {
                            if model.sortDescriptor.field == field {
                                Label(
                                    "\(field.displayName) (\(model.sortDescriptor.ascending ? "Ascending" : "Descending"))",
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text(field.displayName)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("View Options")
        }
    }
}
