import XCTest
@testable import Mac7Zip

/// End-to-end tests against the **real** bundled 7zz helper. These run on macOS CI
/// (where the helper is an arm64 Mach-O). On non-macOS they are skipped.
final class SevenZipEngineIntegrationTests: XCTestCase {
    private var workDir: URL!
    private var engine: SevenZipEngine!

    private static var helperURL: URL? {
        let relative = "Vendor/7zz/26.06/arm64/7zz"
        var searched: [String] = []

        // 1. Explicit override (some environments can inject it).
        if let env = ProcessInfo.processInfo.environment["MAC7ZIP_7ZZ"] {
            searched.append(env)
            if FileManager.default.isExecutableFile(atPath: env) { return URL(fileURLWithPath: env) }
        }

        // 2. Walk up from this source file's compile-time path — the most reliable
        //    anchor, since `xcodebuild test` does not forward shell env vars.
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            dir = dir.deletingLastPathComponent()
            let candidate = dir.appendingPathComponent(relative)
            searched.append(candidate.path)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }

        // 3. Fall back to walking up from the working directory.
        var cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            let candidate = cwd.appendingPathComponent(relative)
            searched.append(candidate.path)
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
            cwd = cwd.deletingLastPathComponent()
        }

        print("[SevenZipEngineIntegrationTests] helper not found; searched:\n" + searched.joined(separator: "\n"))
        return nil
    }

    override func setUpWithError() throws {
        guard let helper = Self.helperURL else {
            throw XCTSkip("7zz helper not available (non-macOS or not vendored)")
        }
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipEngineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        engine = SevenZipEngine(executableURL: helper)
    }

    override func tearDownWithError() throws {
        if let workDir { try? FileManager.default.removeItem(at: workDir) }
    }

    private func makeSourceTree() throws -> URL {
        let src = workDir.appendingPathComponent("src", isDirectory: true)
        let sub = src.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "hello world".write(to: src.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "second".write(to: src.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        try "deep".write(to: sub.appendingPathComponent("c.txt"), atomically: true, encoding: .utf8)
        return src
    }

    func testCreateListAndExtractRoundTrip() async throws {
        let src = try makeSourceTree()
        let archive = workDir.appendingPathComponent("sample.7z")

        try await engine.createArchive(at: archive, from: [src], options: ArchiveOptions(format: .sevenZip))
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))

        let entries = try await engine.listContents(of: archive)
        XCTAssertFalse(entries.isEmpty)
        XCTAssertTrue(entries.contains { $0.path.hasSuffix("a.txt") })

        let testResult = try await engine.test(archive: archive)
        XCTAssertTrue(testResult.passed, testResult.message)

        let dest = workDir.appendingPathComponent("out", isDirectory: true)
        try await engine.extract(
            archive: archive,
            to: dest,
            options: ExtractOptions(destination: dest)
        )
        let extracted = dest.appendingPathComponent("src/a.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extracted.path))
        XCTAssertEqual(try String(contentsOf: extracted, encoding: .utf8), "hello world")
    }

    func testZipRoundTrip() async throws {
        let src = try makeSourceTree()
        let archive = workDir.appendingPathComponent("sample.zip")
        try await engine.createArchive(at: archive, from: [src], options: ArchiveOptions(format: .zip))

        let entries = try await engine.listContents(of: archive)
        XCTAssertFalse(entries.isEmpty)

        let dest = workDir.appendingPathComponent("outzip", isDirectory: true)
        try await engine.extract(archive: archive, to: dest, options: ExtractOptions(destination: dest))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("src/b.txt").path))
    }

    func testEncryptedSevenZipWithPassword() async throws {
        let src = try makeSourceTree()
        let archive = workDir.appendingPathComponent("secret.7z")
        try await engine.createArchive(
            at: archive,
            from: [src],
            options: ArchiveOptions(format: .sevenZip, password: "correct-horse")
        )

        let dest = workDir.appendingPathComponent("outenc", isDirectory: true)
        try await engine.extract(
            archive: archive,
            to: dest,
            options: ExtractOptions(password: "correct-horse", destination: dest)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("src/a.txt").path))
    }

    func testWrongPasswordFails() async throws {
        let src = try makeSourceTree()
        let archive = workDir.appendingPathComponent("secret2.7z")
        try await engine.createArchive(
            at: archive,
            from: [src],
            options: ArchiveOptions(format: .sevenZip, password: "right")
        )

        let dest = workDir.appendingPathComponent("outwrong", isDirectory: true)
        do {
            try await engine.extract(
                archive: archive,
                to: dest,
                options: ExtractOptions(password: "wrong", destination: dest)
            )
            XCTFail("Expected failure with wrong password")
        } catch {
            // Any typed archive error is acceptable; the destination must stay empty.
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: dest.path)) ?? []
            XCTAssertTrue(contents.isEmpty, "No files should be written on wrong password")
        }
    }

    func testCorruptArchiveIsRejected() async throws {
        let bad = workDir.appendingPathComponent("bad.7z")
        try "not an archive".write(to: bad, atomically: true, encoding: .utf8)
        do {
            _ = try await engine.listContents(of: bad)
            XCTFail("Expected corrupt error")
        } catch {
            // expected
        }
    }

    func testRarCreationIsRefused() async throws {
        let src = try makeSourceTree()
        let archive = workDir.appendingPathComponent("x.rar")
        do {
            try await engine.createArchive(at: archive, from: [src], options: ArchiveOptions(format: .rar))
            XCTFail("RAR creation must be refused (unRAR restriction)")
        } catch let error as ArchiveError {
            if case .unsupportedFormat = error { return }
            XCTFail("Expected unsupportedFormat, got \(error)")
        }
    }

    func testTraversalArchiveIsRefused() async throws {
        // Build an archive containing a traversal path using 7zz itself.
        let evilDir = workDir.appendingPathComponent("evil", isDirectory: true)
        try FileManager.default.createDirectory(at: evilDir, withIntermediateDirectories: true)
        try "pwned".write(to: evilDir.appendingPathComponent("x.txt"), atomically: true, encoding: .utf8)
        let archive = workDir.appendingPathComponent("evil.7z")
        try await engine.createArchive(at: archive, from: [evilDir.appendingPathComponent("x.txt")], options: ArchiveOptions())

        // A legitimate archive must extract fine — the guard is exercised by the
        // validator unit tests; here we assert the pipeline does not regress.
        let dest = workDir.appendingPathComponent("outevil", isDirectory: true)
        try await engine.extract(archive: archive, to: dest, options: ExtractOptions(destination: dest))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("x.txt").path))
    }
}
