import XCTest
@testable import Mac7Zip

final class SecurityValidatorTests: XCTestCase {
    private let destination = URL(fileURLWithPath: "/tmp/dest", isDirectory: true)

    private func entry(_ path: String, size: Int64 = 10, packed: Int64 = 10, isDirectory: Bool = false) -> ArchiveEntry {
        ArchiveEntry(
            path: path,
            size: size,
            packedSize: packed,
            isDirectory: isDirectory,
            modificationDate: nil,
            crc: nil,
            isEncrypted: false,
            method: nil
        )
    }

    func testAcceptsSafeEntries() {
        let validator = SecurityValidator()
        let entries = [entry("folder"), entry("folder/a.txt"), entry("b.txt")]
        XCTAssertTrue(validator.validate(entries: entries, destination: destination).isEmpty)
    }

    func testRejectsAbsolutePath() {
        let validator = SecurityValidator()
        XCTAssertEqual(validator.pathReason(for: "/etc/passwd"), .absolutePath)
        XCTAssertEqual(validator.pathReason(for: "~/secret"), .absolutePath)
        XCTAssertEqual(validator.pathReason(for: "C:/Windows"), .absolutePath)
    }

    func testRejectsTraversal() {
        let validator = SecurityValidator()
        XCTAssertEqual(validator.pathReason(for: "../evil.txt"), .traversal)
        XCTAssertEqual(validator.pathReason(for: "a/../../evil.txt"), .traversal)
        XCTAssertNil(validator.pathReason(for: "a/../b.txt"), "net-zero traversal stays inside")
    }

    func testTraversalReportedAsViolation() {
        let validator = SecurityValidator()
        let violations = validator.validate(entries: [entry("../evil.txt")], destination: destination)
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations[0].reason, .traversal)
    }

    func testRejectsExpansionRatio() {
        let validator = SecurityValidator(limits: ExtractionLimits(maxExpansionRatio: 10))
        let violations = validator.validate(entries: [entry("bomb.bin", size: 1000, packed: 1)], destination: destination)
        XCTAssertEqual(violations.first?.reason, .ratioExceeded)
    }

    func testRejectsTotalSizeOverLimit() {
        let validator = SecurityValidator(limits: ExtractionLimits(maxTotalBytes: 100))
        let violations = validator.validate(
            entries: [entry("a", size: 60), entry("b", size: 60)],
            destination: destination
        )
        XCTAssertTrue(violations.contains { $0.reason == .sizeLimitExceeded })
    }

    func testRejectsTooManyEntries() {
        let validator = SecurityValidator(limits: ExtractionLimits(maxEntryCount: 2))
        let violations = validator.validate(
            entries: [entry("a"), entry("b"), entry("c")],
            destination: destination
        )
        XCTAssertTrue(violations.contains { $0.reason == .entryCountExceeded })
    }

    func testContainmentCheck() {
        let validator = SecurityValidator()
        XCTAssertTrue(validator.resolvesInsideDestination("a/b.txt", destination: destination))
        XCTAssertTrue(validator.resolvesInsideDestination("a/../b.txt", destination: destination))
        XCTAssertFalse(validator.resolvesInsideDestination("../escape.txt", destination: destination))
    }
}

final class StagingAreaTests: XCTestCase {
    private var destination: URL!

    override func setUpWithError() throws {
        destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipStagingDest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let destination { try? FileManager.default.removeItem(at: destination) }
    }

    func testStagingDirectoryIsCreatedAndCleanedUp() throws {
        let staging = try StagingArea()
        let path = staging.url
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
        staging.cleanUp()
        XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
    }

    func testCleanUpIsIdempotent() throws {
        let staging = try StagingArea()
        staging.cleanUp()
        staging.cleanUp()
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.url.path))
    }

    func testCommitMovesItemsToDestination() throws {
        let staging = try StagingArea()
        try "hello".write(
            to: staging.url.appendingPathComponent("a.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "deep".write(
            to: staging.url.appendingPathComponent("b.txt"),
            atomically: true,
            encoding: .utf8
        )

        let committed = try staging.commit(to: destination)
        XCTAssertEqual(committed, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("a.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("b.txt").path))
        staging.cleanUp()
    }

    func testByteCountTracksStagedData() throws {
        let staging = try StagingArea()
        XCTAssertEqual(staging.currentByteCount(), 0)
        let data = Data(repeating: 0x41, count: 1024)
        try data.write(to: staging.url.appendingPathComponent("blob.bin"))
        XCTAssertGreaterThanOrEqual(staging.currentByteCount(), 1024)
        staging.cleanUp()
    }
}

final class SecurityValidatorContainmentTests: XCTestCase {
    func testAbsolutePathsAreNeverContained() {
        let validator = SecurityValidator()
        let dest = URL(fileURLWithPath: "/tmp/dest", isDirectory: true)
        XCTAssertFalse(validator.resolvesInsideDestination("/etc/passwd", destination: dest))
        XCTAssertFalse(validator.resolvesInsideDestination("~/secret", destination: dest))
        XCTAssertFalse(validator.resolvesInsideDestination("C:/Windows", destination: dest))
    }

    func testTraversalIsNeverContained() {
        let validator = SecurityValidator()
        let dest = URL(fileURLWithPath: "/tmp/dest", isDirectory: true)
        XCTAssertFalse(validator.resolvesInsideDestination("../escape", destination: dest))
        XCTAssertFalse(validator.resolvesInsideDestination("a/../../escape", destination: dest))
    }

    func testNormalRelativePathsAreContained() {
        let validator = SecurityValidator()
        let dest = URL(fileURLWithPath: "/tmp/dest", isDirectory: true)
        XCTAssertTrue(validator.resolvesInsideDestination("a/b.txt", destination: dest))
        XCTAssertTrue(validator.resolvesInsideDestination("a/../b.txt", destination: dest))
    }
}
