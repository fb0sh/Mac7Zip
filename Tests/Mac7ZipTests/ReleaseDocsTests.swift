import XCTest
@testable import Mac7Zip

final class ReleaseDocsTests: XCTestCase {
    private var repoRoot: URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("project.yml").path) { return dir }
        }
        return dir
    }

    private func exists(_ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent(relative).path)
    }

    func testReleaseDocsPresent() {
        XCTAssertTrue(exists("CHANGELOG.md"))
        XCTAssertTrue(exists("THIRD_PARTY_NOTICES.md"))
        XCTAssertTrue(exists("versions.env"))
        XCTAssertTrue(exists("docs/release/PRIVACY.md"))
        XCTAssertTrue(exists("docs/release/RELEASE-NOTES-0.1.0.md"))
        XCTAssertTrue(exists("docs/execution/TOOLCHAIN.md"))
        XCTAssertTrue(exists("docs/execution/PERFORMANCE.md"))
    }

    func testNoticesMentionLicenseAndRestriction() {
        let text = (try? String(contentsOf: repoRoot.appendingPathComponent("THIRD_PARTY_NOTICES.md"), encoding: .utf8)) ?? ""
        XCTAssertTrue(text.contains("LGPL"))
        XCTAssertTrue(text.lowercased().contains("unrar"))
    }

    func testVersionsPinSevenZip() {
        let text = (try? String(contentsOf: repoRoot.appendingPathComponent("versions.env"), encoding: .utf8)) ?? ""
        XCTAssertTrue(text.contains("SEVENZIP_VERSION=26.06"))
        XCTAssertTrue(text.contains("XCODEGEN_VERSION="))
    }
}
