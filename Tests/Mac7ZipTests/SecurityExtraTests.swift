import XCTest
@testable import Mac7Zip

final class SymlinkTargetValidationTests: XCTestCase {
    private let validator = SecurityValidator()
    private let dest = URL(fileURLWithPath: "/tmp/dest", isDirectory: true)

    func testAbsoluteSymlinkTargetRejected() {
        XCTAssertEqual(validator.symlinkTargetReason(entryPath: "a/link", linkTarget: "/etc/passwd"), .symlinkEscape)
    }

    func testRelativeEscapingTargetRejected() {
        XCTAssertEqual(validator.symlinkTargetReason(entryPath: "a/link", linkTarget: "../../etc/passwd"), .symlinkEscape)
    }

    func testSafeRelativeTargetAllowed() {
        XCTAssertNil(validator.symlinkTargetReason(entryPath: "a/link", linkTarget: "b.txt"))
        XCTAssertNil(validator.symlinkTargetReason(entryPath: "a/link", linkTarget: "../sibling.txt"))
    }

    func testEntryWithEscapingSymlinkFailsValidation() {
        let entry = ArchiveEntry(
            path: "a/link",
            size: 0, packedSize: 0, isDirectory: false,
            modificationDate: nil, crc: nil, isEncrypted: false, method: nil,
            linkTarget: "../../../etc/passwd"
        )
        let violations = validator.validate(entries: [entry], destination: dest)
        XCTAssertTrue(violations.contains { $0.reason == .symlinkEscape })
    }
}

final class ListingSymlinkParseTests: XCTestCase {
    func testParserCapturesSymbolicLinkTarget() {
        let output = """
        7-Zip (z) 26.06
        ----------
        Path = docs/link
        Size = 0
        Packed Size = 0
        Modified = 2026-11-23 10:00:00
        Attributes = A_ -rw-r--r--
        Symbolic Link = ../../etc/passwd
        CRC =
        Method = Store
        Encrypted = -

        """
        let entries = SevenZipOutputParser.parseListing(output)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.linkTarget, "../../etc/passwd")
    }
}

private struct SlowOperation: TaskOperation {
    let kind: TaskKind = .copy
    let title = "Slow op"
    func run(report: @escaping @Sendable (Double?, TaskMetrics) -> Void) async throws {
        for _ in 0..<50 {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

final class TaskCancellationTests: XCTestCase {
    func testCancelRunningOperation() async throws {
        let center = TaskCenter(maxConcurrency: 1)
        let id = await center.submit(SlowOperation())
        // Give it a moment to start.
        try await Task.sleep(nanoseconds: 30_000_000)
        await center.cancel(id)
        // Poll for terminal state.
        var state: TaskState?
        for _ in 0..<100 {
            if let record = await center.allRecords.first(where: { $0.id == id }) {
                state = record.state
                if record.state.isTerminal { break }
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(state, .cancelled)
    }
}
