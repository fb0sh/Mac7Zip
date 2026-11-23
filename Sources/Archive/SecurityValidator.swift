import Foundation

/// A refused archive entry, with the reason it was refused.
struct SecurityViolation: Equatable, Sendable {
    enum Reason: String, Sendable {
        case absolutePath
        case traversal
        case symlinkEscape
        case specialFile
        case sizeLimitExceeded
        case ratioExceeded
        case entryCountExceeded
    }

    let path: String
    let reason: Reason
}

/// Configurable limits with conservative defaults (ADR-008 / SPEC-SEC FR-SEC-06).
struct ExtractionLimits: Sendable, Equatable {
    var maxTotalBytes: Int64 = 4 * 1024 * 1024 * 1024
    var maxExpansionRatio: Double = 100
    var maxEntryCount: Int = 1_000_000
}

/// Validates archive entries before extraction. Fail-closed: any violation means
/// the whole extraction is refused (ADR-008).
struct SecurityValidator: Sendable {
    let limits: ExtractionLimits

    init(limits: ExtractionLimits = ExtractionLimits()) {
        self.limits = limits
    }

    /// Validates all entries against the destination root.
    /// - Returns: the offending violations (empty when safe).
    func validate(entries: [ArchiveEntry], destination: URL) -> [SecurityViolation] {
        var violations: [SecurityViolation] = []

        if entries.count > limits.maxEntryCount {
            violations.append(SecurityViolation(path: "", reason: .entryCountExceeded))
        }

        var totalBytes: Int64 = 0
        for entry in entries {
            totalBytes += max(0, entry.size)

            if let reason = pathReason(for: entry.path) {
                violations.append(SecurityViolation(path: entry.path, reason: reason))
                continue
            }

            // Special files are identified via attributes in listings; the parser
            // marks folders via `isDirectory`, so anything with a device/FIFO-like
            // name pattern is refused here as a belt-and-braces check.
            if isSpecialFile(entry.path) {
                violations.append(SecurityViolation(path: entry.path, reason: .specialFile))
            }

            // Expansion ratio guard (packed size 0 means "unknown"/stored).
            if entry.packedSize > 0, entry.size > 0 {
                let ratio = Double(entry.size) / Double(entry.packedSize)
                if ratio > limits.maxExpansionRatio {
                    violations.append(SecurityViolation(path: entry.path, reason: .ratioExceeded))
                }
            }
        }

        if totalBytes > limits.maxTotalBytes {
            violations.append(SecurityViolation(path: "", reason: .sizeLimitExceeded))
        }

        return violations
    }

    /// Rejects absolute paths and `..` traversal, returning the reason.
    func pathReason(for rawPath: String) -> SecurityViolation.Reason? {
        let path = rawPath.replacingOccurrences(of: "\\", with: "/")

        if path.hasPrefix("/") || path.hasPrefix("~") {
            return .absolutePath
        }
        // Windows-style drive letters are also absolute.
        if path.count >= 2, path[path.index(path.startIndex, offsetBy: 1)] == ":" {
            return .absolutePath
        }

        var depth = 0
        for component in path.split(separator: "/") {
            if component == ".." {
                depth -= 1
                if depth < 0 { return .traversal }
            } else if component == "." || component.isEmpty {
                continue
            } else {
                depth += 1
            }
        }
        return nil
    }

    /// Resolves an entry path against the destination and verifies containment.
    ///
    /// Absolute paths and escaping traversal are rejected up front: relying on
    /// `appendingPathComponent` alone is unsafe because it treats a leading `/`
    /// as a *relative* component (so "/etc/passwd" would look contained).
    func resolvesInsideDestination(_ rawPath: String, destination: URL) -> Bool {
        if pathReason(for: rawPath) != nil { return false }

        let candidate = destination
            .appendingPathComponent(rawPath)
            .standardizedFileURL
        let root = destination.standardizedFileURL.path
        let resolved = candidate.path
        return resolved == root || resolved.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    private func isSpecialFile(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        return name.hasPrefix("dev/") || name.hasSuffix(".fifo") || name.hasSuffix(".sock")
    }
}
