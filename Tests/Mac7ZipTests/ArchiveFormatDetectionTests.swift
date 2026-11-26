import XCTest
@testable import Mac7Zip

final class ArchiveFormatDetectionTests: XCTestCase {
    private func magic(_ bytes: [UInt8], padTo size: Int = 0) -> Data {
        var data = Data(bytes)
        if data.count < size { data.append(Data(repeating: 0, count: size - data.count)) }
        return data
    }

    // MARK: - Signatures

    func testSevenZipSignature() {
        XCTAssertEqual(ArchiveFormat.format(forMagic: magic([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C], padTo: 32)), .sevenZip)
    }

    func testZipFamilySignatures() {
        for signature: [UInt8] in [[0x50, 0x4B, 0x03, 0x04], [0x50, 0x4B, 0x05, 0x06], [0x50, 0x4B, 0x07, 0x08]] {
            XCTAssertEqual(ArchiveFormat.format(forMagic: magic(signature, padTo: 32)), .zip)
        }
    }

    func testRarSignatures() {
        XCTAssertEqual(ArchiveFormat.format(forMagic: magic([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00], padTo: 32)), .rar)
        XCTAssertEqual(ArchiveFormat.format(forMagic: magic([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00], padTo: 32)), .rar)
    }

    func testCompressedStreamSignatures() {
        XCTAssertEqual(ArchiveFormat.format(forMagic: magic([0x1F, 0x8B], padTo: 32)), .gzip)
        XCTAssertEqual(ArchiveFormat.format(forMagic: magic(Array("BZh9".utf8), padTo: 32)), .bzip2)
        XCTAssertEqual(ArchiveFormat.format(forMagic: magic([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00], padTo: 32)), .xz)
    }

    func testTarByUstarMagic() {
        var header = [UInt8](repeating: 0, count: 512)
        header.replaceSubrange(0..<4, with: Array("file".utf8))
        header.replaceSubrange(257..<262, with: Array("ustar".utf8))
        XCTAssertEqual(ArchiveFormat.format(forMagic: Data(header)), .tar)
    }

    /// Old tar has no "ustar" magic; the header checksum identifies it.
    func testTarByChecksum() {
        var header = [UInt8](repeating: 0, count: 512)
        header.replaceSubrange(0..<9, with: Array("oldstyle".utf8))
        // Checksum field: 8 spaces while summing.
        for index in 148..<156 { header[index] = 0x20 }
        let sum = header.reduce(0) { $0 + Int($1) }
        // Build the octal field explicitly: `String(format: "%o", Int)` passes the
        // wrong C type to a variadic, so the format is not reliable here.
        let octal = String(sum, radix: 8)
        XCTAssertFalse(octal.isEmpty)
        let padded = String(repeating: "0", count: max(0, 6 - octal.count)) + octal
        header.replaceSubrange(148..<148 + padded.count, with: Array(padded.utf8))
        header[148 + padded.count] = 0

        XCTAssertEqual(ArchiveFormat.format(forMagic: Data(header)), .tar)
    }

    func testUnknownBytesAreNotAnArchive() {
        XCTAssertNil(ArchiveFormat.format(forMagic: magic(Array("hello world".utf8), padTo: 512)))
        XCTAssertNil(ArchiveFormat.format(forMagic: Data()))
    }

    // MARK: - Name vs content

    func testNameDetectionStillWorksForCallersWithoutAFile() {
        XCTAssertEqual(ArchiveFormat.detectFromName(URL(fileURLWithPath: "/a/b.7z")), .sevenZip)
        XCTAssertEqual(ArchiveFormat.detectFromName(URL(fileURLWithPath: "/a/b.apk")), .zip)
        XCTAssertNil(ArchiveFormat.detectFromName(URL(fileURLWithPath: "/a/b.bin")))
    }

    /// The extension must not override the bytes: a real ZIP named `.7z` is a ZIP.
    func testContentBeatsAMisleadingExtension() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipFormatTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let misnamed = dir.appendingPathComponent("actually-zip.7z")
        var payload = Data([0x50, 0x4B, 0x03, 0x04])
        payload.append(Data(repeating: 0, count: 64))
        try payload.write(to: misnamed)

        XCTAssertEqual(ArchiveFormat.detect(from: misnamed), .zip)
    }

    func testDirectoryIsNeverAnArchive() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipFormatTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertNil(ArchiveFormat.detect(from: dir))
    }

    /// A real file with a misleading extension is identified by its content.
    func testContentDetectionIgnoresTheExtension() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mac7ZipFormatTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let disguised = dir.appendingPathComponent("actually-7z.bin")
        var payload = Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
        payload.append(Data(repeating: 0, count: 64))
        try payload.write(to: disguised)

        XCTAssertNil(ArchiveFormat.detectFromName(disguised))
        XCTAssertEqual(ArchiveFormat.detect(from: disguised), .sevenZip)
    }
}
