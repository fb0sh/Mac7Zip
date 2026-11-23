import XCTest
@testable import Mac7Zip

final class DragExportPlannerTests: XCTestCase {
    private func file(_ name: String, dir: Bool = false) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            isDirectory: dir,
            size: 1,
            modificationDate: nil,
            kind: "File"
        )
    }

    func testRealFilesDragAsFileURLs() {
        let payload = DragExportPlanner.payload(for: file("a.txt"), isInsideArchive: false)
        guard case .fileURL(let url) = payload else {
            return XCTFail("Expected a file URL payload")
        }
        XCTAssertEqual(url.lastPathComponent, "a.txt")
    }

    func testArchiveFilesDragAsPromises() {
        let payload = DragExportPlanner.payload(for: file("docs/a.txt"), isInsideArchive: true)
        guard case .promise(let entryPath, let fileName) = payload else {
            return XCTFail("Expected a promise payload")
        }
        XCTAssertEqual(entryPath, "docs/a.txt")
        XCTAssertEqual(fileName, "a.txt")
    }

    func testArchiveDirectoriesAreNotDraggable() {
        let payload = DragExportPlanner.payload(for: file("docs", dir: true), isInsideArchive: true)
        XCTAssertEqual(payload, .none)
    }

    func testFileTypeResolution() {
        XCTAssertEqual(DragExportPlanner.fileType(for: "a.txt"), "public.plain-text")
        XCTAssertFalse(DragExportPlanner.fileType(for: "noext").isEmpty)
        XCTAssertEqual(DragExportPlanner.fileType(for: "weird.zzzqqq"), "public.data")
    }
}
