import XCTest
@testable import Mac7Zip

final class ArchiveFileIconCatalogTests: XCTestCase {
    func testResourceNameSanitizesDots() {
        XCTAssertEqual(ArchiveFileIconCatalog.resourceName(forExtension: "7z"), "7z")
        XCTAssertEqual(ArchiveFileIconCatalog.resourceName(forExtension: "tar.gz"), "tar_gz")
        XCTAssertNil(ArchiveFileIconCatalog.resourceName(forExtension: "txt"))
    }

    func testLongestSuffixWins() {
        XCTAssertEqual(ArchiveFileIconCatalog.resourceName(forFileName: "backup.tar.gz"), "tar_gz")
        XCTAssertEqual(ArchiveFileIconCatalog.resourceName(forFileName: "backup.tar.xz"), "tar_xz")
        XCTAssertEqual(ArchiveFileIconCatalog.resourceName(forFileName: "photo.ZIP"), "zip")
        XCTAssertEqual(ArchiveFileIconCatalog.resourceName(forFileName: "plain.txt"), nil)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(ArchiveFileIconCatalog.resourceName(forFileName: "A.Tar.Gz"), "tar_gz")
    }
}

final class ArchiveFileIconResourceTests: XCTestCase {
    private var repoRoot: URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("project.yml").path) { return dir }
        }
        return dir
    }

    func testEveryCatalogExtensionHasAnIcns() {
        let dir = repoRoot.appendingPathComponent("Sources/Resources/FileIcons")
        for ext in ArchiveFileIconCatalog.extensions {
            let name = ArchiveFileIconCatalog.resourceName(forExtension: ext)!
            let file = dir.appendingPathComponent(name + ".icns")
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "Missing icon \(name).icns")
            let size = (try? Data(contentsOf: file).count) ?? 0
            XCTAssertGreaterThan(size, 1000, "\(name).icns looks empty")
        }
    }

    func testIcnsMagic() throws {
        let dir = repoRoot.appendingPathComponent("Sources/Resources/FileIcons")
        let data = try Data(contentsOf: dir.appendingPathComponent("7z.icns"))
        XCTAssertEqual(Array(data.prefix(4)), Array("icns".utf8))
    }

    func testProjectDeclaresPerExtensionIcons() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        XCTAssertTrue(yml.contains("CFBundleTypeIconFile: 7z"))
        XCTAssertTrue(yml.contains("CFBundleTypeIconFile: tar_gz"))
    }
}

final class ExtensionPackagingTests: XCTestCase {
    private var repoRoot: URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("project.yml").path) { return dir }
        }
        return dir
    }

    private func yml() -> String {
        (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
    }

    func testPreviewExtensionDeclaresQuickLookPoint() {
        let text = yml()
        XCTAssertTrue(text.contains("com.apple.quicklook.preview"), "Preview extension must declare its NSExtensionPointIdentifier in properties")
        XCTAssertTrue(text.contains("Mac7ZipPreview"))
    }

    func testFinderSyncDeclaresItsPoint() {
        XCTAssertTrue(yml().contains("com.apple.FinderSync"))
    }

    func testBothExtensionsAreEmbedded() {
        let text = yml()
        XCTAssertTrue(text.contains("- target: Mac7ZipFinderSync\n        embed: true"))
        XCTAssertTrue(text.contains("- target: Mac7ZipPreview\n        embed: true"))
    }

    func testExtensionsHaveSandboxEntitlements() {
        for name in ["Mac7ZipFinderSync", "Mac7ZipPreview"] {
            let url = repoRoot.appendingPathComponent("Support/\(name).entitlements")
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            XCTAssertTrue(text.contains("com.apple.security.app-sandbox"), "\(name) must be sandboxed")
        }
    }

    func testImportedTypesDeclareIcons() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        for icon in ["UTTypeIconFile: 7z", "UTTypeIconFile: gz", "UTTypeIconFile: tar_gz", "UTTypeIconFile: xz", "UTTypeIconFile: rar"] {
            XCTAssertTrue(yml.contains(icon), "Missing \(icon)")
        }
    }

    func testQuickLookExtensionsDeclared() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        XCTAssertTrue(yml.contains("com.apple.quicklook.preview"))
        XCTAssertTrue(yml.contains("Mac7ZipPreview"))
        XCTAssertTrue(yml.contains("- target: Mac7ZipPreview\n        embed: true"))
    }

    /// Regression: a catch-all document type used to claim `org.7-zip.7-zip-archive`
    /// with the `zip` icon, so LaunchServices resolved .7z to zip. Each UTI must be
    /// claimed by at most one document type, and that type's icon must be the one
    /// declared for the UTI.
    func testNoDocumentTypeClaimsAnotherTypesUTIWithADifferentIcon() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        XCTAssertFalse(
            yml.contains("CFBundleTypeIconFile: zip\n            LSItemContentTypes:\n              - org.7-zip.7-zip-archive"),
            "The zip catch-all must not claim the 7z UTI"
        )
        XCTAssertTrue(yml.contains("CFBundleTypeIconFile: 7z\n            CFBundleTypeExtensions: [\"7z\"]\n            LSItemContentTypes: [org.7-zip.7-zip-archive]"))
    }

    /// Data-based Quick Look previews must declare the flag and subclass
    /// QLPreviewProvider, otherwise Quick Look reports "Principal object invalid".
    func testPreviewExtensionIsDataBased() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        XCTAssertTrue(yml.contains("QLIsDataBasedPreview: true"), "Preview extension must set QLIsDataBasedPreview")
        let source = (try? String(contentsOf: repoRoot.appendingPathComponent("Sources/Mac7ZipPreview/PreviewProvider.swift"), encoding: .utf8)) ?? ""
        XCTAssertTrue(source.contains("QLPreviewProvider"), "PreviewProvider must subclass QLPreviewProvider")
    }
}
