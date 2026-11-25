import AppKit
import Combine
import Foundation

/// Owns the browsing state for the main window: location (real directory or
/// archive-internal path), listing, selection, sort, history and file operations.
@MainActor
final class BrowserStore: ObservableObject {
    @Published private(set) var currentDirectory: URL
    @Published private(set) var location: BrowserLocation
    @Published private(set) var items: [FileItem] = []
    @Published var selection: Set<FileItem.ID> = []
    @Published var sortDescriptor: FileSortDescriptor = .default
    @Published var errorMessage: String?
    @Published var operationError: String?
    @Published var testResultMessage: String?
    @Published var extractRequested = false
    @Published var compressionRequested = false
    @Published var infoRequestedURL: URL?
    @Published var lastOperationMessage: String?
    @Published private(set) var lastExtractMessage: String?
    @Published private(set) var loadState: LoadState = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false

    private var provider: FileSystemProvider
    private let access: FileAccess
    private let fileOperations: FileOperating
    private let transfers: FileTransferService
    private let archiveProviderFactory: @Sendable (URL) -> FileSystemProvider?
    /// Optional override for double-clicking an archive (Settings: Open vs Extract).
    /// Returns true when it handled the URL.
    var archiveActivationHandler: ((URL) -> Bool)?

    /// Set by the UI so transfers can be queued with visible progress (M4-07).
    private weak var tasksBridge: TaskCenterAdapter?
    /// Stack of enclosing archives when browsing a nested archive (archive-in-archive).
    private var archiveParentStack: [(url: URL, internalPath: String, temp: URL?)] = []
    private var history: [BrowserLocation]
    private var historyIndex: Int

    init(
        startingAt url: URL = FileLocations.home,
        provider: FileSystemProvider = RealFileSystemProvider(),
        access: FileAccess = RealFileAccess(),
        fileOperations: FileOperating = FileOperationsService(),
        transfers: FileTransferService = FileTransferService(),
        archiveProviderFactory: @escaping @Sendable (URL) -> FileSystemProvider? = BrowserStore.makeArchiveProvider
    ) {
        let standardized = url.standardizedFileURL
        self.currentDirectory = standardized
        self.location = .real(standardized)
        self.provider = provider
        self.access = access
        self.fileOperations = fileOperations
        self.transfers = transfers
        self.archiveProviderFactory = archiveProviderFactory
        self.history = [.real(standardized)]
        self.historyIndex = 0
    }

    /// Default archive provider: needs the bundled 7zz helper to exist.
    nonisolated static func makeArchiveProvider(_ archiveURL: URL) -> FileSystemProvider? {
        guard let helper = SevenZipLocator.helperURL() else { return nil }
        return ArchiveFileSystemProvider(
            engine: SevenZipEngine(executableURL: helper),
            archiveURL: archiveURL
        )
    }

    /// Connects the task queue; called once when the window appears.
    func attachTasks(_ adapter: TaskCenterAdapter) {
        tasksBridge = adapter
    }

    var capabilities: FileSystemCapabilities { provider.capabilities }
    var canModify: Bool { capabilities.contains(.createDirectory) }
    var isInsideArchive: Bool {
        if case .archive = location { return true }
        return false
    }
    var archiveInternalPath: String? {
        if case .archive(_, let internalPath) = location { return internalPath }
        return nil
    }
    var archiveURL: URL? {
        if case .archive(let url, _) = location { return url }
        return nil
    }

