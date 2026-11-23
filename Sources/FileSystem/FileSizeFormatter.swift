import Foundation

/// Deterministic, locale-independent byte-count formatting used by the status
/// bar and the size column. Implemented locally (rather than with
/// `ByteCountFormatter`) so tests can assert exact strings.
enum FileSizeFormatter {
    private static let units = ["KB", "MB", "GB", "TB", "PB", "EB"]

    static func string(fromByteCount bytes: Int64) -> String {
        if bytes <= 0 { return "0 bytes" }
        if bytes < 1000 { return "\(bytes) bytes" }

        var value = Double(bytes)
        var unitIndex = -1
        while value >= 1000 && unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }

        let formatted: String
        if value >= 100 || value.truncatingRemainder(dividingBy: 1) == 0 {
            formatted = String(format: "%.0f", value)
        } else {
            formatted = String(format: "%.1f", value)
        }
        return "\(formatted) \(units[unitIndex])"
    }
}
