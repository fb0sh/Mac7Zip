import XCTest
@testable import Mac7Zip

final class ZipCentralDirectoryReaderTests: XCTestCase {
    private func u16(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    private func u32(_ v: Int) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }

    private func makeZip(entries: [(nameBytes: [UInt8], flags: Int, uncompressed: Int)]) -> Data {
        var cd: [UInt8] = []
        let cdStart = 0
        for e in entries {
            var rec: [UInt8] = []
            rec += u32(0x0201_4B50)          // signature
            rec += u16(20); rec += u16(20)   // version made/by
            rec += u16(e.flags); rec += u16(0) // flags, method
            rec += u16(0); rec += u16(0)     // time, date
            rec += u32(0)                    // crc
            rec += u32(e.uncompressed)       // compressed size
            rec += u32(e.uncompressed)       // uncompressed size
            rec += u16(e.nameBytes.count)    // name length
            rec += u16(0); rec += u16(0)     // extra, comment
            rec += u16(0); rec += u16(0)     // disk, internal attrs
            rec += u32(0); rec += u32(0)     // external attrs, local header offset
            rec += e.nameBytes
            cd += rec
        }
        var eocd: [UInt8] = []
        eocd += u32(0x0605_4B50)
        eocd += u16(0); eocd += u16(0)
        eocd += u16(entries.count); eocd += u16(entries.count)
        eocd += u32(cd.count); eocd += u32(cdStart)
        eocd += u16(0)
        return Data(cd + eocd)
    }

    func testParsesGBKName() throws {
        let gbk = [UInt8]([0xD6, 0xD0, 0xCE, 0xC4]) + Array(".txt".utf8) // 中文.txt in GBK
        let data = makeZip(entries: [(gbk, 0, 123)])
        let entries = try XCTUnwrap(ZipCentralDirectoryReader.entries(in: data))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "中文.txt")
        XCTAssertEqual(entries[0].uncompressedSize, 123)
        XCTAssertFalse(entries[0].isDirectory)
    }

    func testParsesUTF8FlaggedName() throws {
        let bytes = Array("报告.pdf".utf8)
        let data = makeZip(entries: [(bytes, 0x0800, 10)])
        let entries = try XCTUnwrap(ZipCentralDirectoryReader.entries(in: data))
        XCTAssertEqual(entries[0].path, "报告.pdf")
    }

    func testDirectoryEntry() throws {
        let gbk = [UInt8]([0xCE, 0xC4, 0xBC, 0xFE, 0xBC, 0xD0]) + [0x2F] // 文件夹/
        let data = makeZip(entries: [(gbk, 0, 0)])
        let entries = try XCTUnwrap(ZipCentralDirectoryReader.entries(in: data))
        XCTAssertEqual(entries[0].path, "文件夹/")
        XCTAssertTrue(entries[0].isDirectory)
    }

    func testNotAZipReturnsNil() {
        XCTAssertNil(ZipCentralDirectoryReader.entries(in: Data([0, 1, 2, 3, 4])))
    }
}
