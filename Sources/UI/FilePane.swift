import SwiftUI

/// One self-contained browsing pane: path bar, file list with state overlay, and
/// status bar. Used for both the primary view and the secondary dual-pane view,
/// so each pane has its own `BrowserStore` injected via the environment.
struct FilePane: View {
    @ObservedObject var model: BrowserStore

    var body: some View {
        VStack(spacing: 0) {
            PathBarView()
            Divider()
            ZStack {
                FileListView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                overlay
            }
            Divider()
            StatusBarView()
        }
        .environmentObject(model)
    }

    @ViewBuilder
    private var overlay: some View {
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
