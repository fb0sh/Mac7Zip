import XCTest
@testable import Mac7Zip

/// Behaviour tests for the interactions users actually perform (navigation,
/// selection, sorting, opening). These are the gaps behind "体验感很差".
@MainActor
final class BrowserNavigationBehaviorTests: XCTestCase {
    private var root: URL!
    private var store: BrowserStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipNav-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in ["alpha.txt", "beta.txt", "Gamma.txt"] {
            try "x".write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("sub", isDirectory: true),
            withIntermediateDirectories: true
        )
        store = BrowserStore(startingAt: root)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    /// Waits for the async reload triggered by navigation.
    private func settle(_ expectation: () -> Bool, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if expectation() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func testInitialLocationIsTheGivenFolder() {
        XCTAssertEqual(store.currentDirectory.standardizedFileURL, root.standardizedFileURL)
        XCTAssertFalse(store.isInsideArchive)
    }

    func testLoadListsFolderContents() async {
        store.reload()
        await settle { !store.items.isEmpty }
        let names = Set(store.items.map(\.name))
        XCTAssertEqual(names, ["alpha.txt", "beta.txt", "Gamma.txt", "sub"])
        XCTAssertEqual(store.loadState, .loaded)
    }

    func testDirectoriesSortBeforeFiles() async {
        store.reload()
        await settle { !store.items.isEmpty }
        XCTAssertTrue(store.items.first?.isDirectory ?? false, "Folders must come first")
    }

    func testNavigateIntoSubfolderAndBack() async {
        store.reload()
        await settle { !store.items.isEmpty }
        let sub = root.appendingPathComponent("sub")
        store.navigate(to: sub)
        XCTAssertEqual(store.currentDirectory.standardizedFileURL, sub.standardizedFileURL)
        XCTAssertTrue(store.canGoBack)

        store.goBack()
        XCTAssertEqual(store.currentDirectory.standardizedFileURL, root.standardizedFileURL)
        XCTAssertTrue(store.canGoForward)
    }

    func testGoUpFromRootGoesToParent() async {
        store.reload()
        await settle { !store.items.isEmpty }
        store.goUp()
        XCTAssertEqual(store.currentDirectory.standardizedFileURL, root.deletingLastPathComponent().standardizedFileURL)
    }

    func testHistoryTruncatesAfterNewNavigation() async {
        store.reload()
        await settle { !store.items.isEmpty }
        let sub = root.appendingPathComponent("sub")
        store.navigate(to: sub)
        store.goBack()
        // Navigating somewhere new must discard the forward history.
        store.navigate(to: root.appendingPathComponent("sub"))
        XCTAssertFalse(store.canGoForward)
    }

    func testSortTogglesDirectionAndKeepsCount() async {
        store.reload()
        await settle { !store.items.isEmpty }
        let count = store.items.count
        store.setSort(field: .name, ascending: true)
        let asc = store.items.filter { !$0.isDirectory }.map(\.name)
        store.toggleSort(field: .name)
        let desc = store.items.filter { !$0.isDirectory }.map(\.name)
        XCTAssertEqual(asc, desc.reversed())
        XCTAssertEqual(store.items.count, count)
    }

    func testSelectionSurvivesSortButNotNavigation() async {
        store.reload()
        await settle { !store.items.isEmpty }
        guard let first = store.items.first else { return XCTFail("no items") }
        store.selection = [first.id]
        store.setSort(field: .size, ascending: true)
        XCTAssertTrue(store.selection.contains(first.id), "Sorting must keep the selection")

        store.navigate(to: root.appendingPathComponent("sub"))
        XCTAssertTrue(store.selection.isEmpty, "Navigating must clear the selection")
    }

    func testSelectedSizeSumsOnlySelection() async {
        store.reload()
        await settle { !store.items.isEmpty }
        let files = store.items.filter { !$0.isDirectory }
        guard files.count >= 2 else { return XCTFail("need files") }
        store.selection = [files[0].id, files[1].id]
        XCTAssertEqual(store.selectedSize, files[0].size + files[1].size)
    }

    func testOpenFolderNavigatesInsteadOfOpeningExternally() async {
        store.reload()
        await settle { !store.items.isEmpty }
        guard let sub = store.items.first(where: { $0.isDirectory }) else { return XCTFail("no folder") }
        store.open(sub)
        XCTAssertEqual(store.currentDirectory.standardizedFileURL, sub.url.standardizedFileURL)
    }

    func testArchiveCapabilitiesAreReadOnly() {
        let archive = ArchiveFileSystemProvider(
            engine: StubArchiveEngine(entries: []),
            archiveURL: URL(fileURLWithPath: "/tmp/a.zip")
        )
        XCTAssertFalse(archive.capabilities.contains(.createDirectory))
        XCTAssertFalse(archive.capabilities.contains(.delete))
    }

    func testSortDescriptorDefaultsAreStable() {
        let descriptor = FileSortDescriptor.default
        XCTAssertEqual(descriptor.field, .name)
        XCTAssertTrue(descriptor.ascending)
    }
}
