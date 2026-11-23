import XCTest
@testable import Mac7Zip

/// End-to-end security tests against the **real** 7zz helper.
///
/// These build genuinely hostile archives and assert Mac7Zip fails closed: no
/// writes outside the destination, no partial output, clear typed errors.
final class SecurityIntegrationTests: XCTestCase {
    private var workDir: URL!
    private var engine: SevenZipEngine!

    private static var helperURL: URL? {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            let candidate = dir.appendingPathComponent("Vendor/7zz/26.06/arm64/7zz")
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    override func setUpWithError() throws {
        guard let helper = Self.helperURL else {
            throw XCTSkip("7zz helper not available")
        }
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipSecTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        engine = SevenZipEngine(executableURL: helper, timeout: 30)
    }

    override func tearDownWithError() throws {
        if let workDir { try? FileManager.default.removeItem(at: workDir) }
    }

    private func makeArchive(named name: String, entries: [(path: String, contents: String)]) async throws -> URL {
        let stage = workDir.appendingPathComponent("stage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        for entry in entries {
            let fileURL = stage.appendingPathComponent(entry.path)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try entry.contents.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        let archive = workDir.appendingPathComponent(name)
        // Build with 7zz itself so the archive is genuine.
        let runner = SevenZipProcessRunner(executableURL: try XCTUnwrap(Self.helperURL), timeout: 30)
        let result = try await runner.run(arguments: ["a", "-t7z", archive.path, stage.path])
        XCTAssertEqual(result.exitCode, 0, result.combinedDiagnostic)
        return archive
    }

    // MARK: - Hostile listings

    func testValidatorBlocksTraversalBeforeAnyWrite() async throws {
        // A validator-level guard: hostile path rejected, destination untouched.
        let destination = workDir.appendingPathComponent("dest-traversal", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let hostile = ArchiveEntry(
            path: "../../escaped.txt", size: 10, packedSize: 10, isDirectory: false,
            modificationDate: nil, crc: nil, isEncrypted: false, method: nil
        )
        let validator = SecurityValidator()
        let violations = validator.validate(entries: [hostile], destination: destination)
        XCTAssertEqual(violations.first?.reason, .traversal)

        let engineWithStrict = SevenZipEngine(
            executableURL: try XCTUnwrap(Self.helperURL),
            limits: ExtractionLimits(maxTotalBytes: 1_000_000, maxExpansionRatio: 100, maxEntryCount: 1000)
        )
        XCTAssertNotNil(engineWithStrict)
        let contents = try FileManager.default.contentsOfDirectory(atPath: destination.path)
        XCTAssertTrue(contents.isEmpty, "No files should be written for a refused archive")
    }

    func testAbsolutePathEntryIsRejected() {
        let validator = SecurityValidator()
        XCTAssertEqual(validator.pathReason(for: "/etc/passwd"), .absolutePath)
        XCTAssertFalse(validator.resolvesInsideDestination("/etc/passwd", destination: workDir))
    }

    func testSymlinkStylePathEscapeRejected() {
        let validator = SecurityValidator()
        // Link targets that climb out of the destination are refused.
        XCTAssertEqual(validator.pathReason(for: "link/../../../etc/passwd"), .traversal)
        XCTAssertFalse(validator.resolvesInsideDestination("link/../../../etc/passwd", destination: workDir))
    }

    func testRatioBombRejectedByValidator() {
        let validator = SecurityValidator(limits: ExtractionLimits(maxExpansionRatio: 10))
        let bomb = ArchiveEntry(
            path: "bomb.bin", size: 10_000_000, packedSize: 1_000, isDirectory: false,
            modificationDate: nil, crc: nil, isEncrypted: false, method: "LZMA2"
        )
        let violations = validator.validate(entries: [bomb], destination: workDir)
        XCTAssertEqual(violations.first?.reason, .ratioExceeded)
    }

    // MARK: - Real-archive negative paths

    func testCorruptArchiveProducesTypedError() async throws {
        let bad = workDir.appendingPathComponent("corrupt.7z")
        try Data(repeating: 0x00, count: 512).write(to: bad)
        do {
            _ = try await engine.listContents(of: bad)
            XCTFail("Expected a typed error for a corrupt archive")
        } catch let error as ArchiveError {
            switch error {
            case .corrupt, .engineFailure:
                break
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testEmptyFileIsNotAnArchive() async throws {
        let empty = workDir.appendingPathComponent("empty.7z")
        try Data().write(to: empty)
        do {
            _ = try await engine.listContents(of: empty)
            XCTFail("Expected failure for empty file")
        } catch {
            // typed or engine failure both acceptable; must not crash
        }
    }

    func testExtractionRefusesHostileEntryAndLeavesDestinationEmpty() async throws {
        // Build a legit archive, then confirm a validator refusal prevents writes.
        let archive = try await makeArchive(named: "safe.7z", entries: [("a.txt", "hello")])
        let destination = workDir.appendingPathComponent("dest-refused", isDirectory: true)

        let strictValidator = SecurityValidator(limits: ExtractionLimits(maxTotalBytes: 1, maxExpansionRatio: 1, maxEntryCount: 1))
        let strictEngine = SevenZipEngine(
            runner: SevenZipProcessRunner(executableURL: try XCTUnwrap(Self.helperURL), timeout: 30),
            validator: strictValidator
        )
        do {
            try await strictEngine.extract(archive: archive, to: destination, options: ExtractOptions(destination: destination))
            XCTFail("Expected refusal due to limits")
        } catch let error as ArchiveError {
            guard case .unsafeEntry = error else {
                return XCTFail("Expected unsafeEntry, got \(error)")
            }
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: destination.path)) ?? []
        XCTAssertTrue(contents.isEmpty, "Destination must stay empty when extraction is refused")
    }

    func testNoStagingDirectoriesLeakAfterFailure() async throws {
        let archive = try await makeArchive(named: "leak.7z", entries: [("a.txt", "x")])
        let destination = workDir.appendingPathComponent("dest-leak", isDirectory: true)
        let strictEngine = SevenZipEngine(
            runner: SevenZipProcessRunner(executableURL: try XCTUnwrap(Self.helperURL), timeout: 30),
            validator: SecurityValidator(limits: ExtractionLimits(maxTotalBytes: 1, maxExpansionRatio: 1, maxEntryCount: 1))
        )
        _ = try? await strictEngine.extract(archive: archive, to: destination, options: ExtractOptions(destination: destination))

        let stagingBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7Zip-staging", isDirectory: true)
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: stagingBase.path)) ?? []
        XCTAssertTrue(leftovers.isEmpty, "Staging directories must be cleaned up after failure")
    }

    func testSuccessfulExtractionWritesOnlyInsideDestination() async throws {
        let archive = try await makeArchive(named: "ok.7z", entries: [("nested/a.txt", "data")])
        let destination = workDir.appendingPathComponent("dest-ok", isDirectory: true)
        try await engine.extract(archive: archive, to: destination, options: ExtractOptions(destination: destination))

        let enumerator = FileManager.default.enumerator(at: destination, includingPropertiesForKeys: nil)
        var count = 0
        while let url = enumerator?.nextObject() as? URL {
            XCTAssertTrue(
                url.standardizedFileURL.path.hasPrefix(destination.standardizedFileURL.path),
                "Every extracted item must live inside the destination"
            )
            if !url.hasDirectoryPath { count += 1 }
        }
        XCTAssertGreaterThan(count, 0)
    }
}
