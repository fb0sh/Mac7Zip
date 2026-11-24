import XCTest
@testable import Mac7Zip

final class LocalizationTests: XCTestCase {
    private var repoRoot: URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("project.yml").path) { return dir }
        }
        return dir
    }

    private func strings(_ lang: String) -> [String: String] {
        let url = repoRoot.appendingPathComponent("Resources/\(lang).lproj/Localizable.strings")
        guard let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String]
        else { return [:] }
        return dict
    }

    func testChineseLocalizationExistsAndTranslates() {
        let zh = strings("zh-Hans")
        XCTAssertFalse(zh.isEmpty, "zh-Hans Localizable.strings should parse")
        XCTAssertEqual(zh["Cancel"], "取消")
        XCTAssertEqual(zh["New Folder"], "新建文件夹")
        XCTAssertGreaterThan(zh.count, 50, "Coverage should be broad")
    }

    func testEnglishBaseIsIdentity() {
        let en = strings("en")
        XCTAssertEqual(en["Cancel"], "Cancel")
    }

    func testInfoDeclaresChineseLocalization() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        XCTAssertTrue(yml.contains("CFBundleLocalizations"))
        XCTAssertTrue(yml.contains("zh-Hans"))
    }

    func testFinderSyncExtensionDeclared() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        XCTAssertTrue(yml.contains("Mac7ZipFinderSync"))
        XCTAssertTrue(yml.contains("com.apple.FinderSync"))
    }
}
