import XCTest
@testable import Mac7Zip

/// Guards against "icon slot declared but no image" — the exact bug that shipped a
/// blank app icon (TKT-M6-07 follow-up).
final class AppIconTests: XCTestCase {
    private var repoRoot: URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("project.yml").path) { return dir }
        }
        return dir
    }

    private var iconSetDir: URL {
        repoRoot.appendingPathComponent("Sources/Resources/Assets.xcassets/AppIcon.appiconset")
    }

    private func contentsJSON() throws -> [String: Any] {
        let url = iconSetDir.appendingPathComponent("Contents.json")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testEveryIconSlotHasARealImage() throws {
        let json = try contentsJSON()
        let images = try XCTUnwrap(json["images"] as? [[String: Any]])
        XCTAssertFalse(images.isEmpty, "AppIcon must declare image slots")

        for slot in images {
            let name = try XCTUnwrap(
                slot["filename"] as? String,
                "Slot \(slot["size"] ?? "?")/\(slot["scale"] ?? "?") has no filename — the app icon would be blank"
            )
            let path = iconSetDir.appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.fileExists(atPath: path.path), "Missing icon file: \(name)")
            let size = (try? Data(contentsOf: path).count) ?? 0
            XCTAssertGreaterThan(size, 200, "Icon file \(name) looks empty/truncated")
        }
    }

    func testIconPixelsMatchDeclaredSize() throws {
        let json = try contentsJSON()
        let images = try XCTUnwrap(json["images"] as? [[String: Any]])
        for slot in images {
            guard let name = slot["filename"] as? String,
                  let sizeString = slot["size"] as? String,
                  let scale = slot["scale"] as? String else { continue }
            let points = Double(sizeString.split(separator: "x").first.map(String.init) ?? "") ?? 0
            let factor = Double(scale.replacingOccurrences(of: "x", with: "")) ?? 1
            let expected = Int(points * factor)
            let data = try Data(contentsOf: iconSetDir.appendingPathComponent(name))
            let (w, h) = try PNGSize.read(data)
            XCTAssertEqual(w, expected, "\(name) width")
            XCTAssertEqual(h, expected, "\(name) height")
        }
    }

    func testAccentColorIsDefined() throws {
        let url = repoRoot.appendingPathComponent("Sources/Resources/Assets.xcassets/AccentColor.colorset/Contents.json")
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let colors = try XCTUnwrap(json["colors"] as? [[String: Any]])
        XCTAssertFalse(colors.isEmpty)
        XCTAssertNotNil(colors.first?["color"], "AccentColor must define an actual colour")
    }

    func testProjectReferencesAppIcon() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        XCTAssertTrue(yml.contains("ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon"))
        XCTAssertTrue(yml.contains("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor"))
    }
}

/// Minimal PNG header reader (width/height from IHDR).
enum PNGSize {
    enum Failure: Error { case badSignature, badHeader }

    static func read(_ data: Data) throws -> (Int, Int) {
        let sig: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard data.count > 24, Array(data.prefix(8)) == sig else { throw Failure.badSignature }
        let bytes = [UInt8](data[16..<24])
        let w = bytes[0..<4].reduce(0) { $0 << 8 | Int($1) }
        let h = bytes[4..<8].reduce(0) { $0 << 8 | Int($1) }
        guard w > 0, h > 0 else { throw Failure.badHeader }
        return (w, h)
    }
}
