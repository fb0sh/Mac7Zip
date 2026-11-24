import XCTest
@testable import Mac7Zip

/// Golden-file tests over **real** 7-Zip 26.06 output captured on macOS CI.
final class SevenZipOutputParserTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: name, withExtension: "txt", subdirectory: "Fixtures")
                ?? Bundle(for: Self.self).url(forResource: name, withExtension: "txt"),
            "Missing fixture \(name).txt"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testParsesListingEntries() throws {
        let output = try fixture("list-slt-7z")
        let entries = SevenZipOutputParser.parseListing(output)

        XCTAssertEqual(entries.count, 5, "src, src/sub, a.txt, b.txt, sub/c.txt")

        let names = Set(entries.map(\.path))
        XCTAssertTrue(names.contains("src"))
        XCTAssertTrue(names.contains("src/sub"))
        XCTAssertTrue(names.contains("src/a.txt"))

        let directory = try XCTUnwrap(entries.first { $0.path == "src" })
        XCTAssertTrue(directory.isDirectory)
        XCTAssertFalse(directory.isEncrypted)

        let file = try XCTUnwrap(entries.first { $0.path == "src/a.txt" })
        XCTAssertFalse(file.isDirectory)
        XCTAssertEqual(file.size, 12)
        XCTAssertNotNil(file.modificationDate)
        XCTAssertNotNil(file.method)
    }

    func testListingHeaderMetadata() throws {
        let output = try fixture("list-slt-7z")
        let header = SevenZipOutputParser.parseListingHeader(output)
        XCTAssertEqual(header["Type"], "7z")
        XCTAssertEqual(header["Solid"], "+")
        XCTAssertTrue((header["Method"] ?? "").contains("LZMA2"))
    }

    func testParsesProgressPercent() throws {
        let output = try fixture("progress-add-7z")
        let percent = SevenZipOutputParser.parseProgressPercent(output)
        XCTAssertEqual(percent, 0.0, "Captured run reports 0% for a tiny archive")
    }

    func testProgressReturnsNilWhenNoPercent() {
        XCTAssertNil(SevenZipOutputParser.parseProgressPercent("no numbers here"))
        XCTAssertNil(SevenZipOutputParser.parseProgressPercent(""))
    }

    func testParsesFileCount() throws {
        let output = try fixture("progress-add-7z")
        XCTAssertEqual(SevenZipOutputParser.parseFileCount(output), 3)
    }

    func testParsesSuccessfulTest() throws {
        let output = try fixture("test-ok-7z")
        let result = SevenZipOutputParser.parseTestResult(output)
        XCTAssertTrue(result.passed)
    }

    func testParsesCorruptArchive() throws {
        let output = try fixture("list-corrupt-7z")
        let result = SevenZipOutputParser.parseTestResult(output)
        XCTAssertFalse(result.passed)

        let errors = SevenZipOutputParser.parseErrorLines(output)
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.joined().lowercased().contains("cannot open the file as"))
    }

    func testDateParsing() {
        XCTAssertNotNil(SevenZipOutputParser.parseDate("2026-11-23 07:59:42.9876352"))
        XCTAssertNotNil(SevenZipOutputParser.parseDate("2026-11-23 07:59:42"))
        XCTAssertNil(SevenZipOutputParser.parseDate("not a date"))
    }

    func testEncryptedFlagParsing() {
        let synthetic = """
        ----------
        Path = secret.txt
        Size = 10
        Packed Size = 20
        Attributes = A
        Encrypted = +
        Method = AES-256
        CRC = ABCD1234

        """
        let entries = SevenZipOutputParser.parseListing(synthetic)
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].isEncrypted)
        XCTAssertEqual(entries[0].method, "AES-256")
        XCTAssertEqual(entries[0].crc, "ABCD1234")
    }
}
