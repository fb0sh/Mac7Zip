import XCTest
@testable import Mac7Zip

private struct ProgressStubEngine: ArchiveEngine {
    func createArchive(at destination: URL, from sources: [URL], options: ArchiveOptions) async throws {}
    func extract(archive: URL, to destination: URL, options: ExtractOptions) async throws {}
    func listContents(of archive: URL) async throws -> [ArchiveEntry] { [] }
    func test(archive: URL) async throws -> ArchiveTestResult { ArchiveTestResult(passed: true, message: "ok") }

    func extract(archive: URL, to destination: URL, options: ExtractOptions,
                 progress: (@Sendable (Double, String?) -> Void)?) async throws {
        progress?(0.25, "a.txt")
        progress?(0.75, "b.txt")
    }

    func createArchive(at destination: URL, from sources: [URL], options: ArchiveOptions,
                       progress: (@Sendable (Double, String?) -> Void)?) async throws {
        progress?(0.5, "x")
    }
}

private final class Collect: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var values: [Double?] = []
    private(set) var items: [String?] = []
    func add(_ p: Double?, _ m: TaskMetrics) {
        lock.lock(); values.append(p); items.append(m.currentItem); lock.unlock()
    }
}

final class ProgressReportingTests: XCTestCase {
    func testExtractOperationForwardsPercentages() async throws {
        let op = ExtractOperation(
            engine: ProgressStubEngine(),
            archive: URL(fileURLWithPath: "/tmp/a.zip"),
            destination: URL(fileURLWithPath: "/tmp/out"),
            options: ExtractOptions(destination: URL(fileURLWithPath: "/tmp/out"))
        )
        let box = Collect()
        try await op.run { p, m in box.add(p, m) }
        XCTAssertTrue(box.values.contains(0.25))
        XCTAssertTrue(box.values.contains(0.75))
        XCTAssertEqual(box.values.last ?? nil, 1.0, "Should finish at 100%")
        XCTAssertTrue(box.items.contains("b.txt"))
    }

    func testCreateOperationForwardsPercentage() async throws {
        let op = CreateArchiveOperation(
            engine: ProgressStubEngine(),
            destination: URL(fileURLWithPath: "/tmp/a.7z"),
            sources: [URL(fileURLWithPath: "/tmp/x")],
            options: ArchiveOptions()
        )
        let box = Collect()
        try await op.run { p, m in box.add(p, m) }
        XCTAssertTrue(box.values.contains(0.5))
        XCTAssertEqual(box.values.last ?? nil, 1.0)
    }

    func testParseProgressFromCarriageReturnLines() {
        XCTAssertEqual(SevenZipOutputParser.parseProgressPercent("\r 42%"), 0.42)
        XCTAssertEqual(SevenZipOutputParser.parseProgressPercent("  7% 12 - file.bin"), 0.07)
        XCTAssertNil(SevenZipOutputParser.parseProgressPercent("no percent here"))
    }
}
