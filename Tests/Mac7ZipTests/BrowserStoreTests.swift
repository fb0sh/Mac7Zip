import XCTest
@testable import Mac7Zip

/// Minimal provider that returns an empty listing; used to exercise navigation
/// and sort state without touching the real filesystem.
private struct EmptyProvider: FileSystemProvider {
    var kind: FileSystemProviderKind { .real }
    var capabilities: FileSystemCapabilities { [.list] }
    func list(_ location: BrowserLocation) async throws -> [FileItem] { [] }
}

@MainActor
final class BrowserStoreTests: XCTestCase {
    private func makeStore(startingAt url: URL) -> BrowserStore {
        BrowserStore(startingAt: url, provider: EmptyProvider(), access: RealFileAccess())
    }

    func testLocationIsReal() {
        let url = URL(fileURLWithPath: "/Users/example")
        let store = makeStore(startingAt: url)
        XCTAssertEqual(store.location, .real(url.standardizedFileURL))
    }

    func testNavigateBuildsHistoryAndBackForward() {
        let a = URL(fileURLWithPath: "/tmp/a")
        let b = URL(fileURLWithPath: "/tmp/b")
        let store = makeStore(startingAt: a)
        XCTAssertFalse(store.canGoBack)
        XCTAssertFalse(store.canGoForward)

        store.navigate(to: b)
        XCTAssertTrue(store.canGoBack)

        store.goBack()
        XCTAssertFalse(store.canGoBack)
        XCTAssertTrue(store.canGoForward)

        store.goForward()
        XCTAssertFalse(store.canGoForward)
    }

    func testNavigationClearsSelection() {
        let a = URL(fileURLWithPath: "/tmp/a")
        let b = URL(fileURLWithPath: "/tmp/b")
        let store = makeStore(startingAt: a)
        store.selection = [URL(fileURLWithPath: "/tmp/a/file.txt")]
        store.navigate(to: b)
        XCTAssertTrue(store.selection.isEmpty)
    }

    func testSortToggle() {
        let store = makeStore(startingAt: URL(fileURLWithPath: "/tmp/a"))
        XCTAssertEqual(store.sortDescriptor.field, .name)
        XCTAssertTrue(store.sortDescriptor.ascending)

        store.toggleSort(field: .name)
        XCTAssertEqual(store.sortDescriptor.field, .name)
        XCTAssertFalse(store.sortDescriptor.ascending)

        store.toggleSort(field: .size)
        XCTAssertEqual(store.sortDescriptor.field, .size)
        XCTAssertTrue(store.sortDescriptor.ascending)
    }

    func testResolveNavigationTargetForExistingDirectory() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = makeStore(startingAt: dir)
        let resolved = store.resolveNavigationTarget(dir.path)
        XCTAssertEqual(resolved?.standardizedFileURL, dir.standardizedFileURL)
    }

    func testResolveNavigationTargetMissingReturnsNil() {
        let store = makeStore(startingAt: URL(fileURLWithPath: "/tmp/a"))
        XCTAssertNil(store.resolveNavigationTarget("/definitely/not/a/real/path/xyz"))
    }
}
