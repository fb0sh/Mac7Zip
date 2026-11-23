import XCTest
@testable import Mac7Zip

final class FileSizeFormatterTests: XCTestCase {
    func testZeroBytes() {
        XCTAssertEqual(FileSizeFormatter.string(fromByteCount: 0), "0 bytes")
    }

    func testNegativeTreatedAsZero() {
        XCTAssertEqual(FileSizeFormatter.string(fromByteCount: -10), "0 bytes")
    }

    func testSubKilobyte() {
        XCTAssertEqual(FileSizeFormatter.string(fromByteCount: 999), "999 bytes")
    }

    func testOneKilobyte() {
        XCTAssertEqual(FileSizeFormatter.string(fromByteCount: 1_000), "1 KB")
    }

    func testFractionalKilobyte() {
        XCTAssertEqual(FileSizeFormatter.string(fromByteCount: 1_500), "1.5 KB")
    }

    func testMegabytes() {
        XCTAssertEqual(FileSizeFormatter.string(fromByteCount: 1_000_000), "1 MB")
    }

    func testFractionalMegabytes() {
        XCTAssertEqual(FileSizeFormatter.string(fromByteCount: 2_500_000), "2.5 MB")
    }

    func testGigabytes() {
        XCTAssertEqual(FileSizeFormatter.string(fromByteCount: 3_000_000_000), "3 GB")
    }
}
