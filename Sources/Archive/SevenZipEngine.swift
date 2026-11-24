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
    /// ZIP-family code page for decoding legacy (non-UTF-8) file names, e.g. 936 = GBK.
    /// `nil` = auto-detect by retrying common code pages when names look garbled.
    static var zipCodePage: Int? = nil
    /// Code pages tried during auto-detection, in order of likelihood for CN/legacy archives.
    static let autoZipCodePages = [936, 950, 65001]
    private static var resolvedZipCodePage: [String: Int] = [:]

    static func isZipFamily(_ url: URL) -> Bool {
        ["zip", "apk", "jar", "epub", "cbz", "docx", "xlsx", "pptx", "odt"]
            .contains(url.pathExtension.lowercased())
    }

    private static func looksGarbled(_ entries: [ArchiveEntry]) -> Bool {
        entries.contains { $0.path.contains("\u{FFFD}") || $0.path.contains("?") }
    }

    private static func garbleScore(_ entries: [ArchiveEntry]) -> Int {
        entries.reduce(0) { partial, entry in
            partial + entry.path.filter { $0 == "\u{FFFD}" || $0 == "?" }.count
        }
    }
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
        let key = archive.path
        let explicit = Self.zipCodePage
        var codePage = explicit ?? Self.resolvedZipCodePage[key]
        var entries = try await listOnce(archive: archive, password: password, codePage: codePage)

        // Auto mode: if legacy ZIP names came out garbled, retry common code pages.
        if explicit == nil, Self.isZipFamily(archive), Self.looksGarbled(entries) {
            var best = entries
            var bestScore = Self.garbleScore(entries)
            var bestCodePage = codePage
            for candidate in Self.autoZipCodePages {
                if let attempt = try? await listOnce(archive: archive, password: password, codePage: candidate) {
                    let score = Self.garbleScore(attempt)
                    if score < bestScore {
                        bestScore = score; best = attempt; bestCodePage = candidate
                    }
                }
                if bestScore == 0 { break }
            }
            entries = best
            if let resolved = bestCodePage { Self.resolvedZipCodePage[key] = resolved }
        } else if let codePage {
            Self.resolvedZipCodePage[key] = codePage
        }

        // Last resort for ZIP: read original names from the central directory
        // (7-Zip may have replaced legacy names with '?' during listing).
        if Self.isZipFamily(archive), Self.looksGarbled(entries),
           let repaired = Self.repairZipNames(entries, archive: archive) {
            entries = repaired
        }
        return entries
    }

    /// Rebuilds entry paths from the ZIP central directory (authoritative names).
    static func repairZipNames(_ entries: [ArchiveEntry], archive: URL) -> [ArchiveEntry]? {
        guard let cd = ZipCentralDirectoryReader.entries(inFileAt: archive), cd.count == entries.count else {
            return nil
        }
        return zip(entries, cd).map { entry, raw in
            ArchiveEntry(
                path: raw.path,
                size: entry.size,
                packedSize: entry.packedSize,
                isDirectory: raw.isDirectory || entry.isDirectory,
                modificationDate: entry.modificationDate,
                crc: entry.crc,
                isEncrypted: entry.isEncrypted,
                method: entry.method,
                linkTarget: entry.linkTarget
            )
        }
    }

    private func listOnce(archive: URL, password: String?, codePage: Int?) async throws -> [ArchiveEntry] {
        var arguments = ["l", "-slt", "-sccUTF-8"]
        arguments.append(contentsOf: try passwordArguments(password))
        if let codePage, Self.isZipFamily(archive) {
            arguments.append("-mcp=\(codePage)")
        }
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
        try await createArchive(at: destination, from: sources, options: options, progress: nil)
    }

    func createArchive(
        at destination: URL, from sources: [URL], options: ArchiveOptions,
        progress: (@Sendable (Double, String?) -> Void)?
    ) async throws {
        guard options.format.canCreate else {
            throw ArchiveError.unsupportedFormat(options.format.displayName)
        }
        guard !sources.isEmpty else {
            throw ArchiveError.engineFailure(code: 7, diagnostic: "No sources selected")
        }

        // Write to a temporary file first so a failed/cancelled run never leaves a
        // half-written archive at the final path, and an existing file survives
        // until success (SPEC-CW FR-CW-09).
        let parent = destination.deletingLastPathComponent()
        let tempDestination = parent.appendingPathComponent(".mac7zip-\(UUID().uuidString).partial")

        // Resolve the password through the transport policy first: this throws
        // (fail closed) before anything is written.
        let passwordArguments = try passwordArguments(options.password)

        let request = CompressionRequest(
            sources: sources,
            destination: tempDestination,
            format: options.format,
            level: options.compressionLevel,
            method: nil,
            password: nil,
            encryptFileNames: options.encryptFileNames,
            advanced: options.advanced
        )
        var arguments = CompressionPlanner.arguments(for: request)
        arguments.insert("-bsp1", at: 1)
        // Insert password switches immediately before the destination path.
        if !passwordArguments.isEmpty {
            arguments.insert(contentsOf: passwordArguments, at: arguments.count - sources.count - 1)
        }

        let result: ProcessResult
        do {
            result = try await runner.run(arguments: arguments)
        } catch {
            try? FileManager.default.removeItem(at: tempDestination)
            throw error
        }

        if let error = ArchiveError.from(exitCode: result.exitCode, diagnostic: result.combinedDiagnostic) {
            try? FileManager.default.removeItem(at: tempDestination)
            throw error
        }

        // Promote the finished archive into place. Cleanup happens only if the
        // move did not consume the temp file — a `defer` here would delete it
        // before the move ran.
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: tempDestination, to: destination)
        } catch {
            try? fileManager.removeItem(at: tempDestination)
            throw error
        }
    }


    /// Builds the `7zz x` argument list. IMPORTANT: the archive path must come
    /// **before** the entry filters (7-Zip treats anything before the archive as a
    /// switch and at/after it as an archive; file filters belong after the archive).
    static func extractArguments(
        archive: URL,
        entries: [String]?,
        overwriteMode: OverwriteMode,
        passwordArguments: [String],
        codePage: Int?,
        outputDirectory: URL
    ) -> [String] {
        var arguments = ["x", "-sccUTF-8", "-y", "-ao\(overwriteMode.switchValue)"]
        arguments.append(contentsOf: passwordArguments)
        if let codePage { arguments.append("-mcp=\(codePage)") }
        arguments.append(archive.path)
        if let entries, !entries.isEmpty {
            arguments.append(contentsOf: entries)
        }
        arguments.append("-o\(outputDirectory.path)")
        return arguments
    }

    // MARK: - Extract

    func extract(archive: URL, to destination: URL, options: ExtractOptions) async throws {
        try await extract(archive: archive, to: destination, options: options, progress: nil)
    }

    func extract(
        archive: URL, to destination: URL, options: ExtractOptions,
        progress: (@Sendable (Double, String?) -> Void)?
    ) async throws {
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

        let codePage = Self.isZipFamily(archive)
            ? (Self.zipCodePage ?? Self.resolvedZipCodePage[archive.path]) : nil
        var arguments = Self.extractArguments(
            archive: archive,
            entries: options.entries,
            overwriteMode: options.overwriteMode,
            passwordArguments: try passwordArguments(options.password),
            codePage: codePage,
            outputDirectory: staging.url
        )
        arguments.insert("-bsp1", at: 1)

        let result = try await runner.run(arguments: arguments, onLine: { line in
            if let percent = SevenZipOutputParser.parseProgressPercent(line) { progress?(percent, nil) }
        })
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
