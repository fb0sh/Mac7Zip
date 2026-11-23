import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: FileBrowserModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sidebarSelection: SidebarLocation? = .home

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $sidebarSelection)
        } detail: {
            VStack(spacing: 0) {
                PathBarView()
                Divider()
                FileListView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                StatusBarView()
            }
        }
        .toolbar {
            MainToolbar(model: model, columnVisibility: $columnVisibility)
        }
        .navigationTitle(model.currentDirectory.lastPathComponent.isEmpty ? "Mac7Zip" : model.currentDirectory.lastPathComponent)
        .navigationSubtitle(model.currentDirectory.path)
        .frame(minWidth: 760, minHeight: 480)
        .task { model.loadInitialContentIfNeeded() }
        .onChange(of: sidebarSelection) { _, newValue in
            if let newValue {
                model.navigate(to: newValue.url)
            }
        }
        .alert("Can’t Open Folder", isPresented: errorBinding) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}
