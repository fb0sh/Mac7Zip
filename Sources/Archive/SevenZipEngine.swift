import Foundation

/// Concrete `ArchiveEngine` backed by the bundled `7zz` helper.
///
/// Extraction is a staged pipeline (ADR-008):
/// 1. list entries and **validate** them (fail-closed),
/// 2. extract into a private `StagingArea`,
/// 3. monitor size/limits and re-validate,
/// 4. commit per-item into the destination.
///
/// Multi-file extraction is deliberately **not** whole-operation atomic.
/// How a password may reach 7zz.
///
/// **Verified 2026-11-23 on macOS 26 / 7-Zip 26.06:** the `-p` prompt reads from
/// the console and ignores piped stdin *and* a `script(1)` pseudo-terminal. There
/// is therefore no non-argv transport available. Mac7Zip refuses password
/// operations by default rather than silently exposing the password in `ps`.
enum PasswordTransport: Sendable {
    /// Fail closed (default). No insecure fallback.
    case unavailable
    /// Explicit opt-in: pass `-p<password>` in argv. Visible to other processes
    /// via `ps`; must only be used with the user's informed consent.
    case argvExplicit
}

struct SevenZipEngine: ArchiveEngine {
    let runner: SevenZipProcessRunner
    let validator: SecurityValidator
    let passwordTransport: PasswordTransport

    init(
        runner: SevenZipProcessRunner,
        validator: SecurityValidator = SecurityValidator(),
        passwordTransport: PasswordTransport = .unavailable
    ) {
        self.runner = runner
        self.validator = validator
        self.passwordTransport = passwordTransport
    }

    init(
        executableURL: URL,
        limits: ExtractionLimits = ExtractionLimits(),
        timeout: TimeInterval = 300,
        passwordTransport: PasswordTransport = .unavailable
    ) {
        self.runner = SevenZipProcessRunner(executableURL: executableURL, timeout: timeout)
        self.validator = SecurityValidator(limits: limits)
        self.passwordTransport = passwordTransport
    }

    /// Applies the password policy, returning the argv fragment to use.
    private func passwordArguments(_ password: String?) throws -> [String] {
        guard let password else { return [] }
        switch passwordTransport {
        case .unavailable:
            throw ArchiveError.passwordTransportUnavailable
        case .argvExplicit:
            return ["-p\(password)"]
        }
    }

    // MARK: - List

    func listContents(of archive: URL) async throws -> [ArchiveEntry] {
        try await listContents(of: archive, password: nil)
    }

    func listContents(of archive: URL, password: String?) async throws -> [ArchiveEntry] {
        var arguments = ["l", "-slt", "-sccUTF-8"]
        arguments.append(contentsOf: try passwordArguments(password))
        arguments.append(archive.path)
        let result = try await runner.run(arguments: arguments)
        let diagnostic = result.combinedDiagnostic

        if let error = ArchiveError.from(exitCode: result.exitCode, diagnostic: diagnostic) {
            if case .engineFailure = error, diagnostic.lowercased().contains("is not archive") {
                throw ArchiveError.corrupt(diagnostic)
            }
            throw error
        }
        return SevenZipOutputParser.parseListing(result.standardOutput)
    }

    // MARK: - Test

    func test(archive: URL) async throws -> ArchiveTestResult {
        let result = try await runner.run(arguments: ["t", "-sccUTF-8", archive.path])
        if let error = ArchiveError.from(exitCode: result.exitCode, diagnostic: result.combinedDiagnostic) {
            if case .engineFailure = error {
                return SevenZipOutputParser.parseTestResult(result.combinedDiagnostic)
            }
            throw error
        }
        return SevenZipOutputParser.parseTestResult(result.standardOutput)
    }

    // MARK: - Create

    func createArchive(at destination: URL, from sources: [URL], options: ArchiveOptions) async throws {
        guard options.format.canCreate else {
            throw ArchiveError.unsupportedFormat(options.format.displayName)
        }
        guard !sources.isEmpty else {
            throw ArchiveError.engineFailure(code: 7, diagnostic: "No sources selected")
        }

        var arguments = ["a", "-t\(options.format.switchValue)", "-mx\(max(0, min(9, options.compressionLevel)))", "-sccUTF-8"]
        if options.format == .sevenZip && options.encryptFileNames {
            arguments.append("-mhe")
        }
        arguments.append(contentsOf: try passwordArguments(options.password))
        arguments.append(destination.path)
        arguments.append(contentsOf: sources.map(\.path))

        let result = try await runner.run(arguments: arguments)
        if let error = ArchiveError.from(exitCode: result.exitCode, diagnostic: result.combinedDiagnostic) {
            throw error
        }
    }

    // MARK: - Extract

    func extract(archive: URL, to destination: URL, options: ExtractOptions) async throws {
        // 1. Validate before writing anything.
        let entries = try await listContents(of: archive, password: options.password)
        let violations = validator.validate(entries: entries, destination: destination)
        if let first = violations.first {
            throw ArchiveError.unsafeEntry(
                paths: violations.map(\.path).filter { !$0.isEmpty },
                reason: first.reason.rawValue
            )
        }

        // 2. Extract into a private staging area.
        let staging = try StagingArea()
        defer { staging.cleanUp() }

        var arguments = ["x", "-sccUTF-8", "-y", "-ao\(options.overwriteMode.switchValue)"]
        arguments.append(contentsOf: try passwordArguments(options.password))
        if let entriesToExtract = options.entries, !entriesToExtract.isEmpty {
            arguments.append(contentsOf: entriesToExtract)
        }
        arguments.append(archive.path)
        arguments.append("-o\(staging.url.path)")

        let result = try await runner.run(arguments: arguments)
        if let error = ArchiveError.from(exitCode: result.exitCode, diagnostic: result.combinedDiagnostic) {
            throw error
        }

        // 3. Enforce limits against what actually landed on disk.
        let written = staging.currentByteCount()
        if written > validator.limits.maxTotalBytes {
            throw ArchiveError.unsafeEntry(paths: [], reason: SecurityViolation.Reason.sizeLimitExceeded.rawValue)
        }

        // 4. Commit into the real destination.
        let target = destination
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try staging.commit(to: target)
    }
}
