import XCTest
@testable import Mac7Zip

final class ServiceActionPlannerTests: XCTestCase {
    private let archive = URL(fileURLWithPath: "/tmp/a.7z")
    private let text = URL(fileURLWithPath: "/tmp/a.txt")

    func testOpenArchiveRequiresArchive() {
        XCTAssertEqual(ServiceActionPlanner.plan(for: .openArchive, urls: [archive]), .browse(archive))
        XCTAssertEqual(ServiceActionPlanner.plan(for: .openArchive, urls: [text]), .none)
        XCTAssertEqual(ServiceActionPlanner.plan(for: .openArchive, urls: []), .none)
    }

    func testExtractHere() {
        XCTAssertEqual(ServiceActionPlanner.plan(for: .extractHere, urls: [archive]), .extract(archive: archive, subfolder: false))
        XCTAssertEqual(ServiceActionPlanner.plan(for: .extractToFolder, urls: [archive]), .extract(archive: archive, subfolder: true))
    }

    func testTestArchive() {
        XCTAssertEqual(ServiceActionPlanner.plan(for: .testArchive, urls: [archive]), .test(archive: archive))
        XCTAssertEqual(ServiceActionPlanner.plan(for: .testArchive, urls: [text]), .none)
    }

    func testAddToArchiveSuggestsName() {
        guard case .create(let sources, let name) = ServiceActionPlanner.plan(for: .addToArchive, urls: [archive]) else {
            return XCTFail("expected create")
        }
        XCTAssertEqual(sources, [archive])
        XCTAssertEqual(name, "a.7z")

        guard case .create(let multi, let multiName) = ServiceActionPlanner.plan(for: .addToArchive, urls: [archive, text]) else {
            return XCTFail("expected create")
        }
        XCTAssertEqual(multi.count, 2)
        XCTAssertEqual(multiName, "Archive.7z")
    }

    func testTitles() {
        XCTAssertEqual(ServiceAction.extractHere.menuTitle, "Extract Here")
        XCTAssertEqual(ServiceAction.extractToFolder.menuTitle, "Extract to <name>/")
    }
}

final class QuickLookTempWorkspaceTests: XCTestCase {
    func testCreateAndCleanUp() throws {
        var workspace = QuickLookTempWorkspace()
        let dir = try workspace.create()
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
        try "x".write(to: dir.appendingPathComponent("preview.txt"), atomically: true, encoding: .utf8)

        workspace.cleanUp()
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path), "Temp workspace must be removed")
        workspace.cleanUp() // idempotent
    }

    func testCleanUpWithoutCreateIsNoOp() {
        let workspace = QuickLookTempWorkspace()
        workspace.cleanUp()
    }
}

final class AcceptanceDocsTests: XCTestCase {
    private var repoRoot: URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("project.yml").path) { return dir }
        }
        return dir
    }

    func testAcceptanceCoversAllMiAcs() {
        let url = repoRoot.appendingPathComponent("docs/execution/ACCEPTANCE.md")
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        for ac in ["AC-MI-1", "AC-MI-2", "AC-MI-3", "AC-MI-4", "AC-MI-5", "AC-MI-6"] {
            XCTAssertTrue(text.contains(ac), "ACCEPTANCE.md must cover \(ac)")
        }
    }

    func testProjectDeclaresServices() {
        let yml = (try? String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)) ?? ""
        XCTAssertTrue(yml.contains("NSServices"))
        XCTAssertTrue(yml.contains("openArchiveService"))
    }
}
