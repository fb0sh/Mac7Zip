import Foundation

/// Result of running one 7zz invocation.
struct ProcessResult: Sendable {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String

    var combinedDiagnostic: String {
        [standardError, standardOutput]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

/// Runs the bundled `7zz` helper as a subprocess.
///
/// Design points (ADR-005):
/// - stdout and stderr are drained **concurrently** so the pipe buffers can never
///   fill and deadlock the child.
/// - Passwords travel over **stdin** via an interactive `-p` prompt, never argv.
/// - Cancellation sends SIGINT, then SIGTERM, then SIGKILL after a grace period.
struct SevenZipProcessRunner: Sendable {
    let executableURL: URL
    var graceInterval: TimeInterval = 3
    var timeout: TimeInterval = 300

    init(executableURL: URL, graceInterval: TimeInterval = 3, timeout: TimeInterval = 300) {
        self.executableURL = executableURL
        self.graceInterval = graceInterval
        self.timeout = timeout
    }

    /// Builds the argv for a call. Password is deliberately never included.
    static func arguments(_ args: [String]) -> [String] { args }

    func run(
        arguments: [String],
        stdinLines: [String] = [],
        timeout: TimeInterval? = nil,
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "en_US.UTF-8"
        environment["LANG"] = "en_US.UTF-8"
        process.environment = environment

        let outPipe = Pipe()
        let errPipe = Pipe()
        let inPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = inPipe

        let collector = OutputCollector(onLine: onLine)
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            collector.appendStdout(data)
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            collector.appendStderr(data)
        }

        // Completion is delivered via the continuation, never by blocking a
        // cooperative thread with `waitUntilExit()` (that starves the pool).
        let waiter = ExitWaiter()
        process.terminationHandler = { finished in
            waiter.finish(finished.terminationStatus)
        }

        do {
            try process.run()
        } catch {
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }

        // Interactive prompts (e.g. password) are answered over stdin, never argv.
        // 7zz asks twice when *creating* an encrypted archive, hence `stdinLines`.
        if !stdinLines.isEmpty {
            inPipe.fileHandleForWriting.write(Data((stdinLines.joined(separator: "\n") + "\n").utf8))
        }
        try? inPipe.fileHandleForWriting.close()

        // Watchdog: never let a wedged child hang the caller forever.
        let effectiveTimeout = timeout ?? self.timeout
        let watchdog = Task.detached { [graceInterval, effectiveTimeout] in
            try? await Task.sleep(nanoseconds: UInt64(max(effectiveTimeout, 1) * 1_000_000_000))
            guard !Task.isCancelled, process.isRunning else { return }
            process.interrupt()
            try? await Task.sleep(nanoseconds: UInt64(graceInterval * 1_000_000_000))
            guard !Task.isCancelled, process.isRunning else { return }
            process.terminate()
            try? await Task.sleep(nanoseconds: UInt64(graceInterval * 1_000_000_000))
            guard !Task.isCancelled, process.isRunning else { return }
            kill(process.processIdentifier, SIGKILL)
        }

        let exitCode = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiter.attach(continuation)
            }
        } onCancel: {
            if process.isRunning { process.interrupt() }
        }

        watchdog.cancel()
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        // Final drain: bytes written just before exit may not have been delivered
        // to the readability handlers yet. Dropping them loses trailing output
        // (e.g. "Everything is Ok"), so read whatever is left.
        Self.drainRemaining(outPipe.fileHandleForReading, into: collector, isStdout: true)
        Self.drainRemaining(errPipe.fileHandleForReading, into: collector, isStdout: false)

        let snapshot = collector.snapshot()
        return ProcessResult(exitCode: exitCode, standardOutput: snapshot.stdout, standardError: snapshot.stderr)
    }

    /// Reads any buffered bytes left in a pipe after the child exited.
    private static func drainRemaining(_ handle: FileHandle, into collector: OutputCollector, isStdout: Bool) {
        var emptyStreak = 0
        while true {
            let data: Data
            do {
                data = try handle.read(upToCount: 65_536) ?? Data()
            } catch {
                return
            }
            if data.isEmpty {
                // The child may have exited microseconds before its final bytes
                // reached the pipe; retry a couple of times before giving up.
                emptyStreak += 1
                if emptyStreak >= 3 { return }
                usleep(5_000)
                continue
            }
            emptyStreak = 0
            if isStdout {
                collector.appendStdout(data)
            } else {
                collector.appendStderr(data)
            }
        }
    }
}

/// Bridges `Process` termination to an async continuation without blocking.
private final class ExitWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int32, Never>?
    private var finishedCode: Int32?

    func attach(_ continuation: CheckedContinuation<Int32, Never>) {
        lock.lock()
        if let code = finishedCode {
            lock.unlock()
            continuation.resume(returning: code)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func finish(_ code: Int32) {
        lock.lock()
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(returning: code)
        } else {
            finishedCode = code
            lock.unlock()
        }
    }
}

/// Thread-safe accumulator for subprocess output.
///
/// Stores **raw bytes** and decodes once at snapshot time, so non-UTF-8 (e.g. GBK
/// Chinese) names and multi-byte characters split across pipe reads are preserved.
final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutData = Data()
    private var stderrData = Data()
    private let onLine: (@Sendable (String) -> Void)?
    private var stdoutLineBuffer = Data()

    init(onLine: (@Sendable (String) -> Void)?) {
        self.onLine = onLine
    }

    func appendStdout(_ data: Data) {
        lock.lock()
        stdoutData.append(data)
        stdoutLineBuffer.append(data)
        let lines = Self.drainLines(&stdoutLineBuffer)
        lock.unlock()
        for line in lines { onLine?(line) }
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        stderrData.append(data)
        lock.unlock()
    }

    /// Splits complete lines (terminated by `\n`) out of the byte buffer.
    private static func drainLines(_ buffer: inout Data) -> [String] {
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            lines.append(SubprocessTextDecoder.decode(lineData))
        }
        return lines
    }

    func snapshot() -> (stdout: String, stderr: String) {
        lock.lock()
        defer { lock.unlock() }
        return (SubprocessTextDecoder.decode(stdoutData), SubprocessTextDecoder.decode(stderrData))
    }
}
