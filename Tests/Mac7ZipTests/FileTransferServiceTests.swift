import XCTest
@testable import Mac7Zip

final class FileTransferServiceTests: XCTestCase {
    private var root: URL!
    private var sourceDir: URL!
    private var destDir: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipTransfer-\(UUID().uuidString)", isDirectory: true)
        sourceDir = root.appendingPathComponent("src", isDirectory: true)
        destDir = root.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private func makeFile(_ name: String, in dir: URL, contents: String = "data") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func request(_ kind: FileTransferRequest.Kind, _ sources: [URL], policy: ConflictPolicy = .replace) -> FileTransferRequest {
        FileTransferRequest(kind: kind, sources: sources, destinationDirectory: destDir, conflictPolicy: policy)
    }

    // MARK: - Copy

    func testCopyFiles() throws {
        let a = try makeFile("a.txt", in: sourceDir)
        let b = try makeFile("b.txt", in: sourceDir)
        let outcomes = try FileTransferService.performSynchronously(request(.copy, [a, b]), fileManager: .default)
        XCTAssertEqual(outcomes.count, 2)
        XCTAssertTrue(outcomes.allSatisfy { $0.status == .copied })
        XCTAssertTrue(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("a.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceDir.appendingPathComponent("a.txt").path),
                      "Copy must keep the source")
    }

    func testCopyDirectoryRecursively() throws {
        let nested = sourceDir.appendingPathComponent("folder/sub", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        _ = try makeFile("deep.txt", in: nested, contents: "deep")
        let outcomes = try FileTransferService.performSynchronously(
            request(.copy, [sourceDir.appendingPathComponent("folder")]),
            fileManager: .default
        )
        XCTAssertEqual(outcomes.first?.status, .copied)
        let copied = destDir.appendingPathComponent("folder/sub/deep.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: copied.path))
        XCTAssertEqual(try String(contentsOf: copied, encoding: .utf8), "deep")
    }

    // MARK: - Move

    func testMoveRemovesSource() throws {
        let a = try makeFile("move.txt", in: sourceDir, contents: "x")
        let outcomes = try FileTransferService.performSynchronously(request(.move, [a]), fileManager: .default)
        XCTAssertEqual(outcomes.first?.status, .moved)
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("move.txt").path))
    }

    // MARK: - Conflicts

    func testSkipKeepsExisting() throws {
        let a = try makeFile("dup.txt", in: sourceDir, contents: "new")
        _ = try makeFile("dup.txt", in: destDir, contents: "old")
        let outcomes = try FileTransferService.performSynchronously(request(.copy, [a], policy: .skip), fileManager: .default)
        XCTAssertEqual(outcomes.first?.status, .skipped)
        XCTAssertEqual(try String(contentsOf: destDir.appendingPathComponent("dup.txt"), encoding: .utf8), "old")
    }

    func testReplaceOverwrites() throws {
        let a = try makeFile("dup.txt", in: sourceDir, contents: "new")
        _ = try makeFile("dup.txt", in: destDir, contents: "old")
        let outcomes = try FileTransferService.performSynchronously(request(.copy, [a], policy: .replace), fileManager: .default)
        XCTAssertEqual(outcomes.first?.status, .copied)
        XCTAssertEqual(try String(contentsOf: destDir.appendingPathComponent("dup.txt"), encoding: .utf8), "new")
    }

    func testKeepBothCreatesSuffixedCopy() throws {
        let a = try makeFile("dup.txt", in: sourceDir, contents: "new")
        _ = try makeFile("dup.txt", in: destDir, contents: "old")
        let outcomes = try FileTransferService.performSynchronously(request(.copy, [a], policy: .keepBoth), fileManager: .default)
        XCTAssertEqual(outcomes.first?.status, .copied)
        XCTAssertEqual(outcomes.first?.destination?.lastPathComponent, "dup (2).txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("dup (2).txt").path))
        XCTAssertEqual(try String(contentsOf: destDir.appendingPathComponent("dup.txt"), encoding: .utf8), "old")
    }

    // MARK: - Duplicate

    func testDuplicateKeepsSourceAndSuffixes() throws {
        let a = try makeFile("single.txt", in: destDir, contents: "v")
        let outcomes = try FileTransferService.performSynchronously(
            FileTransferRequest(kind: .duplicate, sources: [a], destinationDirectory: destDir, conflictPolicy: .keepBoth),
            fileManager: .default
        )
        XCTAssertEqual(outcomes.first?.status, .duplicated)
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("single (2).txt").path))
    }

    // MARK: - Partial failure reporting

    func testMissingSourceReportsFailureWithoutAbortingBatch() throws {
        let missing = sourceDir.appendingPathComponent("nope.txt")
        let good = try makeFile("good.txt", in: sourceDir)
        let outcomes = try FileTransferService.performSynchronously(request(.copy, [missing, good]), fileManager: .default)
        XCTAssertEqual(outcomes.count, 2)
        if case .failed = outcomes[0].status {} else { XCTFail("Expected first item to fail") }
        XCTAssertEqual(outcomes[1].status, .copied)
    }

    // MARK: - Symlinks

    func testSymlinkIsPreservedNotFollowed() throws {
        let target = try makeFile("target.txt", in: root, contents: "target")
        let link = sourceDir.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: target.path)

        let outcomes = try FileTransferService.performSynchronously(request(.copy, [link]), fileManager: .default)
        XCTAssertEqual(outcomes.first?.status, .copied)
        let copiedLink = destDir.appendingPathComponent("link.txt")
        XCTAssertTrue(FileTransferService.isSymlink(copiedLink), "Symlink must remain a link, not a copy of its target")
    }

    func testUniqueSiblingNaming() {
        let dir = root!
        let existing = dir.appendingPathComponent("x.7z")
        XCTAssertEqual(FileTransferService.uniqueSibling(of: existing, fileManager: .default).lastPathComponent, "x (2).7z")
    }
}
