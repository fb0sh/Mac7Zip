import AppKit
import Combine
import Foundation

/// Owns the browsing state for the main window: current directory, listing,
/// selection, sort configuration, and navigation history. All mutation happens
/// on the main actor; disk reads are delegated to `FileSystemService`.
@MainActor
final class FileBrowserModel: ObservableObject {
    @Published private(set) var currentDirectory: URL
    @Published private(set) var items: [FileItem] = []
    @Published var selection: Set<FileItem.ID> = []
    @Published var sortDescriptor: FileSortDescriptor = .default
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false

    private let fileSystem: FileSystemService
    private var history: [URL]
    private var historyIndex: Int

    init(
        startingAt url: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileSystem: FileSystemService = FileSystemService()
    ) {
        let standardized = url.standardizedFileURL
        self.currentDirectory = standardized
        self.fileSystem = fileSystem
        self.history = [standardized]
        self.historyIndex = 0
    }

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
        let directory = currentDirectory
        isLoading = true
        Task {
            do {
                let contents = try await fileSystem.contents(of: directory)
                guard directory == currentDirectory else { return }
                items = FileSorting.sorted(contents, by: sortDescriptor)
                let validIDs = Set(items.map(\.id))
                selection = selection.intersection(validIDs)
                errorMessage = nil
            } catch {
                guard directory == currentDirectory else { return }
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
