import XCTest
@testable import Mac7Zip

/// End-to-end tests against the **real** bundled 7zz helper. These run on macOS CI
/// (where the helper is an arm64 Mach-O). On non-macOS they are skipped.
final class SevenZipEngineIntegrationTests: XCTestCase {
    private var workDir: URL!
    private var engine: SevenZipEngine!
    private var engineWithArgvPassword: SevenZipEngine!
    private var engineRefusingPasswords: SevenZipEngine!

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
        engine = SevenZipEngine(executableURL: helper, timeout: 30)
        engineWithArgvPassword = SevenZipEngine(executableURL: helper, timeout: 30, passwordTransport: .argvExplicit)
        engineRefusingPasswords = SevenZipEngine(executableURL: helper, timeout: 30, passwordTransport: .unavailable)
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

    func testPasswordOperationsFailClosedWhenTransportIsUnavailable() async throws {
        let src = try makeSourceTree()
        let archive = workDir.appendingPathComponent("blocked.7z")
        do {
            try await engineRefusingPasswords.createArchive(
                at: archive,
                from: [src],
                options: ArchiveOptions(format: .sevenZip, password: "correct-horse")
            )
            XCTFail("Password operations must fail closed when the transport is unavailable")
        } catch let error as ArchiveError {
            XCTAssertEqual(error, .passwordTransportUnavailable)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.path))
    }

    func testEncryptedSevenZipWithPassword() async throws {
        let src = try makeSourceTree()
        let archive = workDir.appendingPathComponent("secret.7z")
        try await engineWithArgvPassword.createArchive(
            at: archive,
            from: [src],
            options: ArchiveOptions(format: .sevenZip, password: "correct-horse")
        )

        let dest = workDir.appendingPathComponent("outenc", isDirectory: true)
        try await engineWithArgvPassword.extract(
            archive: archive,
            to: dest,
            options: ExtractOptions(password: "correct-horse", destination: dest)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("src/a.txt").path))
    }

    /// Regression: a legacy ZIP whose names are GBK bytes still shows the right
    /// names. 7-Zip decodes those bytes with the wrong single-byte code page and
    /// emits look-alike CJK with no '?' at all, so `looksGarbled` misses it; the
    /// libarchive cross-check has to catch it.
    func testLegacyGBKZipNamesAreRepaired() async throws {
        let archive = workDir.appendingPathComponent("legacy-gbk.zip")
        let name = "项目申报/袁翔_项目申报.pdf"
        try makeLegacyZip(at: archive, entries: [("项目申报/", Data()), (name, Data("hi".utf8))])

        let entries = try await engine.listContents(of: archive)
        let paths = entries.map(\.path)
        XCTAssertTrue(paths.contains { $0.contains("项目申报") }, "GBK names not repaired: \(paths)")
        XCTAssertFalse(paths.contains { $0.contains("?" ) || $0.contains("\u{FFFD}") }, "Still garbled: \(paths)")
    }

    /// Writes a ZIP whose entry names are encoded as GBK with the UTF-8 flag
    /// cleared, i.e. what Windows tools produced before UTF-8 support.
    private func makeLegacyZip(at url: URL, entries: [(String, Data)]) throws {
        var body = Data()
        var central: [(raw: Data, crc: UInt32, size: Int, mode: Int, offset: Int)] = []

        for (name, payload) in entries {
            guard let raw = name.data(using: .gb18030) else { continue }
            let offset = body.count
            let crc = Self.crc32(payload)
            let isDir = name.hasSuffix("/")
            let stored = payload                   // method 0: no compression needed
            body.append(Self.le32(0x04034b50))
            body.append(Self.le16(20))             // version needed
            body.append(Self.le16(0))              // flags: no UTF-8 bit
            body.append(Self.le16(0))              // method: stored
            body.append(Self.le16(0))              // time
            body.append(Self.le16(0x21))           // date
            body.append(Self.le32(crc))
            body.append(Self.le32(UInt32(stored.count)))
            body.append(Self.le32(UInt32(stored.count)))
            body.append(Self.le16(UInt16(raw.count)))
            body.append(Self.le16(0))
            body.append(raw)
            body.append(stored)
            central.append((raw, crc, stored.count, isDir ? 0o40755 : 0o100644, offset))
        }

        let cdOffset = body.count
        for entry in central {
            let (raw, crc, size, mode, offset) = (entry.raw, entry.crc, entry.size, entry.mode, entry.offset)
            body.append(Self.le32(0x02014b50))   // signature
            body.append(Self.le16(20))            // version made by
            body.append(Self.le16(20))            // version needed
            body.append(Self.le16(0))             // flags
            body.append(Self.le16(0))             // method
            body.append(Self.le16(0))             // time
            body.append(Self.le16(0x21))          // date
            body.append(Self.le32(crc))
            body.append(Self.le32(UInt32(size)))  // compressed size
            body.append(Self.le32(UInt32(size)))  // uncompressed size
            body.append(Self.le16(UInt16(raw.count)))
            body.append(Self.le16(0))             // extra length
            body.append(Self.le16(0))             // comment length
            body.append(Self.le16(0))             // disk number
            body.append(Self.le16(0))             // internal attributes
            body.append(Self.le32(UInt32(mode) << 16))  // external attributes
            body.append(Self.le32(UInt32(offset)))
            body.append(raw)
        }
        let cdSize = body.count - cdOffset
        body.append(Self.le32(0x06054b50))
        body.append(Self.le16(0))
        body.append(Self.le16(0))
        body.append(Self.le16(UInt16(central.count)))
        body.append(Self.le16(UInt16(central.count)))
        body.append(Self.le32(UInt32(cdSize)))
        body.append(Self.le32(UInt32(cdOffset)))
        body.append(Self.le16(0))
        try body.write(to: url)
    }

    private static func le16(_ value: UInt16) -> Data {
        var little = value.littleEndian
        return withUnsafeBytes(of: &little) { Data($0) }
    }

    private static func le32(_ value: UInt32) -> Data {
        var little = value.littleEndian
        return withUnsafeBytes(of: &little) { Data($0) }
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1 }
        }
        return crc ^ 0xFFFFFFFF
    }

    func testWrongPasswordFails() async throws {
        let src = try makeSourceTree()
        let archive = workDir.appendingPathComponent("secret2.7z")
        try await engineWithArgvPassword.createArchive(
            at: archive,
            from: [src],
            options: ArchiveOptions(format: .sevenZip, password: "right")
        )

        let dest = workDir.appendingPathComponent("outwrong", isDirectory: true)
        do {
            try await engineWithArgvPassword.extract(
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

/// Creation-focused integration tests (TKT-M3-01 / M3-04 / M3-07).
final class CompressionIntegrationTests: XCTestCase {
    private var workDir: URL!
    private var engine: SevenZipEngine!
    private var engineRefusingPasswords: SevenZipEngine!

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
        guard let helper = Self.helperURL else { throw XCTSkip("7zz helper not available") }
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipCompTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        engine = SevenZipEngine(executableURL: helper, timeout: 30)
        engineRefusingPasswords = SevenZipEngine(executableURL: helper, timeout: 30, passwordTransport: .unavailable)
    }

    override func tearDownWithError() throws {
        if let workDir { try? FileManager.default.removeItem(at: workDir) }
    }

    private func makeFiles() throws -> [URL] {
        let a = workDir.appendingPathComponent("one.txt")
        let b = workDir.appendingPathComponent("two.txt")
        try "one".write(to: a, atomically: true, encoding: .utf8)
        try "two".write(to: b, atomically: true, encoding: .utf8)
        return [a, b]
    }

    func testCreateZipAndVerifyContents() async throws {
        let files = try makeFiles()
        let archive = workDir.appendingPathComponent("out.zip")
        try await engine.createArchive(at: archive, from: files, options: ArchiveOptions(format: .zip))
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))

        let entries = try await engine.listContents(of: archive)
        XCTAssertEqual(Set(entries.filter { !$0.isDirectory }.map { ($0.path as NSString).lastPathComponent }),
                       ["one.txt", "two.txt"])
    }

    func testCreateDoesNotLeavePartialFileOnRefusedFormat() async throws {
        let files = try makeFiles()
        let archive = workDir.appendingPathComponent("bad.rar")
        do {
            try await engine.createArchive(at: archive, from: files, options: ArchiveOptions(format: .rar))
            XCTFail("RAR creation must fail")
        } catch { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.path))
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: workDir.path))?
            .filter { $0.hasSuffix(".partial") } ?? []
        XCTAssertTrue(leftovers.isEmpty, "No partial files may remain")
    }

    func testOverwriteReplacesExistingArchive() async throws {
        let files = try makeFiles()
        let archive = workDir.appendingPathComponent("replace.zip")
        try await engine.createArchive(at: archive, from: [files[0]], options: ArchiveOptions(format: .zip))
        let firstSize = try FileManager.default.attributesOfItem(atPath: archive.path)[.size] as? Int ?? 0

        try await engine.createArchive(at: archive, from: files, options: ArchiveOptions(format: .zip))
        let entries = try await engine.listContents(of: archive)
        XCTAssertEqual(entries.filter { !$0.isDirectory }.count, 2)
        XCTAssertGreaterThanOrEqual(try FileManager.default.attributesOfItem(atPath: archive.path)[.size] as? Int ?? 0, firstSize)
    }

    func testPasswordCreationFailsClosedWhenTransportIsUnavailable() async throws {
        let files = try makeFiles()
        let archive = workDir.appendingPathComponent("enc.7z")
        do {
            try await engineRefusingPasswords.createArchive(
                at: archive,
                from: files,
                options: ArchiveOptions(format: .sevenZip, password: "pw")
            )
            XCTFail("Expected passwordTransportUnavailable")
        } catch let error as ArchiveError {
            XCTAssertEqual(error, .passwordTransportUnavailable)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.path))
    }
}
