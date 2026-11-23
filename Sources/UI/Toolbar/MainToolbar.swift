import SwiftUI

/// Native macOS toolbar. Navigation and archive actions are grouped; every
/// archive/editing action that is not implemented in Phase 0 is disabled.
struct MainToolbar: ToolbarContent {
    let model: BrowserStore
    @ObservedObject var tasks: TaskCenterAdapter
    @Binding var columnVisibility: NavigationSplitViewVisibility
    var isDualPane: Bool = false
    var onToggleDualPane: (() -> Void)? = nil
    var onAddFavourite: (() -> Void)? = nil
    @State private var showingTasks = false

    init(
        model: BrowserStore,
        tasks: TaskCenterAdapter,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        isDualPane: Bool = false,
        onToggleDualPane: (() -> Void)? = nil,
        onAddFavourite: (() -> Void)? = nil
    ) {
        self.model = model
        self.tasks = tasks
        self._columnVisibility = columnVisibility
        self.isDualPane = isDualPane
        self.onToggleDualPane = onToggleDualPane
        self.onAddFavourite = onAddFavourite
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
            Button {
                model.requestCompression()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Create an archive from the selection")
            .disabled(model.isInsideArchive)

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
            Button {
                TransferViewActions.copySelection(in: model)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy selected items to another folder")
            .disabled(model.selection.isEmpty || !model.canModify)

            Button {
                TransferViewActions.moveSelection(in: model)
            } label: {
                Image(systemName: "folder")
            }
            .help("Move selected items to another folder")
            .disabled(model.selection.isEmpty || !model.canModify)

            Button {
                FileOperationsViewActions.deleteSelection(in: model)
            } label: {
                Image(systemName: "trash")
            }
            .help("Move to Trash")
            .disabled(model.selection.isEmpty)

            Button {
                model.showInfoForSelection()
            } label: {
                Image(systemName: "info.circle")
            }
            .help("Show information about the selection")
            .disabled(model.isInsideArchive)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                onAddFavourite?()
            } label: {
                Image(systemName: "star")
            }
            .help("Add the current folder to Favourites")
            .disabled(onAddFavourite == nil)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                onToggleDualPane?()
            } label: {
                Image(systemName: isDualPane ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
            }
            .help("Toggle dual-pane mode")
            .disabled(onToggleDualPane == nil)
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
