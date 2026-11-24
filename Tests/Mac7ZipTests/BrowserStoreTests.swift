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

    // MARK: - Archive browsing (TKT-M2-05)

    private func makeStubProvider(_ entries: [ArchiveEntry]) -> FileSystemProvider {
        ArchiveFileSystemProvider(engine: StubArchiveEngine(entries: entries), archiveURL: URL(fileURLWithPath: "/tmp/a.zip"))
    }

    func testOpenArchiveSwitchesLocation() {
        let zipURL = URL(fileURLWithPath: "/tmp/a.zip")
        let entries = [
            ArchiveEntry(path: "docs", size: 0, packedSize: 0, isDirectory: true, modificationDate: nil, crc: nil, isEncrypted: false, method: nil),
            ArchiveEntry(path: "docs/x.txt", size: 3, packedSize: 3, isDirectory: false, modificationDate: nil, crc: nil, isEncrypted: false, method: "Deflate"),
        ]
        let store = BrowserStore(
            startingAt: URL(fileURLWithPath: "/tmp"),
            provider: RealFileSystemProvider(),
            access: RealFileAccess(),
            archiveProviderFactory: { _ in
                ArchiveFileSystemProvider(engine: StubArchiveEngine(entries: entries), archiveURL: zipURL)
            }
        )
        store.openArchive(zipURL)
        XCTAssertTrue(store.isInsideArchive)
        XCTAssertEqual(store.archiveInternalPath, "")
        XCTAssertFalse(store.canModify, "Archive locations are read-only")
    }

    func testNavigateInsideArchiveAndGoUp() {
        let zipURL = URL(fileURLWithPath: "/tmp/a.zip")
        let entries = [
            ArchiveEntry(path: "docs/x.txt", size: 3, packedSize: 3, isDirectory: false, modificationDate: nil, crc: nil, isEncrypted: false, method: "Deflate"),
        ]
        let store = BrowserStore(
            startingAt: URL(fileURLWithPath: "/tmp"),
            access: RealFileAccess(),
            archiveProviderFactory: { _ in
                ArchiveFileSystemProvider(engine: StubArchiveEngine(entries: entries), archiveURL: zipURL)
            }
        )
        store.openArchive(zipURL)
        store.navigateToArchivePath("docs")
        XCTAssertEqual(store.archiveInternalPath, "docs")

        store.goUp()
        XCTAssertEqual(store.archiveInternalPath, "")

        store.goUp()
        XCTAssertFalse(store.isInsideArchive, "Going up from archive root leaves the archive")
    }

    func testArchivePathsNeverBecomeRealLocations() {
        let zipURL = URL(fileURLWithPath: "/tmp/a.zip")
        let store = BrowserStore(
            startingAt: URL(fileURLWithPath: "/tmp"),
            access: RealFileAccess(),
            archiveProviderFactory: { _ in
                ArchiveFileSystemProvider(engine: StubArchiveEngine(entries: []), archiveURL: zipURL)
            }
        )
        store.openArchive(zipURL)
        store.navigateToArchivePath("deep/nested")
        guard case .archive(_, let internalPath) = store.location else {
            return XCTFail("Expected archive location")
        }
        XCTAssertEqual(internalPath, "deep/nested")
        XCTAssertNil(store.location.realURL)
    }

    // MARK: - Regression: back from archive must restore the real provider

    func testGoingBackFromArchiveListsRealDirectory() async {
        let realDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipBack-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: realDir, withIntermediateDirectories: true)
        try? "x".write(to: realDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: realDir) }

        let zipURL = URL(fileURLWithPath: "/tmp/a.zip")
        let store = BrowserStore(
            startingAt: realDir,
            access: RealFileAccess(),
            archiveProviderFactory: { _ in
                ArchiveFileSystemProvider(engine: StubArchiveEngine(entries: []), archiveURL: zipURL)
            }
        )
        store.reload()
        await waitUntil { !store.items.isEmpty }

        store.openArchive(zipURL)
        XCTAssertTrue(store.isInsideArchive)

        store.goBack()
        XCTAssertFalse(store.isInsideArchive)
        await waitUntil { !store.items.isEmpty }
        XCTAssertNil(store.errorMessage, "Back to a real folder must not raise unsupported-location")
        XCTAssertEqual(store.items.map(\.name), ["file.txt"])
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
