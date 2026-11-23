import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: BrowserStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sidebarSelection: SidebarLocation? = .home

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $sidebarSelection)
        } detail: {
            VStack(spacing: 0) {
                PathBarView()
                Divider()
                ZStack {
                    FileListView(model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    statusOverlay
                }
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
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch model.loadState {
        case .loading:
            if model.items.isEmpty {
                ProgressView("Loading…").controlSize(.large)
            }
        case .empty:
            ContentUnavailableView("Empty Folder", systemImage: "folder")
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(message)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Button("Retry") { model.reload() }
            }
            .padding()
        case .loaded:
            EmptyView()
        }
    }
}
