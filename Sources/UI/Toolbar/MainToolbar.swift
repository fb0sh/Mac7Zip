import SwiftUI

/// Native macOS toolbar. Navigation and archive actions are grouped; every
/// archive/editing action that is not implemented in Phase 0 is disabled.
struct MainToolbar: ToolbarContent {
    let model: BrowserStore
    @ObservedObject var tasks: TaskCenterAdapter
    @Binding var showSidebar: Bool
    @Binding var showPreview: Bool
    var isDualPane: Bool = false
    var onToggleDualPane: (() -> Void)? = nil
    @State private var showingTasks = false

    init(
        model: BrowserStore,
        tasks: TaskCenterAdapter,
        showSidebar: Binding<Bool>,
        showPreview: Binding<Bool>,
        isDualPane: Bool = false,
        onToggleDualPane: (() -> Void)? = nil
    ) {
        self.model = model
        self.tasks = tasks
        self._showSidebar = showSidebar
        self._showPreview = showPreview
        self.isDualPane = isDualPane
        self.onToggleDualPane = onToggleDualPane
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                showSidebar.toggle()
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
            ForEach(CoreOperation.allCases) { operation in
                Button {
                    perform(operation)
                } label: {
                    Label(operation.title, systemImage: operation.systemImage)
                }
                .help(operation.title)
                .disabled(!isEnabled(operation))
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showPreview.toggle()
            } label: {
                Image(systemName: showPreview ? "sidebar.squares.right" : "sidebar.squares.right")
            }
            .help("Show or Hide Preview")
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

    private func isEnabled(_ operation: CoreOperation) -> Bool {
        CoreOperation.isEnabled(
            operation,
            isInsideArchive: model.isInsideArchive,
            canModify: model.canModify,
            hasSelection: !model.selection.isEmpty,
            hasItems: !model.items.isEmpty
        )
    }

    private func perform(_ operation: CoreOperation) {
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
}
