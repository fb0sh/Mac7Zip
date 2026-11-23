import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: BrowserStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var tasks = TaskCenterAdapter()
    @StateObject private var notifications = NotificationCoordinator()
    @State private var notifiedTaskIDs: Set<UUID> = []
    @StateObject private var favourites = FavouritesStore()
    @StateObject private var panes = DualPaneController()
    @StateObject private var secondaryModel = BrowserStore()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(favourites: favourites) { url in
                activeModel.navigate(to: url)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    favourites.add(url: activeModel.currentDirectory)
                } label: {
                    Label("Add Current Folder", systemImage: "star")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .padding(8)
                .disabled(favourites.isFavourite(activeModel.currentDirectory))
            }
        } detail: {
            if panes.isDualPane {
                HSplitView {
                    FilePane(model: model)
                        .overlay(paneBorder(index: 0))
                        .onTapGesture { panes.setActive(0) }
                    FilePane(model: secondaryModel)
                        .overlay(paneBorder(index: 1))
                        .onTapGesture { panes.setActive(1) }
                }
            } else {
                FilePane(model: model)
            }
        }
        .toolbar {
            MainToolbar(
                model: model,
                tasks: tasks,
                columnVisibility: $columnVisibility,
                isDualPane: panes.isDualPane,
                onToggleDualPane: {
                    panes.toggle()
                    if panes.isDualPane { secondaryModel.navigate(to: model.currentDirectory) }
                },
                onAddFavourite: { favourites.add(url: model.currentDirectory) }
            )
        }
        .navigationTitle(model.currentDirectory.lastPathComponent.isEmpty ? "Mac7Zip" : model.currentDirectory.lastPathComponent)
        .navigationSubtitle(subtitle)
        .frame(minWidth: 760, minHeight: 480)
        .task {
            // Double-click an archive: honour the Settings choice (Open vs Extract).
            model.archiveActivationHandler = { url in
                guard settingsStore.settings.activation == .extract else { return false }
                model.extractArchiveInline(url, tasks: tasks, settings: settingsStore.settings)
                return true
            }
            // Window restoration (TKT-M5-07): reopen the last folder if enabled.
            if settingsStore.settings.restoreLastLocation,
               let restored = RestorationStore().restorableURL(),
               restored.standardizedFileURL != model.currentDirectory.standardizedFileURL {
                model.navigate(to: restored)
            } else {
                model.loadInitialContentIfNeeded()
            }
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
        .onOpenURL { url in FileOpenInbox.shared.enqueue(url) }
        .onReceive(FileOpenInbox.shared.$pendingURL.compactMap { $0 }) { url in
            if ArchiveDocumentTypes.handles(pathExtension: url.pathExtension) {
                model.openArchive(url)
            }
        }
        .onChange(of: tasks.records) { _, records in
            let enabled = settingsStore.settings.sendCompletionNotifications
            guard enabled else { return }
            for record in records where record.state.isTerminal && !notifiedTaskIDs.contains(record.id) {
                notifiedTaskIDs.insert(record.id)
                Task { await notifications.notifyTaskFinished(record: record, enabled: enabled) }
            }
        }
        .onChange(of: model.currentDirectory) { _, newValue in
            if !model.isInsideArchive { RestorationStore().record(newValue) }
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

    private var activeModel: BrowserStore {
        panes.isDualPane && panes.activePane == 1 ? secondaryModel : model
    }

    private func paneBorder(index: Int) -> some View {
        Rectangle()
            .strokeBorder(panes.isDualPane && panes.activePane == index ? Color.accentColor : Color.clear, lineWidth: 2)
    }
}
