import XCTest
@testable import Mac7Zip

final class SubprocessTextDecoderTests: XCTestCase {
    func testUTF8Passthrough() {
        XCTAssertEqual(SubprocessTextDecoder.decode(Data("中文.txt".utf8)), "中文.txt")
    }

    func testGBKChineseDecodes() {
        // GBK bytes for "中文" are D6 D0 CE C4 (invalid as UTF-8).
        let gbk = Data([0xD6, 0xD0, 0xCE, 0xC4])
        XCTAssertEqual(SubprocessTextDecoder.decode(gbk), "中文")
    }

    func testInvalidBytesNeverDropped() {
        let garbage = Data([0xFF, 0xFE, 0x00, 0x41])
        XCTAssertFalse(SubprocessTextDecoder.decode(garbage).isEmpty, "Decoding must never drop the line")
    }

    func testOutputCollectorHandlesMultibyteSplitAcrossChunks() {
        var received: [String] = []
        let collector = OutputCollector(onLine: { line in received.append(line) })
        // Split a GBK two-character name across two pipe reads, at a byte boundary.
        collector.appendStdout(Data([0xD6]))
        collector.appendStdout(Data([0xD0, 0xCE, 0xC4]) + Data("\n".utf8))
        let snapshot = collector.snapshot()
        XCTAssertTrue(snapshot.stdout.contains("中文"), "split multibyte characters must survive")
        XCTAssertEqual(received, ["中文"])
    }

    func testOutputCollectorPreservesMixedContent() {
        let collector = OutputCollector(onLine: nil)
        collector.appendStdout(Data("Path = 报告/说明.txt\n".utf8))
        XCTAssertTrue(collector.snapshot().stdout.contains("报告/说明.txt"))
    }
}
