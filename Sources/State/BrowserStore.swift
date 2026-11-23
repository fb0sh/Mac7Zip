import AppKit
import Combine
import Foundation

/// Owns the browsing state for the main window: location, listing, selection,
/// sort configuration, and navigation history. All mutation happens on the main
/// actor; disk reads are delegated to a `FileSystemProvider` (which uses `FileAccess`).
@MainActor
final class BrowserStore: ObservableObject {
    @Published private(set) var currentDirectory: URL
    @Published private(set) var items: [FileItem] = []
    @Published var selection: Set<FileItem.ID> = []
    @Published var sortDescriptor: FileSortDescriptor = .default
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false

    private let provider: FileSystemProvider
    private let access: FileAccess
    private var history: [URL]
    private var historyIndex: Int

    init(
        startingAt url: URL = FileLocations.home,
        provider: FileSystemProvider = RealFileSystemProvider(),
        access: FileAccess = RealFileAccess()
    ) {
        let standardized = url.standardizedFileURL
        self.currentDirectory = standardized
        self.provider = provider
        self.access = access
        self.history = [standardized]
        self.historyIndex = 0
    }

    /// The current browse location (real filesystem today; archive later).
    var location: BrowserLocation { .real(currentDirectory) }

    /// Capabilities of the active provider (drives UI enable/disable).
    var capabilities: FileSystemCapabilities { provider.capabilities }

    var selectedItems: [FileItem] {
        items.filter { selection.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    // MARK: - Loading

    func loadInitialContentIfNeeded() {
        if items.isEmpty && !isLoading {
            reload()
        }
    }

    func reload() {
        let requestedLocation = location
        let directory = currentDirectory
        isLoading = true
        Task {
            do {
                let contents = try await provider.list(requestedLocation)
                guard currentDirectory == directory else { return }
                items = FileSorting.sorted(contents, by: sortDescriptor)
                let validIDs = Set(items.map(\.id))
                selection = selection.intersection(validIDs)
                errorMessage = nil
            } catch {
                guard currentDirectory == directory else { return }
                items = []
                selection = []
                errorMessage = Self.message(for: error, directory: directory)
            }
            isLoading = false
        }
    }

    // MARK: - Navigation

    func navigate(to url: URL) {
        let target = url.standardizedFileURL
        guard target != currentDirectory else { return }
        history = Array(history.prefix(historyIndex + 1))
        history.append(target)
        historyIndex = history.count - 1
        load(target)
    }

    func goBack() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        load(history[historyIndex])
    }

    func goForward() {
        guard historyIndex < history.count - 1 else { return }
        historyIndex += 1
        load(history[historyIndex])
    }

    func goUp() {
        if let parent = PathUtilities.parent(of: currentDirectory) {
            navigate(to: parent)
        }
    }

    private func load(_ url: URL) {
        currentDirectory = url
        selection = []
        refreshNavigationFlags()
        reload()
    }

    /// Resolves a user-entered path to a navigable directory URL. A file path
    /// resolves to its parent directory; a missing path resolves to nil.
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
            navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func openSelected() {
        if let first = selectedItems.first {
            open(first)
        }
    }

    // MARK: - Helpers

    private func refreshNavigationFlags() {
        canGoBack = historyIndex > 0
        canGoForward = historyIndex < history.count - 1
    }

    private static func message(for error: Error, directory: URL) -> String {
        if let providerError = error as? FileSystemProviderError {
            switch providerError {
            case .unsupportedLocation:
                return "This location can’t be browsed here."
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
            return "“\(directory.lastPathComponent)” can’t be opened because you don’t have permission to view it."
        }
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(EACCES) {
            return "You don’t have permission to view “\(directory.path)”."
        }
        return error.localizedDescription
    }
}

/// Backwards-compatible name used by Phase 0 UI code.
typealias FileBrowserModel = BrowserStore
