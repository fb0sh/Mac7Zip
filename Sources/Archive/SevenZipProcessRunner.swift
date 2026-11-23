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

    init(executableURL: URL, graceInterval: TimeInterval = 3) {
        self.executableURL = executableURL
        self.graceInterval = graceInterval
    }

    /// Builds the argv for a call. Password is deliberately never included.
    static func arguments(_ args: [String]) -> [String] { args }

    func run(
        arguments: [String],
        stdinLines: [String] = [],
        timeout: TimeInterval = 600,
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

        try process.run()

        // Interactive prompts (e.g. password) are answered over stdin, never argv.
        // 7zz asks twice when *creating* an encrypted archive, hence `stdinLines`.
        if !stdinLines.isEmpty {
            let handle = inPipe.fileHandleForWriting
            handle.write(Data((stdinLines.joined(separator: "\n") + "\n").utf8))
        }
        try? inPipe.fileHandleForWriting.close()

        // `waitUntilExit` is not cancellation-aware, but awaiting it from a task
        // whose parent was cancelled can surface `CancellationError`. The child's
        // exit status is what matters, so run it detached from the caller's
        // cancellation state.
        let termination = Task.detached { () -> Int32 in
            process.waitUntilExit()
            return process.terminationStatus
        }

        // Escalating cancellation: SIGINT -> SIGTERM -> SIGKILL. Runs only when
        // the caller actually cancels; it never fires on normal completion.
        let escalator = Task.detached { [graceInterval] in
            do {
                try await Task.sleep(nanoseconds: UInt64(graceInterval * 1_000_000_000))
                guard process.isRunning else { return }
                process.interrupt() // SIGINT
                try await Task.sleep(nanoseconds: UInt64(graceInterval * 1_000_000_000))
                guard process.isRunning else { return }
                process.terminate() // SIGTERM
                try await Task.sleep(nanoseconds: UInt64(graceInterval * 1_000_000_000))
                guard process.isRunning else { return }
                kill(process.processIdentifier, SIGKILL)
            } catch {
                // Cancelled because the process already finished.
            }
        }

        let exitCode = await withTaskCancellationHandler {
            await Self.awaitTermination(termination, process: process, timeout: timeout)
        } onCancel: {
            // Caller cancelled: begin the escalation immediately.
            if process.isRunning { process.interrupt() }
        }

        escalator.cancel()
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        let snapshot = collector.snapshot()
        return ProcessResult(exitCode: exitCode, standardOutput: snapshot.stdout, standardError: snapshot.stderr)
    }

    /// Waits for the child, but kills it if it exceeds `timeout` so a stuck
    /// prompt or a wedged 7zz can never hang the caller forever.
    private static func awaitTermination(
        _ termination: Task<Int32, Never>,
        process: Process,
        timeout: TimeInterval
    ) async -> Int32 {
        let deadline = Task.detached {
            try? await Task.sleep(nanoseconds: UInt64(max(timeout, 1) * 1_000_000_000))
        }
        let winner = await withTaskGroup(of: Bool.self) { group -> Bool in
            group.addTask {
                _ = await termination.value
                return true // process finished
            }
            group.addTask {
                await deadline.value
                return false // timed out
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        if !winner {
            if process.isRunning { process.terminate() }
            try? await Task.sleep(nanoseconds: 500_000_000)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            _ = await termination.value
        }
        deadline.cancel()
        return process.terminationStatus
    }
}

/// Thread-safe accumulator for subprocess output.
final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = ""
    private var stderr = ""
    private let onLine: (@Sendable (String) -> Void)?
    private var stdoutBuffer = ""
    private var stderrBuffer = ""

    init(onLine: (@Sendable (String) -> Void)?) {
        self.onLine = onLine
    }

    func appendStdout(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        lock.lock()
        stdout += text
        stdoutBuffer += text
        let lines = drainLines(&stdoutBuffer)
        lock.unlock()
        lines.forEach { onLine?($0) }
    }

    func appendStderr(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        lock.lock()
        stderr += text
        stderrBuffer += text
        _ = drainLines(&stderrBuffer)
        lock.unlock()
    }

    private func drainLines(_ buffer: inout String) -> [String] {
        var lines: [String] = []
        while let range = buffer.range(of: "\n") {
            lines.append(String(buffer[buffer.startIndex..<range.lowerBound]))
            buffer = String(buffer[range.upperBound...])
        }
        return lines
    }

    func snapshot() -> (stdout: String, stderr: String) {
        lock.lock()
        defer { lock.unlock() }
        return (stdout, stderr)
    }
}
