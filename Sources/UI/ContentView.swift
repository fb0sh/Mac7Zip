import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: BrowserStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var tasks = TaskCenterAdapter()
    @StateObject private var notifications = NotificationCoordinator()
    @StateObject private var quickLook = QuickLookController()
    @State private var notifiedTaskIDs: Set<UUID> = []
    @StateObject private var favourites = FavouritesStore()
    @StateObject private var panes = DualPaneController()
    @StateObject private var secondaryModel = BrowserStore()
    @State private var showSidebar = false
    @State private var showPreview = false
    @State private var showFinderExtensionPrompt = false

    var body: some View {
        HSplitView {
            if showSidebar {
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
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)
            }

            detailContent
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)

            if showPreview {
                PreviewPane(target: previewTarget)
                    .frame(minWidth: 220, idealWidth: 300, maxWidth: 480)
            }
        }
        .environmentObject(tasks)
        .focusedSceneValue(\.browserStore, model)
        .toolbar {
            MainToolbar(
                model: model,
                tasks: tasks,
                showSidebar: $showSidebar,
                showPreview: $showPreview,
                isDualPane: panes.isDualPane,
                onToggleDualPane: {
                    panes.toggle()
                    if panes.isDualPane { secondaryModel.navigate(to: model.currentDirectory) }
                }
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

            // Nudge about the Finder extension at most once (never nag every launch).
            let promptKey = "Mac7Zip.finderExtensionPromptShown"
            if !UserDefaults.standard.bool(forKey: promptKey),
               await FinderExtensionChecker.check() != .enabled {
                showFinderExtensionPrompt = true
                UserDefaults.standard.set(true, forKey: promptKey)
            }
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
        .onOpenURL { url in
            if url.scheme == "mac7zip", url.host == "action" {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let action = components?.queryItems?
                    .first { $0.name == "action" }?.value
                    .flatMap(ServiceAction.init(rawValue:))
                let files = components?.queryItems?
                    .filter { $0.name == "file" }.compactMap { $0.value.map { URL(fileURLWithPath: $0) } } ?? []
                if let action { _ = ServiceHandlers.handle(action, urls: files) }
            } else {
                FileOpenInbox.shared.enqueue(url)
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .mac7zipQuickLook)) { _ in
            Task { await previewSelection() }
        }
        .onChange(of: model.currentDirectory) { _, newValue in
            if !model.isInsideArchive { RestorationStore().record(newValue) }
        }
        .alert("Finder 右键菜单未启用", isPresented: $showFinderExtensionPrompt) {
            Button("去启用") {
                FinderExtensionChecker.enable()
                FinderExtensionChecker.openSettings()
            }
            Button("稍后", role: .cancel) {}
        } message: {
            Text("Mac7Zip 的 Finder 扩展还没启用，右键菜单里不会出现“打开/解压/添加到压缩包”。可在“系统设置 ▸ 通用 ▸ 登录项与扩展 ▸ 访达扩展”中勾选 Mac7Zip Finder。")
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

    private func previewSelection() async {
        guard let item = model.selectedItems.first, !item.isDirectory else { return }
        if let archiveURL = model.archiveURL {
            guard let helper = SevenZipLocator.helperURL() else { return }
            do {
                let engine = SevenZipEngine(executableURL: helper)
                _ = try await quickLook.prepare(entryPath: item.name, archiveURL: archiveURL, engine: engine)
                quickLook.present()
            } catch {
                model.operationError = error.localizedDescription
            }
        } else {
            quickLook.presentFile(item.url)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
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

    /// What the preview pane should show for the current window.
    private var previewTarget: PreviewTarget {
        PreviewTarget.resolve(
            item: model.selectedItems.first,
            isInsideArchive: model.isInsideArchive,
            archiveURL: model.archiveURL,
            internalPath: model.archiveInternalPath ?? ""
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
