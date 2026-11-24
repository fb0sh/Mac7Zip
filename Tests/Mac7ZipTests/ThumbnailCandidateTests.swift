import XCTest
@testable import Mac7Zip

final class ThumbnailCandidateTests: XCTestCase {
    private func entry(_ path: String, _ size: Int64, dir: Bool = false) -> ThumbnailCandidate.Entry {
        ThumbnailCandidate.Entry(path: path, size: size, isDirectory: dir)
    }

    func testPicksLargestImage() {
        let entries = [
            entry("docs/readme.txt", 900),
            entry("docs/small.png", 100),
            entry("docs/big.jpg", 5_000),
            entry("docs/mid.jpeg", 1_000),
        ]
        XCTAssertEqual(ThumbnailCandidate.bestImageEntry(in: entries)?.path, "docs/big.jpg")
    }

    func testIgnoresDirectories() {
        let entries = [entry("cover.png", 10, dir: true), entry("a.txt", 99)]
        XCTAssertNil(ThumbnailCandidate.bestImageEntry(in: entries))
    }

    func testNoImagesReturnsNil() {
        XCTAssertNil(ThumbnailCandidate.bestImageEntry(in: [entry("a.txt", 1), entry("b.bin", 2)]))
    }

    func testCaseInsensitiveExtension() {
        XCTAssertEqual(ThumbnailCandidate.bestImageEntry(in: [entry("COVER.PNG", 5)])?.path, "COVER.PNG")
    }

    func testBadgeText() {
        XCTAssertEqual(ThumbnailCandidate.badgeText(forFileName: "a.zip"), "ZIP")
        XCTAssertEqual(ThumbnailCandidate.badgeText(forFileName: "a.tar.gz"), "TAR.GZ")
        XCTAssertEqual(ThumbnailCandidate.badgeText(forFileName: "a.7z"), "7Z")
        XCTAssertEqual(ThumbnailCandidate.badgeText(forFileName: "noext"), "ARCHIVE")
    }

    func testSummaryText() {
        XCTAssertEqual(ThumbnailCandidate.summaryText(fileCount: 1, folderCount: 0), "1 file")
        XCTAssertEqual(ThumbnailCandidate.summaryText(fileCount: 2, folderCount: 1), "1 folder · 2 files")
        XCTAssertEqual(ThumbnailCandidate.summaryText(fileCount: 0, folderCount: 0), "Empty archive")
    }
}
