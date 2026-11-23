import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: BrowserStore
    @StateObject private var tasks = TaskCenterAdapter()
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
            MainToolbar(model: model, tasks: tasks, columnVisibility: $columnVisibility)
        }
        .navigationTitle(model.currentDirectory.lastPathComponent.isEmpty ? "Mac7Zip" : model.currentDirectory.lastPathComponent)
        .navigationSubtitle(subtitle)
        .frame(minWidth: 760, minHeight: 480)
        .task {
            model.loadInitialContentIfNeeded()
            model.attachTasks(tasks)
            await tasks.start()
        }
        .sheet(isPresented: infoSheetBinding) {
            if let url = model.infoRequestedURL {
                InfoSheet(url: url) { model.infoRequestedURL = nil }
            }
        }
        .sheet(isPresented: compressionSheetBinding) {
            CompressionSheet(
                sources: model.compressionSources,
                defaultDirectory: model.currentDirectory,
                onCreate: { request in
                    model.performCompression(request: request, tasks: tasks)
                },
                onCancel: { model.compressionRequested = false }
            )
        }
        .sheet(isPresented: extractSheetBinding) {
            if let archiveURL = model.archiveURL {
                ExtractOptionsSheet(
                    archiveName: archiveURL.lastPathComponent,
                    defaultDestination: archiveURL.deletingLastPathComponent(),
                    onExtract: { options in
                        model.performExtract(options: options, tasks: tasks)
                    },
                    onCancel: { model.extractRequested = false }
                )
            }
        }
        .onChange(of: sidebarSelection) { _, newValue in
            if let newValue {
                model.navigate(to: newValue.url)
            }
        }
        .alert("Archive Test", isPresented: testResultBinding) {
            Button("OK", role: .cancel) { model.testResultMessage = nil }
        } message: {
            Text(model.testResultMessage ?? "")
        }
        .alert("Operation Failed", isPresented: operationErrorBinding) {
            Button("OK", role: .cancel) { model.operationError = nil }
        } message: {
            Text(model.operationError ?? "")
        }
    }

    private var subtitle: String {
        if let internalPath = model.archiveInternalPath {
            let name = model.archiveURL?.lastPathComponent ?? "Archive"
            return internalPath.isEmpty ? name : "\(name) › \(internalPath)"
        }
        return model.currentDirectory.path
    }

    private var infoSheetBinding: Binding<Bool> {
        Binding(
            get: { model.infoRequestedURL != nil },
            set: { if !$0 { model.infoRequestedURL = nil } }
        )
    }

    private var compressionSheetBinding: Binding<Bool> {
        Binding(
            get: { model.compressionRequested },
            set: { if !$0 { model.compressionRequested = false } }
        )
    }

    private var extractSheetBinding: Binding<Bool> {
        Binding(
            get: { model.extractRequested },
            set: { if !$0 { model.extractRequested = false } }
        )
    }

    private var testResultBinding: Binding<Bool> {
        Binding(
            get: { model.testResultMessage != nil },
            set: { if !$0 { model.testResultMessage = nil } }
        )
    }

    private var operationErrorBinding: Binding<Bool> {
        Binding(
            get: { model.operationError != nil },
            set: { if !$0 { model.operationError = nil } }
        )
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
