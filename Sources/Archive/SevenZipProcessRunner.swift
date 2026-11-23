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
        password: String? = nil,
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

        // Password is written to stdin (interactive prompt). Never argv.
        if let password {
            let handle = inPipe.fileHandleForWriting
            handle.write(Data((password + "\n").utf8))
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
            await termination.value
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
