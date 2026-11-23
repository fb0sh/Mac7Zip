import Foundation

/// Parses `7zz` text output into typed values. Pure functions over captured
/// output so parsing is unit-testable against real golden fixtures (no process).
enum SevenZipOutputParser {

    // MARK: - Listing (`l -slt`)

    /// Parses `7zz l -slt` output into entries.
    ///
    /// The format is a header block, a `----------` separator, then repeated
    /// `Key = Value` blocks per entry.
    static func parseListing(_ output: String) -> [ArchiveEntry] {
        guard let separatorRange = output.range(of: "----------") else { return [] }
        let entrySection = String(output[separatorRange.upperBound...])

        var entries: [ArchiveEntry] = []
        var current: [String: String] = [:]

        func flush() {
            guard let path = current["Path"], !path.isEmpty else {
                current = [:]
                return
            }
            let attributes = current["Attributes"] ?? ""
            let isDirectory = attributes.hasPrefix("D")
            let size = Int64(current["Size"] ?? "") ?? 0
            let packed = Int64(current["Packed Size"] ?? "") ?? 0
            let encrypted = (current["Encrypted"] ?? "-").contains("+")
            let method = current["Method"].flatMap { $0.isEmpty ? nil : $0 }
            let crc = current["CRC"].flatMap { $0.isEmpty ? nil : $0 }
            let modified = current["Modified"].flatMap { parseDate($0) }
            let linkTarget = current["Symbolic Link"].flatMap { $0.isEmpty ? nil : $0 }
                ?? (attributes.contains("l") ? (current["Target"] ?? nil) : nil)

            entries.append(
                ArchiveEntry(
                    path: path,
                    size: size,
                    packedSize: packed,
                    isDirectory: isDirectory,
                    modificationDate: modified,
                    crc: crc,
                    isEncrypted: encrypted,
                    method: method,
                    linkTarget: linkTarget
                )
            )
            current = [:]
        }

        for rawLine in entrySection.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flush()
                continue
            }
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<equals]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
            current[key] = value
        }
        flush()
        return entries
    }

    /// Detects archive-level metadata (type/method) from a listing header.
    static func parseListingHeader(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        let header = output.components(separatedBy: "----------").first ?? output
        for line in header.split(separator: "\n") {
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<equals]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { result[key] = value }
        }
        return result
    }

    // MARK: - Progress (`-bsp1`)

    /// Parses the latest percentage from progress output. Returns `nil` when no
    /// reliable percentage is present (never fabricates a value).
    static func parseProgressPercent(_ output: String) -> Double? {
        let normalized = output.replacingOccurrences(of: "\r", with: "\n")
        let pattern = #"(\d{1,3})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = normalized as NSString
        let matches = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length))
        guard let last = matches.last, last.numberOfRanges > 1 else { return nil }
        let value = ns.substring(with: last.range(at: 1))
        guard let percent = Double(value), (0...100).contains(percent) else { return nil }
        return percent / 100.0
    }

    /// Parses "Files read from disk: 3" style counters when present.
    static func parseFileCount(_ output: String) -> Int? {
        let pattern = #"Files read from disk:\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = output as NSString
        guard let match = regex.firstMatch(in: output, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        return Int(ns.substring(with: match.range(at: 1)))
    }

    // MARK: - Test (`t`)

    static func parseTestResult(_ output: String) -> ArchiveTestResult {
        let lower = output.lowercased()
        if lower.contains("everything is ok") {
            return ArchiveTestResult(passed: true, message: "Everything is Ok")
        }
        if lower.contains("is not archive") || lower.contains("cannot open the file as") {
            return ArchiveTestResult(passed: false, message: "Not a valid archive")
        }
        if lower.contains("wrong password") {
            return ArchiveTestResult(passed: false, message: "Wrong password")
        }
        if lower.contains("crc failed") || lower.contains("data error") {
            return ArchiveTestResult(passed: false, message: "Archive is damaged (CRC error)")
        }
        let errors = parseErrorLines(output)
        return ArchiveTestResult(
            passed: false,
            message: errors.isEmpty ? "Archive test failed" : errors.joined(separator: "; ")
        )
    }

    /// Extracts actionable error lines from a diagnostic dump.
    static func parseErrorLines(_ output: String) -> [String] {
        var errors: [String] = []
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("ERROR:") || line.hasPrefix("Open ERROR:") {
                errors.append(line.replacingOccurrences(of: "ERROR: ", with: ""))
            }
        }
        return errors
    }

    /// True when the diagnostic indicates a missing password rather than a wrong one.
    static func indicatesPasswordRequired(_ output: String) -> Bool {
        let lower = output.lowercased()
        return lower.contains("enter password") || lower.contains("password required")
    }

    // MARK: - Helpers

    /// 7zz emits `yyyy-MM-dd HH:mm:ss` with optional fractional seconds.
    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        for format in ["yyyy-MM-dd HH:mm:ss.SSSSSSS", "yyyy-MM-dd HH:mm:ss.SSS", "yyyy-MM-dd HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}
