import XCTest
@testable import Mac7Zip

final class FileMetadataServiceTests: XCTestCase {
    private var root: URL!
    private var service: FileMetadataService!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipMeta-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        service = FileMetadataService()
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    func testPermissionStringFormatting() {
        XCTAssertEqual(FileMetadata.describe(0o755), "rwxr-xr-x")
        XCTAssertEqual(FileMetadata.describe(0o644), "rw-r--r--")
        XCTAssertEqual(FileMetadata.describe(0o700), "rwx------")
        XCTAssertEqual(FileMetadata.describe(0o000), "---------")
    }

    func testFileMetadata() throws {
        let url = root.appendingPathComponent("a.txt")
        try "hello".write(to: url, atomically: true, encoding: .utf8)
        let meta = try service.metadata(for: url)
        XCTAssertEqual(meta.name, "a.txt")
        XCTAssertFalse(meta.isDirectory)
        XCTAssertEqual(meta.size, 5)
        XCTAssertNotNil(meta.modificationDate)
        XCTAssertNotNil(meta.permissionString)
        XCTAssertEqual(meta.permissionString?.count, 9)
    }

    func testDirectoryItemCount() throws {
        let dir = root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for index in 0..<3 {
            try "x".write(to: dir.appendingPathComponent("f\(index)"), atomically: true, encoding: .utf8)
        }
        let meta = try service.metadata(for: dir)
        XCTAssertTrue(meta.isDirectory)
        XCTAssertEqual(meta.itemCount, 3)
    }

    func testMissingFileThrowsTypedError() {
        let missing = root.appendingPathComponent("nope.txt")
        XCTAssertThrowsError(try service.metadata(for: missing))
    }

    func testSetPermissionsRoundTrip() throws {
        let url = root.appendingPathComponent("perm.txt")
        try "x".write(to: url, atomically: true, encoding: .utf8)
        try service.setPermissions(0o600, for: url)
        let meta = try service.metadata(for: url)
        XCTAssertEqual(meta.posixPermissions, 0o600)
        XCTAssertEqual(meta.permissionString, "rw-------")

        try service.setPermissions(0o644, for: url)
        XCTAssertEqual(try service.metadata(for: url).posixPermissions, 0o644)
    }

    func testSymlinkMetadata() throws {
        let target = root.appendingPathComponent("target.txt")
        try "t".write(to: target, atomically: true, encoding: .utf8)
        let link = root.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: target.path)
        let meta = try service.metadata(for: link)
        XCTAssertTrue(meta.isSymlink)
        XCTAssertEqual(meta.linkTarget, target.path)
    }

    // MARK: - Finder tags (M4-08)

    func testFinderTagsRoundTrip() throws {
        let url = root.appendingPathComponent("tagged.txt")
        try "x".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertTrue(FinderTagService.tags(for: url).isEmpty)

        try FinderTagService.setTags(["Red", "Work"], for: url)
        XCTAssertEqual(FinderTagService.tags(for: url), ["Red", "Work"])

        try FinderTagService.setTags([], for: url)
        XCTAssertTrue(FinderTagService.tags(for: url).isEmpty)
    }

    func testTagsAppearInMetadata() throws {
        let url = root.appendingPathComponent("meta-tag.txt")
        try "x".write(to: url, atomically: true, encoding: .utf8)
        try FinderTagService.setTags(["Green"], for: url)
        XCTAssertEqual(try service.metadata(for: url).finderTags, ["Green"])
    }
}
