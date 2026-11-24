import XCTest
import UniformTypeIdentifiers
@testable import Mac7Zip

final class DragExportPlannerTests: XCTestCase {
    private func makeItem(_ name: String, dir: Bool = false) -> FileItem {
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
        let payload = DragExportPlanner.payload(for: makeItem("a.txt"), isInsideArchive: false)
        guard case .fileURL(let url) = payload else {
            return XCTFail("Expected a file URL payload")
        }
        XCTAssertEqual(url.lastPathComponent, "a.txt")
    }

    func testArchiveFilesDragAsPromises() {
        let payload = DragExportPlanner.payload(for: makeItem("docs/a.txt"), isInsideArchive: true)
        guard case .promise(let entryPath, let fileName, let isDirectory) = payload else {
            return XCTFail("Expected a promise payload")
        }
        XCTAssertEqual(entryPath, "docs/a.txt")
        XCTAssertEqual(fileName, "a.txt")
        XCTAssertFalse(isDirectory)
    }

    func testArchiveDirectoriesDragAsFolderPromises() {
        let payload = DragExportPlanner.payload(for: makeItem("docs", dir: true), isInsideArchive: true)
        guard case .promise(let entryPath, let fileName, let isDirectory) = payload else {
            return XCTFail("Archive folders should be draggable via a promise")
        }
        XCTAssertEqual(entryPath, "docs")
        XCTAssertEqual(fileName, "docs")
        XCTAssertTrue(isDirectory)
        XCTAssertEqual(DragExportPlanner.fileType(for: "docs", isDirectory: true), UTType.folder.identifier)
    }

    func testNestedEntryPathIncludesInternalFolder() {
        let payload = DragExportPlanner.payload(for: makeItem("a.txt"), isInsideArchive: true, internalPath: "docs/sub")
        guard case .promise(let entryPath, _, _) = payload else { return XCTFail("promise") }
        XCTAssertEqual(entryPath, "docs/sub/a.txt")
    }

    func testFileTypeResolution() {
        XCTAssertEqual(DragExportPlanner.fileType(for: "a.txt"), "public.plain-text")
        XCTAssertFalse(DragExportPlanner.fileType(for: "noext").isEmpty)
        // Unknown extensions resolve to a dynamic UTI, which is still a valid type id.
        let unknown = DragExportPlanner.fileType(for: "weird.zzzqqq")
        XCTAssertFalse(unknown.isEmpty)
    }

    func testProducedFileNameUsesLastComponent() {
        XCTAssertEqual(DragExportPlanner.producedFileName(entryPath: "docs/a.txt"), "a.txt")
        XCTAssertEqual(DragExportPlanner.producedFileName(entryPath: "a.txt"), "a.txt")
        XCTAssertEqual(DragExportPlanner.producedFileName(entryPath: "a/b/c/deep.bin"), "deep.bin")
    }

    func testAppBundleDetection() {
        let app = FileItem(url: URL(fileURLWithPath: "/Applications/Safari.app"), name: "Safari.app",
                           isDirectory: true, size: 0, modificationDate: nil, kind: "Application")
        XCTAssertTrue(app.isApplicationBundle)
        let folder = FileItem(url: URL(fileURLWithPath: "/tmp/Documents"), name: "Documents",
                              isDirectory: true, size: 0, modificationDate: nil, kind: "Folder")
        XCTAssertFalse(folder.isApplicationBundle)
        let file = FileItem(url: URL(fileURLWithPath: "/tmp/a.zip"), name: "a.zip",
                            isDirectory: false, size: 1, modificationDate: nil, kind: "ZIP")
        XCTAssertFalse(file.isApplicationBundle)
    }
}
