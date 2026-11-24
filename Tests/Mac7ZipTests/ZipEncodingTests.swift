import XCTest
@testable import Mac7Zip

final class ZipEncodingTests: XCTestCase {
    func testCodePageMapping() {
        XCTAssertNil(ZipFileNameEncoding.auto.codePage)
        XCTAssertEqual(ZipFileNameEncoding.gbk.codePage, 936)
        XCTAssertEqual(ZipFileNameEncoding.big5.codePage, 950)
        XCTAssertEqual(ZipFileNameEncoding.utf8.codePage, 65001)
    }

    func testDefaultsToAuto() {
        XCTAssertEqual(AppSettings().zipEncoding, .auto)
    }

    func testZipFamilyDetection() {
        XCTAssertTrue(SevenZipEngine.isZipFamily(URL(fileURLWithPath: "/a/b.zip")))
        XCTAssertTrue(SevenZipEngine.isZipFamily(URL(fileURLWithPath: "/a/b.APK")))
        XCTAssertTrue(SevenZipEngine.isZipFamily(URL(fileURLWithPath: "/a/b.docx")))
        XCTAssertFalse(SevenZipEngine.isZipFamily(URL(fileURLWithPath: "/a/b.7z")))
        XCTAssertFalse(SevenZipEngine.isZipFamily(URL(fileURLWithPath: "/a/b.tar.gz")))
    }
}