    var selectedItems: [FileItem] { items.filter { selection.contains($0.id) } }
    var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }

    // MARK: - Loading

    func loadInitialContentIfNeeded() {
        if items.isEmpty && !isLoading { reload() }
    }

    func reload() {
        let requestedLocation = location
        isLoading = true
        loadState = .loading
        let activeProvider = provider
        Task {
            do {
                let contents = try await activeProvider.list(requestedLocation)
                guard location == requestedLocation else { return }
                items = FileSorting.sorted(contents, by: sortDescriptor)
                selection = selection.intersection(Set(items.map(\.id)))
                errorMessage = nil
                loadState = items.isEmpty ? .empty : .loaded
            } catch {
                guard location == requestedLocation else { return }
                items = []
                selection = []
                let message = Self.message(for: error, location: requestedLocation)
                errorMessage = message
                loadState = .failed(message)
            }
            isLoading = false
        }
    }

    // MARK: - Navigation

    func navigate(to url: URL) {
        let target = url.standardizedFileURL
        provider = RealFileSystemProvider()
        discardNestedArchives()
        moveTo(.real(target))
    }

    func openArchive(_ url: URL) {
        guard let archiveProvider = archiveProviderFactory(url) else {
            operationError = "The 7-Zip engine isn’t available, so archives can’t be opened."
            return
        }
        discardNestedArchives()
        provider = archiveProvider
        moveTo(.archive(archiveURL: url.standardizedFileURL, internalPath: ""))
    }

    /// Navigate to a folder **inside** the currently open archive.
    func navigateToArchivePath(_ internalPath: String) {
        guard let archiveURL else { return }
        moveTo(.archive(archiveURL: archiveURL, internalPath: internalPath))
    }

    private func moveTo(_ newLocation: BrowserLocation) {
        guard newLocation != location else { return }
        history = Array(history.prefix(historyIndex + 1))
        history.append(newLocation)
        historyIndex = history.count - 1
        apply(newLocation)
    }

    func goBack() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        apply(history[historyIndex])
    }

    func goForward() {
        guard historyIndex < history.count - 1 else { return }
        historyIndex += 1
        apply(history[historyIndex])
    }

    func goUp() {
        switch location {
        case .real(let url):
            if let parent = PathUtilities.parent(of: url) { navigate(to: parent) }
        case .archive(let url, let internalPath):
            if internalPath.isEmpty {
                if let parent = archiveParentStack.popLast() {
                    // Return to the enclosing archive rather than the filesystem.
                    provider = archiveProviderFactory(parent.url) ?? provider
                    moveTo(.archive(archiveURL: parent.url, internalPath: parent.internalPath))
                    if let temp = parent.temp { try? FileManager.default.removeItem(at: temp) }
                } else {
                    // Leave the archive: go to its enclosing real directory.
                    provider = RealFileSystemProvider()
                    if let parentURL = PathUtilities.parent(of: url) { moveTo(.real(parentURL)) }
                }
            } else {
                let parent = ArchiveFileSystemProvider.normalize(
                    (internalPath as NSString).deletingLastPathComponent
                )
                moveTo(.archive(archiveURL: url, internalPath: parent))
            }
        }
    }

    private func apply(_ newLocation: BrowserLocation) {
        location = newLocation
        switch newLocation {
        case .real(let url):
            // Returning to the filesystem from a history entry must use the real
            // provider; otherwise an archive provider would reject the real path.
            if !(provider is RealFileSystemProvider) {
                provider = RealFileSystemProvider()
            }
            currentDirectory = url
        case .archive(let url, _):
            let alreadyOpen = (provider as? ArchiveFileSystemProvider)?.sourceArchiveURL.standardizedFileURL
                == url.standardizedFileURL
            if !alreadyOpen, let archiveProvider = archiveProviderFactory(url) {
                provider = archiveProvider
            }
            currentDirectory = url
        }
        selection = []
        refreshNavigationFlags()
        reload()
    }

    /// Resolves a user-entered path to a navigable directory URL.
    func resolveNavigationTarget(_ rawPath: String) -> URL? {
        let url = access.normalizeUserPath(rawPath)
        let snapshot = access.snapshot(at: url)
        guard snapshot.exists else { return nil }
        return snapshot.isDirectory ? url : url.deletingLastPathComponent()
    }

    // MARK: - Sorting

    func setSort(field: FileSortField, ascending: Bool) {
        if sortDescriptor.field == field && sortDescriptor.ascending == ascending { return }
        sortDescriptor = FileSortDescriptor(field: field, ascending: ascending)
        items = FileSorting.sorted(items, by: sortDescriptor)
    }

    func toggleSort(field: FileSortField) {
        let ascending = sortDescriptor.field == field ? !sortDescriptor.ascending : true
        setSort(field: field, ascending: ascending)
    }

    // MARK: - Opening

    func open(_ item: FileItem) {
        if item.isDirectory {
            if let archiveURL, isInsideArchive {
                let childPath = ArchiveFileSystemProvider.normalize(
                    (archiveInternalPath ?? "") + "/" + item.name
                )
                _ = archiveURL
                navigateToArchivePath(childPath)
            } else {
                navigate(to: item.url)
            }
            return
        }

        if !isInsideArchive, ArchiveFormat.detect(from: item.url) != nil {
            if let handler = archiveActivationHandler, handler(item.url) { return }
            openArchive(item.url)
            return
        }
        if isInsideArchive {
            if ArchiveFormat.detect(from: item.url) != nil {
                openNestedArchive(entryName: item.name)
            } else {
                openEntryWithSystemDefault(item)
            }
            return
        }
        NSWorkspace.shared.open(item.url)
    }

    func openSelected() {
        if let first = selectedItems.first { open(first) }
    }

    // MARK: - Extraction

    func requestExtract() {
        guard isInsideArchive else { return }
        extractRequested = true
    }

    /// Runs extraction through `TaskCenter` so it is queued, cancellable and
    /// observable. `options.destination` is the user-chosen folder; a subfolder
    /// is applied when requested.
    func performExtract(options: ExtractOptions, tasks: TaskCenterAdapter) {
        guard let archiveURL, let helper = SevenZipLocator.helperURL() else {
            operationError = "The 7-Zip engine isn’t available."
            extractRequested = false
            return
        }
        let selected = selectedItems.filter { !$0.isDirectory }.map(\.name)
        var effective = options
        if !selected.isEmpty {
            let base = archiveInternalPath ?? ""
            effective.entries = selected.map { base.isEmpty ? $0 : base + "/" + $0 }
        }
        if let subfolder = options.createSubfolder {
            effective.destination = options.destination.appendingPathComponent(subfolder, isDirectory: true)
        }
        let engine = SevenZipEngine(executableURL: helper)
        let operation = ExtractOperation(
            engine: engine,
            archive: archiveURL,
            destination: effective.destination,
            options: effective
        )
        extractRequested = false
        Task {
            let id = await tasks.submit(operation)
            _ = id
            lastExtractMessage = "Extracting to \(effective.destination.lastPathComponent)…"
        }
    }

    // MARK: - Extract-with-settings (double-click "Extract" behaviour)

    /// Extracts an archive into a sibling `<name>/` folder through `TaskCenter`.
    func extractArchiveInline(_ archiveURL: URL, tasks: TaskCenterAdapter, settings: AppSettings) {
        guard let helper = SevenZipLocator.helperURL() else {
            operationError = "The 7-Zip engine isn’t available."
            return
        }
        let parent = archiveURL.deletingLastPathComponent()
        var options = ExtractOptions(destination: parent)
        options.password = nil
        if settings.extractSubfolderByDefault {
            options.createSubfolder = archiveURL.deletingPathExtension().lastPathComponent
        }
        let engine = SevenZipEngine(executableURL: helper, limits: settings.extractionLimits)
        let operation = ExtractOperation(
            engine: engine,
            archive: archiveURL,
            destination: parent,
            options: options
        )
        Task {
            await tasks.submit(operation)
        }
    }

    // MARK: - Info

    func showInfoForSelection() {
        if let first = selectedItems.first { infoRequestedURL = first.url }
        else if !isInsideArchive { infoRequestedURL = currentDirectory }
    }

    // MARK: - Copy / Move / Duplicate

    /// Performs a transfer into `destinationDirectory`, then refreshes and reports
    /// a structured summary (partial failures are surfaced, never hidden).
    func transfer(
        kind: FileTransferRequest.Kind,
        to destinationDirectory: URL,
        policy: ConflictPolicy
    ) async {
        guard canModify else { return }
        let sources = selectedItems.map(\.url)
        guard !sources.isEmpty else { return }

        if let bridge = tasksBridge {
            // Preferred path: queued, cancellable, shows real progress.
            enqueueTransfer(kind: kind, to: destinationDirectory, policy: policy, tasks: bridge)
            return
        }

        let request = FileTransferRequest(
            kind: kind,
            sources: sources,
            destinationDirectory: destinationDirectory,
            conflictPolicy: policy
        )
        do {
            let outcomes = try await transfers.perform(request)
            reportTransferOutcomes(outcomes, kind: kind)
        } catch {
            operationError = error.localizedDescription
        }
    }

    /// Same as `transfer`, but queued through `TaskCenter` so it shows real
    /// progress and can be cancelled (TKT-M4-07).
    func enqueueTransfer(
        kind: FileTransferRequest.Kind,
        to destinationDirectory: URL,
        policy: ConflictPolicy,
        tasks: TaskCenterAdapter
    ) {
        guard canModify else { return }
        let sources = selectedItems.map(\.url)
        guard !sources.isEmpty else { return }
        let request = FileTransferRequest(
            kind: kind,
            sources: sources,
            destinationDirectory: destinationDirectory,
            conflictPolicy: policy
        )
        selection = []
        Task {
            await tasks.submit(FileTransferOperation(request: request))
            reload()
        }
    }

    /// Summarises outcomes honestly: counts, skips and up to three errors.
    private func reportTransferOutcomes(_ outcomes: [FileTransferOutcome], kind: FileTransferRequest.Kind) {
        let failures = outcomes.compactMap { outcome -> String? in
            if case .failed(let message) = outcome.status { return message }
            return nil
        }
        let done = outcomes.filter {
            if case .failed = $0.status { return false }
            return $0.status != .skipped
        }.count
        let skipped = outcomes.filter { $0.status == .skipped }.count
        var summary = "\(done) item(s) \(kind == .move ? "moved" : kind == .duplicate ? "duplicated" : "copied")."
        if skipped > 0 { summary += " \(skipped) skipped." }
        if !failures.isEmpty { summary += "\n" + failures.prefix(3).joined(separator: "\n") }
        lastOperationMessage = summary
        selection = []
        reload()
    }

    // MARK: - Nested archives

    /// Opens an archive that lives **inside** the current archive by extracting it
    /// to a private temp file, then browsing that file. `goUp` returns to the parent.
    private func openNestedArchive(entryName: String) {
        guard let currentArchive = archiveURL, let helper = SevenZipLocator.helperURL() else {
            operationError = "The 7-Zip engine isn’t available."
            return
        }
        let entryPath = ArchiveFileSystemProvider.normalize((archiveInternalPath ?? "") + "/" + entryName)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7Zip-nested-\(UUID().uuidString)", isDirectory: true)
        let parentInternalPath = archiveInternalPath ?? ""

        Task {
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let engine = SevenZipEngine(executableURL: helper)
                var options = ExtractOptions(destination: tempDir)
                options.entries = [entryPath]
                options.password = nil
                try await engine.extract(archive: currentArchive, to: tempDir, options: options)

                let name = (entryPath as NSString).lastPathComponent
                let produced = tempDir.appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: produced.path) else {
                    operationError = "Couldn’t extract the inner archive."
                    return
                }
                archiveParentStack.append((currentArchive, parentInternalPath, tempDir))
                if let nestedProvider = archiveProviderFactory(produced) {
                    provider = nestedProvider
                }
                moveTo(.archive(archiveURL: produced, internalPath: ""))
            } catch {
                operationError = Self.archiveMessage(error)
            }
        }
    }

    /// Extracts a single archive entry to a temp folder and hands it to its default
    /// app, so files that are neither archives nor folders behave like real files.
    /// The temp copy is deliberately left in place: the receiving app may still be
    /// reading it, and macOS reclaims the temp directory.
    private func openEntryWithSystemDefault(_ item: FileItem) {
        guard let currentArchive = archiveURL, let helper = SevenZipLocator.helperURL() else {
            operationError = "The 7-Zip engine isn’t available."
            return
        }
        let entryPath = ArchiveFileSystemProvider.normalize((archiveInternalPath ?? "") + "/" + item.name)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7Zip-open-\(UUID().uuidString)", isDirectory: true)

        Task {
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let engine = SevenZipEngine(executableURL: helper)
                var options = ExtractOptions(destination: tempDir)
                options.entries = [entryPath]
                options.password = nil
                options.overwriteMode = .overwrite
                try await engine.extract(archive: currentArchive, to: tempDir, options: options)

                // Extraction preserves the entry's internal path.
                let produced = tempDir.appendingPathComponent(entryPath)
                guard FileManager.default.fileExists(atPath: produced.path) else {
                    operationError = "Couldn’t extract the file to open it."
                    return
                }
                NSWorkspace.shared.open(produced)
            } catch {
                operationError = Self.archiveMessage(error)
            }
        }
    }

    private func discardNestedArchives() {
        for entry in archiveParentStack {
            if let temp = entry.temp { try? FileManager.default.removeItem(at: temp) }
        }
        archiveParentStack.removeAll()
    }

    // MARK: - Compression

    /// Sources for a new archive: the selection, or the whole current folder.
    var compressionSources: [URL] {
        let selected = selectedItems.map(\.url)
        return selected.isEmpty ? [currentDirectory] : selected
    }

    func requestCompression() {
        guard !isInsideArchive else {
            operationError = "You can’t create an archive from inside another archive."
            return
        }
        compressionRequested = true
    }

    /// Runs creation through `TaskCenter` so it appears in the Tasks popover and
    /// is cancellable, with completion feedback.
    func performCompression(request: CompressionRequest, tasks: TaskCenterAdapter) {
        guard let helper = SevenZipLocator.helperURL() else {
            operationError = "The 7-Zip engine isn’t available."
            compressionRequested = false
            return
        }
        let errors = CompressionPlanner.validate(request)
        guard errors.isEmpty else {
            operationError = errors.map(CompressionPlanner.describe).joined(separator: "\n")
            compressionRequested = false
            return
        }
        let engine = SevenZipEngine(executableURL: helper)
        let operation = CreateArchiveOperation(
            engine: engine,
            destination: request.destination,
            sources: request.sources,
            options: ArchiveOptions(
                format: request.format,
                password: request.password,
                compressionLevel: request.level,
                encryptFileNames: request.encryptFileNames,
                advanced: request.advanced
            )
        )
        compressionRequested = false
        Task {
            await tasks.submit(operation)
            lastOperationMessage = "Creating \(request.destination.lastPathComponent)…"
        }
    }

    // MARK: - Archive integrity

    /// Runs `7zz t` on the currently open archive. Password-protected archives are
    /// refused with an explanation rather than silently using an insecure transport.
    func testCurrentArchive() async {
        guard let archiveURL else { return }
        guard let helper = SevenZipLocator.helperURL() else {
            operationError = "The 7-Zip engine isn’t available."
            return
        }
        do {
            let engine = SevenZipEngine(executableURL: helper)
            let result = try await engine.test(archive: archiveURL)
            testResultMessage = result.passed ? "Archive is OK." : result.message
        } catch ArchiveError.passwordTransportUnavailable {
            operationError = "This archive is password-protected. Secure password entry isn’t available yet, so Mac7Zip won’t pass your password in a way other processes can read."
        } catch {
            operationError = Self.archiveMessage(error)
        }
    }

    private static func archiveMessage(_ error: Error) -> String {
        guard let archiveError = error as? ArchiveError else { return error.localizedDescription }
        switch archiveError {
        case .passwordRequired: return "This archive requires a password."
        case .wrongPassword: return "The password is incorrect."
        case .corrupt(let detail): return "The archive appears to be damaged. \(detail)"
        case .unsupportedFormat(let format): return "Unsupported archive format: \(format)."
        case .cancelled: return "The operation was cancelled."
        case .outOfMemory: return "Not enough memory to complete the operation."
        case .engineNotFound: return "The 7-Zip engine isn’t available."
        case .passwordTransportUnavailable: return "Secure password entry isn’t available yet."
        case .notImplemented: return "This feature isn’t implemented yet."
        case .unsafeEntry(let paths, let reason):
            let list = paths.isEmpty ? "" : " (\(paths.prefix(3).joined(separator: ", ")))"
            return "Extraction refused for safety: \(reason)\(list)."
        case .engineFailure(_, let diagnostic):
            return diagnostic.isEmpty ? "The archive engine failed." : diagnostic
        }
    }

    // MARK: - File operations

    func newFolder(named name: String) async {
        guard canModify else { return }
        do {
            _ = try await fileOperations.createFolder(named: name, in: currentDirectory)
            reload()
        } catch {
            operationError = Self.operationMessage(error)
        }
    }

    func rename(_ item: FileItem, to newName: String) async {
        guard canModify else { return }
        do {
            _ = try await fileOperations.rename(item.url, to: newName)
            reload()
        } catch {
            operationError = Self.operationMessage(error)
        }
    }

    func deleteSelected() async {
        guard canModify else { return }
        let targets = selectedItems
        guard !targets.isEmpty else { return }
        do {
            for item in targets { try await fileOperations.moveToTrash(item.url) }
            reload()
        } catch {
            operationError = Self.operationMessage(error)
        }
    }

    // MARK: - Helpers

    private func refreshNavigationFlags() {
        canGoBack = historyIndex > 0
        canGoForward = historyIndex < history.count - 1
    }

    private static func operationMessage(_ error: Error) -> String {
        guard let fileError = error as? FileError else { return error.localizedDescription }
        switch fileError {
        case .accessDenied(let path): return "You don’t have permission to modify “\(path)”."
        case .notFound(let name): return "“\(name)” no longer exists."
        case .alreadyExists(let name): return "“\(name)” already exists."
        case .invalidName(let name): return "“\(name)” is not a valid name."
        case .operationFailed(let message): return message
        case .cancelled: return "The operation was cancelled."
        }
    }

    private static func message(for error: Error, location: BrowserLocation) -> String {
        if let providerError = error as? FileSystemProviderError {
            switch providerError {
            case .unsupportedLocation: return "This location can’t be browsed here."
            }
        }
        let name: String
        switch location {
        case .real(let url): name = url.lastPathComponent
        case .archive(let url, _): name = url.lastPathComponent
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
            return "“\(name)” can’t be opened because you don’t have permission to view it."
        }
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(EACCES) {
            return "You don’t have permission to view this location."
        }
        return error.localizedDescription
    }
}

/// Backwards-compatible name used by Phase 0 UI code.
typealias FileBrowserModel = BrowserStore
