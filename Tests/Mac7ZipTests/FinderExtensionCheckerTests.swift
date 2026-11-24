import XCTest
@testable import Mac7Zip

final class FinderExtensionCheckerTests: XCTestCase {
    private let id = "com.fb0sh.Mac7Zip.FinderSync"

    func testEmptyOutputMeansNotInstalled() {
        XCTAssertEqual(FinderExtensionChecker.parse("", bundleID: id), .notInstalled)
    }

    func testEnabledLine() {
        let out = "+    com.fb0sh.Mac7Zip.FinderSync(0.1.0)\n-    com.apple.something"
        XCTAssertEqual(FinderExtensionChecker.parse(out, bundleID: id), .enabled)
    }

    func testDisabledLine() {
        let out = "-    com.fb0sh.Mac7Zip.FinderSync(0.1.0)"
        XCTAssertEqual(FinderExtensionChecker.parse(out, bundleID: id), .disabled)
    }

    func testMissingBundleIsNotInstalled() {
        let out = "+    com.other.extension(1.0)"
        XCTAssertEqual(FinderExtensionChecker.parse(out, bundleID: id), .notInstalled)
    }

    func testNeedsAttention() {
        XCTAssertFalse(FinderExtensionState.enabled.needsAttention)
        XCTAssertTrue(FinderExtensionState.disabled.needsAttention)
        XCTAssertTrue(FinderExtensionState.notInstalled.needsAttention)
    }
}
