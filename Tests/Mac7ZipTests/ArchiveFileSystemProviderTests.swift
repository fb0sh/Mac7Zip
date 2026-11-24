import XCTest
@testable import Mac7Zip

struct StubArchiveEngine: ArchiveEngine {
    let entries: [ArchiveEntry]
    var createCalled = false

    func createArchive(at destination: URL, from sources: [URL], options: ArchiveOptions) async throws {}
    func extract(archive: URL, to destination: URL, options: ExtractOptions) async throws {}
    func listContents(of archive: URL) async throws -> [ArchiveEntry] { entries }
    func test(archive: URL) async throws -> ArchiveTestResult { ArchiveTestResult(passed: true, message: "ok") }
}

final class ArchiveFileSystemProviderTests: XCTestCase {
    private let archive = URL(fileURLWithPath: "/tmp/photos.zip")

    private func entry(_ path: String, isDirectory: Bool = false, size: Int64 = 10) -> ArchiveEntry {
        ArchiveEntry(
            path: path,
            size: size,
            packedSize: size,
            isDirectory: isDirectory,
            modificationDate: nil,
            crc: nil,
            isEncrypted: false,
            method: isDirectory ? nil : "Deflate"
        )
    }

    private func sampleEntries() -> [ArchiveEntry] {
        [
            entry("photos", isDirectory: true),
            entry("photos/a.jpg", size: 100),
            entry("photos/b.jpg", size: 200),
            entry("photos/holiday", isDirectory: true),
            entry("photos/holiday/c.jpg", size: 300),
            entry("readme.txt", size: 5),
        ]
    }

    func testRootListingShowsDirectChildrenOnly() {
        let items = ArchiveFileSystemProvider.directoryListing(
            entries: sampleEntries(),
            prefix: "",
            archiveURL: archive
        )
        let names = Set(items.map(\.name))
        XCTAssertEqual(names, ["photos", "readme.txt"])
        XCTAssertTrue(items.first { $0.name == "photos" }?.isDirectory ?? false)
        XCTAssertFalse(items.first { $0.name == "readme.txt" }?.isDirectory ?? true)
    }

    func testNestedListing() {
        let items = ArchiveFileSystemProvider.directoryListing(
            entries: sampleEntries(),
            prefix: "photos",
            archiveURL: archive
        )
        let names = Set(items.map(\.name))
        XCTAssertEqual(names, ["a.jpg", "b.jpg", "holiday"])
        XCTAssertEqual(items.first { $0.name == "a.jpg" }?.size, 100)
    }

    func testDeepNestedListing() {
        let items = ArchiveFileSystemProvider.directoryListing(
            entries: sampleEntries(),
            prefix: "photos/holiday",
            archiveURL: archive
        )
        XCTAssertEqual(Set(items.map(\.name)), ["c.jpg"])
    }

    func testDirectoriesAreSynthesisedWhenNotExplicitlyListed() {
        // Some engines omit folder entries entirely.
        let entries = [entry("a/b/c.txt", size: 1)]
        let root = ArchiveFileSystemProvider.directoryListing(entries: entries, prefix: "", archiveURL: archive)
        XCTAssertEqual(Set(root.map(\.name)), ["a"])
        XCTAssertTrue(root[0].isDirectory)

        let level2 = ArchiveFileSystemProvider.directoryListing(entries: entries, prefix: "a", archiveURL: archive)
        XCTAssertEqual(Set(level2.map(\.name)), ["b"])
    }

    func testProviderIsReadOnly() {
        let provider = ArchiveFileSystemProvider(engine: StubArchiveEngine(entries: sampleEntries()), archiveURL: archive)
        XCTAssertEqual(provider.kind, .archive)
        XCTAssertTrue(provider.capabilities.contains(.list))
        XCTAssertTrue(provider.capabilities.contains(.readFile))
        XCTAssertFalse(provider.capabilities.contains(.writeFile))
        XCTAssertFalse(provider.capabilities.contains(.rename))
        XCTAssertFalse(provider.capabilities.contains(.delete))
        XCTAssertFalse(provider.capabilities.contains(.createDirectory))
    }

    func testProviderRejectsRealLocation() async {
        let provider = ArchiveFileSystemProvider(engine: StubArchiveEngine(entries: sampleEntries()), archiveURL: archive)
        do {
            _ = try await provider.list(.real(URL(fileURLWithPath: "/tmp")))
            XCTFail("Expected unsupportedLocation")
        } catch let error as FileSystemProviderError {
            XCTAssertEqual(error, .unsupportedLocation)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProviderRejectsOtherArchive() async {
        let provider = ArchiveFileSystemProvider(engine: StubArchiveEngine(entries: sampleEntries()), archiveURL: archive)
        do {
            _ = try await provider.list(.archive(archiveURL: URL(fileURLWithPath: "/tmp/other.zip"), internalPath: ""))
            XCTFail("Expected unsupportedLocation")
        } catch let error as FileSystemProviderError {
            XCTAssertEqual(error, .unsupportedLocation)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNormalizeStripsSlashesAndBackslashes() {
        XCTAssertEqual(ArchiveFileSystemProvider.normalize("/a/b/"), "a/b")
        XCTAssertEqual(ArchiveFileSystemProvider.normalize("a\\b"), "a/b")
        XCTAssertEqual(ArchiveFileSystemProvider.normalize(""), "")
    }

    func testBreadcrumbs() {
        XCTAssertEqual(ArchiveFileSystemProvider.breadcrumbs(prefix: "a/b/c"), ["a", "b", "c"])
        XCTAssertTrue(ArchiveFileSystemProvider.breadcrumbs(prefix: "").isEmpty)
    }

    func testArchiveEntriesNeverExposeRealURLs() {
        // The synthetic URL ends with the internal path, but `BrowserLocation`
        // still marks it as an archive location — the provider rejects `.real`.
        let items = ArchiveFileSystemProvider.directoryListing(
            entries: sampleEntries(),
            prefix: "",
            archiveURL: archive
        )
        XCTAssertTrue(items.allSatisfy { $0.url.path.hasPrefix(archive.path) })
    }
}

final class ArchiveMetadataMappingTests: XCTestCase {
    func testFileEntriesCarryArchiveMetadata() {
        let entries = [
            ArchiveEntry(path: "a.txt", size: 12, packedSize: 28, isDirectory: false,
                         modificationDate: nil, crc: "ABCD1234", isEncrypted: true, method: "AES-256"),
        ]
        let items = ArchiveFileSystemProvider.directoryListing(
            entries: entries,
            prefix: "",
            archiveURL: URL(fileURLWithPath: "/tmp/a.7z")
        )
        let item = try? XCTUnwrap(items.first)
        XCTAssertEqual(item?.archiveMetadata?.packedSize, 28)
        XCTAssertEqual(item?.archiveMetadata?.crc, "ABCD1234")
        XCTAssertEqual(item?.archiveMetadata?.isEncrypted, true)
        XCTAssertEqual(item?.archiveMetadata?.method, "AES-256")
    }

    func testRealFileItemsHaveNoArchiveMetadata() {
        let item = FileItem(url: URL(fileURLWithPath: "/tmp/x.txt"), name: "x.txt",
                            isDirectory: false, size: 1, modificationDate: nil, kind: "Document")
        XCTAssertNil(item.archiveMetadata)
    }
}
