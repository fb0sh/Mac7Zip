import XCTest
@testable import Mac7Zip

final class PreviewTargetTests: XCTestCase {
    private func item(_ name: String, dir: Bool = false) -> FileItem {
        FileItem(url: URL(fileURLWithPath: "/tmp/\(name)"), name: name, isDirectory: dir,
                 size: 1, modificationDate: nil, kind: "f")
    }

    func testNoSelection() {
        XCTAssertEqual(PreviewTarget.resolve(item: nil, isInsideArchive: false, archiveURL: nil, internalPath: ""), .none)
    }

    func testRealFile() {
        let target = PreviewTarget.resolve(item: item("a.txt"), isInsideArchive: false, archiveURL: nil, internalPath: "")
        guard case .file(let url) = target else { return XCTFail("expected file") }
        XCTAssertEqual(url.lastPathComponent, "a.txt")
    }

    func testRealFolderIsNotPreviewed() {
        XCTAssertEqual(PreviewTarget.resolve(item: item("docs", dir: true), isInsideArchive: false, archiveURL: nil, internalPath: ""), .none)
    }

    func testArchiveEntryPathIncludesInternalFolder() {
        let archive = URL(fileURLWithPath: "/tmp/a.zip")
        let target = PreviewTarget.resolve(item: item("x.txt"), isInsideArchive: true, archiveURL: archive, internalPath: "docs")
        guard case .archiveEntry(let a, let entry, let name) = target else { return XCTFail("expected entry") }
        XCTAssertEqual(a, archive)
        XCTAssertEqual(entry, "docs/x.txt")
        XCTAssertEqual(name, "x.txt")
    }

    func testArchiveFolderIsNotPreviewed() {
        let archive = URL(fileURLWithPath: "/tmp/a.zip")
        XCTAssertEqual(
            PreviewTarget.resolve(item: item("docs", dir: true), isInsideArchive: true, archiveURL: archive, internalPath: ""),
            .none
        )
    }
}
