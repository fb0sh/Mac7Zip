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
struct SevenZipEngine: ArchiveEngine {
    let runner: SevenZipProcessRunner
    let validator: SecurityValidator

    init(runner: SevenZipProcessRunner, validator: SecurityValidator = SecurityValidator()) {
        self.runner = runner
        self.validator = validator
    }

    init(executableURL: URL, limits: ExtractionLimits = ExtractionLimits()) {
        self.runner = SevenZipProcessRunner(executableURL: executableURL)
        self.validator = SecurityValidator(limits: limits)
    }

    // MARK: - List

    func listContents(of archive: URL) async throws -> [ArchiveEntry] {
        let result = try await runner.run(arguments: ["l", "-slt", "-sccUTF-8", archive.path])
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
        if options.password != nil {
            // Interactive prompt; the password itself goes over stdin only.
            arguments.append("-p")
        }
        arguments.append(destination.path)
        arguments.append(contentsOf: sources.map(\.path))

        let result = try await runner.run(arguments: arguments, password: options.password)
        if let error = ArchiveError.from(exitCode: result.exitCode, diagnostic: result.combinedDiagnostic) {
            throw error
        }
    }

    // MARK: - Extract

    func extract(archive: URL, to destination: URL, options: ExtractOptions) async throws {
        // 1. Validate before writing anything.
        let entries = try await listContents(of: archive)
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
        if options.password != nil {
            arguments.append("-p")
        }
        if let entriesToExtract = options.entries, !entriesToExtract.isEmpty {
            arguments.append(contentsOf: entriesToExtract)
        }
        arguments.append(archive.path)
        arguments.append("-o\(staging.url.path)")

        let result = try await runner.run(arguments: arguments, password: options.password)
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
