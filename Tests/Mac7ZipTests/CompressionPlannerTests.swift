import XCTest
@testable import Mac7Zip

final class CompressionPlannerTests: XCTestCase {
    private var workDir: URL!
    private var source: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipPlanTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        source = workDir.appendingPathComponent("a.txt")
        try "hello".write(to: source, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        if let workDir { try? FileManager.default.removeItem(at: workDir) }
    }

    private func request(
        format: ArchiveFormat = .sevenZip,
        name: String = "out.7z",
        level: Int = 5
    ) -> CompressionRequest {
        CompressionRequest(
            sources: [source],
            destination: workDir.appendingPathComponent(name),
            format: format,
            level: level
        )
    }

    func testValidRequestHasNoErrors() {
        XCTAssertTrue(CompressionPlanner.validate(request()).isEmpty)
    }

    func testNoSourcesIsRejected() {
        var r = request()
        r.sources = []
        XCTAssertTrue(CompressionPlanner.validate(r).contains(.noSources))
    }

    func testRarCreationIsUnsupported() {
        let r = request(format: .rar, name: "out.rar")
        XCTAssertTrue(CompressionPlanner.validate(r).contains(.unsupportedFormat("RAR")))
    }

    func testTarIsUnsupportedInMvp() {
        let r = request(format: .tar, name: "out.tar")
        XCTAssertTrue(CompressionPlanner.validate(r).contains(.unsupportedFormat("TAR")))
    }

    func testInvalidLevelRejected() {
        var r = request()
        r.level = 99
        XCTAssertTrue(CompressionPlanner.validate(r).contains(.invalidLevel(99)))
    }

    func testDestinationThatIsDirectoryRejected() throws {
        let dir = workDir.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var r = request()
        r.destination = dir
        XCTAssertTrue(CompressionPlanner.validate(r).contains(.destinationIsDirectory("folder")))
    }

    func testArchiveInsideSourceRejected() {
        let r = CompressionRequest(
            sources: [workDir],
            destination: workDir.appendingPathComponent("nested.7z"),
            format: .sevenZip
        )
        XCTAssertTrue(CompressionPlanner.validate(r).contains(.archiveInsideSource(workDir.lastPathComponent)))
    }

    func testEncryptFileNamesRequiresSevenZip() {
        var r = request(format: .zip, name: "out.zip")
        r.encryptFileNames = true
        XCTAssertTrue(CompressionPlanner.validate(r).contains(.encryptFileNamesRequires7z))
    }

    func testPasswordRejectedWhenTransportUnavailable() {
        var r = request()
        r.password = "secret"
        XCTAssertTrue(CompressionPlanner.validate(r, passwordTransportAvailable: false).contains(.passwordUnavailable))
        XCTAssertFalse(CompressionPlanner.validate(r, passwordTransportAvailable: true).contains(.passwordUnavailable))
    }

    func testArgumentMapping() {
        let r = request(format: .zip, name: "out.zip", level: 7)
        let args = CompressionPlanner.arguments(for: r)
        XCTAssertEqual(args.first, "a")
        XCTAssertTrue(args.contains("-tzip"))
        XCTAssertTrue(args.contains("-mx7"))
        XCTAssertTrue(args.contains("-sccUTF-8"))
        XCTAssertEqual(args.last, source.standardizedFileURL.path)
        XCTAssertEqual(args[args.count - 2], r.destination.standardizedFileURL.path)
    }

    func testMethodAndHeaderEncryptionOnlyForSevenZip() {
        var r = request()
        r.method = "LZMA2"
        r.encryptFileNames = true
        let args = CompressionPlanner.arguments(for: r)
        XCTAssertTrue(args.contains("-m0=LZMA2"))
        XCTAssertTrue(args.contains("-mhe"))

        var zip = request(format: .zip, name: "o.zip")
        zip.method = "LZMA2"
        zip.encryptFileNames = true
        let zipArgs = CompressionPlanner.arguments(for: zip)
        XCTAssertFalse(zipArgs.contains("-m0=LZMA2"))
        XCTAssertFalse(zipArgs.contains("-mhe"))
    }

    func testSuggestedArchiveName() {
        XCTAssertEqual(
            CompressionPlanner.suggestedArchiveName(for: [source], format: .sevenZip),
            "a.7z"
        )
        XCTAssertEqual(
            CompressionPlanner.suggestedArchiveName(for: [source, workDir], format: .zip),
            "Archive.zip"
        )
    }

    func testUniqueDestinationSuffixes() throws {
        let target = workDir.appendingPathComponent("out.7z")
        try Data().write(to: target)
        let unique = CompressionPlanner.uniqueDestination(for: target)
        XCTAssertEqual(unique.lastPathComponent, "out (2).7z")
    }

    func testConflictPolicies() throws {
        let target = workDir.appendingPathComponent("exists.7z")
        try Data().write(to: target)
        XCTAssertEqual(CompressionPlanner.resolveConflict(at: target, policy: .replace), target)
        XCTAssertNil(CompressionPlanner.resolveConflict(at: target, policy: .skip))
        XCTAssertEqual(CompressionPlanner.resolveConflict(at: target, policy: .keepBoth)?.lastPathComponent, "exists (2).7z")

        let fresh = workDir.appendingPathComponent("fresh.7z")
        XCTAssertEqual(CompressionPlanner.resolveConflict(at: fresh, policy: .skip), fresh)
    }
}
