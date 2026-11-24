import XCTest
@testable import Mac7Zip

final class BrowserLocationTests: XCTestCase {
    func testRealLocationExposesURL() {
        let url = URL(fileURLWithPath: "/Users/example")
        let location = BrowserLocation.real(url)
        XCTAssertEqual(location.realURL?.path, "/Users/example")
        XCTAssertFalse(location.isArchive)
        XCTAssertNotNil(location.standardizedRealURL)
    }

    func testArchiveLocationHasNoRealURL() {
        let location = BrowserLocation.archive(
            archiveURL: URL(fileURLWithPath: "/tmp/a.zip"),
            internalPath: "folder/file.txt"
        )
        XCTAssertNil(location.realURL)
        XCTAssertTrue(location.isArchive)
    }

    func testArchiveInternalPathIsNotAFileURL() {
        let location = BrowserLocation.archive(
            archiveURL: URL(fileURLWithPath: "/tmp/a.zip"),
            internalPath: "deep/nested/path"
        )
        // The archive location must never yield a real filesystem URL for internal paths.
        XCTAssertNil(location.realURL)
    }
}
