import XCTest
@testable import Mac7Zip

private struct SleepyOperation: TaskOperation {
    let kind: TaskKind = .test
    let title: String
    let delay: UInt64
    let fail: Bool

    func run(report: @Sendable (Double?, TaskMetrics) -> Void) async throws {
        report(0.5, TaskMetrics())
        try await Task.sleep(nanoseconds: delay)
        report(1.0, TaskMetrics())
        if fail { throw ArchiveError.engineFailure(code: 2, diagnostic: "boom") }
    }
}

private actor Gate {
    private var open = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if open { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func openGate() {
        open = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

private struct GatedOperation: TaskOperation {
    let kind: TaskKind = .test
    let title: String
    let gate: Gate
    func run(report: @Sendable (Double?, TaskMetrics) -> Void) async throws {
        try await gate.wait()
    }
}

final class TaskCenterTests: XCTestCase {
    func testOperationRunsAndSucceeds() async throws {
        let center = TaskCenter()
        let id = await center.submit(SleepyOperation(title: "t", delay: 10_000_000, fail: false))
        try await Task.sleep(nanoseconds: 400_000_000)
        let records = await center.allRecords
        let record = try XCTUnwrap(records.first { $0.id == id })
        XCTAssertEqual(record.state, .succeeded)
        XCTAssertEqual(record.progress, 1.0)
        XCTAssertNotNil(record.startedAt)
        XCTAssertNotNil(record.endedAt)
    }

    func testOperationFailureIsRecorded() async throws {
        let center = TaskCenter()
        let id = await center.submit(SleepyOperation(title: "f", delay: 10_000_000, fail: true))
        try await Task.sleep(nanoseconds: 400_000_000)
        let records = await center.allRecords
        let record = try XCTUnwrap(records.first { $0.id == id })
        XCTAssertEqual(record.state, .failed)
        XCTAssertNotNil(record.errorDescription)
    }

    func testSerialQueueRunsOneAtATime() async throws {
        let center = TaskCenter(maxConcurrency: 1)
        let gateA = Gate()
        let a = await center.submit(GatedOperation(title: "a", gate: gateA))
        let b = await center.submit(GatedOperation(title: "b", gate: Gate()))

        // Deterministic: A is blocked inside run(), so B must stay queued.
        var records: [TaskRecord] = []
        for _ in 0..<100 {
            records = await center.allRecords
            if records.first(where: { $0.id == a })?.state == .running,
               records.first(where: { $0.id == b })?.state == .queued { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(records.first { $0.id == a }?.state, .running)
        XCTAssertEqual(records.first { $0.id == b }?.state, .queued)

        await gateA.openGate()
        for _ in 0..<200 {
            records = await center.allRecords
            if records.first(where: { $0.id == a })?.state == .succeeded,
               records.first(where: { $0.id == b })?.state == .running { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(records.first { $0.id == a }?.state, .succeeded)
    }

    func testCancelQueuedTask() async throws {
        let center = TaskCenter(maxConcurrency: 1)
        _ = await center.submit(SleepyOperation(title: "long", delay: 300_000_000, fail: false))
        let queued = await center.submit(SleepyOperation(title: "queued", delay: 1_000_000, fail: false))
        await center.cancel(queued)
        let records = await center.allRecords
        XCTAssertEqual(records.first { $0.id == queued }?.state, .cancelled)
    }

    func testIndeterminateProgressStaysNil() async throws {
        struct NilProgress: TaskOperation {
            let kind: TaskKind = .list
            let title = "nil"
            func run(report: @Sendable (Double?, TaskMetrics) -> Void) async throws {
                report(nil, TaskMetrics())
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        let center = TaskCenter()
        let id = await center.submit(NilProgress())
        try await Task.sleep(nanoseconds: 300_000_000)
        let records = await center.allRecords
        XCTAssertNil(records.first { $0.id == id }?.progress)
    }
}

final class ArchiveErrorMappingTests: XCTestCase {
    func testExitCodeMapping() {
        XCTAssertNil(ArchiveError.from(exitCode: 0, diagnostic: ""))
        XCTAssertEqual(ArchiveError.from(exitCode: 255, diagnostic: ""), .cancelled)
        XCTAssertEqual(ArchiveError.from(exitCode: 8, diagnostic: ""), .outOfMemory)
        if case .engineFailure(let code, _)? = ArchiveError.from(exitCode: 7, diagnostic: "bad switch") {
            XCTAssertEqual(code, 7)
        } else {
            XCTFail("Expected engineFailure for exit 7")
        }
    }

    func testWrongPasswordDetection() {
        XCTAssertEqual(
            ArchiveError.from(exitCode: 2, diagnostic: "Wrong password?"),
            .wrongPassword
        )
    }

    func testCorruptDetection() {
        if case .corrupt? = ArchiveError.from(exitCode: 2, diagnostic: "Can not open the file as archive") {
            // ok
        } else {
            XCTFail("Expected corrupt")
        }
    }

    func testRarCannotBeCreated() {
        XCTAssertFalse(ArchiveFormat.rar.canCreate)
        XCTAssertTrue(ArchiveFormat.sevenZip.canCreate)
        XCTAssertTrue(ArchiveFormat.zip.canCreate)
        XCTAssertTrue(ArchiveFormat.rar.canExtract)
    }

    func testFormatDetection() {
        XCTAssertEqual(ArchiveFormat.detect(from: URL(fileURLWithPath: "/tmp/a.7z")), .sevenZip)
        XCTAssertEqual(ArchiveFormat.detect(from: URL(fileURLWithPath: "/tmp/a.zip")), .zip)
        XCTAssertEqual(ArchiveFormat.detect(from: URL(fileURLWithPath: "/tmp/a.tar.gz")), .gzip)
        XCTAssertEqual(ArchiveFormat.detect(from: URL(fileURLWithPath: "/tmp/a.rar")), .rar)
        XCTAssertNil(ArchiveFormat.detect(from: URL(fileURLWithPath: "/tmp/a.txt")))
    }
}
